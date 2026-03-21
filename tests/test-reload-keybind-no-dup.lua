local runner = require("_runner")
local spawn = require("awful.spawn")

local somewm_client = assert(os.getenv("SOMEWM_CLIENT"), "SOMEWM_CLIENT must be exported")

local list_stdout
local list_stderr
local list_exit_code
local list_done = false

local reload_stdout
local reload_stderr
local reload_reason
local reload_exit_code
local reload_done = false

local function count_matches(haystack, needle)
    local count = 0
    local start = 1

    while true do
        local i = haystack:find(needle, start, true)
        if not i then
            return count
        end
        count = count + 1
        start = i + #needle
    end
end

local function list_keybindings(callback)
    spawn.easy_async({ somewm_client, "keybind.list" }, function(stdout, stderr, _, exit_code)
        list_stdout = stdout
        list_stderr = stderr
        list_exit_code = exit_code
        list_done = true
        callback()
    end)
end

local initial_count

local steps = {
    function(count)
        if count == 1 then
            list_done = false
            list_keybindings(function()
                initial_count = count_matches(list_stdout or "", "reload test keybinding")
            end)
        end

        return list_done or nil
    end,

    function(count)
        assert(list_exit_code == 0,
            string.format("initial keybind.list failed (exit=%s, stdout=%s, stderr=%s)",
                tostring(list_exit_code), tostring(list_stdout), tostring(list_stderr)))
        assert(initial_count == 1,
            string.format("expected one initial keybinding entry, got %s from stdout=%s",
                tostring(initial_count), tostring(list_stdout)))

        if count == 1 then
            reload_done = false
            spawn.easy_async({ somewm_client, "reload" }, function(stdout, stderr, reason, exit_code)
                reload_stdout = stdout
                reload_stderr = stderr
                reload_reason = reason
                reload_exit_code = exit_code
                reload_done = true
            end)
        end

        return reload_done or nil
    end,

    function(count)
        if count == 1 then
            assert(reload_exit_code == 0,
                string.format(
                    "reload command failed (reason=%s, exit=%s, stdout=%s, stderr=%s)",
                    tostring(reload_reason),
                    tostring(reload_exit_code),
                    tostring(reload_stdout),
                    tostring(reload_stderr)
                )
            )

            list_done = false
            list_keybindings(function() end)
        end

        return list_done or nil
    end,

    function()
        assert(list_exit_code == 0,
            string.format("post-reload keybind.list failed (exit=%s, stdout=%s, stderr=%s)",
                tostring(list_exit_code), tostring(list_stdout), tostring(list_stderr)))

        local after_reload_count = count_matches(list_stdout or "", "reload test keybinding")
        assert(after_reload_count == initial_count,
            string.format(
                "reload duplicated global keybindings (before=%s, after=%s, stdout=%s, stderr=%s)",
                tostring(initial_count),
                tostring(after_reload_count),
                tostring(list_stdout),
                tostring(list_stderr)
            )
        )

        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
