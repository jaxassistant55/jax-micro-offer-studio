# rando.id Theme Editor Repo-Grounded Handoff Packet

Generated: 2026-06-20 16:17:20 JST
Offer page: https://jaxassistant55.github.io/jax-micro-offer-studio/rando-theme-editor-ux-sprint.html
Public repo: https://github.com/rando-id/rando.id
Local public clone: `/Users/jax/autonomous_earning_run_2026-06-09/non_bounty/rando.id`
Inspected commit: `8a0ccca`
Paid-feature issue: https://github.com/rando-id/rando.id/issues/53
Fixed first sprint: $100
Confirmed money: $0

## Current issue state

The issue asks for a paid theme editor UX design. It is open, labeled `paid`, and explicitly says to close it when a real design exists. The first paid unit should be a design packet, not a public PR or implementation promise.

## Files inspected

1. `specs/apps.md`
   - Defines `themes` with `id`, `name`, `kind`, `light_palette`, `dark_palette`, `active_from`, `active_to`, and `is_paid`.
   - Defines `user_theme_prefs` with `mode`, `active_theme_id`, and paid `auto_seasonal`.
   - Places multiple themes in v0.2 and paid auto-theme/random/avatar/list features in v0.3+.
   - Lists custom theme editor as a deferred paid design question.

2. `packages/config/src/themes/index.ts`
   - Defines `ThemeMode = light | dark | system`.
   - Defines `ThemePalette` slots: `background`, `foreground`, `primary`, `secondary`, `accent`, `muted`, and `border`.
   - Defines `ThemePack` with `default | seasonal | custom`, light/dark palettes, optional seasonal windows, and `isPaid`.
   - Exposes `FREE_THEME_LIMIT = 2` and `PAID_THEME_LIMIT = 5`.

3. `packages/config/src/themes/example.theme.ts`
   - Documents the pack-authoring contract.
   - Warns that theme IDs are storage and URL keys, so rename/migration behavior must be designed.
   - Keeps every palette slot required in both light and dark mode.

4. `packages/config/src/__tests__/themes.test.ts`
   - Current test coverage validates limit constants, default lookup, and seasonal windows.
   - New custom-theme validation should live near this package before UI work.

5. `packages/config/src/feature-flags.ts`
   - Existing flags use `free | pro` tiers.
   - Suggested new flag: `custom-theme-editor: pro`.

6. `packages/ui/src/tamagui.config.ts`
   - Tamagui config is created from the default config.
   - Runtime custom themes require an implementation design before the UI is built.

## Recommended scope

Deliver in the first $100 sprint:

1. UX decision record for in-app editor versus Figma/JSON import.
2. End-to-end flow and information architecture.
3. Palette validation rules and error copy.
4. Preview-state checklist across contact list, contact detail, list detail, settings, and empty states.
5. Storage recommendation for user-owned custom packs.
6. Paid-gate and free-preview behavior.
7. Implementation-ready issue split with acceptance criteria.

Defer:

1. Full implementation.
2. Theme marketplace.
3. Creator revenue share.
4. Production database migration.
5. Public PR or issue comment without explicit approval.

## Exact user steps to claim this lane

1. Open the live offer page: https://jaxassistant55.github.io/jax-micro-offer-studio/rando-theme-editor-ux-sprint.html
2. Open this packet: https://jaxassistant55.github.io/jax-micro-offer-studio/rando_theme_editor_repo_grounded_packet.md
3. Open the prepared notes: https://jaxassistant55.github.io/jax-micro-offer-studio/rando_theme_editor_design_notes.md
4. Add only a seller-owned checkout, invoice, marketplace order, funded milestone, or payment-request URL.
5. Open the source issue: https://github.com/rando-id/rando.id/issues/53
6. Do not post unless you approve the draft response.
7. Require this exact acceptance before payment:

   I accept the rando.id Theme Editor UX Sprint fixed-scope terms at $100. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized product requirements and non-sensitive design constraints; the deliverable is limited to a repo-grounded UX decision packet, IA/user-flow map, palette validation rules, storage and paid-gate recommendation, acceptance criteria, and implementation-ready issue breakdown; and private user data, credentials, payment data, production database access, private analytics, proprietary design files, code implementation, public posting, pull requests, or ongoing revisions are not included unless separately agreed before payment.

8. Ask for public or buyer-authorized product constraints only. Do not request private user data, production credentials, payment data, proprietary design files, or private analytics.
9. Wait for external payment proof. If payment is pending, estimated, reversible, disputed, or not under your control, count $0.
10. Deliver this design packet and notes after proof.
11. Capture proof: buyer URL/message, exact accepted scope, payment reference, amount, fees, refund/hold state, delivery URL, buyer/platform acceptance if required, payout/payable/cleared status, and date.
12. Update the tracker only after posted, released, funded, payable, cleared, credited, or verified net money exists.

## Draft public response, still not posted

I can turn this into a repo-grounded UX decision packet rather than jumping straight to implementation. I inspected the current theme spec and config: `ThemePack` already has light/dark palettes, `custom` kind, paid flags, free/pro limits, and the product spec already names `themes` and `user_theme_prefs`. For $100, I can deliver a concrete design that decides the editor surface, validation rules, storage model, paid gate, user flow, and implementation-ready issue split. I would not need private user data, production access, credentials, payment data, or proprietary design files, and I would only post a public follow-up or PR after explicit approval.
