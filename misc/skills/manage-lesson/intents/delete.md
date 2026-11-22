# Intent: delete

Remove a lesson safely.

## Parameters

- `topic`, `dir` — common parameters.
- `lesson` — required slug/path. **If missing, list candidate lessons and ask which one.**
- `confirm` — required explicit confirmation after the reference check.

## Steps

1. Read the lesson and its bucket `README.md`.
2. Reference check: search other lesson files and bucket READMEs for links or mentions of this lesson. Report every inbound reference to the user.
3. Ask for explicit confirmation, naming the file and the references found. Do not proceed without it.
4. Delete the file. Remove its bullet from the bucket README. Update or remove any inbound references that would otherwise break — show those edits in the same confirmation request.
5. Run `node <skill>/scripts/verify-lessons.js <dir>`.

## Do not

- Delete on a vague "yes" given before the reference check was shown.
- Delete a bucket README or a whole bucket with this intent.
- Modify archived sources.
