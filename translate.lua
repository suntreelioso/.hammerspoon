--[[
Hammerspoon Translation Script (Clean Version)
1. Displays translation results only in a rectangular, opaque UI.
2. Disables text selection and uses system default font colors.
3. Features a "Copy" button in the bottom-right.
4. Fixed 420*280 size, supports Esc key to close.
]]--

-- Configuration
local TRANSLATE_URL = "https://translate.google.com/translate_a/single?dt=t&client=gtx&sl=auto&tl=zh-CN&q="
local WINDOW_WIDTH = 420
local WINDOW_HEIGHT = 280

-- Global Variables
local transWebView = nil
local escBinder = nil
local lastTranslation = "" 

-- 1. Translation Logic
local function fetchTranslation(text, callback)
    local url = TRANSLATE_URL .. hs.http.encodeForQuery(text)
    hs.http.asyncGet(url, nil, function(status, body)
        if status ~= 200 then
            callback("Translation Error (HTTP " .. status .. ")")
            return
        end
        local ok, response = pcall(hs.json.decode, body)
        if not ok or not response or not response[1] then
            callback("Failed to parse data")
            return
        end
        local result = ""
        for _, value in ipairs(response[1]) do
            if value[1] then result = result .. value[1] end
        end
        callback(result)
    end)
end

-- 2. HTML Template
local function getHtml(translation)
    local function escape(s)
        return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\n", "<br>")
    end

    return [[
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                * { 
                    box-sizing: border-box; 
                    user-select: none !important; 
                    -webkit-user-select: none !important;
                }
                body {
                    margin: 0; padding: 0;
                    background-color: #FFFFFF;
                    overflow: hidden;
                    font-family: -apple-system, sans-serif;
                }
                .container {
                    margin: 0;
                    width: 100vw;
                    height: 100vh;
                    padding: 25px;
                    background-color: #FFFFFF;
                    color: #000000;
                    border-radius: 0;
                    border: 1px solid #DDDDDD;
                    display: flex;
                    flex-direction: column;
                    position: relative;
                }
                @media (prefers-color-scheme: dark) {
                    body, .container {
                        background-color: #262626;
                        color: #FFFFFF;
                        border: 1px solid #404040;
                    }
                }
                .label { 
                    font-size: 11px; 
                    color: #888888; 
                    font-weight: bold; 
                    margin-bottom: 8px; 
                    text-transform: uppercase; 
                    letter-spacing: 0.5px; 
                }
                .text-box { 
                    font-size: 15px; 
                    line-height: 1.6; 
                    word-wrap: break-word; 
                    overflow-y: auto; 
                    flex-grow: 1;
                    padding-bottom: 40px;
                }
                .copy-btn {
                    position: absolute;
                    bottom: 50px;
                    right: 20px;
                    font-size: 12px;
                    color: #007AFF;
                    cursor: pointer;
                    padding: 5px 10px;
                    border: 1px solid rgba(0, 122, 255, 0.3);
                    background: transparent;
                }
                .copy-btn:active {
                    opacity: 0.5;
                }
                .footer { 
                    position: absolute;
                    bottom: 0;
                    left: 0;
                    width: 100%;
                    text-align: center; 
                    font-size: 10px; 
                    color: #999999; 
                    padding: 10px 0;
                    border-top: 1px solid rgba(128,128,128,0.1);
                    background: inherit;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="label">Translation</div>
                <div class="text-box">]] .. escape(translation) .. [[</div>
                <div class="copy-btn" onclick="window.location.href='hammerspoon://copytranslate'">Copy</div>
                <div class="footer">Press Esc to Close</div>
            </div>
        </body>
        </html>
    ]]
end

-- 3. Window Management
local function closePopup()
    if transWebView then 
        transWebView:delete() 
        transWebView = nil 
    end
    if escBinder then 
        escBinder:disable() 
    end
end

local function showPopup(translation)
    lastTranslation = translation
    if transWebView then closePopup() end

    local screen = hs.screen.mainScreen():fullFrame()
    local mousePos = hs.mouse.absolutePosition()
    local x = math.max(screen.x + 10, math.min(mousePos.x - WINDOW_WIDTH/2, screen.x + screen.w - WINDOW_WIDTH - 10))
    local y = mousePos.y + 25
    if y + WINDOW_HEIGHT > screen.y + screen.h then y = mousePos.y - WINDOW_HEIGHT - 25 end

    transWebView = hs.webview.new({x = x, y = y, w = WINDOW_WIDTH, h = WINDOW_HEIGHT})
    
    transWebView:transparent(false)
    if transWebView.allowTextSelection then
        transWebView:allowTextSelection(false)
    end
    
    transWebView:windowStyle(hs.webview.windowMasks.borderless)
    transWebView:shadow(true)      
    transWebView:level(hs.drawing.windowLevels.mainMenu)
    
    local b1 = hs.drawing.windowBehaviors.canJoinAllSpaces or 0
    local b2 = hs.drawing.windowBehaviors.fullScreenAuxiliary or 0
    transWebView:behavior(b1 + b2)

    transWebView:html(getHtml(translation))
    transWebView:show()

    if escBinder then escBinder:enable() end
end

-- 4. Text Extraction Logic
local function translateSelection()
    local oldClipboard = hs.pasteboard.getContents()
    local focusedElement = hs.uielement.focusedElement()
    local text = nil
    
    if focusedElement then
        pcall(function() text = focusedElement:selectedText() end)
    end

    if not text or text == "" then
        hs.eventtap.keyStroke({"cmd"}, "c")
        hs.timer.doAfter(0.3, function()
            local newText = hs.pasteboard.getContents()
            if newText and newText ~= "" then
                showPopup("Translating...")
                fetchTranslation(newText, function(res)
                    if transWebView then 
                        lastTranslation = res
                        transWebView:html(getHtml(res)) 
                    end
                end)
            end
        end)
    else
        showPopup("Translating...")
        fetchTranslation(text, function(res)
            if transWebView then 
                lastTranslation = res
                transWebView:html(getHtml(res)) 
            end
        end)
    end
end

-- 5. Watcher Initialization
local function setupWatchers()
    if not escBinder then
        escBinder = hs.hotkey.new({}, "escape", function() closePopup() end)
    end
end

-- Register URL Event for Copying
hs.urlevent.bind("copytranslate", function()
    if lastTranslation and lastTranslation ~= "" and lastTranslation ~= "Translating..." then
        hs.pasteboard.setContents(lastTranslation)
    end
end)

-- 6. Main Hotkey Binding: Alt + A
hs.hotkey.bind({"alt"}, "a", function()
    setupWatchers()
    translateSelection()
end)
