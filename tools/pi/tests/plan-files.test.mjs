import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import test from 'node:test';

import {
	extractPlansDirFromAgents,
	renderPlanMarkdown,
	slugifyPlanName,
} from '../agent/extensions/modes/utils.ts';

const extensionSource = stripTypeScriptTypes(
	readFileSync(new URL('../agent/extensions/modes/index.ts', import.meta.url), 'utf8'),
)
	.replace(
		/import\s*\{[^}]*\}\s*from\s*"@earendil-works\/pi-tui";/,
		'const Key = { shift: () => ({}), ctrlAlt: () => ({}) };',
	)
	.replace('from "./utils.ts"', `from "${pathToFileURL(new URL('../agent/extensions/modes/utils.ts', import.meta.url).pathname).href}"`);

let serial = 0;

function planMessage(steps = ['Do a thing', 'Do another thing']) {
	const text = `Plan:\n${steps.map((step, i) => `${i + 1}. ${step}`).join('\n')}`;
	return { role: 'assistant', content: [{ type: 'text', text }] };
}

async function fixture(t, { agents, misc = false, subdir, answer } = {}) {
	const root = mkdtempSync(join(tmpdir(), 'pi-modes-'));
	t.after(() => rmSync(root, { recursive: true, force: true }));
	mkdirSync(join(root, '.git'));
	if (agents) writeFileSync(join(root, 'AGENTS.md'), agents);
	if (misc) mkdirSync(join(root, 'misc', 'plans'), { recursive: true });
	const cwd = subdir ? join(root, subdir) : root;
	if (subdir) mkdirSync(cwd, { recursive: true });

	const handlers = {};
	const commands = {};
	const pi = {
		registerFlag() {},
		registerCommand(name, command) {
			commands[name] = command;
		},
		registerShortcut() {},
		getActiveTools() {
			return [];
		},
		setActiveTools() {},
		appendEntry() {},
		on(event, handler) {
			(handlers[event] ??= []).push(handler);
		},
		sendMessage() {},
		getFlag() {
			return undefined;
		},
	};

	const { default: extension } = await import(
		`data:text/javascript;base64,${Buffer.from(extensionSource).toString('base64')}#${serial++}`
	);
	extension(pi);

	const notifications = [];
	const ctx = {
		mode: 'tui',
		cwd,
		hasUI: true,
		ui: {
			notify: (message, level) => notifications.push({ message, level }),
			setStatus() {},
			setWidget() {},
			select: async (message, options) =>
				answer ? answer(message, options) : options[0],
			editor: async () => undefined,
			theme: { fg: (_color, text) => text, strikethrough: (text) => text },
		},
		sessionManager: { getEntries: () => [] },
	};

	await commands.plan.handler('', ctx);
	return { root, cwd, ctx, handlers, commands, notifications };
}

const stayInPlanMode = (message, options) =>
	message.includes('what next') ? options[1] : options[0];

test('extractPlansDirFromAgents reads explicit markers and natural language', () => {
	assert.equal(extractPlansDirFromAgents('plans-dir: docs/plans'), 'docs/plans');
	assert.equal(extractPlansDirFromAgents('- Plan files: `notes/plans/`'), 'notes/plans');
	assert.equal(extractPlansDirFromAgents('Use docs/plans to store plans'), 'docs/plans');
	assert.equal(extractPlansDirFromAgents('Store plans under `planning/`.'), 'planning');
	assert.equal(extractPlansDirFromAgents('Plans should be saved in docs/plans'), 'docs/plans');
	assert.equal(extractPlansDirFromAgents('Plans go in `.plans`'), '.plans');
	assert.equal(extractPlansDirFromAgents('Do not store plans in docs/plans'), undefined);
	assert.equal(extractPlansDirFromAgents('No plan storage override here.'), undefined);
});

test('slugifyPlanName and renderPlanMarkdown produce a readable plan file', () => {
	assert.equal(slugifyPlanName('Refactor the header + nav!'), 'refactor-the-header-nav');
	assert.equal(slugifyPlanName('...'), 'plan');

	const markdown = renderPlanMarkdown({
		title: 'Fix login',
		project: '/repo',
		created: '2026-01-01T00:00:00.000Z',
		status: 'in-progress',
		body: 'Plan:\n1. Fix it',
		todos: [
			{ step: 1, text: 'Fix it', completed: true },
			{ step: 2, text: 'Test it', completed: false },
		],
	});
	assert.match(markdown, /^# Plan: Fix login/m);
	assert.match(markdown, /- Status: in progress/);
	assert.match(markdown, /- \[x\] 1\. Fix it/);
	assert.match(markdown, /- \[ \] 2\. Test it/);
	assert.match(markdown, /## Plan\n\nPlan:\n1\. Fix it/);
});

test('plan mode creates misc/plans after confirmation and saves the plan', async (t) => {
	const { root, ctx, handlers } = await fixture(t, { answer: stayInPlanMode });
	await handlers.agent_end[0]({ messages: [planMessage()] }, ctx);

	const dir = join(root, 'misc', 'plans');
	assert.equal(existsSync(dir), true);
	const files = readdirSyncSafe(dir);
	assert.equal(files.length, 1);
	const content = readFileSync(join(dir, files[0]), 'utf8');
	assert.match(content, /# Plan: Do a thing/);
	assert.match(content, /1\. Do a thing/);
});

test('plan mode uses an existing misc/plans without asking to create it', async (t) => {
	let askedToCreate = false;
	const { root, ctx, handlers } = await fixture(t, {
		misc: true,
		answer: (message, options) => {
			if (message.includes('does not exist')) askedToCreate = true;
			return stayInPlanMode(message, options);
		},
	});
	await handlers.agent_end[0]({ messages: [planMessage()] }, ctx);

	assert.equal(askedToCreate, false);
	assert.equal(readdirSyncSafe(join(root, 'misc', 'plans')).length, 1);
});

test('an AGENTS.md override wins, relative to the AGENTS.md file', async (t) => {
	const { root, ctx, handlers } = await fixture(t, {
		agents: 'Use docs/plans to store plans\n',
		subdir: 'src/app',
		answer: stayInPlanMode,
	});
	await handlers.agent_end[0]({ messages: [planMessage()] }, ctx);

	assert.equal(readdirSyncSafe(join(root, 'docs', 'plans')).length, 1);
	assert.equal(existsSync(join(root, 'misc', 'plans')), false);
});

test('declining creation leaves the repo untouched', async (t) => {
	const { root, ctx, handlers } = await fixture(t, {
		answer: (message, options) =>
			message.includes('does not exist') ? options[1] : options[1],
	});
	await handlers.agent_end[0]({ messages: [planMessage()] }, ctx);

	assert.equal(existsSync(join(root, 'misc', 'plans')), false);
});

function readdirSyncSafe(path) {
	try {
		return readdirSync(path);
	} catch {
		return [];
	}
}
