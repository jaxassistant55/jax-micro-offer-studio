# rando.id Theme Editor UX Sprint Notes

Generated: 2026-06-20 16:17:20 JST
Public repo: https://github.com/rando-id/rando.id
Paid-feature issue: https://github.com/rando-id/rando.id/issues/53
Related product spec: https://github.com/rando-id/rando.id/blob/main/specs/apps.md
Inspected commit: `8a0ccca`
Fixed first sprint: $100
Confirmed money: $0

## Why this is viable

The issue is recent, open, labeled `paid`, and explicitly says the theme editor is a UX design exercise that should close when a real design exists. This is not a bounty and not a request for private data. The useful first paid deliverable is a repo-grounded product design packet that resolves the open surface decisions before implementation.

## Repo facts

- `specs/apps.md` already defines `themes` and `user_theme_prefs` tables with custom themes, light/dark palettes, paid flags, active theme, and paid auto-seasonal behavior.
- `packages/config/src/themes/index.ts` defines `ThemeMode`, `ThemePalette`, `ThemePack`, `FREE_THEME_LIMIT = 2`, `PAID_THEME_LIMIT = 5`, `getThemePack`, and seasonal window helpers.
- `packages/config/src/themes/example.theme.ts` documents the real theme-pack authoring contract and warns that theme IDs are stable storage keys.
- `packages/config/src/feature-flags.ts` has a simple `free | pro` tier model, but no `custom-theme-editor` flag yet.
- `packages/ui/src/tamagui.config.ts` creates Tamagui config from the default config; runtime custom themes need a design choice before code.
- `apps/web` and `apps/native` both consume the shared UI/config layer, so the design should avoid a web-only surface unless explicitly chosen.

## Decision packet deliverable

1. Product choice: in-app editor first, with JSON import as an advanced option after validation.
2. Editor IA: gallery, duplicate starting theme, edit light palette, edit dark palette, validate, preview, save, apply, share/export later.
3. Palette validation: every `ThemePalette` slot required, hex format only in v1, contrast gate for background/foreground and primary/background, visible border/muted contrast checks.
4. Paid gate: add `custom-theme-editor` as a pro feature while allowing free users to preview/import one sample without saving.
5. Storage: DB JSON for user-owned packs first; Vercel Blob only for exported files or future marketplace assets.
6. Tamagui constraint: generated user themes must be translated into the runtime theme shape without requiring a rebuild.
7. Test plan: pure validation tests in `packages/config`, route/component tests for save/apply flows, and web/native preview smoke tests.

## Suggested user flow

```text
Settings -> Themes -> Create custom theme
  -> Pick starting pack
  -> Edit light palette
  -> Edit dark palette
  -> Validate contrast and required slots
  -> Preview on contact/list/detail/settings samples
  -> Save as private custom theme
  -> Apply now
```

## Non-goals

- No production database changes in this first sprint.
- No private user data, credentials, payment data, or production analytics.
- No public comment, issue close, or PR without explicit approval.
- No full implementation promise inside the $100 design sprint.
- No marketplace, revenue share, or paid creator program design unless separately accepted.

## Draft response, still not posted

I can turn this into a repo-grounded UX decision packet rather than jumping straight to implementation. I inspected the current theme spec and config: `ThemePack` already has light/dark palettes, `custom` kind, paid flags, free/pro limits, and the product spec already names `themes` and `user_theme_prefs`. For $100, I can deliver a concrete design that decides the editor surface, validation rules, storage model, paid gate, user flow, and implementation-ready issue split. I would not need private user data, production access, credentials, payment data, or proprietary design files, and I would only post a public follow-up or PR after explicit approval.
