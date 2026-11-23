# Stage index

Routing only — no lesson content lives here. Lessons stay in `{{GUIDE_PATH}}`.

An intent names a stage; the reader loads this file, the stage README, the guide
root README, the bucket README, then only the lessons the task names. Never read
a whole bucket, and never open a second sibling branch for the same question.
A nested stage file only adds or overrides; it never restates an ancestor.

| Stage | Owns | Guide buckets |
| --- | --- | --- |
{{STAGE_ROWS}}

## Adding to the pipeline

- A new lesson goes into a guide bucket first; the bucket README is its index.
  No edit here unless a *whole bucket* is new.
- A new stage is one folder here plus one row in the table above. Intent files
  keep pointing at this index, not at individual lessons.
