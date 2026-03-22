local runner = require("_runner")
local spawn = require("awful.spawn")
local akeyboard = require("awful.keyboard")

local somewm_client = assert(os.getenv("SOMEWM_CLIENT"), "SOMEWM_CLIENT must be exported")

local reload_stdout
local reload_stderr
local reload_reason
local reload_exit_code
local reload_done = false
local initial_key_count

local function current_client_default_key_count()
    return #(akeyboard._get_client_keybindings() or {})
end

local steps = {
    function(count)
        if count == 1 then
            initial_key_count = current_client_default_key_count()
            assert(initial_key_count == 1,
                "expected one initial default client keybinding, got " .. tostring(initial_key_count))

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

    function()
        assert(reload_exit_code == 0,
            string.format(
                "reload command failed (reason=%s, exit=%s, stdout=%s, stderr=%s)",
                tostring(reload_reason),
                tostring(reload_exit_code),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )

        local after_reload_key_count = current_client_default_key_count()
        assert(after_reload_key_count == initial_key_count,
            string.format(
                "reload duplicated default client keybindings (before=%s, after=%s, stdout=%s, stderr=%s)",
                tostring(initial_key_count),
                tostring(after_reload_key_count),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )

        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
