local function load_util()
    package.loaded["awful.util"] = nil
    _G.awesome = {
        conffile = "/tmp/reload-spec-rc.lua",
        restart = function() end,
    }
    return require("awful.util")
end

describe("awful.util.restart", function()
    local util

    before_each(function()
        util = load_util()
    end)

    it("returns validation errors without reloading", function()
        local restart_calls = 0
        local checked_path

        _G.awesome.restart = function()
            restart_calls = restart_calls + 1
        end

        util.checkfile = function(path)
            checked_path = path
            return "reload validation failed"
        end

        local result = util.restart()

        assert.are.equal("reload validation failed", result)
        assert.are.equal(0, restart_calls)
        assert.are.equal("/tmp/reload-spec-rc.lua", checked_path)
    end)

    it("calls awesome.restart after successful validation", function()
        local restart_calls = 0
        local checked_path

        _G.awesome.restart = function()
            restart_calls = restart_calls + 1
        end

        util.checkfile = function(path)
            checked_path = path
            return function() end
        end

        local result = util.restart()

        assert.is_nil(result)
        assert.are.equal(1, restart_calls)
        assert.are.equal("/tmp/reload-spec-rc.lua", checked_path)
    end)
end)
