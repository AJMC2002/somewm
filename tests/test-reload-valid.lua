---------------------------------------------------------------------------
-- @author somewm contributors
-- @copyright 2026 somewm contributors
--
-- Regression test: reloading should happen in-process instead of re-execing
-- the compositor. The running Lua VM should observe the updated config marker.
---------------------------------------------------------------------------

local runner = require("_runner")
local spawn = require("awful.spawn")

local conffile = assert(awesome.conffile, "awesome.conffile must be set")
local somewm_client = assert(os.getenv("SOMEWM_CLIENT"), "SOMEWM_CLIENT must be exported")

local reload_stdout
local reload_stderr
local reload_reason
local reload_exit_code
local reload_done = false
local original_content

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = assert(file:read("*a"))
    file:close()
    return content
end

local function write_file(path, content)
    local file = assert(io.open(path, "w"))
    assert(file:write(content))
    file:close()
end

local steps = {
    function(count)
        if count == 1 then
            assert(awesome._reload_marker == "v1", "expected initial reload marker v1")

            original_content = read_file(conffile)
            local updated, replacements = original_content:gsub(
                'awesome%._reload_marker = "v1"',
                'awesome._reload_marker = "v2"'
            )

            assert(replacements == 1, "expected to update exactly one reload marker in rc.lua")
            write_file(conffile, updated)

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
        if original_content then
            write_file(conffile, original_content)
        end

        assert(reload_exit_code == 0,
            string.format(
                "reload command failed (reason=%s, exit=%s, stdout=%s, stderr=%s)",
                tostring(reload_reason),
                tostring(reload_exit_code),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )

        return awesome._reload_marker == "v2"
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
