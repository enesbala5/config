# Close the film with a clean audit, credits and the mux

**Feeds stage:** film-sound

Delivery is three gates, not just a loud wav: re-run the licence audit (`audit.py`, exit 0), then `credits.py` writes `CREDITS.md` and `out/CREDITS_description.txt` — paste the description text into the video description, where CC BY attribution is required. `mux.mjs` (Node) stream-copies the picture and cuts the AAC audio to the picture's duration, so the video is not re-encoded. Finally verify the finished, muxed file by listening to it (`earshot timeline out/film_sound.mp4 --cues out/qa/cues_sounded.json`), not the master wav. Credits exit 0 and lag 0 are the close gates.
