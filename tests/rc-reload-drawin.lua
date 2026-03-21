pcall(require, "luarocks.loader")

local awful = require("awful")
local wibox = require("wibox")
require("awful.autofocus")

modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
}

screen.connect_signal("request::desktop_decoration", function(s)
    awful.tag({ "test" }, s, awful.layout.layouts[1])

    wibox({
        screen = s,
        x = s.geometry.x,
        y = s.geometry.y,
        width = 120,
        height = 24,
        visible = true,
        ontop = false,
        bg = "#222222",
    })
end)

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
