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
            assert(awesome._reload_theme_marker == "v1", "expected initial theme marker")
            assert(awesome._reload_theme_drawin, "expected persistent drawin")
            assert(awesome._reload_theme_drawin.shadow == false,
                "expected drawin shadow disabled before reload")

            original_content = read_file(conffile)
            local updated = original_content
            local replacements = 0

            updated, replacements = updated:gsub(
                'beautiful%.shadow_drawin_enabled = false',
                'beautiful.shadow_drawin_enabled = true'
            )
            assert(replacements == 1, "expected to enable drawin shadow in rc.lua")

            updated, replacements = updated:gsub(
                'beautiful%.shadow_drawin_radius = 4',
                'beautiful.shadow_drawin_radius = 18'
            )
            assert(replacements == 1, "expected to update drawin shadow radius in rc.lua")

            updated, replacements = updated:gsub(
                'awesome%._reload_theme_marker = "v1"',
                'awesome._reload_theme_marker = "v2"'
            )
            assert(replacements == 1, "expected to update theme marker in rc.lua")

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

        assert(awesome._reload_theme_marker == "v2", "expected theme marker after reload")
        assert(awesome._reload_theme_drawin, "expected persistent drawin after reload")
        assert(type(awesome._reload_theme_drawin.shadow) == "table",
            string.format(
                "reload did not refresh shadow defaults on existing drawin (shadow=%s, stdout=%s, stderr=%s)",
                tostring(awesome._reload_theme_drawin.shadow),
                tostring(reload_stdout),
                tostring(reload_stderr)
            )
        )
        assert(awesome._reload_theme_drawin.shadow.radius == 18,
            string.format(
                "existing drawin did not pick up updated shadow radius (radius=%s)",
                tostring(awesome._reload_theme_drawin.shadow.radius)
            )
        )

        return true
    end,
}

runner.run_steps(steps, { kill_clients = false, wait_per_step = 5 })
