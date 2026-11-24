# A/B the change, match a claim, compare to a palette

**Feeds stage:** listening

To choose between candidates use `earshot ab a.ogg b.ogg --query "a crisp fast air whoosh"` with `--a-start/--a-end/--b-start/--b-end` for trims (A and B may be the same multi-take file). A whole-file A/B of multi-take files compares every take plus the silence between them. `earshot match winner.ogg "a deep thocky key press" --alts "a clicky blue switch" "a typewriter key"` tests one claim; `earshot compare winner.ogg --refs approved/ [--start --end]` checks it fits the palette (typicality z >= -1 fits, < -2 is an outlier). For a change, A/B before/after (`--query "warm punchy kick"` or `--refs pro_refs/`), read how B differs in measured words (louder, brighter, longer decay), then `earshot timeline after.wav` and compare event lines and sync stats with the old run. Change one thing at a time.
