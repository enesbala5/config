# Rules: design

Constraints while designing a surface or a sequence. Loaded by `audit` and
`plan`, and by `verify` when it checks a proposed design.

- **One primary action.** Exactly one primary action per page, form, first
  session or email; settle it before designing the rest.
  Evidence: `<config>/misc/guides/conversion/page-conversion/one-primary-cta-above-fold.md`
  Evidence: `<config>/misc/guides/conversion/page-conversion/landing-page-single-focus.md`
  Evidence: `<config>/misc/guides/conversion/activation/one-goal-per-first-session.md`
  Evidence: `<config>/misc/guides/conversion/lifecycle-email/one-email-one-job.md`
- **Aha before ask.** Place any upgrade or paywall ask after demonstrated value,
  timed to the activation event.
  Evidence: `<config>/misc/guides/conversion/monetization/ask-for-upgrade-after-value.md`
- **Genuine triggers only.** Tie a paywall to a real user action or limit, not an
  arbitrary timer, and never interrupt an active flow.
  Evidence: `<config>/misc/guides/conversion/monetization/trigger-paywalls-on-genuine-moments.md`
- **Respect the no.** Every paywall offers a visible decline that does not cost
  access, and back off after dismissal.
  Evidence: `<config>/misc/guides/conversion/monetization/respect-the-no-with-escape-hatch-and-cool-down.md`
- **Cut steps to value.** Remove non-value steps between signup and first value
  instead of explaining them.
  Evidence: `<config>/misc/guides/conversion/activation/cut-every-step-between-signup-and-value.md`
- **Dismissable guidance.** Keep tours short, one-time and closable; no step may
  gate product use.
  Evidence: `<config>/misc/guides/conversion/activation/keep-guided-tours-short-and-dismissable.md`
- **Email supports the product.** Email reinforces the in-app flow with one CTA
  and personalization on real actions; it never duplicates it.
  Evidence: `<config>/misc/guides/conversion/lifecycle-email/email-supports-in-app-onboarding.md`
