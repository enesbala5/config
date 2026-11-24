# A stand-in is flagged by one line only

**Feeds stage:** making-sounds

`earshot makes no THING; ID is only the nearest sound it has` means the catalogue lacks the thing and the file is a stand-in. Build it with `earshot build`, take one of the three starting points by id, or tell the user it is missing — never pass a stand-in off as the thing. There is no error for an unknown thing: every request gets a file, and this line is the only sign. The same applies to `built from parts by the cookbook recipe NAME` (a recipe answered; `earshot recipe NAME` prints it to change) versus `a start from parts: earshot make --recipe NAME` (a cookbook sketch is only a start).
