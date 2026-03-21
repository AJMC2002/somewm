# SomeWM Hot Reload Phase 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Harden the phase-1 hot reload path so repeated reloads stay stable over long sessions and preserve more Lua-managed runtime behavior without leaking stale state.

**Architecture:** Build on the phase-1 in-process reload transaction by classifying persistent Lua state, adding targeted cleanup/rebind hooks, and expanding regression coverage to repeated reload scenarios. Preserve client connections and compositor objects throughout.

**Tech Stack:** C, Lua, wlroots-based `somewm`, Meson/Make, Nix integration, integration tests, long-session manual verification.

---

### Task 1: Inventory Residual Runtime State After Phase 1

**Files:**
- Modify: `/home/moski/repos/somewm/docs/reload-notes.md`

**Step 1: Add a developer inventory document**

Track which runtime objects survive phase-1 reload and why:
- timers
- `package.loaded` modules
- signal closures
- drawins/widgets
- screen-local Lua objects

**Step 2: Record which items are safe, unsafe, or unknown**

Use three buckets:
- safe to keep
- must be cleared
- requires rebinding

### Task 2: Add Package Cache Invalidation Rules

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`

**Step 1: Implement selective `package.loaded` invalidation**

Invalidate config-local modules before reload while preserving core builtin modules needed by the compositor.

**Step 2: Keep builtin framework modules stable unless explicitly required**

Do not blindly clear everything under `package.loaded`.

**Step 3: Add a small allowlist/denylist helper**

Keep the policy explicit in code rather than scattered string checks.

### Task 3: Add Timer and Drawin Cleanup Hooks

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`
- Modify: `/home/moski/repos/somewm/objects/drawin.c`
- Modify: `/home/moski/repos/somewm/lua/gears/timer.lua`

**Step 1: Identify reload-owned timers**

Add a narrow hook to stop timers created by config-owned UI where feasible.

**Step 2: Expand drawin cleanup so repeated reloads do not duplicate bars/widgets**

Ensure stale internal windows are destroyed or replaced before new ones are created.

**Step 3: Verify cleanup ordering**

Make sure timer cleanup does not reference already-destroyed drawins.

### Task 4: Rebind Existing Objects to Reloaded Lua Logic

**Files:**
- Modify: `/home/moski/repos/somewm/objects/client.c`
- Modify: `/home/moski/repos/somewm/objects/screen.c`
- Modify: `/home/moski/repos/somewm/luaa.c`

**Step 1: Identify object-level signals that should be re-emitted after reload**

Examples:
- screen decoration
- rule evaluation
- theme refresh

**Step 2: Add explicit post-reload rebind hooks**

Avoid relying on incidental side effects from startup-only paths.

**Step 3: Document any intentional limitations**

If some existing client state cannot be reinterpreted without a full VM swap, write that down.

### Task 5: Stress-Test Repeated Reloads

**Files:**
- Create: `/home/moski/repos/somewm/tests/test-reload-repeat.lua`
- Create: `/home/moski/repos/somewm/tests/test-reload-stateful-modules.lua`

**Step 1: Add a repeated reload integration test**

Scenario:
- reload the compositor config multiple times in one run
- assert compositor remains responsive

**Step 2: Add a stateful-module regression test**

Scenario:
- load a config-local Lua module with internal state
- reload after source changes
- verify the reloaded module behavior is the one now in effect

### Task 6: Add Manual Soak Verification

**Files:**
- Modify: `/home/moski/repos/somewm/docs/reload-notes.md`

**Step 1: Define a soak checklist**

Include:
- reload 10 times
- open/close apps between reloads
- multi-monitor decoration rebuild
- notification system still alive
- no duplicated bars

**Step 2: Define failure signatures**

Examples:
- duplicate keybindings
- duplicate wibars
- dead promptbox
- stale notifications
- rising memory usage

### Task 7: Verify the Hardened Path

**Files:**
- Test: `/home/moski/repos/somewm`

**Step 1: Build the fork**

Run:
```bash
nix build /home/moski/repos/somewm#somewm
```

**Step 2: Run the full test suite**

Run:
```bash
make -C /home/moski/repos/somewm test
```

**Step 3: Run the repeated-reload integration cases directly**

Run:
```bash
bash /home/moski/repos/somewm/tests/run-integration.sh /home/moski/repos/somewm/tests/test-reload-repeat.lua
bash /home/moski/repos/somewm/tests/run-integration.sh /home/moski/repos/somewm/tests/test-reload-stateful-modules.lua
```

### Task 8: Commit

Run:
```bash
git -C /home/moski/repos/somewm add docs/reload-notes.md luaa.c objects/drawin.c objects/client.c objects/screen.c lua/gears/timer.lua tests/test-reload-repeat.lua tests/test-reload-stateful-modules.lua
git -C /home/moski/repos/somewm commit -m "fix: harden repeated hot reload behavior"
```
