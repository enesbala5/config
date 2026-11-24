# fit turns a recording into editable code, not a trimmed sample

**Feeds stage:** film-sound

`earshot fit` fits a small synthesis model with readable parameters — ringing modes, tracked partials, a noise gesture, or layers of them — to a recording and writes it as a forge recipe module that renders new takes, variations and morphs: `earshot fit click.wav -o made/click_fit.py --report`, `earshot fit --morph a.wav b.wav --amount 0.5 -o made/ab_morph.py`. A fit is a derivative of its recording, so it keeps the source's licence. Use it when a film needs variants of one recorded sound without shipping the original audio; use `make` or `sfx` when a catalogue design already is the thing.
