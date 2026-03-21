# SomeWM Hot Reload Design

**Date:** 2026-03-21

**Problem:** `Mod4 + Ctrl + r` currently routes through `awesome.restart()` in `somewm`, and the pinned build re-execs the compositor process. In Wayland, that leaves the compositor in a broken state and can black-screen the session.

**Goal:** replace the current restart-based behavior with a production-style hot reload flow for config changes, implemented in a local fork at `/home/moski/repos/somewm`.

## Scope

### Phase 1

Implement an in-process config reload that:

- keeps the compositor process alive
- keeps Wayland clients connected
- reloads `rc.lua` without `execvp`
- rebuilds reload-managed runtime state such as keybindings, rules, bars, theme-derived values, and screen decorations
- rejects invalid configs before changing live state
- avoids black-screen failure if reload cannot be applied

### Phase 2

Improve long-session reload safety by cleaning up or rebinding more Lua-owned state:

- timers
- package/module caches
- custom signal connections
- Lua-created drawins and widgets not explicitly covered by phase 1
- repeated reload leak/regression protection

## Production Standard Target

The target behavior follows the common WM/compositor split used by i3, sway, Hyprland, and Qtile:

- `reload` is in-process
- `restart` is separate from `reload`
- config is validated before live apply
- invalid reload keeps the existing running session
- not every setting must apply retroactively, but reloadable settings must be documented

## Constraints From Current SomeWM

- `luaA_loadrc()` already exists and is used at startup.
- `luaA_loadrc()` already contains fallback behavior and partial module invalidation for config loading.
- `awesome.restart()` currently calls `execvp(...)`, which is the wrong model for Wayland hot reload.
- `globalconf_init()` / `globalconf_wipe()` and reload-adjacent cleanup hooks already exist:
  - `luaA_signal_cleanup()`
  - `luaA_keybinding_cleanup()`
  - drawin arrays in `globalconf`
- IPC already exposes `reload` and `restart` commands via `lua/awful/ipc.lua`.

## Recommended Architecture

### Reload Path

Add a dedicated in-process reload transaction in C, exposed as the implementation behind `awesome.restart()` and IPC `reload`.

High-level flow:

1. Validate target config file before mutating runtime state.
2. Snapshot enough live state to recover if reload fails.
3. Clear reload-managed Lua state.
4. Re-run `luaA_loadrc()` in the existing compositor process.
5. Re-emit runtime setup signals needed to reconstruct config-owned objects.
6. Return success or preserve the previous session if reload fails.

### Runtime State Classification

**Reload-managed in phase 1**

- global keybindings
- client keybindings
- global Lua signal registrations
- rules emitted from `ruled.client.connect_signal("request::rules", ...)`
- screen decoration setup emitted from `request::desktop_decoration`
- notification rule setup
- drawins/wibars that belong to the previous config

**Deferred to phase 2**

- arbitrary third-party Lua module state in `package.loaded`
- timers held only in Lua closures
- custom user modules with persistent side effects
- complete teardown of every signal connection created by arbitrary Lua

## Failure Model

Phase 1 must prefer safety over completeness.

- If config validation fails: keep old config live, show/log error.
- If reload application fails after cleanup begins: do not quit compositor.
- If full rollback is too expensive for phase 1: fail closed by keeping clients alive and surfacing a visible error notification, then make rollback support a phase-2 item.

## Integration Plan

The implementation should live in a local fork:

- fork workspace: `/home/moski/repos/somewm`
- NixOS flake input should later be switched from `github:trip-zip/somewm` to `path:/home/moski/repos/somewm` during integration/testing

## Testing Strategy

### Phase 1

- add unit tests for reload helpers where possible
- add integration tests for:
  - valid reload replacing keybindings
  - invalid reload preserving the existing running config
  - screen decorations/wibars rebuilding after reload
  - repeated reload not crashing the compositor

### Phase 2

- add soak-style repeated reload tests
- add leak/regression checks for drawins, signals, and timers
- add behavior tests around client continuity and layout persistence across repeated reloads

## Success Criteria

### Phase 1 success

- `Mod4 + Ctrl + r` no longer black-screens the session
- live Wayland clients stay connected during config reload
- invalid config does not kill the compositor
- config-owned UI and bindings visibly refresh

### Phase 2 success

- repeated reloads remain stable over long sessions
- stale bindings/signals/widgets do not accumulate
- custom-config reload behavior is predictable and documented
