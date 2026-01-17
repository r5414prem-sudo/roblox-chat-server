-- Universal Cross-Game Chat (Fixed & Redesigned)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")

-- ✅ YOUR SERVER URL
local SERVER_URL = "https://roblox-chat-mj5k.onrender.com"

-- Detect which HTTP function to use
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

if not httpRequest then
    warn("⚠️ Your executor doesn't support HTTP requests!")
    return
end

-- Settings
local UPDATE_INTERVAL = 2
local MAX_MESSAGE_LENGTH = 200
local DISPLAY_NAME = LocalPlayer.DisplayName

-- State
local lastMessageTime = nil
local isActive = true
local currentGameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
local currentJobId = game.JobId
local isAutoScrollEnabled = true

-- Copy server invite link to clipboard
local inviteLink = game.PlaceId .. "|" .. game.JobId
if setclipboard then
    setclipboard(inviteLink)
    print("📋 Server invite link copied to clipboard!")
end

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1003
screenGui.Parent = game:GetService("CoreGui")

-- Main Frame (NOT DRAGGABLE - only title bar will be)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 380, 0, 420)
mainFrame.Position = UDim2.new(1, -400, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Active = false
mainFrame.Draggable = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Title Bar (THIS IS DRAGGABLE)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = mainFrame

-- Make title bar draggable
local dragging = false
local dragInput, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

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

-- Chat Display Frame (SCROLLABLE, NOT DRAGGABLE)
local chatFrame = Instance.new("ScrollingFrame")
chatFrame.Size = UDim2.new(0.95, 0, 0, 305)
chatFrame.Position = UDim2.new(0.025, 0, 0, 72)
chatFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
chatFrame.BorderSizePixel = 0
chatFrame.ScrollBarThickness = 8
chatFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 255)
chatFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
chatFrame.ScrollingDirection = Enum.ScrollingDirection.Y
chatFrame.Active = true
chatFrame.Parent = mainFrame

local chatCorner = Instance.new("UICorner")
chatCorner.CornerRadius = UDim.new(0, 8)
chatCorner.Parent = chatFrame

local chatLayout = Instance.new("UIListLayout")
chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
chatLayout.Padding = UDim.new(0, 8)
chatLayout.Parent = chatFrame

-- Update canvas size when layout changes
chatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    chatFrame.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
end)

-- Scroll Down Button (Hidden by default)
local scrollDownBtn = Instance.new("TextButton")
scrollDownBtn.Size = UDim2.new(0, 45, 0, 45)
scrollDownBtn.Position = UDim2.new(0.5, -22.5, 1, -55)
scrollDownBtn.AnchorPoint = Vector2.new(0.5, 0.5)
scrollDownBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
scrollDownBtn.Text = "⬇"
scrollDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scrollDownBtn.Font = Enum.Font.GothamBold
scrollDownBtn.TextSize = 22
scrollDownBtn.Visible = false
scrollDownBtn.ZIndex = 10
scrollDownBtn.Parent = chatFrame

local scrollDownCorner = Instance.new("UICorner")
scrollDownCorner.CornerRadius = UDim.new(1, 0)
scrollDownCorner.Parent = scrollDownBtn

local scrollDownStroke = Instance.new("UIStroke")
scrollDownStroke.Color = Color3.fromRGB(30, 30, 30)
scrollDownStroke.Thickness = 2
scrollDownStroke.Parent = scrollDownBtn

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

-- JSON Encode/Decode Functions
local HttpService = game:GetService("HttpService")

-- Functions
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

local function scrollToBottom()
    chatFrame.CanvasPosition = Vector2.new(0, chatFrame.AbsoluteCanvasSize.Y)
    isAutoScrollEnabled = true
    scrollDownBtn.Visible = false
end

local function getPlayerAvatar(userId)
    local success, result = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    return success and result or ""
end

local function createMessageBubble(username, displayName, message, game, timestamp, inviteData)
    local isMe = (username == LocalPlayer.Name)
    
    local msgFrame = Instance.new("Frame")
    msgFrame.Size = UDim2.new(1, -10, 0, 0)
    msgFrame.BackgroundTransparency = 1
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y
    msgFrame.Parent = chatFrame
    
    local msgLayout = Instance.new("UIListLayout")
    msgLayout.SortOrder = Enum.SortOrder.LayoutOrder
    msgLayout.Padding = UDim.new(0, 4)
    msgLayout.Parent = msgFrame
    
    -- Header Container
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, 20)
    headerFrame.BackgroundTransparency = 1
    headerFrame.LayoutOrder = 1
    headerFrame.Parent = msgFrame
    
    -- Avatar Image
    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 18, 0, 18)
    avatar.Position = isMe and UDim2.new(1, -18, 0, 1) or UDim2.new(0, 0, 0, 1)
    avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    avatar.BorderSizePixel = 0
    avatar.Image = ""
    avatar.Parent = headerFrame
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(1, 0)
    avatarCorner.Parent = avatar
    
    -- Load avatar asynchronously
    task.spawn(function()
        local player = Players:FindFirstChild(username)
        if player then
            local avatarUrl = getPlayerAvatar(player.UserId)
            if avatarUrl ~= "" then
                avatar.Image = avatarUrl
            end
        end
    end)
    
    -- Header Label
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, -24, 1, 0)
    headerLabel.Position = isMe and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 22, 0, 0)
    headerLabel.BackgroundTransparency = 1
    
    local timeStr = timestamp:match("T(%d%d:%d%d)") or "??:??"
    headerLabel.Text = displayName .. " • " .. game .. " • " .. timeStr
    headerLabel.TextColor3 = isMe and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 200, 100)
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.TextSize = 10
    headerLabel.TextXAlignment = isMe and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
    headerLabel.Parent = headerFrame
    
    -- Message Container (with Join Button)
    local messageContainer = Instance.new("Frame")
    messageContainer.Size = UDim2.new(1, 0, 0, 0)
    messageContainer.BackgroundTransparency = 1
    messageContainer.AutomaticSize = Enum.AutomaticSize.Y
    messageContainer.LayoutOrder = 2
    messageContainer.Parent = msgFrame
    
    -- Message bubble
    local bubble = Instance.new("Frame")
    bubble.Size = UDim2.new(0.80, 0, 0, 0)
    bubble.Position = isMe and UDim2.new(0.20, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
    bubble.BackgroundColor3 = isMe and Color3.fromRGB(50, 100, 200) or Color3.fromRGB(50, 50, 50)
    bubble.AutomaticSize = Enum.AutomaticSize.Y
    bubble.BorderSizePixel = 0
    bubble.Parent = messageContainer
    
    local bubbleCorner = Instance.new("UICorner")
    bubbleCorner.CornerRadius = UDim.new(0, 10)
    bubbleCorner.Parent = bubble
    
    local bubblePadding = Instance.new("UIPadding")
    bubblePadding.PaddingLeft = UDim.new(0, 10)
    bubblePadding.PaddingRight = UDim.new(0, 10)
    bubblePadding.PaddingTop = UDim.new(0, 8)
    bubblePadding.PaddingBottom = UDim.new(0, 8)
    bubblePadding.Parent = bubble
    
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, 0, 0, 0)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = message
    msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 12
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextYAlignment = Enum.TextYAlignment.Top
    msgLabel.AutomaticSize = Enum.AutomaticSize.Y
    msgLabel.Parent = bubble
    
    -- Join Button (only if not from current user)
    if not isMe and inviteData and inviteData ~= "" then
        local joinBtn = Instance.new("TextButton")
        joinBtn.Size = UDim2.new(0, 55, 0, 28)
        joinBtn.Position = UDim2.new(1, -60, 0, 0)
        joinBtn.AnchorPoint = Vector2.new(0, 0)
        joinBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        joinBtn.Text = "Join"
        joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        joinBtn.Font = Enum.Font.GothamBold
        joinBtn.TextSize = 11
        joinBtn.Parent = messageContainer
        
        local joinCorner = Instance.new("UICorner")
        joinCorner.CornerRadius = UDim.new(0, 7)
        joinCorner.Parent = joinBtn
        
        joinBtn.MouseButton1Click:Connect(function()
            local placeId, jobId = inviteData:match("(%d+)|(.+)")
            if placeId and jobId then
                joinBtn.Text = "Joining..."
                joinBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
                
                local success = pcall(function()
                    TeleportService:TeleportToPlaceInstance(tonumber(placeId), jobId, LocalPlayer)
                end)
                
                if not success then
                    joinBtn.Text = "Failed"
                    joinBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                    task.wait(2)
                    joinBtn.Text = "Join"
                    joinBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                end
            end
        end)
    end
    
    -- Auto-scroll if enabled
    task.wait(0.1)
    if isAutoScrollEnabled then
        scrollToBottom()
    end
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
                displayName = DISPLAY_NAME,
                message = message,
                game = currentGameName,
                inviteLink = inviteLink
            })
        })
    end)
    
    if success and response.StatusCode == 201 then
        updateStatus(true)
    else
        warn("Failed to send message")
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
                        msg.displayName or msg.username, 
                        msg.message, 
                        msg.game, 
                        msg.timestamp,
                        msg.inviteLink
                    )
                end
                lastMessageTime = msg.timestamp
            end
        end
    else
        updateStatus(false)
    end
end

-- Detect scroll position to show/hide scroll down button
chatFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    local maxScroll = chatFrame.AbsoluteCanvasSize.Y - chatFrame.AbsoluteWindowSize.Y
    local currentScroll = chatFrame.CanvasPosition.Y
    
    -- Show button if not at bottom (with 30px threshold)
    if maxScroll > 0 and (maxScroll - currentScroll) > 30 then
        scrollDownBtn.Visible = true
        isAutoScrollEnabled = false
    else
        scrollDownBtn.Visible = false
        isAutoScrollEnabled = true
    end
end)

-- Button Events
scrollDownBtn.MouseButton1Click:Connect(function()
    scrollToBottom()
end)

sendBtn.MouseButton1Click:Connect(function()
    local message = textBox.Text
    if message ~= "" then
        sendMessage(message)
        createMessageBubble(LocalPlayer.Name, DISPLAY_NAME, message, currentGameName, DateTime.now():ToIsoDate(), inviteLink)
        textBox.Text = ""
    end
end)

textBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local message = textBox.Text
        if message ~= "" then
            sendMessage(message)
            createMessageBubble(LocalPlayer.Name, DISPLAY_NAME, message, currentGameName, DateTime.now():ToIsoDate(), inviteLink)
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
print("📋 Invite Link:", inviteLink)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
