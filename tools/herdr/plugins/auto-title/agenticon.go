package resolver

import "github.com/kryptamine/herdr-auto-title/internal/state"

// Vendor marks from Herdr Agent Icons Max (herdr-radar 47c022d4).
// A pane with no agent, or an agent this face has no mark for, gets "".
//
// Lives in the installed Auto Title checkout as internal/resolver/agenticon.go.
// nameTab prefixes resolver.AgentLogo(tab.Context) onto the resolved title.
var agentLogos = map[string]string{
	"claude":     "\uE1A0",
	"codex":      "\uE1A1",
	"opencode":   "\uE1A2",
	"omp":        "\uE1A3",
	"cline":      "\uE1A4",
	"mastracode": "\uE1A5",
	"kimi":       "\uE1A6",
	"kilo":       "\uE1A7",
	"maki":       "\uE1A8",
	"pi":         "\uE1A9",
	"hermes":     "\uE1AA",
	"cursor":     "\uE1AB",
	"copilot":    "\uE1AC",
	"deepseek":   "\uE1AD",
	"gemini":     "\uE1AE",
	"gpt":        "\uE1AF",
	"qwen":       "\uE1B0",
	"grok":       "\uE1B1",
	"agy":        "\uE1B2",
	"kiro":       "\uE1B3",
	"amp":        "\uE1B4",
	"devin":      "\uE1B5",
	"qodercli":   "\uE1B6",
	"glm":        "\uE1B7",
	"kimchi":     "\uE1B8",
	"muse":       "\uE1B9",
	"crush":      "\uE1BA",
}

// AgentLogo is the vendor mark for the pane a tab is named after.
func AgentLogo(pane *state.PaneState) string {
	if pane == nil || !pane.HasAgent() {
		return ""
	}

	logo, ok := agentLogos[pane.Agent]
	if !ok {
		return ""
	}

	return logo + " "
}
