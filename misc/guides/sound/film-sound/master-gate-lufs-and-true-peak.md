# Master to -14 LUFS inside a tight loudness gate

**Feeds stage:** film-sound

`master.py` masters at -14 LUFS with a true-peak limiter and a ceiling of 0.77 linear. Accept the master only within +-0.5 LU of -14 and at <= -1.5 dBTP; after AAC encoding the true peak must still be <= -1 dBTP, since codec overshoot is already allowed for. Target LRA 5-9 LU, put the loudest moment on the drop (30-60 % into the film), keep the logo 8-20 dB under it and end with a tail into silence. The gate is measured, not judged by a listen: a value outside +-0.5 LU or -1.5 dBTP is a fail and the film goes back through `master.py --measure`.
