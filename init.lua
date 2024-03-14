
require "clipboard"
require "app_toggle"


-- time
hs.hotkey.bind({"alt"}, "t", function()
  datetime = os.date("%Y-%m-%d %H:%M:%S %w")
  hs.alert.show(datetime)
end)

-- audio device
hs.hotkey.bind({"alt"}, "o", function()
  name = nil; volume = nil
  device = hs.audiodevice.current()
  if device ~= nil then
    name = device.name
    volume = device.volume
  end
  hs.alert.show(name .. " ~> " .. math.floor(volume))
end)

