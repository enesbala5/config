/** Slash completions anywhere in a prompt; Enter accepts instead of submitting. */
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteProvider } from "@earendil-works/pi-tui";

export function inlineSlashProvider(current: AutocompleteProvider): AutocompleteProvider {
	const inlineItems = new WeakSet<object>();
	return {
		triggerCharacters: [...new Set([...(current.triggerCharacters ?? []), "/"])],
		async getSuggestions(lines, line, col, options) {
			const before = (lines[line] ?? "").slice(0, col);
			// Only a standalone slash token; leave paths, URLs and command arguments alone.
			const match = before.match(/(?:^|\s)(\/[\w:.-]*)$/);
			if (match && (line > 0 || before.slice(0, -match[1].length).trim())) {
				const result = await current.getSuggestions([match[1]], 0, match[1].length, { ...options, force: false });
				if (result && !options.signal.aborted) {
					for (const item of result.items) inlineItems.add(item);
					return result;
				}
			}
			return current.getSuggestions(lines, line, col, options);
		},
		applyCompletion(lines, line, col, item, prefix) {
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

export default function slashCompletion(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		ctx.ui.addAutocompleteProvider(inlineSlashProvider);
		ctx.ui.setEditorComponent((tui, theme, kb) => new class extends CustomEditor {
			handleInput(data: string): void {
				if (this.isShowingAutocomplete() && kb.matches(data, "tui.input.submit")) {
					// Tab applies the selected item without Pi's slash-command auto-submit.
					super.handleInput("\t");
					return;
				}
				super.handleInput(data);
				// Pi deliberately excludes '/' from provider trigger characters. Ask its
				// editor to refresh after typing an inline slash token instead.
				if (/^[\w:./-]$/.test(data) && !this.isShowingAutocomplete()) {
					const { line, col } = this.getCursor();
					const before = (this.getLines()[line] ?? "").slice(0, col);
					const match = before.match(/(?:^|\s)(\/[\w:.-]*)$/);
					if (match && (line > 0 || before.slice(0, -match[1].length).trim())) {
						(this as unknown as { tryTriggerAutocomplete(): void }).tryTriggerAutocomplete();
					}
				}
			}
		}(tui, theme, kb));
	});
}
