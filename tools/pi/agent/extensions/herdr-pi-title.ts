// Reports pi's session display name to Herdr as the pane's agent *title*.
//
// Herdr's Auto Title plugin (herdr.auto-title) names a tab after the highest
// source it can find. The "agent title" rung (confidence 90) reads
// `PaneInfo.title`, which an integration sets through `pane.report_metadata`.
// Herdr's own pi integration (`herdr integration install pi`, written to
// extensions/herdr-agent-state.ts) reports the agent's state and session but
// never its title, so Auto Title has nothing but the terminal title to go on —
// and pi's terminal title is the static `π - <dir>`, not the session's topic.
//
// This extension is the missing half. It is deliberately a *separate* file:
// Herdr owns herdr-agent-state.ts and overwrites it on every integration
// install/update, so the hook has to live beside it.
//
// pi has no auto-titling of its own: a session name is set by `/name`, by
// `pi --name`, or by an extension. So when pi starts a session in Herdr with no
// name, this asks the active model for a short task title and sets it as the
// session name, the way pi-sidebar-tui labels its panel. If generation is slow
// or fails, the opening prompt is summarised instead, so Auto Title always gets
// something. A name the user sets is never overwritten, and a name this hook
// seeded earlier is re-generated on the next prompt after a reload or resume.
//
// Titles are reported with a TTL and refreshed on a heartbeat, so a pi that
// dies without a clean shutdown stops naming its tab within the TTL instead of
// freezing it. `session_shutdown` clears it immediately on the tidy path.

import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import net from 'node:net';

const HERDR_ENV = process.env.HERDR_ENV;
const socketPath = process.env.HERDR_SOCKET_PATH;
const socketEndpoint = process.platform === 'win32' && socketPath ? `\\\\.\\pipe\\${socketPath}` : socketPath;
const paneId = process.env.HERDR_PANE_ID;

// Distinct from herdr:pi (the managed integration's source) so the two never
// clear each other's metadata.
const source = 'herdr:pi-title';

// Long enough that a missed heartbeat does not blink the title off, short
// enough that a dead pi stops naming its tab promptly.
const ttlMs = 300_000;
const heartbeatMs = 120_000;

function enabled(): boolean {
	return HERDR_ENV === '1' && !!socketPath && !!paneId;
}

// The padding a first prompt usually carries, stripped so the title starts at
// the task rather than at the asking of it.
const fillerPrefix =
	/^(can you |could you |please |i want you to |i'd like you to |i need you to |help me |i need to |let's |let us )+/i;
const wrapperPrefix =
	/^(use|create|run|make|build|write|add|generate|implement|spawn|start)\s+(?:(?:a|an|the|some|my|one)\s+)?(?:\w+\s+){0,3}(?:to|that|which|for)\s+/i;

function summarize(prompt: string): string | undefined {
	const firstLine = prompt
		.split('\n')
		.map((line) => line.trim())
		.find((line) => line.length > 0);
	if (!firstLine) {
		return undefined;
	}

	const stripped = firstLine.replace(fillerPrefix, '').replace(wrapperPrefix, '').trim();
	if (!stripped) {
		return undefined;
	}

	const title = (stripped.charAt(0).toUpperCase() + stripped.slice(1)).slice(0, 60).trim();
	return title ? title : undefined;
}

// A short, action-first phrase with no trailing punctuation. Tighter than the
// 5-7 words pi-sidebar-tui asks for its panel, because a tab is narrower than
// the sidebar.
const titlePrompt =
	'Write a 3-5 word task title for this request. Start with an action verb. No punctuation. Output only the title.';

// A generation that has not answered by now is slow enough that the prompt
// summary is worth showing, and the model title can replace it later.
const fallbackDelayMs = 4000;

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
	return new Promise((resolve, reject) => {
		const timer = setTimeout(() => reject(new Error('title generation timed out')), ms);
		timer.unref?.();
		promise.then(
			(value) => {
				clearTimeout(timer);
				resolve(value);
			},
			(error) => {
				clearTimeout(timer);
				reject(error);
			}
		);
	});
}

function tidyTitle(text: string): string | undefined {
	const cleaned = text
		.replace(/^[\s"'`]+/, '')
		.replace(/[\s"'`]+$/, '')
		.replace(/[.!?]+$/, '')
		.trim();
	if (!cleaned || cleaned.length > 80) {
		return undefined;
	}

	return cleaned.slice(0, 60);
}

// The model context is read loosely: this runs against whatever provider the
// session is using, and none of it is worth failing a turn over.
type TitleContext = {
	modelRegistry?: {
		getAll?: () => Array<{ id?: string }>;
		streamSimple?: (model: unknown, context: unknown, options: unknown) => { result: () => Promise<unknown> };
	};
	model?: { id?: string };
	sessionManager?: { getBranch?: () => unknown[] };
};

// The first thing the user typed, read back from the session. On a reload or
// resume it is how a title this extension seeded earlier is recognised and
// re-generated, rather than left as a raw prompt.
function firstPrompt(ctx: TitleContext): string | undefined {
	try {
		const branch = (ctx.sessionManager?.getBranch?.() ?? []) as Array<{
			type?: string;
			message?: { role?: string; content?: unknown };
		}>;
		for (const entry of branch) {
			if (entry?.type !== 'message' || entry?.message?.role !== 'user') {
				continue;
			}
			const content = entry.message.content;
			const text =
				typeof content === 'string'
					? content
					: Array.isArray(content)
						? ((content.find((part) => (part as { type?: string })?.type === 'text') as { text?: string } | undefined)
								?.text ?? '')
						: '';
			if (text.trim()) {
				return text;
			}
		}
	} catch {
		// A session without a readable branch simply has no opening prompt.
	}

	return undefined;
}

async function generateTitle(prompt: string, ctx: TitleContext): Promise<string | undefined> {
	try {
		const registry = ctx.modelRegistry;
		const model = ctx.model;
		if (!registry?.streamSimple || !model) {
			return undefined;
		}

		const fullModel = registry.getAll?.().find((candidate) => candidate.id === model.id) ?? model;
		const stream = registry.streamSimple(
			fullModel,
			{ messages: [{ role: 'user', content: `${titlePrompt}\n\n${prompt.slice(0, 500)}` }] },
			{ maxTokens: 24, reasoning: 'off' }
		);

		const message = (await withTimeout(stream.result(), 12_000)) as
			{ content?: Array<{ type?: string; text?: string }> } | undefined;
		const text = message?.content?.find((part) => part?.type === 'text')?.text;
		return text ? tidyTitle(text) : undefined;
	} catch {
		return undefined;
	}
}

function sendRequest(request: unknown, timeoutMs = 1000): Promise<boolean> {
	if (!enabled()) {
		return Promise.resolve(true);
	}

	return new Promise((resolve) => {
		let done = false;
		let timeout: ReturnType<typeof setTimeout> | undefined;
		const finish = (delivered: boolean) => {
			if (done) return;
			done = true;
			if (timeout) clearTimeout(timeout);
			socket.destroy();
			resolve(delivered);
		};

		const socket = net.createConnection(socketEndpoint!);
		socket.on('error', () => finish(false));
		socket.on('connect', () => socket.write(`${JSON.stringify(request)}\n`));
		socket.on('data', () => finish(true));
		socket.on('end', () => finish(false));
		timeout = setTimeout(() => finish(false), timeoutMs);
		timeout.unref?.();
	});
}

function reportTitle(title: string | undefined): Promise<void> {
	const params: Record<string, unknown> = {
		pane_id: paneId,
		source
	};

	if (title) {
		params.title = title;
		params.ttl_ms = ttlMs;
	} else {
		params.clear_title = true;
	}

	return sendRequest({
		id: `${source}:${Date.now()}:${Math.random().toString(36).slice(2)}`,
		method: 'pane.report_metadata',
		params
	}).then(() => undefined);
}

export default function herdrPiTitleExtension(pi: ExtensionAPI): void {
	if (!enabled()) {
		return;
	}

	let reported: string | undefined;
	let heartbeat: ReturnType<typeof setInterval> | undefined;
	let active = false;
	// The prompt summary this extension set, if the model was slow. It is the
	// only name the model title is allowed to replace.
	let seeded: string | undefined;
	let generationStarted = false;

	function currentName(): string | undefined {
		try {
			const name = pi.getSessionName?.();
			return typeof name === 'string' && name.trim() ? name.trim() : undefined;
		} catch {
			return undefined;
		}
	}

	// Re-reads the name. An unchanged name is still re-reported so the TTL is
	// refreshed while pi runs; a name that went away clears the title.
	function sync(): void {
		const name = currentName();
		const changed = name !== reported;
		reported = name;
		if (changed || name) {
			void reportTitle(name);
		}
	}

	pi.on('session_start', async (_event, ctx) => {
		// TUI only: RPC/JSON/print modes have no PTY for Herdr to name.
		if (ctx?.mode !== 'tui') {
			return;
		}
		active = true;
		sync();
		if (!heartbeat) {
			heartbeat = setInterval(sync, heartbeatMs);
			heartbeat.unref?.();
		}
	});

	pi.on('before_agent_start', (event, ctx) => {
		if (ctx?.mode !== 'tui') {
			return;
		}

		const existing = currentName();
		const opener = firstPrompt(ctx);
		// A name equal to the summary of the opening prompt is one an earlier run
		// of this extension seeded: re-title it rather than keep the raw prompt.
		const ours = existing !== undefined && opener !== undefined && existing === summarize(opener);
		if (existing && !ours) {
			// The user's or another extension's name: leave it be.
			generationStarted = true;
			return;
		}
		if (generationStarted) {
			return;
		}
		generationStarted = true;
		if (ours) {
			seeded = existing;
		}

		const prompt = (ours ? opener : typeof event?.prompt === 'string' ? event.prompt : '') ?? '';
		const fallback = summarize(prompt);

		// Only reach for the summary if the model has not answered in time, so
		// the tab usually gets the short title and never flashes the raw prompt.
		const timer =
			!ours && fallback
				? setTimeout(() => {
						if (currentName()) {
							return;
						}
						seeded = fallback;
						try {
							pi.setSessionName(fallback);
						} catch {
							// A session that cannot be named yet is not worth failing the turn for.
						}
					}, fallbackDelayMs)
				: undefined;
		timer?.unref?.();

		void generateTitle(prompt, ctx).then((title) => {
			if (timer) {
				clearTimeout(timer);
			}
			const name = currentName();
			// A name that is neither ours nor the seed was set while we generated.
			if (name && name !== seeded) {
				return;
			}
			const chosen = title ?? fallback;
			if (!chosen) {
				return;
			}
			try {
				// Fires session_info_changed, which reports it; the next poll of Auto
				// Title names the tab.
				pi.setSessionName(chosen);
			} catch {
				// As above.
			}
		});
	});

	pi.on('session_info_changed', (event, ctx) => {
		if (ctx?.mode !== 'tui') {
			return;
		}
		active = true;
		reported = typeof event?.name === 'string' && event.name.trim() ? event.name.trim() : undefined;
		void reportTitle(reported);
	});

	pi.on('session_shutdown', () => {
		if (heartbeat) {
			clearInterval(heartbeat);
			heartbeat = undefined;
		}
		if (active) {
			// Best effort: clear the title so Auto Title can fall back immediately.
			void reportTitle(undefined);
		}
	});
}
