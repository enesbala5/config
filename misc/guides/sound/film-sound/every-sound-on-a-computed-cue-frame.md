# Place every sound on a frame the picture code computes

**Feeds stage:** film-sound

Step 0 of the real-recordings pipeline is the cue list (`out/cues.json`): a contact frame, a pop-in's 50 % frame, a move's velocity peak, a riser's hit, the frame the wordmark becomes readable. Every sound sits on one of these computed frames — do not place by eye. Give cues stable ids of the form `act:thing:n` so rules can match a class of action with a regex: one rule then covers every card pop instead of one cue at a time. Cinetic films export this file already; for any other picture write the same format from the timeline constants. Example: a card/chip appearing is placed at 50 % of its travel; a camera-scale move's swish peaks on the velocity peak; a riser ends on the hit.
