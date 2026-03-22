local runner = require("_runner")
local spawn = require("awful.spawn")

local somewm_client = assert(os.getenv("SOMEWM_CLIENT"), "SOMEWM_CLIENT must be exported")

local reload_stdout
local reload_stderr
local reload_reason
local reload_exit_code
local reload_done = false
local initial_drawins

local function visible_drawin_count()
    return #(root.drawins() or {})
end

local steps = {
    function(count)
        if count == 1 then
            initial_drawins = visible_drawin_count()
            assert(initial_drawins == 1,
                "expected one initial visible drawin, got " .. tostring(initial_drawins))

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

        local after_reload_drawins = visible_drawin_count()
        assert(after_reload_drawins == initial_drawins,
            string.format(
                "default config duplicated wibars on reload (before=%s, after=%s, stdout=%s, stderr=%s)",
                tostring(initial_drawins),
                tostring(after_reload_drawins),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )

        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
