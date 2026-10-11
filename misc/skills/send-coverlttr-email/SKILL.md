---
name: send-coverlttr-email
description: >-
  Send a Coverlttr marketing email by POSTing the email/send job to
  https://www.coverlttr.com/api/internal/jobs. Use when the user wants to send
  a React Email template from misc/emails, a Twenty HTTP_REQUEST email, a
  founding-member offer, or any manual send that uses INTERNAL_JOBS_SECRET.
---

# Send a Coverlttr email

Twenty does not send mail itself. It POSTs an allowlisted job. Coverlttr renders the React Email template and Resend delivers it.

## Endpoint

- **URL:** `https://www.coverlttr.com/api/internal/jobs`
- **Method:** `POST`
- **Headers:**
  - `Authorization: Bearer <INTERNAL_JOBS_SECRET>`
  - `Content-Type: application/json`
  - `Idempotency-Key: <stable key>`
- **Secret:** `INTERNAL_JOBS_SECRET` in the coverlttr repo `.env.prod`. Read it in the process that sends. Never print it, log it, or write it into the skill, a commit, or the chat.
- **Success:** HTTP **202** `{ "accepted": true }` means **queued**, not delivered.

```json
{
  "id": "email/send",
  "data": {
    "template": "signup-follow-up",
    "to": "person@example.com",
    "data": {
      "firstName": "Ada"
    }
  }
}
```

`to` is one address, or an array of at most 10 (only the first is used). `data` is template props only: strings, numbers, booleans. Never send HTML. Omit a prop when the value is missing — do not send `"undefined"` or an unresolved `{{…}}` placeholder.

`Idempotency-Key` must be stable for that recipient and send (template + email + a campaign id). A retry with the same key does not enqueue a second email. Use a new key only when the user wants another copy.

## Who to send to

Send only the addresses the user named in that message.

- A test send names one inbox (for example the user's own). Send that address and no one else, even if a CSV of the eventual audience is attached.
- A list send happens only when the user says to send to that list. Read the file, skip rows with no email, and POST one job per address.
- Do not widen a test into the rest of the file on a later turn unless the user asks again.

## founding-member-offer

Template file: `misc/emails/emails/founding-member-offer.tsx`. Template key: `founding-member-offer`.

| Prop | Meaning |
| :--- | :--- |
| `firstName` | Greeting name. Omit when blank. |
| `letterCount` | Number of letters already prepared. `0` or omitted uses the new-user copy. Greater than 0 names that count. Send a JSON number, not a string. |

Audience file, when the user points at it: `/home/e/misc/to organize/coverlttr/founding-member-recipients.csv` (`firstName`, `email`, `letterCount`).

```json
{
  "id": "email/send",
  "data": {
    "template": "founding-member-offer",
    "to": "enb5@protonmail.com",
    "data": {
      "firstName": "Enb",
      "letterCount": 4
    }
  }
}
```

The live API only accepts template keys registered in `frontend/src/lib/jobs/functions/emails/registry.ts`. A 400 `Invalid job payload` on `template` means that key is not on the deployed server yet. Do not call Resend yourself.

If the user still wants that send before the registry change is deployed, POST the same body to the local dev jobs API (`http://localhost:5180/api/internal/jobs`, secret from `.env.dev`) and set `baseURL` to `https://www.coverlttr.com` (sibling of `template` / `to` / `data`) so the unsubscribe link is the public site. Say that this went through the local worker.
