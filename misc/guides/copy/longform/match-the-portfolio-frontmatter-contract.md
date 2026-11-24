# Match the portfolio frontmatter contract

**Feeds stage:** longform

When writing into the portfolio repo the post is `src/posts/{slug}.md`, with
frontmatter carrying `title`, `description`, `metaTitle`, `metaDescription`,
`date`, `updated`, `tags`, `keywords`, `image`, `thumbnail`, `linkPreviewImage`
and `published`.

`title` is readable stack + outcome, not a keyword dump; `description` is a
one-line outcome; meta fields are shorter and mechanism-named for SEO tags;
`tags` come only from `src/lib/info/tags.ts`; `keywords` are comma-separated
tools/outcomes without duplicates; dates are `'YYYY-MM-DD'`; `published: true`
only when the user wants it live. The slug is the filename without `.md` —
short and literal (`nixos-stylix-polarity-toggle`). Omit older marketing-only
fields like `imageClassNames` on technical posts.
