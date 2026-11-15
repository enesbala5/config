// Names Pi sessions for both Herdr TUI and Desktop/core.
//
// Pi emits its session name in the native OSC terminal title; Desktop/core
// consumes that directly. Unnamed sessions otherwise show only `π - <dir>`.
// The TUI additionally needs pane.report_metadata so its Auto Title plugin
// can rank the agent title above terminal/process fallbacks. Its metadata has
// a TTL, heartbeat, and best-effort shutdown clear. Never use that protocol on
// the Desktop/core socket: these are separate Herdr runtimes.
//
// Keep this separate from Herdr's managed herdr-agent-state.ts, which is
// overwritten on integration updates and does not supply a task title.
//
// Seed an unnamed session from its opening prompt, then ask a model for a
// distinctive subject-first title (up to four words). Preserve identifiers
// such as PR #401. Explicit user names are left alone. Reload/resume can name
// an existing unnamed conversation immediately, without another user turn.

import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent';
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

function tuiEnabled(): boolean {
	return HERDR_ENV === '1' && !!socketPath && !!paneId;
}

function enabled(): boolean {
	// Desktop/core uses HC_* rather than the unrelated TUI socket protocol.
	// Naming the Pi session emits its native OSC terminal title, which core
	// already consumes. Never send pane.report_metadata to a core socket.
	return tuiEnabled() || !!process.env.HC_TERMINAL_ID;
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
const titleToken = /^(?:#[0-9]+|[\p{L}\p{N}][\p{L}\p{N}'’.+&-]*)$/u;

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

	const bare = word.replace(/^[^\p{L}\p{N}#]+/u, '').replace(/[^\p{L}\p{N}]+$/u, '');
	return bare && titleToken.test(bare) ? bare : undefined;
}

// Caps a title at maxTitleWords and makes it read as a label: no code, no
// paths, no slash commands, no trailing punctuation.
function shorten(text: string): string | undefined {
	const tokens = text
		.replace(/`/g, '')
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

// The prompt's first line, condensed to a subject-first label. Used as the name the
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
	const normalized = (stripped || firstLine)
		.replace(/https?:\/\/github\.com\/[^/\s]+\/([^/\s]+)\/pull\/(\d+)\S*/gi, '$1 PR #$2')
		.replace(/\bpull request\s*#?(\d+)/gi, 'PR #$1');
	const action = normalized.match(/^(review(?:ing)?|fix(?:ing)?|debug(?:ging)?|implement(?:ing)?|add(?:ing)?|update|build(?:ing)?)\b\s*/i);
	const subject = action ? normalized.slice(action[0].length) : normalized;
	const words = subject.split(/\s+/).map(bareWord)
		.filter((word): word is string => !!word && !stopWords.has(word.toLowerCase()));
	const verb = action?.[1]?.replace(/^(review|fix|debug|implement|add|build)(?:ing)?$/i, '$1');
	// Reserve a word for the activity, with the identifying subject first.
	return shorten([...words.slice(0, verb ? maxTitleWords - 1 : maxTitleWords), ...(verb ? [verb] : [])].join(' '));
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

// Identifying information comes before the activity so neighboring tabs are
// distinguishable even when their labels are truncated.
const titlePrompt =
	'Write a distinctive 2-4 word tab title for this request. Never more than 4 words. ' +
	'Lead with the concrete project, feature, component, or topic, then the activity. ' +
	'Preserve identifying PR/issue numbers (including #), names, and acronyms. ' +
	'Use the working directory only when it identifies the project; never invent details. ' +
	'Avoid generic titles such as Reviewing pull request or Fixing bugs. ' +
	'Good examples: SEO PR #401 Review; Coverlttr Stripe Webhooks; Herdr Pi Desktop Titles. ' +
	'No quotes or decorative punctuation. Output only the title.';

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
	cwd?: string;
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
						messages: [{ role: 'user', content: [{ type: 'text', text: `Working directory: ${ctx.cwd ?? 'unknown'}\nRequest: ${prompt.slice(0, 4000)}` }], timestamp: Date.now() }]
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
	if (!tuiEnabled()) {
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
	let sessionGeneration = 0;

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
		sessionGeneration++;
		generationStarted = false;
		seeded = undefined;
		sync();
		// Reload/resume should repair an unnamed session without another prompt.
		const opener = firstPrompt(ctx);
		if (opener) nameFromPrompt(opener, ctx);
		if (!heartbeat) {
			heartbeat = setInterval(sync, heartbeatMs);
			heartbeat.unref?.();
		}
	});

	function nameFromPrompt(request: string, ctx: ExtensionContext): void {
		if (ctx?.mode !== 'tui' || !active) {
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

		const prompt = (ours ? opener : request) ?? '';
		const generation = sessionGeneration;
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
			if (!active || generation !== sessionGeneration) return;
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
	}

	pi.on('before_agent_start', (event, ctx) => nameFromPrompt(event.prompt, ctx));

	pi.on('session_info_changed', (event, ctx) => {
		if (ctx?.mode !== 'tui') {
			return;
		}
		active = true;
		reported = typeof event?.name === 'string' && event.name.trim() ? event.name.trim() : undefined;
		void reportTitle(reported);
	});

	pi.on('session_shutdown', () => {
		sessionGeneration++;
		if (heartbeat) {
			clearInterval(heartbeat);
			heartbeat = undefined;
		}
		if (active) {
			// Best effort: clear the title so Auto Title can fall back immediately.
			void reportTitle(undefined);
		}
		active = false;
	});
}
