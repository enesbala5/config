# Never say how audio sounds without a reading

**Feeds stage:** listening

You cannot hear. Never say how audio sounds, or that a sound "fits", without an earshot reading behind it, and quote the number when you report: "strong match, z +3.9; p_real 0.96; -14.2 LUFS". earshot runs locally on CPU (audio never leaves the machine except with the optional `llm` command) and caches every embedding and result on disk. Each CLI call is a new process that loads the models first (~20-40 s even for a cached file); inside the MCP server or one Python script the models load once and repeats take seconds. For more than a handful of calls use MCP or a short script (`from earshot import api; api.find(...); api.realness(...)`). Any ffmpeg-readable file works, including the audio of an mp4.
