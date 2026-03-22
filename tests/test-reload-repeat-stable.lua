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

local function request_reload()
    reload_done = false
    spawn.easy_async({ somewm_client, "reload" }, function(stdout, stderr, reason, exit_code)
        reload_stdout = stdout
        reload_stderr = stderr
        reload_reason = reason
        reload_exit_code = exit_code
        reload_done = true
    end)
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
            assert(replacements == 1, "expected to update marker to v2")
            write_file(conffile, updated)
            request_reload()
        end

        return reload_done or nil
    end,

    function()
        assert(reload_exit_code == 0,
            string.format(
                "first reload failed (reason=%s, exit=%s, stdout=%s, stderr=%s)",
                tostring(reload_reason),
                tostring(reload_exit_code),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )
        assert(awesome._reload_marker == "v2", "expected first reload marker v2")
        return true
    end,

    function(count)
        if count == 1 then
            local updated = read_file(conffile)
            updated = updated:gsub('awesome%._reload_marker = "v2"', 'awesome._reload_marker = "v3"')
            write_file(conffile, updated)
            request_reload()
        end

        return reload_done or nil
    end,

    function()
        if original_content then
            write_file(conffile, original_content)
        end

        assert(reload_exit_code == 0,
            string.format(
                "second reload failed (reason=%s, exit=%s, stdout=%s, stderr=%s)",
                tostring(reload_reason),
                tostring(reload_exit_code),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )
        assert(awesome._reload_marker == "v3", "expected second reload marker v3")
        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
