pcall(require, "luarocks.loader")

awesome._reload_instance_signal_hits = awesome._reload_instance_signal_hits or 0

local s = screen.primary or screen[1]
assert(s, "expected a screen for reload instance-signal test")

s:connect_signal("test::reload-instance-signal", function()
    awesome._reload_instance_signal_hits = awesome._reload_instance_signal_hits + 1
end)

awesome.connect_signal("debug::error", function(err)
    io.stderr:write("ERROR: " .. tostring(err) .. "\n")
end)
