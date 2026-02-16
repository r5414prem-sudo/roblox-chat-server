local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- CONFIG
local SERVER_URL = "https://roblox-chat-830h.onrender.com"
local KEY = "YOUR_KEY_HERE" -- Connect this to your Key System variable

-- UI Variables
local unreadCount = 0
local isMinimized = false
local lastTimestamp = nil
local isActive = true

-- UI SETUP (Mobile Responsive)
local screenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
screenGui.Name = "SmoothGlobalChat"

-- Main Chat Frame
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0.35, 0, 0.45, 0)
mainFrame.Position = UDim2.new(0.64, 0, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.ClipsDescendants = true

local uiCorner = Instance.new("UICorner", mainFrame)
uiCorner.CornerRadius = UDim.new(0, 10)

-- Minimize Bar (Hidden by default)
local minBar = Instance.new("TextButton", screenGui)
minBar.Size = UDim2.new(0.2, 0, 0, 40)
minBar.Position = UDim2.new(0.79, 0, 0.9, 0)
minBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
minBar.Text = "💬 Global Chat (0)"
minBar.TextColor3 = Color3.fromRGB(255, 255, 255)
minBar.Visible = false
Instance.new("UICorner", minBar)

-- Chat List (The Slider Area)
local chatList = Instance.new("ScrollingFrame", mainFrame)
chatList.Size = UDim2.new(1, -10, 0.8, -40)
chatList.Position = UDim2.new(0, 5, 0, 45)
chatList.BackgroundTransparency = 1
chatList.ScrollBarThickness = 4
chatList.CanvasSize = UDim2.new(0,0,0,0)

local layout = Instance.new("UIListLayout", chatList)
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Input Box
local input = Instance.new("TextBox", mainFrame)
input.Size = UDim2.new(0.9, 0, 0, 35)
input.Position = UDim2.new(0.05, 0, 0.9, -5)
input.PlaceholderText = "Type message..."
input.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
input.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", input)

-- FUNCTIONS
local function createMessage(data)
    local msgFrame = Instance.new("Frame", chatList)
    msgFrame.Size = UDim2.new(0.95, 0, 0, 50)
    msgFrame.BackgroundTransparency = 1
    
    -- Avatar Image
    local av = Instance.new("ImageLabel", msgFrame)
    av.Size = UDim2.new(0, 35, 0, 35)
    av.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..data.user_id.."&width=420&height=420&format=png"
    Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)
    
    -- Text Logic
    local content = Instance.new("TextLabel", msgFrame)
    content.Position = UDim2.new(0, 45, 0, 0)
    content.Size = UDim2.new(1, -50, 1, 0)
    content.BackgroundTransparency = 1
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.RichText = true
    
    -- Local Time Conversion
    local timeStr = DateTime.fromIsoDate(data.timestamp):ToLocalTime():FormatLocalTime("LT", "en-us")
    
    content.Text = string.format(
        "<font color='#AAAAAA'>[%s]</font> <b>%s</b> <font size='10' color='#55AAFF'>(%s)</font>\n%s",
        timeStr, data.display_name, data.game, data.message
    )
    content.TextColor3 = Color3.new(1,1,1)
    content.TextWrapped = true

    chatList.CanvasPosition = Vector2.new(0, 99999)
end

local function fetchData()
    local success, res = pcall(function()
        local url = SERVER_URL .. "/messages?username=" .. LocalPlayer.Name
        if lastTimestamp then url = url .. "&since=" .. lastTimestamp end
        return game:HttpGet(url)
    end)
    
    if success then
        local data = HttpService:JSONDecode(res)
        for _, msg in pairs(data.messages) do
            if msg.username ~= LocalPlayer.Name then
                createMessage(msg)
                if isMinimized then unreadCount += 1 end
            end
            lastTimestamp = msg.timestamp
        end
        minBar.Text = "💬 Global Chat ("..unreadCount..")"
    end
end

-- BUTTON LOGIC
input.FocusLost:Connect(function(enter)
    if enter and input.Text ~= "" then
        local text = input.Text
        input.Text = ""
        -- Create local bubble instantly for "Smooth" feel
        createMessage({
            user_id = LocalPlayer.UserId,
            display_name = LocalPlayer.DisplayName,
            game = "Current",
            message = text,
            timestamp = DateTime.now():ToIsoDate()
        })
        
        pcall(function()
            game:HttpPost(SERVER_URL.."/send", HttpService:JSONEncode({
                username = LocalPlayer.Name,
                display_name = LocalPlayer.DisplayName,
                user_id = LocalPlayer.UserId,
                message = text,
                game = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
            }))
        end)
    end
end)

-- Minimize Logic
local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -35, 0, 5)
minBtn.Text = "-"
minBtn.BackgroundColor3 = Color3.new(1,0,0)

minBtn.MouseButton1Click:Connect(function()
    isMinimized = true
    mainFrame.Visible = false
    minBar.Visible = true
end)

minBar.MouseButton1Click:Connect(function()
    isMinimized = false
    unreadCount = 0
    mainFrame.Visible = true
    minBar.Visible = false
end)

-- Start Loop
task.spawn(function()
    while isActive do
        fetchData()
        task.wait(2)
    end
end)
