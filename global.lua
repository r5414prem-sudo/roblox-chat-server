-- Universal Cross-Game Chat (Compact & Optimized)
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
local UPDATE_INTERVAL = 1.5
local MAX_MESSAGE_LENGTH = 200
local DISPLAY_NAME = LocalPlayer.DisplayName

-- State
local lastMessageTime = nil
local isActive = true
local isMinimized = false
local currentGameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
local currentJobId = game.JobId
local isAutoScrollEnabled = true
local lastSenderUsername = nil  -- Track last message sender

-- Generate proper invite link (PlaceId|JobId format)
local inviteLink = tostring(game.PlaceId) .. "|" .. tostring(game.JobId)

-- Copy to clipboard
if setclipboard then
    setclipboard(inviteLink)
    print("📋 Server invite copied: " .. inviteLink)
end

-- Verify invite link format
local function verifyInviteLink(link)
    if not link or link == "" then return false end
    local placeId, jobId = link:match("^(%d+)|(.+)$")
    return placeId ~= nil and jobId ~= nil and #jobId > 10
end

if not verifyInviteLink(inviteLink) then
    warn("⚠️ Invalid invite link format!")
    return
end

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1003
screenGui.Parent = game:GetService("CoreGui")

-- Main Frame (Compact for mobile)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 340, 0, 380)
mainFrame.Position = UDim2.new(1, -360, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Active = false
mainFrame.Draggable = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Title Bar (Draggable)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = mainFrame

-- Dragging functionality
local dragging = false
local dragInput, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
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
titleLabel.Size = UDim2.new(1, -95, 1, 0)
titleLabel.Position = UDim2.new(0, 8, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌐 Universal Chat"
titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Status Indicator (shifted left to avoid overlap)
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(1, -118, 0.5, -4)
statusDot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
statusDot.BorderSizePixel = 0
statusDot.Parent = titleBar

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 45, 1, 0)
statusLabel.Position = UDim2.new(1, -110, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Offline"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 8
statusLabel.Parent = titleBar

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -62, 0, 3)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Parent = titleBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 7)
minimizeCorner.Parent = minimizeBtn

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeBtn

-- Game Label
local gameLabel = Instance.new("TextLabel")
gameLabel.Size = UDim2.new(0.94, 0, 0, 20)
gameLabel.Position = UDim2.new(0.03, 0, 0, 38)
gameLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 80)
gameLabel.BorderSizePixel = 0
gameLabel.Text = "📍 " .. currentGameName
gameLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
gameLabel.Font = Enum.Font.Gotham
gameLabel.TextSize = 9
gameLabel.TextTruncate = Enum.TextTruncate.AtEnd
gameLabel.Parent = mainFrame

local gameCorner = Instance.new("UICorner")
gameCorner.CornerRadius = UDim.new(0, 6)
gameCorner.Parent = gameLabel

-- Chat Display Frame
local chatFrame = Instance.new("ScrollingFrame")
chatFrame.Size = UDim2.new(0.94, 0, 0, 280)
chatFrame.Position = UDim2.new(0.03, 0, 0, 64)
chatFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
chatFrame.BorderSizePixel = 0
chatFrame.ScrollBarThickness = 6
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
chatLayout.Padding = UDim.new(0, 5)
chatLayout.Parent = chatFrame

-- Update canvas size
chatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    chatFrame.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
end)

-- Scroll Down Button
local scrollDownBtn = Instance.new("TextButton")
scrollDownBtn.Size = UDim2.new(0, 38, 0, 38)
scrollDownBtn.Position = UDim2.new(0.5, -19, 1, -48)
scrollDownBtn.AnchorPoint = Vector2.new(0.5, 0.5)
scrollDownBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
scrollDownBtn.Text = "⬇"
scrollDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scrollDownBtn.Font = Enum.Font.GothamBold
scrollDownBtn.TextSize = 18
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
inputFrame.Size = UDim2.new(0.94, 0, 0, 30)
inputFrame.Position = UDim2.new(0.03, 0, 1, -35)
inputFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
inputFrame.BorderSizePixel = 0
inputFrame.Parent = mainFrame

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 8)
inputCorner.Parent = inputFrame

local textBox = Instance.new("TextBox")
textBox.Size = UDim2.new(0.7, 0, 0.8, 0)
textBox.Position = UDim2.new(0.02, 0, 0.1, 0)
textBox.BackgroundTransparency = 1
textBox.Text = ""
textBox.PlaceholderText = "Type message..."
textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
textBox.Font = Enum.Font.Gotham
textBox.TextSize = 11
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.ClearTextOnFocus = false
textBox.Parent = inputFrame

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(0.26, 0, 0.8, 0)
sendBtn.Position = UDim2.new(0.73, 0, 0.1, 0)
sendBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
sendBtn.Text = "Send"
sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sendBtn.Font = Enum.Font.GothamBold
sendBtn.TextSize = 11
sendBtn.Parent = inputFrame

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 6)
sendCorner.Parent = sendBtn

local HttpService = game:GetService("HttpService")

-- Avatar cache to reduce API calls
local avatarCache = {}

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
    -- Check cache first
    if avatarCache[userId] then
        return avatarCache[userId]
    end
    
    local success, result = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    
    if success and result then
        avatarCache[userId] = result
        return result
    end
    return ""
end

local function getUserIdFromUsername(username)
    local success, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    return success and userId or nil
end

local function createMessageBubble(username, displayName, message, game, timestamp, inviteData)
    local isMe = (username == LocalPlayer.Name)
    local showHeader = (lastSenderUsername ~= username)  -- Show header only if sender changed
    
    -- Update last sender
    lastSenderUsername = username
    
    local msgFrame = Instance.new("Frame")
    msgFrame.Size = UDim2.new(1, -8, 0, 0)
    msgFrame.BackgroundTransparency = 1
    msgFrame.AutomaticSize = Enum.AutomaticSize.Y
    msgFrame.Parent = chatFrame
    
    local msgLayout = Instance.new("UIListLayout")
    msgLayout.SortOrder = Enum.SortOrder.LayoutOrder
    msgLayout.Padding = UDim.new(0, showHeader and 3 or 2)
    msgLayout.Parent = msgFrame
    
    -- Header (only show if sender changed)
    if showHeader then
        local headerFrame = Instance.new("Frame")
        headerFrame.Size = UDim2.new(1, 0, 0, 16)
        headerFrame.BackgroundTransparency = 1
        headerFrame.LayoutOrder = 1
        headerFrame.Parent = msgFrame
        
        -- Avatar
        local avatar = Instance.new("ImageLabel")
        avatar.Size = UDim2.new(0, 16, 0, 16)
        avatar.Position = isMe and UDim2.new(1, -16, 0, 0) or UDim2.new(0, 0, 0, 0)
        avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        avatar.BorderSizePixel = 0
        avatar.Image = ""
        avatar.Parent = headerFrame
        
        local avatarCorner = Instance.new("UICorner")
        avatarCorner.CornerRadius = UDim.new(1, 0)
        avatarCorner.Parent = avatar
        
        -- Load avatar with optimized caching
        task.spawn(function()
            local player = Players:FindFirstChild(username)
            local userId = player and player.UserId or getUserIdFromUsername(username)
            
            if userId then
                local avatarUrl = getPlayerAvatar(userId)
                if avatarUrl ~= "" then
                    avatar.Image = avatarUrl
                end
            end
        end)
        
        -- Header text
        local headerLabel = Instance.new("TextLabel")
        headerLabel.Size = UDim2.new(1, -20, 1, 0)
        headerLabel.Position = isMe and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 20, 0, 0)
        headerLabel.BackgroundTransparency = 1
        
        local timeStr = timestamp:match("T(%d%d:%d%d)") or "??:??"
        headerLabel.Text = displayName .. " • " .. game .. " • " .. timeStr
        headerLabel.TextColor3 = isMe and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(255, 200, 100)
        headerLabel.Font = Enum.Font.GothamBold
        headerLabel.TextSize = 9
        headerLabel.TextXAlignment = isMe and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
        headerLabel.Parent = headerFrame
    end
    
    -- Message container
    local messageContainer = Instance.new("Frame")
    messageContainer.Size = UDim2.new(1, 0, 0, 0)
    messageContainer.BackgroundTransparency = 1
    messageContainer.AutomaticSize = Enum.AutomaticSize.Y
    messageContainer.LayoutOrder = showHeader and 2 or 1
    messageContainer.Parent = msgFrame
    
    -- Bubble (add left margin if same sender and not me)
    local bubbleLeftMargin = (not showHeader and not isMe) and 20 or 0
    
    local bubble = Instance.new("Frame")
    bubble.Size = UDim2.new(0.78, 0, 0, 0)
    bubble.Position = isMe and UDim2.new(0.22, 0, 0, 0) or UDim2.new(0, bubbleLeftMargin, 0, 0)
    bubble.BackgroundColor3 = isMe and Color3.fromRGB(50, 100, 200) or Color3.fromRGB(50, 50, 50)
    bubble.AutomaticSize = Enum.AutomaticSize.Y
    bubble.BorderSizePixel = 0
    bubble.Active = true
    bubble.Parent = messageContainer
    
    local bubbleCorner = Instance.new("UICorner")
    bubbleCorner.CornerRadius = UDim.new(0, 8)
    bubbleCorner.Parent = bubble
    
    local bubblePadding = Instance.new("UIPadding")
    bubblePadding.PaddingLeft = UDim.new(0, 8)
    bubblePadding.PaddingRight = UDim.new(0, 8)
    bubblePadding.PaddingTop = UDim.new(0, 6)
    bubblePadding.PaddingBottom = UDim.new(0, 6)
    bubblePadding.Parent = bubble
    
    -- Detect URLs in message
    local function hasUrl(text)
        return text:match("https?://[%w-_%.%?%.:/%+=&]+") or text:match("www%.[%w-_%.%?%.:/%+=&]+")
    end
    
    local function makeClickableText(text)
        local urlPattern = "(https?://[%w-_%.%?%.:/%+=&]+)"
        local wwwPattern = "(www%.[%w-_%.%?%.:/%+=&]+)"
        
        if text:match(urlPattern) or text:match(wwwPattern) then
            return true, text:match(urlPattern) or "https://" .. text:match(wwwPattern)
        end
        return false, nil
    end
    
    local hasLink, extractedUrl = makeClickableText(message)
    
    -- Message label with RichText for clickable links
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, 0, 0, 0)
    msgLabel.BackgroundTransparency = 1
    msgLabel.RichText = hasLink
    
    if hasLink then
        -- Highlight links in cyan
        local highlightedText = message:gsub("(https?://[%w-_%.%?%.:/%+=&]+)", '<font color="#00DDFF"><u>%1</u></font>')
        highlightedText = highlightedText:gsub("(www%.[%w-_%.%?%.:/%+=&]+)", '<font color="#00DDFF"><u>%1</u></font>')
        msgLabel.Text = highlightedText
    else
        msgLabel.Text = message
    end
    
    msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 11
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextYAlignment = Enum.TextYAlignment.Top
    msgLabel.AutomaticSize = Enum.AutomaticSize.Y
    msgLabel.Parent = bubble
    
    -- Hold to copy functionality
    local holdTime = 0
    local isHolding = false
    local holdConnection
    
    bubble.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isHolding = true
            holdTime = 0
            
            -- If message has link, open it on click
            if hasLink and extractedUrl then
                -- Open link in browser
                if syn and syn.request then
                    syn.request({
                        Url = "http://127.0.0.1:6463/rpc?v=1",
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = game:GetService("HttpService"):JSONEncode({
                            cmd = "INVITE_BROWSER",
                            args = {code = extractedUrl},
                            nonce = tostring(os.time())
                        })
                    })
                end
                
                -- Try to copy URL to clipboard
                if setclipboard then
                    setclipboard(extractedUrl)
                    
                    -- Visual feedback
                    local originalColor = bubble.BackgroundColor3
                    bubble.BackgroundColor3 = Color3.fromRGB(0, 150, 150)
                    task.wait(0.2)
                    bubble.BackgroundColor3 = originalColor
                end
            end
            
            -- Start hold timer
            holdConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
                if isHolding then
                    holdTime = holdTime + dt
                    
                    -- After 2 seconds, copy message
                    if holdTime >= 2 then
                        isHolding = false
                        holdConnection:Disconnect()
                        
                        -- Copy message to clipboard
                        if setclipboard then
                            setclipboard(message)
                            
                            -- Visual feedback
                            local originalColor = bubble.BackgroundColor3
                            bubble.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                            task.wait(0.3)
                            bubble.BackgroundColor3 = originalColor
                            
                            -- Show copied notification
                            local copiedLabel = Instance.new("TextLabel")
                            copiedLabel.Size = UDim2.new(0, 80, 0, 20)
                            copiedLabel.Position = UDim2.new(0.5, -40, 0.5, -10)
                            copiedLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            copiedLabel.BackgroundTransparency = 0.3
                            copiedLabel.Text = "✓ Copied"
                            copiedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                            copiedLabel.Font = Enum.Font.GothamBold
                            copiedLabel.TextSize = 10
                            copiedLabel.Parent = bubble
                            
                            local copiedCorner = Instance.new("UICorner")
                            copiedCorner.CornerRadius = UDim.new(0, 5)
                            copiedCorner.Parent = copiedLabel
                            
                            task.wait(1.5)
                            copiedLabel:Destroy()
                        end
                    end
                end
            end)
        end
    end)
    
    bubble.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isHolding = false
            if holdConnection then
                holdConnection:Disconnect()
            end
        end
    end)
    
    -- Join button (only show with header and use TeleportToPlaceInstance properly)
    if showHeader and not isMe and inviteData and verifyInviteLink(inviteData) then
        local joinBtn = Instance.new("TextButton")
        joinBtn.Size = UDim2.new(0, 50, 0, 24)
        joinBtn.Position = UDim2.new(1, -54, 0, 0)
        joinBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        joinBtn.Text = "Join"
        joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        joinBtn.Font = Enum.Font.GothamBold
        joinBtn.TextSize = 10
        joinBtn.Parent = messageContainer
        
        local joinCorner = Instance.new("UICorner")
        joinCorner.CornerRadius = UDim.new(0, 6)
        joinCorner.Parent = joinBtn
        
        joinBtn.MouseButton1Click:Connect(function()
            local placeId, jobId = inviteData:match("^(%d+)|(.+)$")
            if placeId and jobId and tonumber(placeId) then
                joinBtn.Text = "..."
                joinBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
                
                -- Multiple teleport methods for better compatibility
                local teleportSuccess = false
                
                -- Method 1: Try TeleportToPlaceInstance (requires permission)
                local method1 = pcall(function()
                    TeleportService:TeleportToPlaceInstance(tonumber(placeId), jobId, LocalPlayer)
                    teleportSuccess = true
                end)
                
                -- Method 2: If method 1 fails, try ReservedTeleportToPlace
                if not method1 then
                    local method2 = pcall(function()
                        local code = TeleportService:ReserveServer(tonumber(placeId))
                        TeleportService:TeleportToPrivateServer(tonumber(placeId), code, {LocalPlayer})
                        teleportSuccess = true
                    end)
                end
                
                -- Method 3: If all fail, try copying link and using regular teleport
                if not teleportSuccess then
                    local method3 = pcall(function()
                        if setclipboard then
                            setclipboard(inviteData)
                        end
                        TeleportService:Teleport(tonumber(placeId), LocalPlayer)
                    end)
                    
                    if not method3 then
                        joinBtn.Text = "✗"
                        joinBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                        
                        -- Show error message
                        local errorLabel = Instance.new("TextLabel")
                        errorLabel.Size = UDim2.new(0, 150, 0, 30)
                        errorLabel.Position = UDim2.new(1, -155, 0, -35)
                        errorLabel.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                        errorLabel.BackgroundTransparency = 0.2
                        errorLabel.Text = "Can't join. Link copied!"
                        errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        errorLabel.Font = Enum.Font.GothamBold
                        errorLabel.TextSize = 9
                        errorLabel.TextWrapped = true
                        errorLabel.Parent = messageContainer
                        
                        local errorCorner = Instance.new("UICorner")
                        errorCorner.CornerRadius = UDim.new(0, 5)
                        errorCorner.Parent = errorLabel
                        
                        task.wait(3)
                        errorLabel:Destroy()
                        
                        joinBtn.Text = "Join"
                        joinBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                    end
                end
            end
        end)
    end
    
    task.wait(0.05)
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
            Headers = {["Content-Type"] = "application/json"},
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
        updateStatus(false)
    end
end

local function fetchMessages()
    local success, response = pcall(function()
        local url = SERVER_URL .. "/messages"
        if lastMessageTime then
            url = url .. "?since=" .. HttpService:UrlEncode(lastMessageTime)
        end
        return httpRequest({Url = url, Method = "GET"})
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

-- Scroll detection
chatFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    local maxScroll = chatFrame.AbsoluteCanvasSize.Y - chatFrame.AbsoluteWindowSize.Y
    local currentScroll = chatFrame.CanvasPosition.Y
    
    if maxScroll > 0 and (maxScroll - currentScroll) > 25 then
        scrollDownBtn.Visible = true
        isAutoScrollEnabled = false
    else
        scrollDownBtn.Visible = false
        isAutoScrollEnabled = true
    end
end)

-- Minimize/Maximize with proper visibility control
minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        -- Hide all content except title bar
        gameLabel.Visible = false
        chatFrame.Visible = false
        inputFrame.Visible = false
        mainFrame:TweenSize(UDim2.new(0, 340, 0, 32), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minimizeBtn.Text = "+"
    else
        -- Show all content
        gameLabel.Visible = true
        chatFrame.Visible = true
        inputFrame.Visible = true
        mainFrame:TweenSize(UDim2.new(0, 340, 0, 380), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        minimizeBtn.Text = "−"
    end
end)

scrollDownBtn.MouseButton1Click:Connect(scrollToBottom)

sendBtn.MouseButton1Click:Connect(function()
    local msg = textBox.Text
    if msg ~= "" then
        sendMessage(msg)
        createMessageBubble(LocalPlayer.Name, DISPLAY_NAME, msg, currentGameName, DateTime.now():ToIsoDate(), inviteLink)
        textBox.Text = ""
    end
end)

textBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local msg = textBox.Text
        if msg ~= "" then
            sendMessage(msg)
            createMessageBubble(LocalPlayer.Name, DISPLAY_NAME, msg, currentGameName, DateTime.now():ToIsoDate(), inviteLink)
            textBox.Text = ""
        end
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    isActive = false
    screenGui:Destroy()
end)

task.spawn(function()
    while isActive and task.wait(UPDATE_INTERVAL) do
        fetchMessages()
    end
end)

task.wait(1)
fetchMessages()

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌐 UNIVERSAL CHAT LOADED")
print("✅ Invite Link: " .. inviteLink)
print("✅ Format Valid: " .. tostring(verifyInviteLink(inviteLink)))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
