import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { registerHooks, stripTypeScriptTypes } from "node:module";
import { tmpdir } from "node:os";
import { delimiter, dirname, join, resolve } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import test from "node:test";

// Resolve the installed Pi, not a second npm copy of its editor. Nix's wrapper
// lives beside lib/pi/node_modules; npm installs work via `npm root -g`.
function installedModules() {
	const candidates = [process.env.PI_NODE_MODULES];
	for (const dir of (process.env.PATH ?? "").split(delimiter)) {
		const bin = join(dir, "pi");
		if (!existsSync(bin)) continue;
		const root = resolve(dirname(realpathSync(bin)), "..");
		candidates.push(join(root, "lib/pi/node_modules"), join(root, "lib/node_modules"));
	}
	try { candidates.push(execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim()); } catch {}
	const found = candidates.find((dir) => dir && existsSync(join(dir, "@earendil-works/pi-coding-agent/dist/index.js")));
	assert.ok(found, "Install Pi or set PI_NODE_MODULES to its node_modules directory");
	return found;
}
const modules = installedModules();
const packagePath = (name, path) => pathToFileURL(join(modules, `@earendil-works/${name}`, path)).href;
const extensionUrl = new URL("../agent/extensions/ctrl-p-slash.ts", import.meta.url).href;
const hooks = registerHooks({
	resolve(specifier, context, next) {
		if (["@earendil-works/pi-coding-agent", "@earendil-works/pi-tui"].includes(specifier)) {
			return next(pathToFileURL(join(modules, specifier, "dist/index.js")).href, context);
		}
		return next(specifier, context);
	},
	load(url, context, next) {
		if (url !== extensionUrl) return next(url, context);
		return { format: "module", source: stripTypeScriptTypes(readFileSync(fileURLToPath(url), "utf8")), shortCircuit: true };
	},
});
const { default: extension, SlashEditor, BUILTIN_COMMANDS, inlineSlashProvider } = await import(extensionUrl);
const { CombinedAutocompleteProvider, setKeybindings } = await import("@earendil-works/pi-tui");
const { KeybindingsManager } = await import(packagePath("pi-coding-agent", "dist/core/keybindings.js"));
const { InteractiveMode } = await import("@earendil-works/pi-coding-agent");
const { BUILTIN_SLASH_COMMANDS } = await import(packagePath("pi-coding-agent", "dist/core/slash-commands.js"));
hooks.deregister();

const plain = (text) => text;
const theme = { borderColor: plain, selectList: { selectedPrefix: plain, selectedText: plain, description: plain, scrollInfo: plain, noMatch: plain } };
const resources = [
	{ name: "widget", source: "extension" },
	{ name: "review", source: "prompt" },
	{ name: "skill:testing", source: "skill" },
];
const commands = [...BUILTIN_SLASH_COMMANDS, ...resources];
const tick = () => new Promise(setImmediate);
async function waitFor(predicate) {
	for (let i = 0; i < 100; i++) {
		if (predicate()) return;
		await delay(5);
	}
	assert.fail("Timed out waiting for editor/dispatcher");
}
function fixture(options = {}) {
	const kb = new KeybindingsManager(options.bindings);
	setKeybindings(kb);
	const errors = [], submitted = [], changes = [];
	let active = true;
	const tui = { terminal: { rows: 40, columns: 120 }, requestRender() {} };
	const editor = new SlashEditor(tui, theme, kb, {
		getCommands: () => resources,
		isActive: () => active,
		onError: (message) => errors.push(message),
	});
	editor.onSubmit = options.submit ?? ((text) => submitted.push(text));
	editor.onChange = (text) => changes.push(text);
	editor.setAutocompleteProvider(options.provider ?? new CombinedAutocompleteProvider(commands, tmpdir()));
	return { editor, errors, submitted, changes, tui, deactivate: () => { active = false; } };
}
function type(editor, text) { for (const char of text) editor.handleInput(char); }
async function suggest(editor, text) {
	type(editor, text);
	await waitFor(() => editor.isShowingAutocomplete());
	// The menu can be visible while a newer query is still pending.
	await delay(10);
}
function deferred() {
	let resolve, reject;
	const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
	return { promise, resolve, reject };
}

// Use the real interactive dispatcher and selector focus lifecycle without
// credentials, model requests, a terminal process, or writes to user settings.
function nativeFixture() {
	const f = fixture();
	const container = { children: [], clear() { this.children = []; }, addChild(child) { this.children.push(child); } };
	let focus = f.editor, opened = 0, selected = 0;
	const mode = Object.create(InteractiveMode.prototype);
	Object.assign(mode, {
		defaultEditor: f.editor, editor: f.editor,
		runtimeHost: { session: { isStreaming: false, isCompacting: false } },
		editorContainer: container,
		ui: { setFocus(component) { focus = component; }, requestRender() {} },
		pendingUserInputs: [], flushPendingBashComponents() {},
		showModelSelector() {
			opened++;
			this.showSelector((done) => {
				const selector = { handleInput(key) { if (key === "\r") selected++; done(); } };
				return { component: selector, focus: selector };
			});
		},
	});
	mode.setupEditorSubmitHandler();
	return { ...f, mode, container, focus: () => focus, opened: () => opened, selected: () => selected };
}

test("built-in command allowlist matches the installed Pi release", () => {
	assert.deepEqual([...BUILTIN_COMMANDS].sort(), BUILTIN_SLASH_COMMANDS.map((cmd) => cmd.name).sort());
});

test("one Enter runs /model through Pi's native dispatcher", async () => {
	const f = nativeFixture();
	await suggest(f.editor, "/mod");
	f.editor.handleInput("\r");
	assert.equal(f.opened(), 1);
	assert.equal(f.editor.getText(), "");
	assert.notEqual(f.focus(), f.editor);
	assert.deepEqual(f.mode.pendingUserInputs, []);
	f.focus().handleInput("\r");
	assert.equal(f.selected(), 1);
	assert.equal(f.focus(), f.editor);
});

for (const key of ["\r", "\x1b"]) {
	test(`inline command preserves draft and cursor after picker ${key === "\r" ? "selection" : "cancellation"}`, async () => {
		const f = nativeFixture();
		f.editor.setText("Please explain  afterwards.");
		// Move into the middle of the line using native editor navigation.
		for (let i = 0; i < " afterwards.".length; i++) f.editor.handleInput("\x1b[D");
		await suggest(f.editor, "/mod");
		f.editor.handleInput("\r");
		assert.equal(f.opened(), 1);
		assert.equal(f.editor.getText(), "Please explain  afterwards.");
		assert.deepEqual(f.editor.getCursor(), { line: 0, col: "Please explain ".length });
		f.focus().handleInput(key);
		assert.equal(f.focus(), f.editor);
		assert.equal(f.editor.getText(), "Please explain  afterwards.");
		assert.deepEqual(f.mode.pendingUserInputs, []);
	});
}

test("inline command on a later line executes without sending the draft", async () => {
	const f = nativeFixture();
	f.editor.setText("First line\nSecond line ");
	await suggest(f.editor, "/mod");
	f.editor.handleInput("\r");
	assert.equal(f.opened(), 1);
	assert.equal(f.editor.getText(), "First line\nSecond line ");
	assert.deepEqual(f.editor.getCursor(), { line: 1, col: 12 });
});

test("Tab inserts the selected name without execution, including remapped Tab", async () => {
	for (const bindings of [{}, { "tui.input.tab": "ctrl+i" }]) {
		const f = fixture({ bindings });
		await suggest(f.editor, "Draft /mod");
		f.editor.handleInput("\t");
		assert.equal(f.editor.getText(), "Draft /model ");
		assert.deepEqual(f.submitted, []);
	}
});

test("Tab allows native standalone argument completion before submission", async () => {
	const provider = new CombinedAutocompleteProvider([
		{ name: "model", getArgumentCompletions: () => [{ value: "test/example", label: "test/example" }] },
	], tmpdir());
	const f = fixture({ provider });
	await suggest(f.editor, "/mod");
	f.editor.handleInput("\t");
	assert.equal(f.editor.getText(), "/model ");
	await suggest(f.editor, "t");
	f.editor.handleInput("\r");
	assert.equal(f.editor.getText(), "/model test/example");
	assert.deepEqual(f.submitted, []);
	f.editor.handleInput("\r");
	assert.deepEqual(f.submitted, ["/model test/example"]);
});

for (const name of ["review", "skill:testing"]) {
	test(`${name} completion inserts only, standalone and inline`, async () => {
		for (const prefix of ["", "Draft "]) {
			const f = fixture();
			await suggest(f.editor, `${prefix}/${name}`);
			f.editor.handleInput("\r");
			assert.equal(f.editor.getText(), `${prefix}/${name} `);
			assert.deepEqual(f.submitted, []);
		}
	});
}

test("slash-looking command arguments retain native completion semantics", async () => {
	const provider = new CombinedAutocompleteProvider([
		{ name: "widget", getArgumentCompletions: () => [{ value: "model", label: "model" }] },
	], tmpdir());
	const f = fixture({ provider });
	await suggest(f.editor, "/widget /mod");
	f.editor.handleInput("\r");
	assert.equal(f.editor.getText(), "/widget model");
	assert.deepEqual(f.submitted, []);
});

test("existing Ctrl+/ model shortcut still passes through with draft intact", () => {
	const f = fixture({ bindings: { "app.model.select": "ctrl+/" } });
	let opened = 0;
	f.editor.onAction("app.model.select", () => { opened++; });
	f.editor.setText("Unfinished draft");
	f.editor.handleInput("\x1b[47;5u");
	assert.equal(opened, 1);
	assert.equal(f.editor.getText(), "Unfinished draft");
	assert.deepEqual(f.submitted, []);
});

test("an extension command executes by itself", async () => {
	const f = fixture();
	await suggest(f.editor, "Draft /wid");
	f.editor.handleInput("\r");
	assert.deepEqual(f.submitted, ["/widget"]);
	assert.equal(f.editor.getText(), "Draft ");
});

test("arrow selection dispatches the highlighted item, not the typed prefix", async () => {
	const f = fixture({ provider: new CombinedAutocompleteProvider([{ name: "model" }, { name: "settings" }], tmpdir()) });
	await suggest(f.editor, "Draft /");
	f.editor.handleInput("\x1b[B");
	f.editor.handleInput("\r");
	assert.deepEqual(f.submitted, ["/settings"]);
});

test("forced absolute file completion named model never executes /model", async () => {
	const provider = {
		getSuggestions: async () => ({ items: [{ value: "model", label: "model" }], prefix: "/mo" }),
		applyCompletion: () => ({ lines: ["model"], cursorLine: 0, cursorCol: 5 }),
	};
	const f = fixture({ provider });
	f.editor.setText("/mo");
	// Force-mode file suggestions, as opposed to natural command suggestions.
	f.editor.forceFileAutocomplete(false);
	await waitFor(() => f.editor.isShowingAutocomplete());
	f.editor.handleInput("\r");
	assert.equal(f.editor.getText(), "model");
	assert.deepEqual(f.submitted, []);
});

test("single-segment absolute paths fall back to native file completion", async () => {
	const f = fixture();
	await suggest(f.editor, "Read /tmp");
	f.editor.handleInput("\r");
	assert.equal(f.editor.getText(), "Read /tmp/");
	assert.deepEqual(f.submitted, []);
});

test("paths and URLs delegate unchanged; stale requests do not mark executable items", async () => {
	for (const text of ["See https://example.com/mod", "Read ./src/mod", "Read /tmp/mod", "Read ~/mod"]) {
		let received;
		const provider = inlineSlashProvider({
			getSuggestions: async (...args) => { received = args; return null; },
			applyCompletion() { assert.fail("no completion expected"); },
		});
		const controller = new AbortController();
		await provider.getSuggestions([text], 0, text.length, { signal: controller.signal });
		assert.deepEqual(received.slice(0, 3), [[text], 0, text.length]);
	}
	let executed = 0;
	const controller = new AbortController();
	controller.abort();
	const item = { value: "model", label: "model" };
	const provider = inlineSlashProvider({
		getSuggestions: async () => ({ items: [item], prefix: "/mod" }),
		applyCompletion: () => ({ lines: ["unchanged"], cursorLine: 0, cursorCol: 0 }),
	}, () => { executed++; });
	await provider.getSuggestions(["Draft /mod"], 0, 10, { signal: controller.signal });
	provider.applyCompletion(["Draft /mod"], 0, 10, item, "/mod");
	assert.equal(executed, 0);
});

test("async housekeeping clears cannot erase existing or newly typed draft text", async () => {
	const pending = deferred();
	let editor;
	({ editor } = fixture({ submit: async () => {
		editor.setText("");
		await pending.promise;
		editor.setText("");
	} }));
	await suggest(editor, "Draft /copy");
	editor.handleInput("\r");
	assert.equal(editor.getText(), "Draft ");
	type(editor, "still typing");
	pending.resolve();
	await tick();
	assert.equal(editor.getText(), "Draft still typing");
});

test("pending dispatch cannot run twice or accidentally submit the draft", async () => {
	const pending = deferred(), submitted = [];
	const f = fixture({ submit: (text) => { submitted.push(text); return pending.promise; } });
	await suggest(f.editor, "Draft /copy");
	f.editor.handleInput("\r");
	f.editor.handleInput("\r");
	assert.deepEqual(submitted, ["/copy"]);
	pending.resolve();
	await tick();
});

test("command-controlled non-empty editor replacements remain intact", async () => {
	let editor;
	({ editor } = fixture({ submit: () => editor.setText("Intentional replacement") }));
	await suggest(editor, "Draft /wid");
	editor.handleInput("\r");
	await tick();
	assert.equal(editor.getText(), "Intentional replacement");
});

test("session commands retain native draft clearing", async () => {
	for (const name of ["new", "resume", "fork", "clone", "tree", "import", "reload", "quit"]) {
		let editor;
		({ editor } = fixture({ submit: () => editor.setText("") }));
		await suggest(editor, `Draft /${name}`);
		editor.handleInput("\r");
		await tick();
		assert.equal(editor.getText(), "", name);
	}
});

test("shutdown invalidates draft protection and prevents stale error notifications", async () => {
	const pending = deferred();
	const f = fixture({ submit: () => pending.promise });
	await suggest(f.editor, "Draft /copy");
	f.editor.handleInput("\r");
	f.deactivate();
	f.editor.setText("");
	pending.reject(new Error("old runtime"));
	await tick();
	assert.equal(f.editor.getText(), "");
	assert.deepEqual(f.errors, []);
});

test("dispatch errors are reported without losing the surrounding draft", async () => {
	const f = fixture({ submit: () => { throw new Error("failed"); } });
	await suggest(f.editor, "Draft /copy");
	f.editor.handleInput("\r");
	await tick();
	assert.equal(f.editor.getText(), "Draft ");
	assert.match(f.errors[0], /\/copy: Error: failed/);
});

test("pasted text expansion and undo survive inline execution", async () => {
	const f = nativeFixture();
	const pasted = "large pasted content\n".repeat(20);
	f.editor.handleInput(`\x1b[200~${pasted}\x1b[201~`);
	assert.match(f.editor.getText(), /\[paste #/);
	await suggest(f.editor, " /mod");
	f.editor.handleInput("\r");
	assert.equal(f.editor.getExpandedText(), `${pasted} `);
	f.focus().handleInput("\x1b");
	f.editor.handleInput("\x1f"); // native Ctrl+- undo
	assert.equal(f.editor.getExpandedText(), `${pasted} /mod`);
});

test("normal Enter, Shift+Enter and Escape retain editor behavior", async () => {
	const f = fixture();
	type(f.editor, "Draft");
	f.editor.handleInput("\x1b[13;2u");
	assert.equal(f.editor.getText(), "Draft\n");
	await suggest(f.editor, "/mod");
	f.editor.handleInput("\x1b");
	assert.equal(f.editor.getText(), "Draft\n/mod");
	assert.deepEqual(f.submitted, []);
	f.editor.setText("Plain prompt");
	f.editor.handleInput("\r");
	assert.deepEqual(f.submitted, ["Plain prompt"]);
});

test("disableSubmit prevents command execution", async () => {
	const f = fixture();
	await suggest(f.editor, "Draft /mod");
	f.editor.disableSubmit = true;
	f.editor.handleInput("\r");
	assert.deepEqual(f.submitted, []);
	assert.equal(f.editor.getText(), "Draft /model ");
});

test("extension loads only in TUI and reinitializes its lifetime on reload", async () => {
	const handlers = {};
	extension({ on: (name, handler) => { handlers[name] = handler; }, getCommands: () => resources });
	let factory;
	const ctx = { mode: "rpc", ui: { setEditorComponent(value) { factory = value; } } };
	handlers.session_start({}, ctx);
	assert.equal(factory, undefined);
	ctx.mode = "tui";
	handlers.session_start({}, ctx);
	const old = factory({ requestRender() {} }, theme, new KeybindingsManager());
	assert.equal(old.slashOptions.isActive(), true);
	handlers.session_shutdown();
	handlers.session_start({}, ctx);
	assert.equal(old.slashOptions.isActive(), false);
	const fresh = factory({ requestRender() {} }, theme, new KeybindingsManager());
	assert.equal(fresh.slashOptions.isActive(), true);
});
