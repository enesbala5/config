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
// name, this names the tab from the opening prompt and then asks a model for a
// better one. Both are cut to four words here, so no title reaches the tab
// longer than that. A name the user sets is never overwritten, and a name this
// hook seeded earlier is re-generated on the next prompt after a reload or
// resume.
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
	/^(use|create|run|make|build|write|add|generate|implement|spawn|start)\s+(?:(?:a|an|the|some|my|one)\s+)?(?:\S+\s+){0,4}(?:to|that|which|for)\s+/i;

// A tab is a few characters wide, so the ceiling is words, not characters. Four
// is the widest that still reads in the sidebar, and both the model title and
// the prompt fallback are cut here, so no title can arrive longer than that.
const maxTitleWords = 4;
const maxTitleChars = 40;

// Words that carry no task. Dropped at the start of a title, and again at the
// end after the cut, so a title never ends on "and", "for", or "to".
const stopWords = new Set(
	('a an the and or but then to for with of in on at by from into as if is are was were be been being it its this that these those ' +
		'i me my we our you your he she they them do does did can could would should will just so ok okay also about how what when where why please help need want like')
		.split(' ')
);

// A token worth keeping in a title: it starts with a letter or digit and holds
// no path, URL, slash command, or flag.
const titleToken = /^[\p{L}\p{N}][\p{L}\p{N}'’.+&-]*$/u;

// A title holds words, so quotes, backticks, and a slash command's leading
// punctuation come off before the token is judged. A path keeps its last
// segment, which is the part that names the work.
function bareWord(token: string): string | undefined {
	let word = token;
	if (word.includes('/')) {
		const segments = word.split('/').filter((segment) => segment.length > 0);
		if (segments.length < 2) {
			return undefined;
		}
		word = segments[segments.length - 1]!;
	}

	const bare = word.replace(/^[^\p{L}\p{N}]+/u, '').replace(/[^\p{L}\p{N}]+$/u, '');
	return bare && titleToken.test(bare) ? bare : undefined;
}

// Caps a title at maxTitleWords and makes it read as a label: no code, no
// paths, no slash commands, no trailing punctuation.
function shorten(text: string): string | undefined {
	const tokens = text
		.replace(/`[^`]*`/g, ' ')
		.split(/\s+/)
		.map(bareWord)
		.filter((token): token is string => token !== undefined);

	while (tokens.length > 0 && stopWords.has(tokens[0]!.toLowerCase())) {
		tokens.shift();
	}

	const kept = tokens.slice(0, maxTitleWords);
	while (kept.length > 1 && stopWords.has(kept[kept.length - 1]!.toLowerCase())) {
		kept.pop();
	}

	const words = kept.map((word) => word.replace(/[-.]+$/, '')).filter((word) => word.length > 0);
	if (words.length === 0) {
		return undefined;
	}

	const title = words.join(' ');
	return (title.charAt(0).toUpperCase() + title.slice(1)).slice(0, maxTitleChars).trim() || undefined;
}

// The prompt's first line, cut down to a tab-sized label. Used as the name the
// tab carries before the model answers, and as the one it falls back to.
function summarize(prompt: string): string | undefined {
	const firstLine = prompt
		.split('\n')
		.map((line) => line.trim())
		.find((line) => line.length > 0);
	if (!firstLine) {
		return undefined;
	}

	const stripped = firstLine.replace(fillerPrefix, '').replace(wrapperPrefix, '').trim();
	return shorten(stripped || firstLine);
}

// A name that is a leading slice of the opening prompt is one an older version
// of this hook wrote: the model title never arrived, so the raw prompt was cut
// to fit. Recognising it lets the tab be re-titled instead of keeping it.
function seededFromPrompt(name: string, opener: string | undefined): boolean {
	const firstLine = opener
		?.split('\n')
		.map((line) => line.trim())
		.find((line) => line.length > 0);
	if (!firstLine) {
		return false;
	}

	// Short names are the user's; a cut prompt is long by definition.
	if (name.length < 12) {
		return false;
	}

	const bare = firstLine.replace(fillerPrefix, '').replace(wrapperPrefix, '').trim() || firstLine;
	const named = name.toLowerCase();
	return bare.toLowerCase().startsWith(named) || firstLine.toLowerCase().startsWith(named);
}

// A short, action-first phrase with no trailing punctuation. Tighter than the
// 5-7 words pi-sidebar-tui asks for its panel, because a tab is narrower than
// the sidebar.
const titlePrompt =
	'Write a 2-4 word task title for this request. Never more than 4 words. Start with an action verb. No punctuation, no quotes. Output only the title.';

// A generation that has not answered by now is not worth waiting for: the tab
// already carries the prompt summary, and a late title would only flicker it.
const titleTimeoutMs = 8000;

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

// The model is asked for four words, this is what makes that true.
function tidyTitle(text: string): string | undefined {
	const cleaned = text
		.replace(/^[\s"'`]+/, '')
		.replace(/[\s"'`]+$/, '')
		.split('\n')[0]!
		.trim();
	if (!cleaned || cleaned.length > 120) {
		return undefined;
	}

	return shorten(cleaned);
}

// The model context is read loosely: this runs against whatever provider the
// session is using, and none of it is worth failing a turn over.
type TitleMessage = { content?: Array<{ type?: string; text?: string }> };

type TitleContext = {
	modelRegistry?: {
		complete?: (model: unknown, context: unknown, options: unknown) => Promise<TitleMessage>;
		getAvailable?: () => TitleModel[];
	};
	model?: TitleModel;
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

type TitleModel = { id?: string; provider?: string };

// The cheaper end of the catalog, tried after the session's own model. A title
// is a two-dollar question; a flash or mini model answers it in a second and
// does not compete with the turn the user is waiting on.
const cheapModel = /(flash|mini|nano|haiku|lite|fast|small)/i;

// The session's model first, then a cheap model on a provider that has
// credentials. The second rung exists because the session model can be one
// whose provider cannot answer a direct call at all.
function titleCandidates(ctx: TitleContext): TitleModel[] {
	const own = ctx.model;
	const others = (ctx.modelRegistry?.getAvailable?.() ?? []).filter(
		(candidate) => !own || candidate.id !== own.id || candidate.provider !== own.provider
	);
	const cheap = others.filter((candidate) => cheapModel.test(candidate.id ?? ''));
	const ordered = [...cheap, ...others].slice(0, 2);
	return own ? [own, ...ordered] : ordered;
}

async function generateTitle(prompt: string, ctx: TitleContext): Promise<string | undefined> {
	const registry = ctx.modelRegistry;
	if (!registry?.complete) {
		return undefined;
	}

	// `complete` rather than `streamSimple`: one promise, no stream to drain.
	//
	// A candidate is used as the registry hands it over. Model ids repeat across
	// providers (`gpt-6.1-sol` is both an `openai` and an `azure` entry), so
	// looking one up by id alone returns the other provider and fails with
	// "provider is not configured" — which is why titles used to fall back to the
	// raw prompt. The budget is generous because a reasoning model spends part of
	// it before the title, and a tight one returns no text at all.
	for (const model of titleCandidates(ctx)) {
		try {
			const message = await withTimeout(
				registry.complete(
					model,
					{
						systemPrompt: titlePrompt,
						messages: [{ role: 'user', content: [{ type: 'text', text: prompt.slice(0, 500) }], timestamp: Date.now() }]
					},
					{ maxTokens: 256 }
				),
				titleTimeoutMs
			);

			const title = tidyTitle(message?.content?.find((part) => part?.type === 'text')?.text ?? '');
			if (title) {
				return title;
			}
		} catch {
			// A provider that cannot answer is not worth failing a turn over; the
			// next candidate, or the prompt summary already on the tab, stands in.
		}
	}

	return undefined;
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
		// A name equal to the summary of the opening prompt, or a leading slice of
		// it, is one an earlier run of this extension seeded: re-title it rather
		// than keep the raw prompt.
		const ours =
			existing !== undefined && (seededFromPrompt(existing, opener) || existing === summarize(opener ?? ''));
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

		// Name the tab immediately with the prompt summary, then let the model
		// replace it. Waiting for the model is what used to leave the tab on the
		// raw first line whenever generation failed or was slow.
		if (fallback) {
			seeded = fallback;
			try {
				pi.setSessionName(fallback);
			} catch {
				// A session that cannot be named yet is not worth failing the turn for.
			}
		}

		void generateTitle(prompt, ctx).then((title) => {
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
