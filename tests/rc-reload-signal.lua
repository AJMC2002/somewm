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

awesome._reload_signal_hits = 0
awesome.connect_signal("test::reload-signal", function()
    awesome._reload_signal_hits = awesome._reload_signal_hits + 1
end)

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
