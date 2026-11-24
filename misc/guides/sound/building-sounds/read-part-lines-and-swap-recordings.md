# Read the part lines and swap wrong recordings

**Feeds stage:** building-sounds

Each `part N` line gives the design the part became, its measured behaviour, the next nearest designs and why it was chosen; watch also for `earshot has no ...`, `no recording of ...; ID is synthesized` and `not understood in part N`. A part is found by its words and can come back as the wrong recording: if a better one exists (`earshot sounds --search WORDS`), swap it with `sound=<id>` in its phrase. The stampede example: part 1 became `horse/trot` (scattered 26.2 a second over 6 s, level drawn -18 to +0 dB), part 2 `thunder/roll`, part 3 `horse/neigh` (2 times, under 3915 Hz).
