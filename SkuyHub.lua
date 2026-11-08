--[[
    SKUY HUB - Client UI / Authorized Private-Test Build
    Install/run only in a Roblox experience you own or are authorized to test.

    Required server objects:
      ReplicatedStorage
        SKUYHubRemotes
          ActionRequest (RemoteEvent)
          StatsUpdate   (RemoteEvent)

    This client intentionally does not call undocumented game remotes.
    The server must validate and implement each action.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("SKUYHubRemotes", 10)
if not Remotes then
    warn("[SKUY HUB] SKUYHubRemotes not found. Add the authorized server bridge first.")
    return
end

local ActionRequest = Remotes:WaitForChild("ActionRequest", 5)
local StatsUpdate = Remotes:WaitForChild("StatsUpdate", 5)
if not ActionRequest or not StatsUpdate then
    warn("[SKUY HUB] Missing ActionRequest or StatsUpdate RemoteEvent.")
    return
end

local running = {}
local stats = {Collected = 0, Harvested = 0, Broken = 0, Planted = 0, Actions = 0}
local statusText = "Connected"

local ACTIONS = {
    {id="AutoFarm", label="Auto Farm", desc="Farming cycle"},
    {id="AutoTake", label="Auto Take", desc="Take nearby items"},
    {id="AutoPlant", label="Auto Plant", desc="Plant selected seed"},
    {id="AutoHarvest", label="Auto Harvest", desc="Harvest ready crops"},
    {id="AutoBreak", label="Auto Break", desc="Break selected blocks"},
    {id="AutoClear", label="Auto Clear", desc="Clear selected area"},
    {id="AutoSplice", label="Auto Splice", desc="Splice selected seeds"},
    {id="AutoCollect", label="Auto Collect", desc="Collect nearby drops"},
}

local COLORS = {
    bg = Color3.fromRGB(13, 14, 18),
    panel = Color3.fromRGB(21, 22, 28),
    panel2 = Color3.fromRGB(29, 30, 38),
    line = Color3.fromRGB(48, 50, 60),
    text = Color3.fromRGB(241, 242, 247),
    muted = Color3.fromRGB(148, 151, 164),
    accent = Color3.fromRGB(166, 122, 255),
    green = Color3.fromRGB(93, 211, 143),
    red = Color3.fromRGB(235, 95, 108),
}

local gui = Instance.new("ScreenGui")
gui.Name = "SkuyHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(370, 500)
main.Position = UDim2.new(0.5, -185, 0.5, -250)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = COLORS.line
stroke.Thickness = 1
stroke.Parent = main

local function label(parent, text, size, color, font)
    local obj = Instance.new("TextLabel")
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextSize = size
    obj.TextColor3 = color or COLORS.text
    obj.Font = font or Enum.Font.Gotham
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.Parent = parent
    return obj
end

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 68)
header.BackgroundColor3 = COLORS.panel
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local title = label(header, "SKUY HUB", 20, COLORS.text, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -70, 0, 26)

local subtitle = label(header, "DARK  /  MINIMAL  •  PRIVATE TEST", 9, COLORS.muted, Enum.Font.GothamMedium)
subtitle.Position = UDim2.fromOffset(19, 39)
subtitle.Size = UDim2.new(1, -35, 0, 16)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -43, 0, 17)
close.BackgroundColor3 = COLORS.panel2
close.Text = "×"
close.TextSize = 20
close.TextColor3 = COLORS.muted
close.Font = Enum.Font.Gotham
close.Parent = header
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Drag window from header
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local status = label(main, "●  " .. statusText, 10, COLORS.green, Enum.Font.GothamMedium)
status.Position = UDim2.fromOffset(18, 78)
status.Size = UDim2.new(1, -36, 0, 18)

local section = label(main, "AUTOMATION", 10, COLORS.muted, Enum.Font.GothamBold)
section.Position = UDim2.fromOffset(18, 105)
section.Size = UDim2.new(1, -36, 0, 18)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 130)
list.Size = UDim2.new(1, -28, 0, 250)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = COLORS.line
list.CanvasSize = UDim2.fromOffset(0, #ACTIONS * 54)
list.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function setStatus(message, isGood)
    status.Text = "●  " .. tostring(message)
    status.TextColor3 = isGood and COLORS.green or COLORS.red
end

local function request(action, enabled)
    ActionRequest:FireServer(action, enabled)
end

for index, item in ipairs(ACTIONS) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 47)
    row.BackgroundColor3 = COLORS.panel
    row.BorderSizePixel = 0
    row.LayoutOrder = index
    row.Parent = list
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local name = label(row, item.label, 12, COLORS.text, Enum.Font.GothamSemibold)
    name.Position = UDim2.fromOffset(12, 7)
    name.Size = UDim2.new(1, -90, 0, 17)

    local desc = label(row, item.desc, 9, COLORS.muted, Enum.Font.Gotham)
    desc.Position = UDim2.fromOffset(12, 25)
    desc.Size = UDim2.new(1, -90, 0, 13)

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.fromOffset(54, 27)
    toggle.Position = UDim2.new(1, -66, 0.5, -13)
    toggle.BackgroundColor3 = COLORS.panel2
    toggle.Text = "OFF"
    toggle.TextSize = 9
    toggle.TextColor3 = COLORS.muted
    toggle.Font = Enum.Font.GothamBold
    toggle.Parent = row
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    toggle.MouseButton1Click:Connect(function()
        local nextValue = not running[item.id]
        running[item.id] = nextValue
        toggle.Text = nextValue and "ON" or "OFF"
        toggle.BackgroundColor3 = nextValue and COLORS.accent or COLORS.panel2
        toggle.TextColor3 = nextValue and Color3.new(1,1,1) or COLORS.muted
        request(item.id, nextValue)
        setStatus(item.label .. (nextValue and " requested" or " stopped"), true)
    end)
end

local statsPanel = Instance.new("Frame")
statsPanel.Position = UDim2.fromOffset(14, 392)
statsPanel.Size = UDim2.new(1, -28, 0, 88)
statsPanel.BackgroundColor3 = COLORS.panel
statsPanel.BorderSizePixel = 0
statsPanel.Parent = main
Instance.new("UICorner", statsPanel).CornerRadius = UDim.new(0, 8)

local statsTitle = label(statsPanel, "SESSION STATISTICS", 9, COLORS.muted, Enum.Font.GothamBold)
statsTitle.Position = UDim2.fromOffset(12, 9)
statsTitle.Size = UDim2.new(1, -24, 0, 14)

local statLabels = {}
local statOrder = {
    {"Collected", "TAKEN"},
    {"Harvested", "HARVEST"},
    {"Broken", "BROKEN"},
    {"Planted", "PLANTED"},
}
for i, entry in ipairs(statOrder) do
    local x = 12 + (i - 1) * 85
    local value = label(statsPanel, "0", 16, COLORS.text, Enum.Font.GothamBold)
    value.Position = UDim2.fromOffset(x, 28)
    value.Size = UDim2.fromOffset(78, 22)
    local caption = label(statsPanel, entry[2], 8, COLORS.muted, Enum.Font.GothamMedium)
    caption.Position = UDim2.fromOffset(x, 53)
    caption.Size = UDim2.fromOffset(78, 14)
    statLabels[entry[1]] = value
end

StatsUpdate.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    for key, value in pairs(stats) do
        if typeof(payload[key]) == "number" then
            stats[key] = math.max(0, math.floor(payload[key]))
        end
    end
    for key, obj in pairs(statLabels) do
        obj.Text = tostring(stats[key] or 0)
    end
    if payload.message then setStatus(payload.message, payload.ok ~= false) end
    if typeof(payload.running) == "table" then
        for id, value in pairs(payload.running) do
            if running[id] ~= nil then running[id] = value end
        end
    end
end)

setStatus("Connected • waiting for server", true)
print("[SKUY HUB] UI loaded. Actions require your authorized server implementation.")
