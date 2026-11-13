/**
 * Ctrl+Shift+\ toggles the pi-sidebar-tui sidebar.
 *
 * pi-sidebar-tui already registers Ctrl+Shift+T, but that is an extension
 * shortcut, not a built-in action: extension shortcuts are keyed by their
 * literal key and keybindings.json only checks them for conflicts against
 * built-in actions, so it cannot remap one. Rather than fork the package we
 * add a second binding here and re-dispatch the sidebar's own `/sidebar-tui`
 * command with `expandPromptTemplates`, so the package keeps owning the
 * toggle logic and compositor lifecycle.
 *
 * The sidebar persists `enabled` to its config file on every change, so that
 * file is an accurate read of the live state; if it is missing the sidebar
 * defaults to enabled.
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

/** Mirror pi-sidebar-tui's config resolution: PI_SIDEBAR_CONFIG, else the pi agent dir. */
function sidebarConfigPath(): string {
	const override = process.env["PI_SIDEBAR_CONFIG"];
	if (override) return override;
	const agentDir = process.env["PI_CODING_AGENT_DIR"] ?? join(homedir(), ".pi", "agent");
	return join(agentDir, "sidebar-tui.json");
}

/** Sidebar defaults to enabled when the config is missing or unreadable. */
function sidebarEnabled(): boolean {
	try {
		const parsed = JSON.parse(readFileSync(sidebarConfigPath(), "utf8")) as {
			enabled?: unknown;
		};
		return typeof parsed.enabled === "boolean" ? parsed.enabled : true;
	} catch {
		return true;
	}
}

export default function sidebarToggleExtension(pi: ExtensionAPI): void {
	pi.registerShortcut(Key.ctrlShift(Key.backslash), {
		description: "Toggle sidebar on/off",
		handler: (ctx) => {
			// Guard against sending `/sidebar-tui …` to the model when the
			// package is not loaded for this session.
			const loaded = pi.getCommands().some((command) => command.name === "sidebar-tui");
			if (!loaded) {
				ctx.ui.notify("pi-sidebar-tui is not loaded; sidebar toggle unavailable", "warning");
				return;
			}
			pi.sendUserMessage(`/sidebar-tui ${sidebarEnabled() ? "off" : "on"}`, {
				expandPromptTemplates: true,
			});
		},
	});
}
