pcall(require, "luarocks.loader")

local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
require("awful.autofocus")

modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
}

beautiful.shadow_drawin_enabled = false
beautiful.shadow_drawin_radius = 4
beautiful.shadow_drawin_opacity = 0.25
awesome._reload_theme_marker = "v1"

screen.connect_signal("request::desktop_decoration", function(s)
    awful.tag({ "test" }, s, awful.layout.layouts[1])

    if not awesome._reload_theme_drawin or not awesome._reload_theme_drawin.valid then
        awesome._reload_theme_drawin = wibox({
            screen = s,
            x = s.geometry.x,
            y = s.geometry.y,
            width = 120,
            height = 24,
            visible = true,
            ontop = false,
            bg = "#222222",
        })
    else
        awesome._reload_theme_drawin.screen = s
        awesome._reload_theme_drawin.visible = true
    end
end)

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
