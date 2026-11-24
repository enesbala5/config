# A written second opinion needs explicit upload consent

**Feeds stage:** placement-and-limits

`earshot llm mix.wav --yes-upload [--with-timeline] [--prompt "Is the riser at 0:12 cheap?"]` asks Google Gemini for a rubric critique (sync, realism, mix, loudness, what sounds cheap, fixes with times). It runs only when the user has set GEMINI_API_KEY (or GOOGLE_API_KEY) AND explicitly agreed that the audio is uploaded to Google. Ask first; never pass `--yes-upload`/consent on your own. Only audio is sent (mono 64 kbps). Its timestamps are approximate and its scores are one model's opinion: confirm every fix with timeline/ab.
