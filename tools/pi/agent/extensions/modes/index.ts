/**
 * Modes Extension
 *
 * A persistent mode system for pi. The active mode's instructions are
 * re-injected before every agent run and the mode is stored in the session, so
 * it stays in effect for the whole conversation (and survives resume) instead
 * of only applying to the first message.
 *
 * Modes:
 * - normal: full tool access (default)
 * - plan:   read-only exploration; produce a numbered plan, then optionally execute it
 * - ask:    read-only Q&A; answer questions without modifying anything
 *
 * Shortcuts:
 * - Shift+Tab   cycle modes (normal -> plan -> ask -> normal)
 * - Ctrl+Alt+P  jump straight to/from plan mode
 *
 * Commands:
 * - /mode [name]  show the current mode, or switch to one
 * - /plan         toggle plan mode (kept for muscle memory)
 * - /todos        show plan progress
 *
 * CLI:
 * - --mode <name>  start in a mode
 */

import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { AssistantMessage, TextContent } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";
import { extractTodoItems, isSafeCommand, markCompletedSteps, type TodoItem } from "./utils.ts";

type ModeName = "normal" | "plan" | "ask";

const MODE_ORDER: ModeName[] = ["normal", "plan", "ask"];

const READ_ONLY_TOOLS = ["read", "grep", "find", "ls"];
const PLAN_TOOLS = [...READ_ONLY_TOOLS, "bash", "questionnaire"];
const ASK_TOOLS = [...READ_ONLY_TOOLS, "questionnaire"];
const DEFAULT_NORMAL_TOOLS = ["read", "bash", "edit", "write"];

const WRITE_TOOLS = new Set<string>(["edit", "write"]);
const MANAGED_TOOLS = new Set<string>([...READ_ONLY_TOOLS, "bash", "edit", "write", "questionnaire"]);

const MODE_CONTEXT_PREFIX = "modes-context:";
const EXEC_CONTEXT_TYPE = "modes-exec-context";

interface ModeInstructions {
	/** One-line summary shown in notifications and the /mode output. */
	summary: string;
	/** Full instructions injected ahead of every run while this mode is active. */
	instructions: string;
}

const MODE_INFO: Record<Exclude<ModeName, "normal">, ModeInstructions> = {
	plan: {
		summary: "Read-only exploration; produces a numbered plan",
		instructions: `[MODE: PLAN — READ-ONLY]
You are in PLAN mode, a read-only exploration mode for safe code analysis.

Restrictions:
- Built-in edit and write tools are disabled
- Bash is restricted to an allowlist of read-only commands
- Do NOT make changes, even if the user implies they want them; describe them instead

Approach:
- Read files IN FULL (no offset/limit) so you have complete context. Partial reads miss critical details.
- Explore thoroughly: grep for related code, find similar patterns, understand the architecture.
- Ask clarifying questions if requirements are ambiguous. Do not assume.

Output a detailed numbered plan under a "Plan:" header:

Plan:
1. First step description
2. Second step description
...

For each step: what to change, why, and potential risks. List files that will be modified.
After the plan, stop and wait for the user to choose whether to execute it.`,
	},
	ask: {
		summary: "Read-only Q&A; explains without changing anything",
		instructions: `[MODE: ASK — READ-ONLY Q&A]
You are in ASK mode. Answer the user's questions clearly and accurately.

Restrictions:
- Built-in edit and write tools are disabled
- Do NOT modify files, run mutating commands, or start implementing
- You may read and search files to ground your answers in the actual code

Approach:
- Answer the question directly first, then add the supporting detail.
- Cite the files and line numbers you relied on.
- If something is ambiguous or unknown, say so rather than guessing.
- Do not produce an implementation plan unless the user explicitly asks for one.`,
	},
};

const MODE_STATUS: Record<ModeName, string | undefined> = {
	normal: undefined,
	plan: "⏸ plan",
	ask: "? ask",
};

interface ModesState {
	mode: ModeName;
	executing: boolean;
	todos: TodoItem[];
	toolsBeforeMode?: string[];
}

function isAssistantMessage(m: AgentMessage): m is AssistantMessage {
	return m.role === "assistant" && Array.isArray(m.content);
}

function getTextContent(message: AssistantMessage): string {
	return message.content
		.filter((block): block is TextContent => block.type === "text")
		.map((block) => block.text)
		.join("\n");
}

function isModeName(value: string): value is ModeName {
	return (MODE_ORDER as string[]).includes(value);
}

export default function modesExtension(pi: ExtensionAPI): void {
	let mode: ModeName = "normal";
	let executing = false;
	let todoItems: TodoItem[] = [];
	let toolsBeforeMode: string[] | undefined;

	pi.registerFlag("mode", {
		description: "Start in a mode: normal, plan, or ask",
		type: "string",
	});

	function uniqueToolNames(names: string[]): string[] {
		return [...new Set(names)];
	}

	function defaultNormalTools(): string[] {
		return uniqueToolNames([...DEFAULT_NORMAL_TOOLS, ...pi.getActiveTools().filter((n) => !MANAGED_TOOLS.has(n))]);
	}

	function applyModeTools(): void {
		if (mode === "normal") {
			pi.setActiveTools(toolsBeforeMode ?? defaultNormalTools());
			toolsBeforeMode = undefined;
			return;
		}

		// Snapshot the full tool set the first time we leave normal mode.
		if (toolsBeforeMode === undefined) {
			toolsBeforeMode = pi.getActiveTools();
		}

		const base = toolsBeforeMode.filter((name) => !WRITE_TOOLS.has(name));
		const extra = mode === "plan" ? PLAN_TOOLS : ASK_TOOLS;
		pi.setActiveTools(uniqueToolNames([...base, ...extra]));
	}

	function updateStatus(ctx: ExtensionContext): void {
		if (executing && todoItems.length > 0) {
			const completed = todoItems.filter((t) => t.completed).length;
			ctx.ui.setStatus("modes", ctx.ui.theme.fg("accent", `📋 ${completed}/${todoItems.length}`));
		} else if (MODE_STATUS[mode]) {
			const color = mode === "plan" ? "warning" : "accent";
			ctx.ui.setStatus("modes", ctx.ui.theme.fg(color, MODE_STATUS[mode] as string));
		} else {
			ctx.ui.setStatus("modes", undefined);
		}

		if (executing && todoItems.length > 0) {
			const lines = todoItems.map((item) => {
				if (item.completed) {
					return ctx.ui.theme.fg("success", "☑ ") + ctx.ui.theme.fg("muted", ctx.ui.theme.strikethrough(item.text));
				}
				return `${ctx.ui.theme.fg("muted", "☐ ")}${item.text}`;
			});
			ctx.ui.setWidget("modes-todos", lines);
		} else {
			ctx.ui.setWidget("modes-todos", undefined);
		}
	}

	function persistState(): void {
		pi.appendEntry("modes-state", {
			mode,
			executing,
			todos: todoItems,
			toolsBeforeMode,
		} satisfies ModesState);
	}

	/**
	 * Switch to a mode. Resets any in-flight plan execution unless we are
	 * deliberately entering "execute the plan" (handled separately).
	 */
	function setMode(next: ModeName, ctx: ExtensionContext, options?: { silent?: boolean; keepExecution?: boolean }): void {
		if (next === mode) return;

		mode = next;
		if (!options?.keepExecution) {
			executing = false;
			todoItems = [];
		}

		applyModeTools();
		updateStatus(ctx);
		persistState();

		if (!options?.silent) {
			const info = next === "normal" ? undefined : MODE_INFO[next];
			ctx.ui.notify(info ? `Mode: ${next} — ${info.summary}` : "Mode: normal — full access", "info");
		}
	}

	function cycleMode(ctx: ExtensionContext): void {
		const index = MODE_ORDER.indexOf(mode);
		setMode(MODE_ORDER[(index + 1) % MODE_ORDER.length], ctx);
	}

	function togglePlan(ctx: ExtensionContext): void {
		setMode(mode === "plan" ? "normal" : "plan", ctx);
	}

	/** Begin executing a plan: restore full tools but keep tracking the todos. */
	function beginExecution(ctx: ExtensionContext): void {
		mode = "normal";
		executing = true;
		applyModeTools();
		updateStatus(ctx);
		persistState();
	}

	// ---------------------------------------------------------------------------
	// Commands
	// ---------------------------------------------------------------------------

	pi.registerCommand("mode", {
		description: "Show or set the current mode (normal, plan, ask)",
		getArgumentCompletions: (prefix) => {
			const items = MODE_ORDER.filter((m) => m.startsWith(prefix)).map((m) => ({
				value: m,
				label: m,
				description: m === "normal" ? "Full tool access" : MODE_INFO[m].summary,
			}));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase();
			if (!requested) {
				const lines = MODE_ORDER.map((m) => {
					const marker = m === mode ? "●" : "○";
					const desc = m === "normal" ? "Full tool access" : MODE_INFO[m].summary;
					return `${marker} ${m}: ${desc}`;
				}).join("\n");
				ctx.ui.notify(`Current mode: ${mode}\n\n${lines}`, "info");
				return;
			}

			if (!isModeName(requested)) {
				ctx.ui.notify(`Unknown mode "${requested}". Choose one of: ${MODE_ORDER.join(", ")}`, "warning");
				return;
			}

			setMode(requested, ctx);
		},
	});

	pi.registerCommand("plan", {
		description: "Toggle plan mode (read-only exploration)",
		handler: async (_args, ctx) => togglePlan(ctx),
	});

	pi.registerCommand("todos", {
		description: "Show current plan progress",
		handler: async (_args, ctx) => {
			if (todoItems.length === 0) {
				ctx.ui.notify("No plan todos. Switch to plan mode with Shift+Tab or /mode plan.", "info");
				return;
			}
			const list = todoItems.map((item, i) => `${i + 1}. ${item.completed ? "✓" : "○"} ${item.text}`).join("\n");
			ctx.ui.notify(`Plan Progress:\n${list}`, "info");
		},
	});

	// ---------------------------------------------------------------------------
	// Shortcuts
	// ---------------------------------------------------------------------------

	pi.registerShortcut(Key.shift("tab"), {
		description: "Cycle modes (normal -> plan -> ask)",
		handler: async (ctx) => cycleMode(ctx),
	});

	pi.registerShortcut(Key.ctrlAlt("p"), {
		description: "Toggle plan mode",
		handler: async (ctx) => togglePlan(ctx),
	});

	// ---------------------------------------------------------------------------
	// Persistent mode instructions
	// ---------------------------------------------------------------------------

	// Re-inject the active mode's instructions before every run so the mode stays
	// in effect for the entire session, not just the first message.
	pi.on("before_agent_start", async () => {
		if (executing && todoItems.length > 0) {
			const remaining = todoItems.filter((t) => !t.completed);
			const todoList = remaining.map((t) => `${t.step}. ${t.text}`).join("\n");
			return {
				message: {
					customType: EXEC_CONTEXT_TYPE,
					content: `[EXECUTING PLAN - Full tool access enabled]

Remaining steps:
${todoList}

Execute each step in order.
After completing a step, include a [DONE:n] tag in your response.`,
					display: false,
				},
			};
		}

		if (mode !== "normal") {
			return {
				message: {
					customType: `${MODE_CONTEXT_PREFIX}${mode}`,
					content: MODE_INFO[mode].instructions,
					display: false,
				},
			};
		}

		return undefined;
	});

	// Drop stale mode/execution context so old instructions never linger in the
	// transcript after switching modes (and so they are not replayed on resume).
	pi.on("context", async (event) => {
		return {
			messages: event.messages.filter((message) => {
				const msg = message as AgentMessage & { customType?: string };
				const customType = msg.customType;
				if (typeof customType !== "string") return true;

				if (customType.startsWith(MODE_CONTEXT_PREFIX)) {
					return customType === `${MODE_CONTEXT_PREFIX}${mode}`;
				}
				if (customType === EXEC_CONTEXT_TYPE) {
					return executing && todoItems.length > 0;
				}
				return true;
			}),
		};
	});

	// Enforce read-only modes at the tool boundary, not just via the active set.
	pi.on("tool_call", async (event) => {
		if (mode === "normal") return;

		if (event.toolName === "edit" || event.toolName === "write") {
			return {
				block: true,
				reason: `${mode} mode: ${event.toolName} is disabled. Switch to normal mode (Shift+Tab) first.`,
			};
		}

		if (event.toolName === "bash") {
			const command = String(event.input.command ?? "");
			if (mode === "ask" || !isSafeCommand(command)) {
				return {
					block: true,
					reason: `${mode} mode: command blocked (read-only). Command: ${command}`,
				};
			}
		}
	});

	// ---------------------------------------------------------------------------
	// Plan progress tracking
	// ---------------------------------------------------------------------------

	pi.on("turn_end", async (event, ctx) => {
		if (!executing || todoItems.length === 0) return;
		if (!isAssistantMessage(event.message)) return;

		const text = getTextContent(event.message);
		if (markCompletedSteps(text, todoItems) > 0) {
			updateStatus(ctx);
		}
		persistState();
	});

	pi.on("agent_end", async (event, ctx) => {
		// Execution finished?
		if (executing && todoItems.length > 0) {
			if (todoItems.every((t) => t.completed)) {
				const completedList = todoItems.map((t) => `~~${t.text}~~`).join("\n");
				pi.sendMessage(
					{ customType: "modes-plan-complete", content: `**Plan Complete!** ✓\n\n${completedList}`, display: true },
					{ triggerTurn: false },
				);
				executing = false;
				todoItems = [];
				updateStatus(ctx);
				persistState();
			}
			return;
		}

		if (mode !== "plan" || !ctx.hasUI) return;

		// Extract todos from the last assistant message.
		const lastAssistant = [...event.messages].reverse().find(isAssistantMessage);
		if (lastAssistant) {
			const extracted = extractTodoItems(getTextContent(lastAssistant));
			if (extracted.length > 0) {
				todoItems = extracted;
			}
		}

		if (todoItems.length === 0) return;
		persistState();

		const todoListText = todoItems.map((t, i) => `${i + 1}. ☐ ${t.text}`).join("\n");
		const planTodoListMessage = {
			customType: "modes-plan-todo-list",
			content: `**Plan Steps (${todoItems.length}):**\n\n${todoListText}`,
			display: true,
		};

		const choice = await ctx.ui.select("Plan mode - what next?", [
			"Execute the plan (track progress)",
			"Stay in plan mode",
			"Refine the plan",
		]);

		if (choice?.startsWith("Execute")) {
			const firstTodoItem = todoItems[0];
			if (!firstTodoItem) return;

			beginExecution(ctx);

			const remainingList = todoItems.map((t) => `${t.step}. ${t.text}`).join("\n");
			const execMessage = `Execute the plan.

Remaining steps:
${remainingList}

Start with: ${firstTodoItem.text}
After completing a step, include a [DONE:n] tag in your response.`;
			pi.sendMessage(planTodoListMessage, { deliverAs: "followUp" });
			pi.sendMessage(
				{ customType: "modes-plan-execute", content: execMessage, display: true },
				{ triggerTurn: true, deliverAs: "followUp" },
			);
		} else if (choice === "Refine the plan") {
			const refinement = await ctx.ui.editor("Refine the plan:", "");
			if (refinement?.trim()) {
				pi.sendMessage(planTodoListMessage, { deliverAs: "followUp" });
				pi.sendUserMessage(refinement.trim(), { deliverAs: "followUp" });
			}
		}
	});

	// ---------------------------------------------------------------------------
	// Session lifecycle
	// ---------------------------------------------------------------------------

	pi.on("session_start", async (_event, ctx) => {
		const flagMode = pi.getFlag("mode");
		if (typeof flagMode === "string" && isModeName(flagMode)) {
			mode = flagMode;
		}

		const entries = ctx.sessionManager.getEntries();
		const stateEntry = entries
			.filter((e: { type: string; customType?: string }) => e.type === "custom" && e.customType === "modes-state")
			.pop() as { data?: ModesState } | undefined;

		if (stateEntry?.data) {
			mode = stateEntry.data.mode ?? mode;
			executing = stateEntry.data.executing ?? executing;
			todoItems = stateEntry.data.todos ?? todoItems;
			toolsBeforeMode = stateEntry.data.toolsBeforeMode ?? toolsBeforeMode;
		}

		// On resume, rebuild completion state by scanning messages after the last
		// plan-execute marker so old [DONE:n] tags from previous plans are ignored.
		const isResume = stateEntry !== undefined;
		if (isResume && executing && todoItems.length > 0) {
			let executeIndex = -1;
			for (let i = entries.length - 1; i >= 0; i--) {
				const entry = entries[i] as { type: string; customType?: string };
				if (entry.customType === "modes-plan-execute") {
					executeIndex = i;
					break;
				}
			}

			const messages: AssistantMessage[] = [];
			for (let i = executeIndex + 1; i < entries.length; i++) {
				const entry = entries[i];
				if (entry.type === "message" && "message" in entry && isAssistantMessage(entry.message as AgentMessage)) {
					messages.push(entry.message as AssistantMessage);
				}
			}
			const allText = messages.map(getTextContent).join("\n");
			markCompletedSteps(allText, todoItems);
		}

		applyModeTools();
		updateStatus(ctx);
	});
}
