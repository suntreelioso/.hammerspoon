

hs.application.enableSpotlightForNameSearches(false)

hs.hotkey.bind({"alt"}, "v", function()
  app = hs.application.get("Code")
  if app == nil then
    return
  end

  if app:isHidden() or not app:isFrontmost() then
    app:activate()
  else
    app:hide()
  end
end)