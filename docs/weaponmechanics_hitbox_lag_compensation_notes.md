# WeaponMechanics Hitbox Lag Compensation Sprint Notes

Primary lead: https://github.com/WeaponMechanics/WeaponMechanics/issues/363
Secondary physics lead: https://github.com/WeaponMechanics/WeaponMechanics/issues/246
Repo: https://github.com/WeaponMechanics/WeaponMechanics

## Why this should start as a $100 diagnostic/design sprint

The primary request asks for custom entity hitboxes and projectile hit checks with lag compensation. That crosses projectile tracing, entity pose/history, server tick timing, configuration validation, and anti-cheat/fairness boundaries. A direct promise to ship a full merged implementation before scope/payment proof would be too broad. A fixed first sprint can still create buyer value by narrowing the design, risk, and exact implementation plan.

## Public-safe deliverable

1. Config surface recommendation for `custom_hitboxes`.
2. Entity selection matrix: player, mob, armor stand, vehicle, and ignored entities.
3. Projectile trace model: current tick, historical pose sample, interpolation window, and fallback behavior.
4. Lag-compensation risk list: high ping abuse, server TPS drops, entity teleport, chunk unload, anti-cheat interaction, and replay-window limits.
5. Validation checklist: config parsing, enabled/disabled behavior, unsupported entity type, max history depth, and safe defaults.
6. Test matrix: stationary entity, moving entity, sprinting player, high ping simulation, low TPS simulation, block obstruction, and projectile speed scaling.
7. Implementation plan that can be converted to a PR only after explicit approval.
8. Repo-grounded handoff packet with inspected source files, MechanicsCore boundary, implementation milestones, user claim steps, and draft response.

## Suggested config shape

```yaml
Custom_Hitboxes:
  Enabled: true
  History_Ticks: 6
  Max_Compensation_Millis: 250
  Entities:
    PLAYER:
      Width: 0.6
      Height: 1.8
      Lag_Compensation: true
    ZOMBIE:
      Width: 0.6
      Height: 1.95
      Lag_Compensation: true
  Projectile_Checks:
    Use_Historical_Position: true
    Interpolate_Between_Ticks: true
    Ignore_If_Tps_Below: 17.0
```

## Non-goals

- No private server debugging.
- No paid plugin jars or license keys.
- No player data or private logs.
- No promise that upstream will merge a future PR.
- No full production deployment or performance guarantee inside the $100 first sprint.

## Repo-grounded packet

Full packet: https://jaxassistant55.github.io/jax-micro-offer-studio/weaponmechanics_hitbox_repo_grounded_packet.md

The public clone was inspected at commit `f9d2c42`. The relevant local files are `WeaponProjectile.java`, `ProjectileSettings.java`, `HitHandler.java`, `HitBoxValidator.java`, `MoveTask.java`, `PlayerWrapper.java`, `config.yml`, `Default_Projectiles.yml`, and the Gradle dependency files. The main finding is that WeaponMechanics has the projectile flow, but `RayTrace`, `EntityTraceResult`, and `HitBox` are supplied by `com.cjcrafter:mechanicscore:4.3.0`, so the first $100 sprint should stay as an implementation packet unless the buyer separately approves a MechanicsCore-aware implementation phase.
