--[[
Hammerspoon Translation Script (Menu Popup Version)
Translates selected text and shows the result in a native popup menu.
Enhanced with Styled Text for larger font support.
]]--

-- UI Settings
local menuFontSize = 16  -- Adjust this value to change font size (default is around 13-14)

-- Translation logic using Google Translate API
function translate(text)
  if text == nil or text == "" then return "No text selected" end

  local baseUrl = "https://translate.google.com/translate_a/single?dt=t&client=gtx&sl=auto&tl=zh-CN&q="
  local encodedQuery = hs.http.encodeForQuery(text)
  local url = baseUrl .. encodedQuery

  local status, body, headers = hs.http.get(url, { ["content-type"] = "application/json" })

  if status ~= 200 then return "Translation Error (" .. status .. ")" end

  local ok, response = pcall(hs.json.decode, body)
  if not ok or not response or not response[1] then return "Failed to parse response" end

  local ret = ""
  for _, value in ipairs(response[1]) do
    if value[1] ~= nil then
      ret = ret .. value[1]
    end
  end
  return ret
end

-- Helper to create styled text for the menu
local function styled(str, isHeader)
  local fontColor = isHeader and { white = 0.5 } or { white = 0 }
  return hs.styledtext.new(str, {
    font = { name = ".AppleSystemUIFont", size = isHeader and (menuFontSize - 4) or menuFontSize },
    color = fontColor
  })
end

-- Create a hidden menubar object for the popup menu
local transMenu = hs.menubar.new(false)

-- Main function to trigger translation and show popup
local function showTranslationPopup()
  local oldClipboard = hs.pasteboard.getContents()
  local focusedElement = hs.uielement.focusedElement()
  local text = ""

  if focusedElement ~= nil then
    text = focusedElement:selectedText()
  end

  -- Use Cmd+C fallback for browsers
  if text == nil or text == "" then
    hs.eventtap.keyStroke({"cmd"}, "c")
    hs.timer.doAfter(0.2, function()
      local copiedText = hs.pasteboard.getContents()
      if copiedText == nil or copiedText == "" or copiedText == oldClipboard then
        return
      end
      processTranslation(copiedText)
    end)
  else
    processTranslation(text)
  end
end

-- Helper to handle the translation and UI display
function processTranslation(text)
  hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
    local result = translate(text)

    -- Truncate and clean original text for display
    local cleanOriginal = text:gsub("\n", " "):gsub("%s+", " ")
    local shortOriginal = (string.len(cleanOriginal) > 50) and (string.sub(cleanOriginal, 1, 50) .. "...") or cleanOriginal

    -- Menu Data with Styled Text (Large Font)
    local menuData = {
      { title = styled("--- TRANSLATION ---", true), disabled = true },
      {
        title = styled(result),
        fn = function() hs.pasteboard.setContents(result) end
      },
      { title = "-" },
      { title = styled("--- ORIGINAL ---", true), disabled = true },
      {
        title = styled(shortOriginal),
        fn = function() hs.pasteboard.setContents(text) end
      },
      { title = "-" },
      { title = styled("Copy Translation"), fn = function() hs.pasteboard.setContents(result) end },
      { title = styled("Copy Original"), fn = function() hs.pasteboard.setContents(text) end }
    }

    transMenu:setMenu(menuData)
    transMenu:popupMenu(hs.mouse.absolutePosition())
  end):start()
end

-- Bind Hotkey: Alt + A
hs.hotkey.bind({"alt"}, "a", showTranslationPopup)
