# Never generate image assets for posts

**Feeds stage:** longform

Do not generate a header, hero, thumbnail, OG/social preview, SVG, PNG or any
other illustration for a technical post. Point `image`, `thumbnail` and
`linkPreviewImage` at the expected paths (for example
`/images/blog/<slug>/hero.svg` and `og.png`) and say plainly that the user still
needs to add those files.
