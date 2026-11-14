/** Slash completions anywhere: Enter runs commands, Tab only inserts text. */
import {
	CustomEditor,
	type ExtensionAPI,
	type KeybindingsManager,
	type SlashCommandInfo,
	type ToolInfo,
} from "@earendil-works/pi-coding-agent";
import { fuzzyFilter, type AutocompleteItem, type AutocompleteProvider, type EditorTheme, type TUI } from "@earendil-works/pi-tui";

// Pi's getCommands() lists extensions, prompts and skills, but not built-ins.
// Keep this list in sync with Pi; the regression suite checks the installed list.
export const BUILTIN_COMMANDS = new Set([
	"settings", "model", "tree", "thinking", "scoped-models", "export", "import",
	"share", "bug", "copy", "name", "session", "changelog", "hotkeys", "fork",
	"clone", "trust", "login", "logout", "new", "compact", "resume", "reload", "quit",
]);
const REPLACES_DRAFT = new Set(["new", "resume", "fork", "clone", "tree", "import", "reload", "quit"]);
const SLASH_TOKEN = /(?:^|\s)(\/[\w:.-]*)$/;

type Completion = Parameters<AutocompleteProvider["applyCompletion"]>;
type CompletionResult = ReturnType<AutocompleteProvider["applyCompletion"]>;
type AcceptCommand = (...args: Completion) => CompletionResult | undefined;

export interface McpMention {
	name: string;
	namespace: string;
	description?: string;
}

// Use the live registry, not mcp.json: this respects trust, --no-mcp and hidden
// tools, includes extension servers, and never reads credentials or reconnects.
export function mcpMentions(tools: ToolInfo[]): McpMention[] {
	const servers = new Map<string, McpMention>();
	for (const tool of tools) {
		const ns = tool.namespace;
		if (tool.exposure === "hidden" || !ns?.name.startsWith("mcp__")) continue;
		const name = ns.aliases?.[0] ?? ns.name.slice("mcp__".length);
		if (!/^[\w-]+$/.test(name)) continue;
		servers.set(ns.name, { name, namespace: ns.name, description: ns.description?.split(/\r?\n/)[0] });
	}
	return [...servers.values()].sort((a, b) => a.name.localeCompare(b.name));
}

export function expandMcpMentions(text: string, servers: McpMention[]): string {
	const byName = new Map(servers.map((server) => [server.name.toLowerCase(), server]));
	return text.replace(/(^|\s)\/mcp:([\w-]+)(?=$|\s|[,.!?;])/gi, (token, space, name) => {
		const server = byName.get(name.toLowerCase());
		return server ? `${space}MCP server ${server.name} (namespace ${server.namespace})` : token;
	});
}

export function inlineSlashProvider(
	current: AutocompleteProvider,
	acceptCommand?: AcceptCommand,
	getMcpMentions: () => McpMention[] = () => [],
): AutocompleteProvider {
	const inlineItems = new WeakSet<AutocompleteItem>();
	const commandItems = new WeakSet<AutocompleteItem>();
	const mcpItems = new WeakSet<AutocompleteItem>();
	return {
		triggerCharacters: [...new Set([...(current.triggerCharacters ?? []), "/"])],
		async getSuggestions(lines, line, col, options) {
			const before = (lines[line] ?? "").slice(0, col);
			const match = before.match(SLASH_TOKEN);
			// A command at the start of line 0 owns the rest of that line as its
			// arguments; do not reinterpret an argument like /model as a new command.
			const commandLine = line === 0 && before.trimStart().startsWith("/");
			const inline = !!match && !commandLine;
			const atStart = commandLine && before.trim() === match?.[1];
			let result = inline && match
				? await current.getSuggestions([match[1]], 0, match[1].length, { ...options, force: false })
				: await current.getSuggestions(lines, line, col, options);
			if (match && (inline || atStart) && !options.force && !options.signal.aborted) {
				const query = match[1].slice(1);
				const servers = getMcpMentions();
				const matches = fuzzyFilter(servers, query, (server) =>
					query.toLowerCase().startsWith("mcp:") ? `mcp:${server.name}` : server.name);
				const items = matches.map((server) => {
					const item = {
						value: `mcp:${server.name}`,
						label: `mcp:${server.name}`,
						description: server.description ? `MCP · ${server.description}` : "MCP server",
					};
					mcpItems.add(item);
					return item;
				});
				if (items.length) {
					const existing = result?.prefix === match[1] ? result.items : [];
					// Bare server prefixes should beat unrelated fuzzy command matches
					// (/Po must offer Polar before export), without hiding real commands.
					const startsWithQuery = (item: AutocompleteItem) => {
						const name = item.value.replace(/^(?:skill:|mcp:)/, "");
						return name.toLowerCase().startsWith(query.toLowerCase())
							|| item.value.toLowerCase().startsWith(query.toLowerCase());
					};
					const combined = [...existing, ...items];
					result = {
						prefix: match[1],
						items: [...combined.filter(startsWithQuery), ...combined.filter((item) => !startsWithQuery(item))],
					};
				}
			}
			if (result && !options.signal.aborted && match && result.prefix === match[1] && (inline || (atStart && !options.force))) {
				for (const item of result.items) {
					commandItems.add(item);
					if (inline) inlineItems.add(item);
				}
			}
			// A slash-prefixed token with no command matches may be an absolute
			// path (e.g. /tmp). Preserve the original provider's file fallback.
			if (!result && inline && !options.signal.aborted) {
				return current.getSuggestions(lines, line, col, options);
			}
			return result;
		},
		applyCompletion(lines, line, col, item, prefix) {
			// Only real command-name suggestions can execute, never forced file or
			// argument completions that happen to share a built-in command's name.
			if (commandItems.has(item) && !mcpItems.has(item)) {
				const accepted = acceptCommand?.(lines, line, col, item, prefix);
				if (accepted) return accepted;
			}
			if (!inlineItems.has(item)) return current.applyCompletion(lines, line, col, item, prefix);
			const text = lines[line] ?? "";
			const before = text.slice(0, col - prefix.length);
			const after = text.slice(col);
			const suffix = after.startsWith(" ") ? "" : " ";
			const replacement = `/${item.value}${suffix}`;
			const result = [...lines];
			result[line] = before + replacement + after;
			return { lines: result, cursorLine: line, cursorCol: before.length + replacement.length };
		},
		shouldTriggerFileCompletion: (lines, line, col) => current.shouldTriggerFileCompletion?.(lines, line, col) ?? true,
	};
}

interface SlashEditorOptions {
	getCommands(): SlashCommandInfo[];
	getMcpMentions?(): McpMention[];
	isActive(): boolean;
	onError(message: string): void;
}

export class SlashEditor extends CustomEditor {
	private confirming = false;
	private selectedCommand: string | undefined;
	private pendingCommand: string | undefined;
	private preserveDraft = false;

	private readonly slashOptions: SlashEditorOptions;
	private readonly slashKeys: KeybindingsManager;

	constructor(tui: TUI, theme: EditorTheme, kb: KeybindingsManager, options: SlashEditorOptions) {
		super(tui, theme, kb);
		this.slashOptions = options;
		this.slashKeys = kb;
	}

	setAutocompleteProvider(provider: AutocompleteProvider): void {
		super.setAutocompleteProvider(inlineSlashProvider(provider, (lines, line, col, item, prefix) => {
			if (!this.confirming || !this.onSubmit) return;
			const runtime = BUILTIN_COMMANDS.has(item.value)
				|| this.slashOptions.getCommands().some((command) => command.name === item.value && command.source === "extension");
			if (!runtime) return; // Skills and templates stay editable until explicitly submitted.
			this.selectedCommand = item.value;
			const result = [...lines];
			const start = col - prefix.length;
			result[line] = lines[line].slice(0, start) + lines[line].slice(col);
			return { lines: result, cursorLine: line, cursorCol: start };
		}, () => this.slashOptions.getMcpMentions?.() ?? []));
	}

	setText(text: string): void {
		// Native command handlers clear the editor even though only the command,
		// not our draft, was submitted. Ignore those clears until dispatch settles.
		// Non-empty replacements (e.g. /rewind) and lifecycle clears remain native.
		if (this.preserveDraft && this.slashOptions.isActive() && text === "") return;
		super.setText(text);
	}

	handleInput(data: string): void {
		const kb = this.slashKeys;
		if (this.pendingCommand && (kb.matches(data, "tui.input.submit") || kb.matches(data, "tui.select.confirm"))) {
			return; // No overlapping dispatches or accidental prompt submission.
		}
		if (this.isShowingAutocomplete() && kb.matches(data, "tui.select.confirm")) {
			this.selectedCommand = undefined;
			this.confirming = !this.disableSubmit;
			// Let Pi apply the actual highlighted item, but prevent its generic
			// slash-completion path from submitting the entire buffer. No fake Tab.
			const disabled = this.disableSubmit;
			this.disableSubmit = true;
			try {
				super.handleInput(data);
			} finally {
				this.disableSubmit = disabled;
				this.confirming = false;
			}
			this.onChange?.(this.getText());
			if (this.selectedCommand) this.dispatchCommand(this.selectedCommand);
			return;
		}
		super.handleInput(data);
		// Pi deliberately excludes '/' from provider trigger characters. Refresh
		// after typing an inline slash token, using the same compatibility hook
		// as the previous extension. Never trigger execution from typing/pasting.
		if (/^[\w:./-]$/.test(data) && !this.isShowingAutocomplete()) {
			const { line, col } = this.getCursor();
			const before = (this.getLines()[line] ?? "").slice(0, col);
			const match = before.match(SLASH_TOKEN);
			if (match && (line > 0 || before.slice(0, -match[1].length).trim())) {
				(this as unknown as { tryTriggerAutocomplete(): void }).tryTriggerAutocomplete();
			}
		}
	}

	private dispatchCommand(name: string): void {
		this.pendingCommand = name;
		this.preserveDraft = !REPLACES_DRAFT.has(name);
		// Use the interactive dispatcher: sendUserMessage() does not handle built-in
		// UI commands such as /model. Bypass submitValue() so cursor, paste markers
		// and undo survive. No saved-text restore can overwrite a newer draft.
		void (async () => {
			try {
				await this.onSubmit?.(`/${name}`);
			} catch (error) {
				if (this.slashOptions.isActive()) this.slashOptions.onError(`/${name}: ${String(error)}`);
			} finally {
				this.pendingCommand = undefined;
				this.preserveDraft = false;
				this.tui.requestRender();
			}
		})();
	}
}

export default function slashCompletion(pi: ExtensionAPI): void {
	let active: object | undefined;
	const getMcpMentions = () => mcpMentions(pi.getAllTools());
	pi.on("input", (event) => {
		const text = expandMcpMentions(event.text, getMcpMentions());
		if (text !== event.text) return { action: "transform", text, images: event.images };
	});
	pi.on("session_shutdown", () => { active = undefined; });
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		const token = active = {};
		ctx.ui.setEditorComponent((tui, theme, kb) => new SlashEditor(tui, theme, kb, {
			getCommands: () => pi.getCommands(),
			getMcpMentions,
			isActive: () => active === token,
			onError: (message) => ctx.ui.notify(message, "error"),
		}));
	});
}
