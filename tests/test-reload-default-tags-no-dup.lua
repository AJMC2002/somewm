local runner = require("_runner")
local spawn = require("awful.spawn")

local somewm_client = assert(os.getenv("SOMEWM_CLIENT"), "SOMEWM_CLIENT must be exported")

local reload_stdout
local reload_stderr
local reload_reason
local reload_exit_code
local reload_done = false
local initial_tag_count

local function current_tag_count()
    local s = screen.primary or screen[1]
    assert(s, "expected a screen")
    return #s.tags
end

local steps = {
    function(count)
        if count == 1 then
            initial_tag_count = current_tag_count()
            assert(initial_tag_count == 9,
                "expected default config to create 9 tags, got " .. tostring(initial_tag_count))

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

        local after_reload_tag_count = current_tag_count()
        assert(after_reload_tag_count == initial_tag_count,
            string.format(
                "default config duplicated tags on reload (before=%s, after=%s, stdout=%s, stderr=%s)",
                tostring(initial_tag_count),
                tostring(after_reload_tag_count),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )

        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
