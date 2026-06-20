# WeaponMechanics Hitbox Repo-Grounded Handoff Packet

Generated: 2026-06-20 13:47:30 JST
Public repository: https://github.com/WeaponMechanics/WeaponMechanics
Local public clone: `/Users/jax/autonomous_earning_run_2026-06-09/non_bounty/WeaponMechanics`
Inspected commit: `f9d2c42`
Primary paid-feature lead: https://github.com/WeaponMechanics/WeaponMechanics/issues/363
Secondary physics lead: https://github.com/WeaponMechanics/WeaponMechanics/issues/246
Offer page: https://jaxassistant55.github.io/jax-micro-offer-studio/weaponmechanics-hitbox-lag-compensation-sprint.html
Fixed first sprint: $100
Confirmed money: $0

## What this packet is

This is the repo-grounded handoff for the $100 WeaponMechanics Hitbox Lag Compensation Sprint. It identifies the current collision path, the config shape already present, the missing lag-compensation integration point, the files to mention, and the exact proof and payment gates before any custom implementation.

This is not a public upstream comment, not a pull request, not payment proof, and not a promise that upstream will merge anything. Counts $0 until an external buyer accepts exact scope, pays through a seller-owned route, receives the agreed deliverable, and funds are posted, released, payable, or cleared.

## Files inspected

1. `weaponmechanics-core/src/main/java/me/deecaad/weaponmechanics/weapon/projectile/weaponprojectile/WeaponProjectile.java`
   - Constructs `RayTrace` with `withRaySize(projectileSettings.getSize())`.
   - Runs `rayTrace.cast(getWorld(), getLocation(), possibleNextLocation, getNormalizedMotion(), ...)` in `updatePosition`.
   - Iterates sorted `RayTraceResult` hits and delegates real block/entity hit handling to `WeaponMechanics.getInstance().getWeaponHandler().getHitHandler().handleHit(hit, this)`.
   - Has through, sticky, bouncy, rolling, and last-hit suppression logic that any custom hitbox work must preserve.

2. `weaponmechanics-core/src/main/java/me/deecaad/weaponmechanics/weapon/projectile/weaponprojectile/ProjectileSettings.java`
   - Existing config already includes `Disable_Entity_Collisions`, `Maximum_Alive_Ticks`, `Maximum_Travel_Distance`, `Size`, `Incendiary_Projectile`, and `Extinguish_In_Water`.
   - `Size` controls projectile ray size, but it does not define per-entity custom hitboxes or historical lag-compensation windows.

3. `weaponmechanics-core/src/main/java/me/deecaad/weaponmechanics/weapon/HitHandler.java`
   - `getDamagePoint(EntityTraceResult result, Vector normalizedMotion)` maps hit location to `HEAD`, `BODY`, `ARMS`, `LEGS`, or `FEET`.
   - It uses `result.getHitBox()`, entity height, entity direction, and `Entity_Hitboxes.<TYPE>` config percentages.
   - A future custom hitbox implementation must keep this result contract coherent, or damage-point classification will drift.

4. `weaponmechanics-core/src/main/java/me/deecaad/weaponmechanics/weapon/projectile/HitBoxValidator.java`
   - Validates current `Entity_Hitboxes` config by entity type.
   - Existing validator only checks vertical damage-point ratios and horizontal/arms flags. It does not validate width, height, offset, historical samples, or compensation windows.

5. `weaponmechanics-core/src/main/java/me/deecaad/weaponmechanics/wrappers/MoveTask.java`
   - Already runs per-entity movement checks and imports `me.deecaad.core.compatibility.HitBox`.
   - This is the strongest local candidate for maintaining a small pose/history ring buffer if lag compensation stays inside WeaponMechanics rather than MechanicsCore.

6. `weaponmechanics-core/src/main/java/me/deecaad/weaponmechanics/wrappers/PlayerWrapper.java`
   - Uses `player.getBoundingBox().getHeight()` for crawling detection.
   - Confirms Paper/Bukkit bounding boxes are available in this codebase, while projectile hit tracing is abstracted through MechanicsCore `RayTrace`/`HitBox`.

7. `weaponmechanics-core/src/main/resources/WeaponMechanics/config.yml`
   - Contains existing `Entity_Hitboxes:` defaults for damage-point classification.

8. `weaponmechanics-core/src/main/resources/WeaponMechanics/projectiles/Default_Projectiles.yml`
   - Shows `Projectile_Settings` examples, including existing `Size` values.

9. `weaponmechanics-core/build.gradle.kts` and `gradle/libs.versions.toml`
   - `RayTrace`, `EntityTraceResult`, and `HitBox` are from `com.cjcrafter:mechanicscore:4.3.0`, not local WeaponMechanics source.

## Main technical finding

The visible WeaponMechanics repository already has a clean projectile-collision flow, but the core ray-trace and hitbox primitives are in external MechanicsCore. A compile-safe full patch needs either a MechanicsCore-supported way to override entity hitboxes/history during `RayTrace.cast`, or a WeaponMechanics-side adapter that preselects candidate historical entity boxes before calling or replacing the current entity collision step.

Without MechanicsCore source/API confirmation, a one-shot patch directly inside `WeaponProjectile.java` would be speculative. The right paid first sprint is a repo-grounded implementation plan plus tests and config contract, then a buyer-approved implementation phase.

## Suggested buyer-facing scope

Deliver in the first $100 sprint:

1. Final config contract for `Custom_Hitboxes` and projectile lag compensation.
2. File-level implementation map with the exact integration points above.
3. Safety defaults: disabled by default, strict max history window, low-TPS fallback, no compensation across teleport/world/chunk unload, and no private server data.
4. Acceptance test matrix for stationary entities, moving entities, sprinting players, high-ping simulation, low-TPS simulation, block obstruction, through/sticky/bouncy behavior, and projectile speed scaling follow-up.
5. A phase-2 implementation estimate that separates WeaponMechanics-only work from any MechanicsCore change.

Do not include in the first $100 sprint:

1. Full production implementation.
2. Private server debugging or deployment.
3. Paid plugin jars, license keys, credentials, player data, payment data, private logs, or live server access.
4. Upstream public comment, issue assignment, or pull request without explicit send approval.
5. Guaranteed upstream merge, performance guarantee, or ongoing support.

## Proposed config contract

```yaml
Custom_Hitboxes:
  Enabled: false
  History_Ticks: 6
  Max_Compensation_Millis: 250
  Ignore_If_Tps_Below: 17.0
  Reset_History_On_Teleport: true
  Reset_History_On_World_Change: true
  Entities:
    PLAYER:
      Width: 0.6
      Height: 1.8
      Eye_Offset_Y: 1.62
      Lag_Compensation: true
    ZOMBIE:
      Width: 0.6
      Height: 1.95
      Eye_Offset_Y: 1.74
      Lag_Compensation: true
  Projectile_Checks:
    Use_Historical_Position: true
    Interpolate_Between_Ticks: true
    Preserve_Projectile_Settings_Size: true
    Preserve_Through_Sticky_Bouncy: true
```

## Implementation plan to quote if buyer accepts

1. Add serializers/settings:
   - `CustomHitboxSettings`
   - `LagCompensationSettings`
   - `CustomEntityHitbox`
   - Validation rules in or near `HitBoxValidator`

2. Add entity history:
   - Store a bounded ring buffer per living entity in `EntityWrapper` or a new `EntityPoseHistoryService`.
   - Update it from the same lifecycle that currently runs movement checks, with `MoveTask` as the inspected anchor.
   - Sample only location, world UUID/name, dimensions, yaw/pitch or facing vector, and timestamp/tick. Do not store player data or private logs.

3. Integrate projectile checks:
   - Keep `WeaponProjectile#updatePosition` as the main flow.
   - Preserve current liquid, through, sticky, bouncy, rolling, and last-hit behavior.
   - Before or inside the entity part of `rayTrace.cast`, pick current or historical hitbox candidates based on shooter ping and configured max compensation.
   - If MechanicsCore exposes no override hook, isolate the fallback in a new class so it can be tested and later moved upstream.

4. Preserve damage-point behavior:
   - Ensure `EntityTraceResult#getHitBox()` still returns the hitbox used for collision.
   - Confirm `HitHandler#getDamagePoint` still receives coherent `hitY`, `maxY`, entity direction, and custom hitbox dimensions.

5. Test:
   - Config disabled equals current behavior.
   - Existing `Projectile_Settings.Size` still works.
   - Custom dimensions reject zero/negative/absurd values.
   - History resets on teleport, world change, death, invalid entity, and chunk unload.
   - High ping is clamped by `Max_Compensation_Millis`.
   - Low TPS disables or clamps historical checks.
   - Block obstruction still wins over historical entity position.
   - Through, sticky, bouncy, rolling, and `Disable_Entity_Collisions` still behave as before.

## Exact user steps to claim this lane

1. Open the live offer page: https://jaxassistant55.github.io/jax-micro-offer-studio/weaponmechanics-hitbox-lag-compensation-sprint.html
2. Open this packet: https://jaxassistant55.github.io/jax-micro-offer-studio/weaponmechanics_hitbox_repo_grounded_packet.md
3. Add a seller-owned payment URL on your side before contacting anyone.
4. Open the primary public lead: https://github.com/WeaponMechanics/WeaponMechanics/issues/363
5. Do not post yet if you do not want to publicly solicit this work. If you do post, use the prepared draft only after you approve it.
6. If a buyer responds, require this exact acceptance sentence before payment:

   I accept the WeaponMechanics Hitbox Lag Compensation Sprint fixed-scope terms at $100. I understand work starts only after seller-owned external payment proof exists; I will provide only public or buyer-authorized non-sensitive version targets, configuration requirements, and reproduction details; the deliverable is limited to a public-safe custom-hitbox and projectile lag-compensation design packet, YAML/config shape recommendation, validation checklist, risk list, and test matrix; and private plugin jars, production server access, player data, private logs, live server deployment, guaranteed upstream merge, performance guarantee, full implementation, ongoing support, or extra revisions are not included unless separately agreed before payment.

7. Send only your own checkout, invoice, marketplace order, funded milestone, or payment request.
8. Wait for external payment proof. If payment is pending, estimated, reversible, disputed, or not under your control, count $0.
9. Deliver this repo-grounded packet and the prepared notes after proof, then ask whether they want a separate phase-2 implementation.
10. Capture proof: buyer URL/message, exact accepted scope, payment reference, amount, fees, refund/hold state, delivery URL, buyer/platform acceptance if required, payout/payable/cleared status, and date.
11. Update the tracker only after posted, released, funded, payable, cleared, credited, or verified net money exists.

## Draft public response, still not posted

I can offer a narrow first sprint for this instead of promising a full merged implementation up front. I inspected the current WeaponMechanics projectile path: `WeaponProjectile` delegates collision to MechanicsCore `RayTrace`, `ProjectileSettings.Size` already controls projectile ray size, `HitHandler#getDamagePoint` depends on `EntityTraceResult#getHitBox()`, and the current `Entity_Hitboxes` validator only covers damage-point ratios. For $100, I can deliver a public-safe repo-grounded implementation packet covering the config contract, exact integration points, lag-compensation bounds, validation rules, and acceptance tests. I would not need private plugin jars, production server access, player data, credentials, payment data, or private logs, and I would only open a PR or public follow-up after explicit approval.
