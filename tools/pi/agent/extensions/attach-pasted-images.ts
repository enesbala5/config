/**
 * Attach pasted image paths as real image content and render them inline.
 *
 * Pi's interactive paste handler writes a clipboard image to a temp file and
 * inserts that file path into the editor (see `handleClipboardPaste`). On
 * submit only that text reaches the model, so the transcript shows a long
 * `/tmp/pi-clipboard-<uuid>.png` path and the model has to `read` it.
 *
 * This extension:
 *   - intercepts the `input` event,
 *   - converts any existing image path into an image attachment,
 *   - replaces the path with a short `[image]` marker, and
 *   - appends a custom entry that draws the image inline.
 *
 * The image is drawn with `@earendil-works/pi-tui`'s `Image` component, which
 * emits normal Kitty/iTerm graphics (the path Herdr forwards). Custom entries
 * are not sent to the model and keep the user message text clean.
 */
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { extname, isAbsolute, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getCapabilities, Image } from "@earendil-works/pi-tui";

const MIME_BY_EXT: Record<string, string> = {
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".webp": "image/webp",
	".gif": "image/gif",
};

const MARKER = "[image]";
const ENTRY_TYPE = "pasted-image";
const MAX_WIDTH_CELLS = 80;

/** Bare or quoted tokens ending in a supported image extension. */
const IMAGE_PATH_RE =
	/"[^"]*?\.(?:png|jpe?g|webp|gif)"|'[^']*?\.(?:png|jpe?g|webp|gif)'|\S+?\.(?:png|jpe?g|webp|gif)(?=\s|$)/gi;

interface PastedImage {
	data: string;
	mimeType: string;
}

function expandHome(p: string): string {
	if (p === "~") return homedir();
	if (p.startsWith("~/")) return resolve(homedir(), p.slice(2));
	return p;
}

export default function (pi: ExtensionAPI) {
	// Draw appended images in the transcript. Not part of LLM context.
	pi.registerEntryRenderer<PastedImage>(ENTRY_TYPE, (entry, _options, theme) => {
		const image = entry.data;
		if (!image?.data || !image.mimeType) return undefined;
		// Renders nothing when the terminal cannot show images; the text
		// marker in the user message still communicates the attachment.
		if (!getCapabilities().images) return undefined;
		return new Image(
			image.data,
			image.mimeType,
			{ fallbackColor: (s) => theme.fg("toolOutput", s) },
			{ maxWidthCells: MAX_WIDTH_CELLS },
		);
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension" || !event.text) {
			return { action: "continue" };
		}

		const candidates: Array<{ match: string; file: string; mime: string }> = [];
		for (const match of event.text.match(IMAGE_PATH_RE) ?? []) {
			const unquoted = match.replace(/^["']|["']$/g, "");
			const expanded = expandHome(unquoted);
			const file = isAbsolute(expanded) ? expanded : resolve(ctx.cwd, expanded);
			const mime = MIME_BY_EXT[extname(file).toLowerCase()];
			if (mime && existsSync(file)) {
				candidates.push({ match, file, mime });
			}
		}

		if (candidates.length === 0) {
			return { action: "continue" };
		}

		const images = [...(event.images ?? [])];
		const beforeCount = images.length;
		let text = event.text;
		for (const candidate of candidates) {
			try {
				const data = await readFile(candidate.file);
				const encoded = data.toString("base64");
				images.push({ type: "image", data: encoded, mimeType: candidate.mime });
				text = text.replace(candidate.match, MARKER);
				// Show it inline immediately, independent of model rendering.
				pi.appendEntry<PastedImage>(ENTRY_TYPE, { data: encoded, mimeType: candidate.mime });
			} catch {
				// Unreadable file: leave its path in the text untouched.
			}
		}

		if (images.length === beforeCount) {
			return { action: "continue" };
		}

		return { action: "transform", text, images };
	});
}
