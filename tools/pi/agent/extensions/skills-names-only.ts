/**
 * Skills: names only.
 *
 * Pi's default skills section prints every skill's name, full description and
 * absolute path. With ~110 installed skills that is ~17k tokens on every
 * request, none of it used unless the model actually loads a skill.
 *
 * This rewrites the `<skills>` section to one line per skill directory (the
 * names) plus a single instruction, so the model still knows the catalog
 * exists and where to read a SKILL.md, at ~1k tokens instead of ~17k.
 *
 * Skills are loaded on demand only: the model reads `<dir>/<name>/SKILL.md`
 * when the user names one. Nothing is removed from disk, and `/skill:<name>`
 * keeps working.
 */
import { dirname } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SKILLS_SECTION = /<skills>[\s\S]*?<\/skills>/;

export default function skillsNamesOnly(pi: ExtensionAPI) {
	pi.on("before_agent_start", (event) => {
		const skills = event.systemPromptOptions.skills?.filter(
			(skill) => !skill.disableModelInvocation,
		);
		if (!skills?.length) return;

		const prompt = event.systemPrompt;
		if (!SKILLS_SECTION.test(prompt)) return;

		const byDir = new Map<string, string[]>();
		for (const skill of skills) {
			const root = dirname(skill.baseDir);
			const names = byDir.get(root) ?? [];
			names.push(skill.name);
			byDir.set(root, names);
		}

		const lines = [
			"<skills>",
			"Skill instructions are not loaded. When the user names a skill, or the task clearly matches one, read `<dir>/<name>/SKILL.md` and follow it.",
		];
		for (const [dir, names] of byDir) {
			lines.push(`${dir}: ${names.sort().join(", ")}`);
		}
		lines.push("</skills>");

		return { systemPrompt: prompt.replace(SKILLS_SECTION, lines.join("\n")) };
	});
}
