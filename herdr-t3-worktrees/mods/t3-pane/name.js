// What a terminal is on, one rule for Inbox cards, the agents list, tabs and pane headers:
// its Pi session, then (agents only) a tab someone named, then a telling terminal title, else the program.
// A terminal with no title of its own reports its address (t9) as one: that tells nothing.
import { terminals, spaces } from "herdr";

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();
// Agents' own title marks, by program (the key their status report names): Pi's "π - <session> - <folder>",
// OpenCode's "OC | <session>". Only theirs come off: a shell's title that happens to look alike stays.
const OWN = {
  pi: (s, folder) => { s = s.replace(/^π - /u, ""); return folder && s.endsWith(` - ${folder}`) ? s.slice(0, -folder.length - 3) : s; },
  opencode: (s) => s.replace(/^OC \| /, ""),
};

// Snapshot once per render; the returned function takes an agent or a pane (status set = an agent).
export function namer() {
  const term = new Map(terminals().map((k) => [k.address, k]));
  const tabs = new Map(spaces().flatMap((s) => s.tabs.map((c) => [c.id, { ...c, space: s.name }])));
  return (x) => {
    const address = x.address ?? x.terminal;
    const tab = tabs.get(x.tab);
    // A title that only names the folder (Codex's project, Pi with no session) says what the space already does.
    const folder = (term.get(address)?.cwd ?? x.cwd ?? "").split(/[\\/]/).pop();
    const own = OWN[x.program?.key];
    const live = own ? own(clean(x.title), folder) : clean(x.title);
    const telling = live && live !== x.program?.name && live.toLowerCase() !== x.program?.key
      && !/^[~/]|^[A-Za-z]:\\/.test(live) && !live.includes("@") && live !== address
      && live !== folder && live !== (x.space_name ?? tab?.space);
    return term.get(address)?.labels?.["pi.session"] || (x.status != null && tab?.named && tab.name)
      || (telling && live) || x.program?.name || address || "shell";
  };
}
