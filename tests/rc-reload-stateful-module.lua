pcall(require, "luarocks.loader")

local awful = require("awful")
require("awful.autofocus")

modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
}

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "test" }, s, awful.layout.layouts[1])
end)

local config_dir = assert(awesome.conffile:match("^(.*)/[^/]+$"), "expected config dir")
package.path = config_dir .. "/?.lua;" .. package.path

local module_path = config_dir .. "/reload_stateful_module.lua"
local probe = io.open(module_path, "r")
if probe then
    probe:close()
else
    local file = assert(io.open(module_path, "w"))
    assert(file:write("return { version = \"v1\" }\n"))
    file:close()
end

local reload_stateful_module = require("reload_stateful_module")
awesome._reload_stateful_version = reload_stateful_module.version

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
