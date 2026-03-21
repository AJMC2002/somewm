local runner = require("_runner")
local spawn = require("awful.spawn")

local somewm_client = assert(os.getenv("SOMEWM_CLIENT"), "SOMEWM_CLIENT must be exported")

local reload_stdout
local reload_stderr
local reload_reason
local reload_exit_code
local reload_done = false

local steps = {
    function(count)
        if count == 1 then
            assert(awesome._reload_rule_requests == 1,
                "expected initial request::rules emission during startup")

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

        assert(awesome._reload_rule_requests == 1,
            string.format(
                "reload failed to re-emit request::rules (count=%s, stdout=%s, stderr=%s)",
                tostring(awesome._reload_rule_requests),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )

        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
