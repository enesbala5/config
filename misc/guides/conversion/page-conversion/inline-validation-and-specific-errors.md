# Validate inline with specific, non-destructive errors

**Feeds stage:** audit

Validate as the person moves to the next field, not aggressively on every
keystroke, with clear indicators such as a green check or red border. Make error
messages specific, positioned near the field and suggestive of a fix — good:
"Please enter a valid email address (e.g., name@company.com)"; bad: "Invalid
input". On submit, focus the first error, summarise multiple errors and preserve
all entered data; never clear the form on error.
