/**
 * Pure utility functions for plan mode.
 * Extracted for testability.
 */

// Destructive commands blocked in plan mode
const DESTRUCTIVE_PATTERNS = [
	/\brm\b/i,
	/\brmdir\b/i,
	/\bmv\b/i,
	/\bcp\b/i,
	/\bmkdir\b/i,
	/\btouch\b/i,
	/\bchmod\b/i,
	/\bchown\b/i,
	/\bchgrp\b/i,
	/\bln\b/i,
	/\btee\b/i,
	/\btruncate\b/i,
	/\bdd\b/i,
	/\bshred\b/i,
	/(^|[^<])>(?!>)/,
	/>>/,
	/\bnpm\s+(install|uninstall|update|ci|link|publish)/i,
	/\byarn\s+(add|remove|install|publish)/i,
	/\bpnpm\s+(add|remove|install|publish)/i,
	/\bpip\s+(install|uninstall)/i,
	/\bapt(-get)?\s+(install|remove|purge|update|upgrade)/i,
	/\bbrew\s+(install|uninstall|upgrade)/i,
	/\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|branch\s+-[dD]|stash|cherry-pick|revert|tag|init|clone)/i,
	/\bsudo\b/i,
	/\bsu\b/i,
	/\bkill\b/i,
	/\bpkill\b/i,
	/\bkillall\b/i,
	/\breboot\b/i,
	/\bshutdown\b/i,
	/\bsystemctl\s+(start|stop|restart|enable|disable)/i,
	/\bservice\s+\S+\s+(start|stop|restart)/i,
	/\b(vim?|nano|emacs|code|subl)\b/i,
];

// Safe read-only commands allowed in plan mode
const SAFE_PATTERNS = [
	/^\s*cat\b/,
	/^\s*head\b/,
	/^\s*tail\b/,
	/^\s*less\b/,
	/^\s*more\b/,
	/^\s*grep\b/,
	/^\s*find\b/,
	/^\s*ls\b/,
	/^\s*pwd\b/,
	/^\s*echo\b/,
	/^\s*printf\b/,
	/^\s*wc\b/,
	/^\s*sort\b/,
	/^\s*uniq\b/,
	/^\s*diff\b/,
	/^\s*file\b/,
	/^\s*stat\b/,
	/^\s*du\b/,
	/^\s*df\b/,
	/^\s*tree\b/,
	/^\s*which\b/,
	/^\s*whereis\b/,
	/^\s*type\b/,
	/^\s*env\b/,
	/^\s*printenv\b/,
	/^\s*uname\b/,
	/^\s*whoami\b/,
	/^\s*id\b/,
	/^\s*date\b/,
	/^\s*cal\b/,
	/^\s*uptime\b/,
	/^\s*ps\b/,
	/^\s*top\b/,
	/^\s*htop\b/,
	/^\s*free\b/,
	/^\s*git\s+(status|log|diff|show|branch|remote|config\s+--get)/i,
	/^\s*git\s+ls-/i,
	/^\s*npm\s+(list|ls|view|info|search|outdated|audit)/i,
	/^\s*yarn\s+(list|info|why|audit)/i,
	/^\s*node\s+--version/i,
	/^\s*python\s+--version/i,
	/^\s*curl\s/i,
	/^\s*wget\s+-O\s*-/i,
	/^\s*jq\b/,
	/^\s*sed\s+-n/i,
	/^\s*awk\b/,
	/^\s*rg\b/,
	/^\s*fd\b/,
	/^\s*bat\b/,
	/^\s*eza\b/,
];

export function isSafeCommand(command: string): boolean {
	const isDestructive = DESTRUCTIVE_PATTERNS.some((p) => p.test(command));
	const isSafe = SAFE_PATTERNS.some((p) => p.test(command));
	return !isDestructive && isSafe;
}

export interface TodoItem {
	step: number;
	text: string;
	completed: boolean;
}

// ---------------------------------------------------------------------------
// Plan file persistence
// ---------------------------------------------------------------------------

/** Explicit marker lines, e.g. `plans-dir: docs/plans`. */
const PLAN_DIR_MARKERS = /^(?:plans?[\s_-]*(?:dir|path|folder)|plans?[\s_-]*files?|plans?[\s_-]*output)\s*[:=]\s*(.+)$/i;

/** Natural-language overrides, e.g. "Use docs/plans to store plans". */
const PLAN_DIR_SENTENCES = [
	/\buse\s+`?([^\s`'"]+)`?\s+(?:to\s+)?(?:store|save|keep|write)\s+(?:the\s+)?plans?\b/i,
	/\b(?:store|save|keep|write)\s+(?:the\s+)?plans?\s+(?:in|under|at|to)\s+`?([^\s`'"]+)`?/i,
	/\bplans?\s+(?:are|should\s+be|must\s+be|go|live|belong)\s+(?:stored|saved|written|kept)?\s*(?:in|under|at|to)\s+`?([^\s`'"]+)`?/i,
	/\bplans?\s+(?:go|live|belong)\s+(?:in|under|at)\s+`?([^\s`'"]+)`?/i,
];

const NEGATED_LINE = /^(?:do\s+not|don't|never|avoid)\b/i;

function cleanPlanDir(value: string): string | undefined {
	let cleaned = value.trim().replace(/^[`'"(\[]+|[`'")\]]+$/g, "");
	cleaned = cleaned.replace(/[.,;:]+$/, "").replace(/\/+$/, "");
	if (!cleaned || cleaned.includes("<") || cleaned.includes(">") || /^[a-z]+:\/\//i.test(cleaned)) {
		return undefined;
	}
	return cleaned;
}

/**
 * Find a plans-directory override in an AGENTS.md body.
 *
 * Explicit markers win. Otherwise common phrasings such as
 * "Use docs/plans to store plans" are recognised. Returns the raw path
 * (still relative to the AGENTS.md file) or undefined.
 */
export function extractPlansDirFromAgents(text: string): string | undefined {
	const lines = text.split(/\r?\n/);

	for (const line of lines) {
		const trimmed = line.replace(/^\s*(?:[-*+]|\d+[.)])\s+/, "").trim();
		if (!trimmed || NEGATED_LINE.test(trimmed)) continue;
		const match = trimmed.match(PLAN_DIR_MARKERS);
		if (match) {
			const dir = cleanPlanDir(match[1]);
			if (dir) return dir;
		}
	}

	for (const line of lines) {
		const trimmed = line.trim();
		if (!trimmed || NEGATED_LINE.test(trimmed)) continue;
		for (const pattern of PLAN_DIR_SENTENCES) {
			const match = trimmed.match(pattern);
			if (match) {
				const dir = cleanPlanDir(match[1]);
				if (dir) return dir;
			}
		}
	}

	return undefined;
}

/** Turn a plan title into a short, filename-safe slug. */
export function slugifyPlanName(text: string, maxLength = 40): string {
	const slug = text
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, maxLength)
		.replace(/-+$/g, "");
	return slug || "plan";
}

export type PlanFileStatus = "draft" | "in-progress" | "complete";

export interface PlanFileData {
	title: string;
	project: string;
	created: string;
	status: PlanFileStatus;
	body: string;
	todos: TodoItem[];
}

/** Render the markdown plan document written under the plans directory. */
export function renderPlanMarkdown(data: PlanFileData): string {
	const statusLabel = data.status === "complete" ? "complete" : data.status === "in-progress" ? "in progress" : "draft";
	const lines = [
		`# Plan: ${data.title}`,
		"",
		`- Status: ${statusLabel}`,
		`- Created: ${data.created}`,
		`- Project: \`${data.project}\``,
	];

	if (data.todos.length > 0) {
		lines.push("", "## Steps", "");
		for (const item of data.todos) {
			lines.push(`- [${item.completed ? "x" : " "}] ${item.step}. ${item.text}`);
		}
	}

	lines.push("", "## Plan", "", data.body.trim(), "");
	return lines.join("\n");
}

export function cleanStepText(text: string): string {
	let cleaned = text
		.replace(/\*{1,2}([^*]+)\*{1,2}/g, "$1") // Remove bold/italic
		.replace(/`([^`]+)`/g, "$1") // Remove code
		.replace(
			/^(Use|Run|Execute|Create|Write|Read|Check|Verify|Update|Modify|Add|Remove|Delete|Install)\s+(the\s+)?/i,
			"",
		)
		.replace(/\s+/g, " ")
		.trim();

	if (cleaned.length > 0) {
		cleaned = cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
	}
	if (cleaned.length > 50) {
		cleaned = `${cleaned.slice(0, 47)}...`;
	}
	return cleaned;
}

export function extractTodoItems(message: string): TodoItem[] {
	const items: TodoItem[] = [];
	const headerMatch = message.match(/\*{0,2}Plan:\*{0,2}\s*\n/i);
	if (!headerMatch) return items;

	const planSection = message.slice(message.indexOf(headerMatch[0]) + headerMatch[0].length);
	const numberedPattern = /^\s*(\d+)[.)]\s+\*{0,2}([^*\n]+)/gm;

	for (const match of planSection.matchAll(numberedPattern)) {
		const text = match[2]
			.trim()
			.replace(/\*{1,2}$/, "")
			.trim();
		if (text.length > 5 && !text.startsWith("`") && !text.startsWith("/") && !text.startsWith("-")) {
			const cleaned = cleanStepText(text);
			if (cleaned.length > 3) {
				items.push({ step: items.length + 1, text: cleaned, completed: false });
			}
		}
	}
	return items;
}

export function extractDoneSteps(message: string): number[] {
	const steps: number[] = [];
	for (const match of message.matchAll(/\[DONE:(\d+)\]/gi)) {
		const step = Number(match[1]);
		if (Number.isFinite(step)) steps.push(step);
	}
	return steps;
}

export function markCompletedSteps(text: string, items: TodoItem[]): number {
	const doneSteps = extractDoneSteps(text);
	for (const step of doneSteps) {
		const item = items.find((t) => t.step === step);
		if (item) item.completed = true;
	}
	return doneSteps.length;
}
