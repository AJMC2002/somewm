# SomeWM Hot Reload Phase 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement production-style in-process config reload in a local `somewm` fork so `Mod4 + Ctrl + r` reloads `rc.lua` without re-execing the compositor.

**Architecture:** Replace the current `execvp`-based `awesome.restart()` path with a reload transaction inside the running compositor. Reuse `luaA_loadrc()` and existing reload-adjacent cleanup hooks, then rebuild config-owned runtime state by re-emitting setup signals. Keep restart and rebuild workflows out of scope for phase 1.

**Tech Stack:** C, Lua, wlroots-based `somewm`, Meson/Make, Nix flake integration, unit tests via `busted`, integration tests via `tests/run-integration.sh`.

---

### Task 1: Create Local Fork Workspace

**Files:**
- Create: `/home/moski/repos/somewm`

**Step 1: Clone upstream into the local repos directory**

Run:
```bash
git clone https://github.com/trip-zip/somewm.git /home/moski/repos/somewm
```

**Step 2: Check out the commit currently pinned by NixOS**

Run:
```bash
git -C /home/moski/repos/somewm checkout a7ecae7aa4918c7d0bf28e62dffe71a0ddb157b8
```

**Step 3: Create a working branch**

Run:
```bash
git -C /home/moski/repos/somewm switch -c feat/hot-reload-phase-1
```

### Task 2: Document Current Reload Entry Points

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`
- Modify: `/home/moski/repos/somewm/lua/awful/ipc.lua`
- Modify: `/home/moski/repos/somewm/lua/awful/util.lua`

**Step 1: Locate the current restart and reload path**

Run:
```bash
rg -n "awesome_restart|luaA_restart|ipc.register\\(\"reload\"|util.restart" /home/moski/repos/somewm -S
```

**Step 2: Add a short developer comment near the existing restart implementation**

Comment should state that the old path is a process restart path and phase 1 will replace it with in-process config reload semantics.

### Task 3: Add a Dedicated Reload Helper in C

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.h`
- Modify: `/home/moski/repos/somewm/luaa.c`

**Step 1: Write a failing integration-oriented helper contract**

Add a new C function declaration such as:
```c
bool luaA_reload_config(void);
```

**Step 2: Implement the minimal helper skeleton**

Initial structure:
```c
bool
luaA_reload_config(void)
{
    /* validate config */
    /* clear reload-managed state */
    /* call luaA_loadrc() */
    /* rebuild runtime state */
    return true;
}
```

**Step 3: Make `awesome.restart()` call the new helper instead of `execvp`**

Update `luaA_restart()` so it performs in-process reload and returns a Lua error or warning path on failure instead of replacing the process image.

### Task 4: Validate Before Mutating Runtime State

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`

**Step 1: Extract the config validation logic into a reusable helper**

Use the same config file chosen by `awesome.conffile` / `luaA_loadrc()`.

**Step 2: Fail fast if the config cannot be loaded**

Minimal behavior:
```c
if (!luaA_validate_current_config(...)) {
    luaA_startup_error("Reload validation failed");
    return false;
}
```

**Step 3: Add logging for the validation decision**

Use existing logging helpers so reload attempts are visible in debug logs.

### Task 5: Reset Reload-Managed Runtime State

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`
- Modify: `/home/moski/repos/somewm/root.c`
- Modify: `/home/moski/repos/somewm/objects/signal.c`
- Modify: `/home/moski/repos/somewm/objects/keybinding.c`

**Step 1: Clear global signal registrations**

Use:
```c
luaA_signal_cleanup();
```

**Step 2: Clear global and client keybindings**

Use:
```c
luaA_keybinding_cleanup();
```

**Step 3: Add a reload-safe helper for config-owned drawins/wibars**

Implement a focused cleanup path for Lua-created drawins so stale bars do not accumulate across reload.

**Step 4: Keep compositor objects alive**

Do not destroy:
- Wayland clients
- screens/outputs
- backend
- seat
- wl_display

### Task 6: Re-run Config Load in the Existing Process

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`

**Step 1: Call `luaA_loadrc()` from the reload helper**

Minimal behavior:
```c
luaA_loadrc();
```

**Step 2: Detect whether reload succeeded**

Use the same loaded/error path already maintained by `luaA_loadrc()` and the startup error buffer.

**Step 3: Abort reload cleanly if no config could be loaded**

Do not terminate the compositor.

### Task 7: Rebuild Config-Owned Runtime Objects

**Files:**
- Modify: `/home/moski/repos/somewm/luaa.c`
- Modify: `/home/moski/repos/somewm/objects/screen.c`
- Modify: `/home/moski/repos/somewm/lua/ruled/client.lua`
- Modify: `/home/moski/repos/somewm/lua/ruled/notification.lua`

**Step 1: Re-emit screen decoration signals for all screens**

This should cause `request::desktop_decoration` handlers in user config to rebuild wibars/tags/promptboxes.

**Step 2: Re-emit client and notification rule signals**

Use the existing `request::rules` flow rather than inventing a new rebuild path.

**Step 3: Reload theme-derived compositor defaults that already have helpers**

Call existing hooks such as shadow/theme refresh where appropriate.

### Task 8: Update Lua-Facing Reload Semantics

**Files:**
- Modify: `/home/moski/repos/somewm/lua/awful/ipc.lua`
- Modify: `/home/moski/repos/somewm/lua/awful/util.lua`
- Modify: `/home/moski/repos/somewm/somewmrc.lua`
- Modify: `/home/moski/repos/somewm/DEVIATIONS.md`

**Step 1: Keep IPC `reload` mapped to in-process reload**

Update user-facing strings from “Restarting...” to “Reloading...”.

**Step 2: Keep `util.restart()` behavior aligned with hot reload**

Make sure `awful.util.restart()` calls the new in-process path.

**Step 3: Update docs/comments that imply re-exec**

Specifically:
- default keybinding description
- deviation docs
- any CLI/help text that conflates reload with restart

### Task 9: Add Regression Tests

**Files:**
- Create: `/home/moski/repos/somewm/tests/test-reload-valid.lua`
- Create: `/home/moski/repos/somewm/tests/test-reload-invalid.lua`
- Create: `/home/moski/repos/somewm/spec/awful/reload_spec.lua`

**Step 1: Add a Lua unit test for the high-level reload helper behavior**

Target:
- validation failure does not route to process restart
- reload path uses the new helper

**Step 2: Add an integration test for valid reload**

Scenario:
- load a config with a known keybinding or theme marker
- change/reload to a second config
- verify the new binding or marker is active

**Step 3: Add an integration test for invalid reload**

Scenario:
- start compositor with a good config
- request reload with a broken config
- verify compositor remains alive and existing behavior remains available

### Task 10: Verify the Fork in Isolation

**Files:**
- Test: `/home/moski/repos/somewm`

**Step 1: Build the fork**

Run:
```bash
nix build /home/moski/repos/somewm#somewm
```

**Step 2: Run the unit tests**

Run:
```bash
make -C /home/moski/repos/somewm test-unit
```

**Step 3: Run the integration tests**

Run:
```bash
make -C /home/moski/repos/somewm test-integration
```

**Step 4: Run the full test suite**

Run:
```bash
make -C /home/moski/repos/somewm test
```

### Task 11: Integrate the Fork Into NixOS

**Files:**
- Modify: `/home/moski/nixos/flake.nix`
- Modify: `/home/moski/nixos/flake.lock`

**Step 1: Point the `somewm` flake input to the local path fork**

Target shape:
```nix
somewm = {
  url = "path:/home/moski/repos/somewm";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

**Step 2: Refresh the lock file**

Run:
```bash
nix flake lock --update-input somewm
```

**Step 3: Build the NixOS system derivation**

Run:
```bash
nix build /home/moski/nixos#nixosConfigurations.moski.config.system.build.toplevel
```

### Task 12: Manual Runtime Verification

**Files:**
- Test: `/home/moski/.config/somewm/rc.lua`

**Step 1: Check the real user config**

Run:
```bash
somewm --check /home/moski/.config/somewm/rc.lua --check-level=critical
```

**Step 2: Start a debug session**

Run:
```bash
dbus-run-session /home/moski/repos/somewm/result/bin/somewm -d -c /home/moski/.config/somewm/rc.lua 2>&1 | tee /tmp/somewm-hot-reload.log
```

**Step 3: Trigger reload from inside the compositor**

Test:
- edit `rc.lua`
- press `Mod4 + Ctrl + r`
- verify session remains visible and running apps stay connected

**Step 4: Trigger invalid reload**

Test:
- introduce a syntax error
- trigger reload
- verify compositor remains alive and surfaces an error

### Task 13: Commit

Run:
```bash
git -C /home/moski/repos/somewm add luaa.c luaa.h lua/awful/ipc.lua lua/awful/util.lua somewmrc.lua DEVIATIONS.md spec/awful/reload_spec.lua tests/test-reload-valid.lua tests/test-reload-invalid.lua
git -C /home/moski/repos/somewm commit -m "feat: implement in-process config hot reload"
```
