# Build when the catalogue lacks the thing

**Feeds stage:** building-sounds

When the answer says `earshot makes no X`, build on the workbench (MCP `build`, `parts`). You know what physically makes the sound: say it, one part a thing, and earshot finds a recording for each and writes the recipe. Example: `earshot build "a stampede of horses" -o stampede.wav --part "hundreds of hoofbeats, for 6 s, getting louder" --part "a low rumble under everything, soft" --part "a horse neighing, twice, far"` → `recipe/a_stampede_of_horses_parts (8.53 s, peak at 6.20 s, -14 LUFS, clean) [built]`. Then read `part N`, `fit:` and `still off:` in that order, and hand it over as what `fit` says: a sketch is a sketch, and a person should listen once. Without `--part` earshot drafts the parts itself.
