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
// name, this seeds one from the opening prompt — the same fallback Claude Code
// offers Auto Title — so tabs are useful without naming every session by hand.
// A name the user sets is never overwritten.
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

	return (stripped.charAt(0).toUpperCase() + stripped.slice(1)).slice(0, 60);
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
		if (ctx?.mode !== 'tui' || currentName()) {
			return;
		}
		const title = summarize(typeof event?.prompt === 'string' ? event.prompt : '');
		if (!title) {
			return;
		}
		try {
			// Fires session_info_changed, which reports it; the next poll of Auto
			// Title names the tab.
			pi.setSessionName(title);
		} catch {
			// A session that cannot be named yet is not worth failing the turn for.
		}
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
