/**
 * Skills: names only.
 *
 * Pi's default skills section prints every skill's name, full description and
 * absolute path. With ~106 installed skills that is ~64k characters (~17k
 * tokens) on every request, none of it used unless the model actually loads a
 * skill.
 *
 * This replaces the section with one line per skill directory (the names) plus
 * a single instruction, so the model still knows the catalog exists and where
 * to read a SKILL.md, at ~1.3k characters instead of ~64k.
 *
 * It overrides the `skills` prompt section instead of forcing a rewritten
 * system prompt, so the stored transcript stays small too. That matters for
 * providers that report no usage (local llama.cpp): pi estimates context from
 * the stored sections, and a 64k-char section made the footer read ~19k tokens
 * against a real request of ~3.5k.
 *
 * Skills load on demand only: the model reads `<dir>/<name>/SKILL.md` when the
 * user names one. Nothing on disk changes and `/skill:<name>` keeps working.
 */
import { dirname } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function skillsNamesOnly(pi: ExtensionAPI) {
	pi.on("before_agent_start", (event) => {
		const options = event.systemPromptOptions;
		const skills = options.skills?.filter((skill) => !skill.disableModelInvocation);
		if (!skills?.length) return;

		const byDir = new Map<string, string[]>();
		for (const skill of skills) {
			const root = dirname(skill.baseDir);
			const names = byDir.get(root) ?? [];
			names.push(skill.name);
			byDir.set(root, names);
		}

		const lines = [
			"Skill instructions are not loaded. When the user names a skill, or the task clearly matches one, read `<dir>/<name>/SKILL.md` and follow it.",
		];
		for (const [dir, names] of byDir) {
			lines.push(`${dir}: ${names.sort().join(", ")}`);
		}

		options.sections.skills = lines.join("\n");
	});
}
