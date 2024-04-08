
function translate(text)
  baseUrl = "https://translate.google.com/translate_a/single?dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&dt=t&client=gtx&sl=en&tl=zh-CN&hl=zh-CN&ie=UTF-8&oe=UTF-8&otf=1&ssel=0&tsel=0&kc=7&q="
  encodedQuery = hs.http.encodeForQuery(text)
  url = baseUrl..encodedQuery
  status, body, headers = hs.http.get(url, { ["content-type"] = "application/json" })
  response = hs.json.decode(body)
  ret = ""
    for key, value in pairs(response[1]) do
      if value[2] ~= nil then
        ret = ret .. value[1]
      end
      -- print(key, value[1], value[2])
    end
  return ret
end

hs.hotkey.bind({"alt"}, "a", function()
  focusedElement = hs.uielement.focusedElement()
  if focusedElement ~= nil then
    text = focusedElement:selectedText()
    point = hs.mouse.absolutePosition()
    view = hs.webview.newBrowser(hs.geometry.rect(point.x, point.y, 400, 200))
    view:level(hs.canvas.windowLevels.popUpMenu)
    text = translate(text)
    view:html('<html><body style="font-size: 15px; font-family: monospace;"><pre style="white-space: pre-wrap;">' .. text .. '</pre></body></html>')
    view:show()
  end
end)