/**
 * Show pasted images: a live preview above the editor, and an inline render in
 * the transcript.
 *
 * Pi's interactive paste handler writes a clipboard image to a temp file and
 * inserts that file path into the editor. On submit only that text reaches the
 * model, so without help the transcript shows a long `/tmp/pi-clipboard-*.png`
 * path and the model has to `read` it.
 *
 * This extension:
 *   - watches the editor while you compose and shows a small preview above the
 *     input the moment an image path appears,
 *   - intercepts the `input` event, converts the path into an image
 *     attachment for the model, replaces the path with `[image]`, and
 *   - appends a custom entry that draws the image inline in the transcript.
 *
 * Images use `@earendil-works/pi-tui`'s `Image` component, which emits normal
 * Kitty/iTerm graphics (the direct-placement path terminal multiplexers like
 * Herdr forward). Custom entries are not sent to the model.
 */
import { existsSync, statSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { extname, isAbsolute, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	getCapabilities,
	Image,
	type Component,
	type ImageTheme,
} from "@earendil-works/pi-tui";

const MIME_BY_EXT: Record<string, string> = {
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg",
	".webp": "image/webp",
	".gif": "image/gif",
};

const MARKER = "[image]";
const ENTRY_TYPE = "pasted-image";
const WIDGET_KEY = "pasted-image-preview";
const POLL_MS = 150;

/** Preview width as a fraction of the available terminal width. */
const WIDTH_FRACTION = 0.2;
const MIN_WIDTH_CELLS = 12;

/** Bare or quoted tokens ending in a supported image extension. */
const IMAGE_PATH_RE =
	/"[^"]*?\.(?:png|jpe?g|webp|gif)"|'[^']*?\.(?:png|jpe?g|webp|gif)'|\S+?\.(?:png|jpe?g|webp|gif)(?=\s|$)/gi;

interface PastedImage {
	data: string;
	mimeType: string;
}

/** Renders one or more images at a fraction of the available width. */
class ImagePreview implements Component {
	private cache = new Map<number, Image[]>();

	constructor(
		private readonly images: PastedImage[],
		private readonly theme: ImageTheme,
	) {}

	render(width: number): string[] {
		const maxWidthCells = Math.max(MIN_WIDTH_CELLS, Math.round(width * WIDTH_FRACTION));
		let components = this.cache.get(maxWidthCells);
		if (!components) {
			components = this.images.map(
				(image) => new Image(image.data, image.mimeType, this.theme, { maxWidthCells }),
			);
			this.cache.set(maxWidthCells, components);
		}
		const lines: string[] = [];
		for (const component of components) {
			lines.push(...component.render(width));
		}
		return lines;
	}

	invalidate(): void {
		this.cache.clear();
	}
}

function expandHome(p: string): string {
	if (p === "~") return homedir();
	if (p.startsWith("~/")) return resolve(homedir(), p.slice(2));
	return p;
}

function findImagePaths(text: string, cwd: string): Array<{ match: string; file: string; mime: string }> {
	const found: Array<{ match: string; file: string; mime: string }> = [];
	for (const match of text.match(IMAGE_PATH_RE) ?? []) {
		const unquoted = match.replace(/^["']|["']$/g, "");
		const expanded = expandHome(unquoted);
		const file = isAbsolute(expanded) ? expanded : resolve(cwd, expanded);
		const mime = MIME_BY_EXT[extname(file).toLowerCase()];
		if (mime && existsSync(file)) {
			found.push({ match, file, mime });
		}
	}
	return found;
}

export default function (pi: ExtensionAPI) {
	// Draw appended images in the transcript. Not part of LLM context.
	pi.registerEntryRenderer<PastedImage>(ENTRY_TYPE, (entry, _options, theme) => {
		const image = entry.data;
		if (!image?.data || !image.mimeType) return undefined;
		if (!getCapabilities().images) return undefined;
		return new ImagePreview([image], { fallbackColor: (s) => theme.fg("toolOutput", s) });
	});

	// Live preview above the editor while composing.
	let pollTimer: ReturnType<typeof setInterval> | undefined;
	const fileCache = new Map<string, { data: string; mimeType: string; mtimeMs: number }>();

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		if (pollTimer) clearInterval(pollTimer);
		const ui = ctx.ui;
		ui.setWidget(WIDGET_KEY, undefined);
		let lastSignature = "";
		let latestRequest = 0;

		const clear = () => {
			latestRequest++;
			ui.setWidget(WIDGET_KEY, undefined);
		};

		const show = async (paths: Array<{ file: string; mime: string }>) => {
			const request = ++latestRequest;
			const images: PastedImage[] = [];
			for (const { file, mime } of paths) {
				let mtimeMs: number;
				try {
					mtimeMs = statSync(file).mtimeMs;
				} catch {
					continue;
				}
				const cached = fileCache.get(file);
				if (cached && cached.mtimeMs === mtimeMs) {
					images.push({ data: cached.data, mimeType: cached.mimeType });
					continue;
				}
				try {
					const data = (await readFile(file)).toString("base64");
					fileCache.set(file, { data, mimeType: mime, mtimeMs });
					images.push({ data, mimeType: mime });
				} catch {
					// Skip unreadable files.
				}
			}
			// A newer paste (or a clear) superseded this read.
			if (request !== latestRequest) return;
			if (images.length === 0 || !getCapabilities().images) {
				ui.setWidget(WIDGET_KEY, undefined);
				return;
			}
			ui.setWidget(
				WIDGET_KEY,
				(_tui, theme) =>
					new ImagePreview(images, { fallbackColor: (s) => theme.fg("toolOutput", s) }),
				{ placement: "aboveEditor" },
			);
		};

		pollTimer = setInterval(() => {
			let text: string;
			try {
				text = ui.getEditorText();
			} catch {
				return;
			}
			const paths = findImagePaths(text, ctx.cwd);
			const signature = paths.map((p) => p.file).join("\n");
			if (signature === lastSignature) return;
			lastSignature = signature;
			if (paths.length === 0) {
				clear();
				return;
			}
			void show(paths);
		}, POLL_MS);
	});

	pi.on("session_shutdown", () => {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = undefined;
		}
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension" || !event.text) {
			return { action: "continue" };
		}

		const candidates = findImagePaths(event.text, ctx.cwd);
		if (candidates.length === 0) {
			return { action: "continue" };
		}

		const images = [...(event.images ?? [])];
		const beforeCount = images.length;
		let text = event.text;
		for (const candidate of candidates) {
			try {
				const encoded = (await readFile(candidate.file)).toString("base64");
				images.push({ type: "image", data: encoded, mimeType: candidate.mime });
				text = text.replace(candidate.match, MARKER);
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
