--[[
Hammerspoon Clipboard Manager (Deduplication Enhanced)
Monitors clipboard changes, stores history, and prevents duplicate entries.
]]--

-- Settings
local frequency = 0.8           -- Check for clipboard changes every X seconds
local hist_size = 50            -- Number of items to keep in history
local label_length = 60         -- Max length of characters displayed in the menu
local honor_clearcontent = false -- If true, removes last item if an app clears the pasteboard
local pasteOnSelect = false     -- Auto-type/paste on selection

-- Core components initialization
local jumpcut = hs.menubar.new()
jumpcut:setTooltip("Clipboard History")
local pasteboard = require("hs.pasteboard")
local settings = require("hs.settings")
local last_change = pasteboard.changeCount()

-- Load history from settings or initialize an empty table
local clipboard_history = settings.get("so.victor.hs.jumpcut") or {}

-- Update menu title and counter
function setTitle()
  if (#clipboard_history == 0) then
    jumpcut:setTitle("Clip")
  else
    jumpcut:setTitle("Clip("..#clipboard_history..")")
  end
end

-- Put item back on pasteboard or paste directly
function putOnPaste(string, key)
  if (pasteOnSelect) then
    hs.eventtap.keyStrokes(string)
    pasteboard.setContents(string)
    last_change = pasteboard.changeCount()
  else
    if (key.alt == true) then -- Perform "direct paste" if Option/Alt is held
      hs.eventtap.keyStrokes(string)
    else
      pasteboard.setContents(string)
      last_change = pasteboard.changeCount()
    end
  end
end

-- Clear all history
function clearAll()
  pasteboard.clearContents()
  clipboard_history = {}
  settings.set("so.victor.hs.jumpcut", clipboard_history)
  last_change = pasteboard.changeCount()
  setTitle()
end

-- Clear the last item from history
function clearLastItem()
  table.remove(clipboard_history, #clipboard_history)
  settings.set("so.victor.hs.jumpcut", clipboard_history)
  last_change = pasteboard.changeCount()
  setTitle()
end

-- Store clipboard content with deduplication logic
function pasteboardToClipboard(item)
  if item == nil or item == "" then return end

  -- Deduplication logic:
  -- Check if the item already exists in history; if so, remove it.
  for i, v in ipairs(clipboard_history) do
    if v == item then
      table.remove(clipboard_history, i)
      break -- Found the duplicate, stop looking
    end
  end

  -- Ensure we don't exceed the history size limit
  while (#clipboard_history >= hist_size) do
    table.remove(clipboard_history, 1)
  end

  -- Insert the new (or moved) item at the end of the list
  table.insert(clipboard_history, item)
  
  -- Persist settings and update UI
  settings.set("so.victor.hs.jumpcut", clipboard_history)
  setTitle()
end

-- Dynamically populate the menu
populateMenu = function(key)
  setTitle()
  menuData = {}
  if (#clipboard_history == 0) then
    table.insert(menuData, {title="None", disabled = true})
  else
    -- Iterate backwards so the newest item appears at the top
    for i = #clipboard_history, 1, -1 do
      local v = clipboard_history[i]
      local displayTitle = v
      if (string.len(v) > label_length) then
        displayTitle = string.sub(v, 0, label_length) .. "…"
      end
      table.insert(menuData, {
        title = displayTitle, 
        fn = function() putOnPaste(v, key) end 
      })
    end
  end

  table.insert(menuData, {title="-"})
  table.insert(menuData, {title="Clear All", fn = function() clearAll() end })
  
  if (key.alt == true or pasteOnSelect) then
    table.insert(menuData, {title="Direct Paste Mode ✍", disabled=true})
  end
  return menuData
end

-- Function to monitor pasteboard changes
function storeCopy()
  now = pasteboard.changeCount()
  if (now > last_change) then
    current_clipboard = pasteboard.getContents()
    
    if (current_clipboard == nil and honor_clearcontent) then
      clearLastItem()
    else
      pasteboardToClipboard(current_clipboard)
    end
    last_change = now
  end
end

-- Start the timer to poll for clipboard changes
timer = hs.timer.new(frequency, storeCopy)
timer:start()

-- Initial UI setup
setTitle()
jumpcut:setMenu(populateMenu)

-- Bind hotkey CMD+SHIFT+V to show the clipboard menu
hs.hotkey.bind({"cmd", "shift"}, "v", function() 
  jumpcut:popupMenu(hs.mouse.getAbsolutePosition()) 
end)
