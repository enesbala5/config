/**
 * Rewind Extension
 *
 * Pi's `/tree` navigator already rewinds the conversation, but it is keyboard
 * driven and shows the whole entry tree. This adds a focused `/rewind` picker
 * that lists only user messages, newest last. Selecting one branches the
 * session from just before that message and puts its text back in the editor,
 * so you can edit and resubmit.
 *
 * The list uses the mouse-aware `SelectList` component, so in fullscreen mode
 * (the default) you can click a row instead of arrowing to it. The keyboard
 * path always works.
 *
 * Optionally, if a git checkpoint exists for the selected message, it can
 * restore the worktree to the state captured before that message's turn.
 * Checkpoints come from `git stash create`, so they never touch the worktree
 * until you opt in to restoring one.
 *
 * Usage: /rewind
 */

import type {
	ExtensionAPI,
	ExtensionCommandContext,
	Theme,
} from "@earendil-works/pi-coding-agent";
import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import {
	Container,
	SelectList,
	type SelectItem,
	type SelectListTheme,
	Spacer,
	Text,
} from "@earendil-works/pi-tui";

const MAX_VISIBLE = 14;
const PREVIEW_CHARS = 72;

interface UserMessage {
	id: string;
	text: string;
	timestamp: string;
	onBranch: boolean;
}

/** Collapse user message content (string or content blocks) into plain text. */
function userMessageText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.map((part) => {
			if (!part || typeof part !== "object") return "";
			if ((part as { type?: string }).type === "text") {
				return (part as { text?: string }).text ?? "";
			}
			if ((part as { type?: string }).type === "image") return "[image]";
			return "";
		})
		.filter(Boolean)
		.join(" ");
}

/** One-line, length-capped preview of a message. */
function preview(text: string): string {
	const oneLine = text.replace(/\s+/g, " ").trim();
	if (!oneLine) return "(empty message)";
	return oneLine.length <= PREVIEW_CHARS ? oneLine : `${oneLine.slice(0, PREVIEW_CHARS - 1)}…`;
}

/** Coarse relative time, e.g. "4m ago". */
function relativeTime(iso: string): string {
	const then = Date.parse(iso);
	if (Number.isNaN(then)) return "";
	const secs = Math.max(0, Math.round((Date.now() - then) / 1000));
	if (secs < 60) return `${secs}s ago`;
	const mins = Math.round(secs / 60);
	if (mins < 60) return `${mins}m ago`;
	const hrs = Math.round(mins / 60);
	if (hrs < 24) return `${hrs}h ago`;
	return `${Math.round(hrs / 24)}d ago`;
}

/** A filter-free picker: header, mouse-aware list, footer. */
class RewindPicker extends Container {
	constructor(
		items: SelectItem[],
		theme: Theme,
		onSelect: (id: string) => void,
		onCancel: () => void,
	) {
		super();

		const selectTheme: SelectListTheme = {
			selectedPrefix: (text) => theme.fg("accent", text),
			selectedText: (text) => theme.fg("accent", text),
			description: (text) => theme.fg("muted", text),
			scrollInfo: (text) => theme.fg("muted", text),
			noMatch: (text) => theme.fg("muted", text),
		};

		this.addChild(new DynamicBorder((text) => theme.fg("accent", text)));
		this.addChild(new Spacer(1));
		this.addChild(new Text(theme.fg("accent", theme.bold("Rewind to which message?")), 1, 0));
		this.addChild(new Spacer(1));

		const list = new SelectList(items, MAX_VISIBLE, selectTheme);
		list.onSelect = (item) => onSelect(item.value);
		list.onCancel = onCancel;
		this.addChild(list);

		this.addChild(new Spacer(1));
		this.addChild(new Text(theme.fg("dim", "↑↓ move · enter/click select · esc cancel"), 1, 0));
		this.addChild(new Spacer(1));
		this.addChild(new DynamicBorder((text) => theme.fg("accent", text)));

		this.list = list;
	}

	private readonly list: SelectList;

	handleInput(data: string): void {
		this.list.handleInput(data);
	}
}

export default function rewindExtension(pi: ExtensionAPI): void {
	// User-message entry id -> git stash ref captured before that message's turn.
	const checkpoints = new Map<string, string>();

	// The leaf is the just-submitted user message at the first turn of a
	// request, which is exactly the worktree state to restore when rewinding to
	// (and redoing) that message. Later turns in the same request have a
	// tool/assistant leaf, so they are skipped.
	pi.on("turn_start", async (_event, ctx) => {
		const leaf = ctx.sessionManager.getLeafEntry();
		if (!leaf || leaf.type !== "message" || leaf.message.role !== "user") return;
		if (checkpoints.has(leaf.id)) return;

		const stash = await pi.exec("git", ["stash", "create"], { cwd: ctx.cwd });
		if (stash.code === 0 && stash.stdout.trim()) {
			checkpoints.set(leaf.id, stash.stdout.trim());
		}
	});

	pi.on("session_shutdown", async () => {
		checkpoints.clear();
	});

	pi.registerCommand("rewind", {
		description: "Rewind the conversation to an earlier user message",
		handler: async (_args, ctx) => {
			await runRewind(pi, ctx, checkpoints);
		},
	});
}

async function runRewind(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	checkpoints: Map<string, string>,
): Promise<void> {
	if (!ctx.hasUI) {
		ctx.ui.notify("Rewind needs an interactive session (use /tree in headless modes)", "error");
		return;
	}
	if (!ctx.isIdle()) {
		ctx.ui.notify("Wait for the current response to finish before rewinding", "warning");
		return;
	}

	const branchIds = new Set(ctx.sessionManager.getBranch().map((entry) => entry.id));
	const messages: UserMessage[] = [];
	for (const entry of ctx.sessionManager.getEntries()) {
		if (entry.type !== "message" || entry.message.role !== "user") continue;
		messages.push({
			id: entry.id,
			text: userMessageText(entry.message.content),
			timestamp: entry.timestamp,
			onBranch: branchIds.has(entry.id),
		});
	}

	if (messages.length === 0) {
		ctx.ui.notify("No user messages to rewind to", "info");
		return;
	}

	const width = String(messages.length).length;
	const items: SelectItem[] = messages.map((message, index) => ({
		value: message.id,
		label: `${String(index + 1).padStart(width)}. ${preview(message.text)}`,
		description: `${relativeTime(message.timestamp)}${message.onBranch ? "" : " · other branch"}`,
	}));

	const selectedId = await pickMessage(ctx, items);
	if (!selectedId) return;

	if (selectedId === ctx.sessionManager.getLeafId()) {
		ctx.ui.notify("Already at this message", "info");
		return;
	}

	const ref = checkpoints.get(selectedId);
	if (ref) {
		const restore = await ctx.ui.select("Restore code state to before this message?", [
			"No, keep current code",
			"Yes, restore code state",
		]);
		if (restore === "Yes, restore code state") {
			const apply = await pi.exec("git", ["stash", "apply", ref], { cwd: ctx.cwd });
			if (apply.code === 0) {
				ctx.ui.notify("Code restored to the checkpoint", "info");
			} else {
				ctx.ui.notify(
					`Could not restore code: ${apply.stderr.trim() || "git stash apply failed"}`,
					"error",
				);
			}
		}
	}

	const summaryChoice = await ctx.ui.select("Summarize the abandoned branch?", [
		"No summary",
		"Summarize",
	]);
	const summarize = summaryChoice === "Summarize";

	try {
		const result = await ctx.navigateTree(selectedId, { summarize });
		if (result.cancelled) {
			ctx.ui.notify("Rewind cancelled", "info");
		}
	} catch (error) {
		ctx.ui.notify(
			`Rewind failed: ${error instanceof Error ? error.message : String(error)}`,
			"error",
		);
	}
}

/** Show the picker as a mouse-capable overlay in the TUI, or a plain list elsewhere. */
async function pickMessage(
	ctx: ExtensionCommandContext,
	items: SelectItem[],
): Promise<string | undefined> {
	if (ctx.mode === "tui") {
		return ctx.ui.custom<string | undefined>((_tui, theme, _keybindings, done) => {
			return new RewindPicker(
				items,
				theme,
				(id) => done(id),
				() => done(undefined),
			);
		});
	}

	const choice = await ctx.ui.select(
		"Rewind to which message?",
		items.map((item) => item.label),
	);
	return choice ? items.find((item) => item.label === choice)?.value : undefined;
}
