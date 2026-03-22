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

client.connect_signal("request::default_keybindings", function()
    awful.keyboard.append_client_keybinding(awful.key({
        modifiers = { modkey },
        key = "u",
        description = "reload test client keybinding",
        group = "reload-test",
        on_press = function() end,
    }))
end)

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
