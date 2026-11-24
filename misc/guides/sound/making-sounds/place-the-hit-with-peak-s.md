# Place the hit with peak_s, not the file start

**Feeds stage:** making-sounds

Every file starts when its sound does (within 2 ms), but its loudest moment is often later. The line says `peak at`; `--json` gives `peak_s`, `onset_s` and, for a row, `events_s` (each event's start) in seconds from the file start. To put the hit on the frame at t, start the file at t minus `peak_s`: "a whoosh for a transition" answered `whoosh/sweep (0.42 s, peak at 0.30 s, ...)`, so for its peak on 12.000 s start it at 11.70 s. A riser ends on its peak, so it starts its own length before the reveal. earshot does not place files on a timeline: the editor, ffmpeg or the page's code does.
