/**
 * Ctrl+P → Insert "/"
 *
 * Repurposes Ctrl+P (normally `app.model.cycleForward`) to insert a forward
 * slash into the prompt editor, so it opens pi's slash-command menu.
 *
 * The `app.model.cycleForward` binding is cleared in keybindings.json; pi
 * reserves that action, so an extension cannot claim Ctrl+P until it is
 * unbound. Model cycling is still available via Ctrl+Shift+P (backward) and
 * the model selector (Ctrl+/).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

export default function ctrlPSlashExtension(pi: ExtensionAPI): void {
	pi.registerShortcut(Key.ctrl("p"), {
		description: "Insert '/' into the prompt (slash-command helper)",
		handler: (ctx) => {
			const current = ctx.ui.getEditorText();
			ctx.ui.setEditorText(`${current}/`);
		},
	});
}
