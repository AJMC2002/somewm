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

awful.keyboard.append_global_keybinding(awful.key({
    modifiers = { modkey, "Shift" },
    key = "y",
    description = "reload test keybinding",
    group = "reload-test",
    on_press = function()
        awesome._reload_keybind_hits = (awesome._reload_keybind_hits or 0) + 1
    end,
}))

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
