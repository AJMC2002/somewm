pcall(require, "luarocks.loader")

local awful = require("awful")
local ruled = require("ruled.client")
require("awful.autofocus")

modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
}

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "test" }, s, awful.layout.layouts[1])
end)

awesome._reload_rule_requests = 0
ruled.connect_signal("request::rules", function()
    awesome._reload_rule_requests = awesome._reload_rule_requests + 1
end)

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
