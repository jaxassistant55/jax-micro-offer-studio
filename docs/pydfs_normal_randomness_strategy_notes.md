# pydfs-lineup-optimizer Normal Randomness Strategy Notes

Generated: 2026-06-20 16:32:22 JST
Public repo: https://github.com/DimaKudosh/pydfs-lineup-optimizer
Paid-help issue: https://github.com/DimaKudosh/pydfs-lineup-optimizer/issues/367
Inspected commit: `429db96`
Fixed first sprint: $100
Confirmed money: $0

## Why this is viable

The issue asks whether pydfs-lineup-optimizer can use normal distribution randomness instead of simple uniform randomness, and the requester says they would be happy to pay for it to be written into their code. The feature is narrow and fits the existing `set_fantasy_points_strategy(...)` extension point.

## Prepared implementation

The local patch adds:

- `NormalFantasyPointsStrategy` in `pydfs_lineup_optimizer/fantasy_points_strategy.py`.
- Package export through `pydfs_lineup_optimizer/__init__.py`.
- Deterministic tests in `tests/test_fantasy_points_strategy.py`.
- Usage documentation in `docs/usage.rst`.

The strategy samples `gauss(player.fppg, player.fppg * deviation)`, where `deviation` uses player-level `max_deviation` when present or `default_deviation` otherwise. If a player has `fppg_floor` or `fppg_ceil`, the sampled result is clamped to those bounds.

## Verification

Focused command:

```bash
PYTHONPATH=/tmp/pydfs_lineup_optimizer_deps python3 -m pytest tests/test_fantasy_points_strategy.py
```

Result: 5 passed.

## Posting boundary

No upstream comment, email, direct message, pull request, or payment request has been sent. The implementation patch is prepared locally for buyer/user review and can be used only after the user approves the external action.

## Draft response, still not posted

I prepared a small tested patch for normal-distribution randomness in pydfs-lineup-optimizer. It adds `NormalFantasyPointsStrategy`, exports it from the package API, documents usage with `optimizer.set_fantasy_points_strategy(...)`, and covers player-level deviation plus floor/ceiling clamps in deterministic tests. The focused test file passes locally. I can hand over the patch or adapt it to your fork/private code after fixed-scope acceptance and external payment proof.
