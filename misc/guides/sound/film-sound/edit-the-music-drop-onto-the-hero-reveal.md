# Edit one licensed track so its drop lands on the hero reveal

**Feeds stage:** film-sound

Use ONE licensed track whose structure fits the film. Write the arc per film bar, then let `arrange.py` fit the tempo, move the grid onto the measured attacks (beat trackers lag 20-50 ms), propose the downbeat phase, anchor the drop's film bar on the strongest drop candidate and draft segments at bar lines. The downbeat is the weak spot: when it prints LOW confidence (on one of the two tracks it was tested on it was half a bar off), choose between the two printed grids from the first note, the section entrances and the chord changes in the bar table, then re-run with `--phase N`. Finish by judgement: harmony continues across each splice, the drop's downbeat on the hero frame, the final chord on the logo, `tail_fade` into the end. Counterexample: trusting the detected grid without this check puts the drop half a bar away from the reveal.
