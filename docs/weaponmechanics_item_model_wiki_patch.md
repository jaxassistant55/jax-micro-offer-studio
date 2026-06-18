## Proposed wiki patch draft: Override_Visual_Item Item_Model

This is a public-safe patch draft for `cosmetics.md` under `Third_Person_Pose`.
It is not posted upstream automatically.

### Modern item model example

```yaml
    Third_Person_Pose:
      Default: NONE
      Scope:
        Pose: BOW
        Override_Visual_Item:
          Item_Model: "namespace:item"
      Reload: BLOCK
      Firearm_Action: CROSSBOW
```

### Compatibility notes

- `Item_Model` should be treated as a namespaced item model key such as `namespace:item`.
- `Item_Model` is the preferred modern override when the target server/client version supports item model keys.
- `Type` plus `Custom_Model_Data` remains the legacy fallback for older resource-pack workflows.
- If both `Item_Model` and legacy fields are present, the plugin owner should choose and document one precedence rule before release.
- A safe default is: prefer `Item_Model`, ignore legacy visual fields for that same override, and warn in validation output.

### Validation checklist

- Accept only non-empty namespaced keys in the form `namespace:path`.
- Reject keys with spaces, uppercase-only placeholders, or missing namespace.
- Confirm `Scope`, `Reload`, and `Firearm_Action` can each use an override independently.
- Confirm third-person observer behavior, because the existing wiki states the pose effect is visible to other players, not the shooter.
- Confirm invalid keys fail safely without replacing the item with an unintended default.

### Test matrix

| Case | Expected result |
| --- | --- |
| `Scope.Override_Visual_Item.Item_Model: "namespace:item"` | Observer sees the configured model during scope pose. |
| Legacy `Type` plus `Custom_Model_Data` only | Existing behavior remains unchanged. |
| Both `Item_Model` and legacy fields | Documented precedence is applied consistently. |
| Invalid `Item_Model` key | Config validation warns and the visual override fails safely. |
| Missing resource-pack model | No server crash; user gets a clear resource-pack troubleshooting path. |
