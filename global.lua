-- Universal Cross-Game Chat Client (Working Version)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ✅ YOUR SERVER URL
local SERVER_URL = "https://roblox-chat-830h.onrender.com"

-- HTTP Request Function (Executor-specific)
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

if not httpRequest then
    warn("⚠️ Your executor doesn't support HTTP requests!")
    return
end

-- Settings
local UPDATE_INTERVAL = 3
local MAX_MESSAGE_LENGTH = 200

-- State
local lastMessageTime = nil
local isActive = true
local currentGameName = "Unknown Game"

-- Get game name safely
pcall(function()
    currentGameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UniversalChat"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1003
screenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 420)
mainFrame.Position = UDim2.new(1, -340, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -75, 1, 0)
titleLabel.Position = UDim2.new(0, 8, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌐 Universal Chat"
titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Status Indicator
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.Position = UDim2.new(1, -68, 0.5, -5)
statusDot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
statusDot.BorderSizePixel = 0
statusDot.Parent = titleBar

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 50, 1, 0)
statusLabel.Position = UDim2.new(1, -58, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Offline"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 9
statusLabel.Parent = titleBar

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 3.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

-- Game Label
local gameLabel = Instance.new("TextLabel")
gameLabel.Size = UDim2.new(0.95, 0, 0, 22)
gameLabel.Position = UDim2.new(0.025, 0, 0, 42)
gameLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 80)
gameLabel.BorderSizePixel = 0
gameLabel.Text = "📍 " .. currentGameName
gameLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
gameLabel.Font = Enum.Font.Gotham
gameLabel.TextSize = 10
gameLabel.TextTruncate = Enum.TextTruncate.AtEnd
gameLabel.Parent = mainFrame

local gameCorner = Instance.new("UICorner")
gameCorner.CornerRadius = UDim.new(0, 6)
gameCorner.Parent = gameLabel

-- Chat Display Frame
local chatFrame = Instance.new("ScrollingFrame")
chatFrame.Size = UDim2.new(0.95, 0, 0, 305)
chatFrame.Position = UDim2.new(0.025, 0, 0, 72)
chatFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
chatFrame.BorderSizePixel = 0
chatFrame.ScrollBarThickness = 6
chatFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 255)
chatFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
chatFrame.ScrollingEnabled = true
chatFrame.ScrollingDirection = Enum.ScrollingDirection.Y
chatFrame.Parent = mainFrame

local chatCorner = Instance.new("UICorner")
chatCorner.CornerRadius = UDim.new(0, 8)
chatCorner.Parent = chatFrame

local chatLayout = Instance.new("UIListLayout")
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
chatLayout.Padding = UDim.new(0, 6)
chatLayout.Parent = chatFrame

-- Auto-resize canvas
chatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    chatFrame.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
end)

-- Input Frame
local inputFrame = Instance.new("Frame")
inputFrame.Size = UDim2.new(0.95, 0, 0, 32)
inputFrame.Position = UDim2.new(0.025, 0, 1, -38)
inputFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
inputFrame.BorderSizePixel = 0
inputFrame.Parent = mainFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 8)
inputCorner.Parent = inputFrame

-- Text Input
local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(0.7, 0, 0.85, 0)
textBox.Position = UDim2.new(0.02, 0, 0.075, 0)
textBox.BackgroundTransparency = 1
textBox.Text = ""
textBox.PlaceholderText = "Type message..."
textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
textBox.Font = Enum.Font.Gotham
textBox.TextSize = 12
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = false
textBox.Parent = inputFrame

-- Send Button
local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(0.26, 0, 0.85, 0)
sendBtn.Position = UDim2.new(0.73, 0, 0.075, 0)
sendBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
sendBtn.Text = "Send"
sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sendBtn.Font = Enum.Font.GothamBold
sendBtn.TextSize = 12
sendBtn.Parent = inputFrame

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 6)
sendCorner.Parent = sendBtn

-- Functions
local function hexToRgb(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1,2), 16) or 200
    local g = tonumber(hex:sub(3,4), 16) or 200
    local b = tonumber(hex:sub(5,6), 16) or 200
    return Color3.fromRGB(r, g, b)
end

local function updateStatus(online)
    if online then
        statusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        statusLabel.Text = "Online"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    else
        statusDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        statusLabel.Text = "Offline"
        statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end

local function createMessageBubble(username, message, game, timestamp, rank, rankEmoji, rankColor)
    local isMe = (username == LocalPlayer.Name)
    
    rank = rank or "Member"
    rankEmoji = rankEmoji or "👤"
    rankColor = rankColor or "#CCCCCC"
    
    local msgFrame = Instance.new("Frame")
    msgFrame.Size = UDim2.new(1, -10, 0, 0)
    msgFrame.BackgroundTransparency = 1
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y
    msgFrame.Parent = chatFrame
    
    local msgLayout = Instance.new("UIListLayout")
    msgLayout.SortOrder = Enum.SortOrder.LayoutOrder
    msgLayout.Padding = UDim.new(0, 2)
    msgLayout.Parent = msgFrame
    
    -- Header with rank
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, 0, 0, 14)
    headerLabel.BackgroundTransparency = 1
    
    local timeStr = timestamp:match("T(%d%d:%d%d)") or "??:??"
    local rankText = "[" .. rankEmoji .. " " .. rank:upper() .. "] "
    headerLabel.Text = rankText .. username .. " • " .. game .. " • " .. timeStr
    headerLabel.TextColor3 = hexToRgb(rankColor)
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 9
    headerLabel.TextXAlignment = isMe and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
    headerLabel.LayoutOrder = 1
    headerLabel.Parent = msgFrame
    
    -- Message bubble
    local bubble = Instance.new("Frame")
    bubble.Size = UDim2.new(0.85, 0, 0, 0)
    bubble.Position = isMe and UDim2.new(0.15, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
    bubble.BackgroundColor3 = isMe and Color3.fromRGB(50, 100, 200) or Color3.fromRGB(50, 50, 50)
    bubble.AutomaticSize = Enum.AutomaticSize.Y
    bubble.LayoutOrder = 2
    bubble.Parent = msgFrame
    
    local bubbleCorner = Instance.new("UICorner")
    bubbleCorner.CornerRadius = UDim.new(0, 8)
    bubbleCorner.Parent = bubble
    
    local bubblePadding = Instance.new("UIPadding")
    bubblePadding.PaddingLeft = UDim.new(0, 8)
    bubblePadding.PaddingRight = UDim.new(0, 8)
    bubblePadding.PaddingTop = UDim.new(0, 6)
    bubblePadding.PaddingBottom = UDim.new(0, 6)
    bubblePadding.Parent = bubble
    
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, 0, 0, 0)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = message
    msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 11
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.AutomaticSize = Enum.AutomaticSize.Y
    msgLabel.Parent = bubble
    
    -- Auto-scroll
    task.wait(0.05)
    chatFrame.CanvasPosition = Vector2.new(0, chatFrame.AbsoluteCanvasSize.Y)
end

local function sendMessage(message)
    if not message or message == "" or message:match("^%s*$") then return end
    
    message = message:sub(1, MAX_MESSAGE_LENGTH)
    
    local success, response = pcall(function()
        return httpRequest({
            Url = SERVER_URL .. "/send",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                username = LocalPlayer.Name,
                message = message,
                game = currentGameName
            })
        })
    end)
    
    if success and response.StatusCode == 201 then
        updateStatus(true)
    else
        warn("Failed to send message:", response and response.StatusCode or "No response")
        updateStatus(false)
    end
end

local function fetchMessages()
    local success, response = pcall(function()
        local url = SERVER_URL .. "/messages"
        if lastMessageTime then
            url = url .. "?since=" .. HttpService:UrlEncode(lastMessageTime)
        end
        return httpRequest({
            Url = url,
            Method = "GET"
        })
    end)
    
    if success and response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        if data.success and data.messages then
            updateStatus(true)
            
            for _, msg in ipairs(data.messages) do
                if msg.username ~= LocalPlayer.Name then
                    createMessageBubble(
                        msg.username, 
                        msg.message, 
                        msg.game, 
                        msg.timestamp,
                        msg.rank,
                        msg.rank_emoji,
                        msg.rank_color
                    )
                end
                lastMessageTime = msg.timestamp
            end
        end
    else
        updateStatus(false)
    end
end

-- Button Events
sendBtn.MouseButton1Click:Connect(function()
    local message = textBox.Text
    if message ~= "" then
        sendMessage(message)
        createMessageBubble(LocalPlayer.Name, message, currentGameName, DateTime.now():ToIsoDate(), "Member", "👤", "#CCCCCC")
        textBox.Text = ""
    end
end)

textBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local message = textBox.Text
        if message ~= "" then
            sendMessage(message)
            createMessageBubble(LocalPlayer.Name, message, currentGameName, DateTime.now():ToIsoDate(), "Member", "👤", "#CCCCCC")
            textBox.Text = ""
        end
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    isActive = false
    screenGui:Destroy()
end)

-- Auto-fetch loop
task.spawn(function()
    while isActive and task.wait(UPDATE_INTERVAL) do
        fetchMessages()
    end
end)

-- Initial fetch
task.wait(1)
fetchMessages()

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌐 UNIVERSAL CHAT LOADED")
print("✅ Works in ANY game!")
print("Server:", SERVER_URL)
print("Game:", currentGameName)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
