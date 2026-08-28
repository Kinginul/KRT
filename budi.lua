-- ======================== SERVICES & CONSTANTS ========================
local Players = game:GetService("Players")
local UserInput = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera = Workspace.CurrentCamera

-- ======================== SPRINT CONFIG ========================
local sprintConfig = {
    mode = "Hold",            -- "Hold" or "Toggle"
    normalSpeed = 16,
    sprintSpeed = 26,
    normalFov = 70,
    sprintFov = 85,
    isSprinting = false,
}

-- ======================== ANIMATION PROFILES ========================
local ANIM_PROFILES = {
    adidas = {
        idle1 = "rbxassetid://122257458498464",
        idle2 = "rbxassetid://98173568987992",
        pose = "rbxassetid://89262795687364",
        walk = "rbxassetid://122150855457006",
        run = "rbxassetid://82598234841035",
        jump = "rbxassetid://75290611992385",
        climb = "rbxassetid://88763136693023",
        fall = "rbxassetid://18537367238",
        swim = "rbxassetid://133308483266208",
        swimidle = "rbxassetid://109346520324160",
    },
    zombie = {
        idle1 = "rbxassetid://10921344533",
        idle2 = "rbxassetid://10921345304",
        pose = "rbxassetid://10921146941",
        walk = "rbxassetid://616163682",
        run = "rbxassetid://616163682",
        jump = "rbxassetid://10921351278",
        fall = "rbxassetid://10921350320",
        climb = "rbxassetid://10921343576",
        swim = "rbxassetid://10921150788",
        swimidle = "rbxassetid://10921151661",
    },
}

local currentProfile = "adidas"  -- default

-- ======================== EMOTE DATA ========================
local EMOTES = {
    { name = "Geol Geol", id = "rbxassetid://138316142522795" },
    { name = "Ange", id = "rbxassetid://134207822469183" },
    { name = "Ga Brutal(SS)", id = "rbxassetid://14548619594" },
	{ name = "entot aku mas", id = "rbxassetid://100179668392253" },
	{ name = "UWAHHH", id = "rbxassetid://74138045051004" },
	{ name = "PINGGUL SANTAI WOK", id = "rbxassetid://134605189785347" },
    { name = "PINGGUL AW AW", id = "rbxassetid://74307872045715" },
    { name = "penggoda", id = "rbxassetid://133486714037697" },
    { name = "animeh", id = "rbxassetid://106516971471692" },
    { name = "goyang brutal", id = "rbxassetid://77016863682150" },
    { name = "Bergetar dia", id = "rbxassetid://105930925220838" },
    { name = "sana sini goyang", id = "rbxassetid://77387643699357" },
    { name = "ndut ndut", id = "rbxassetid://76554449514090" },
    { name = "goyang manis aw", id = "rbxassetid://104511578507004" },
    { name = "ulek ulek aw", id = "rbxassetid://102998462448180" },
    { name = "Stop Emote", id = nil },
}

-- ======================== UTILITY FUNCTIONS ========================
local function getHumanoid(char)
    return char and char:FindFirstChild("Humanoid")
end

local function getAnimator(char)
    local humanoid = getHumanoid(char)
    return humanoid and humanoid:FindFirstChild("Animator")
end

-- ======================== ANIMATION APPLY ========================
local function stopAllAnimations(char)
    local animator = getAnimator(char)
    if not animator then return end
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        track:Stop()
    end
end

local function applyAnimationProfile(char, profileName)
    if not char then return end
    local humanoid = getHumanoid(char)
    if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        warn("R15 required for animation swap")
        return
    end

    local animate = char:FindFirstChild("Animate")
    if not animate then return end

    local profile = ANIM_PROFILES[profileName] or ANIM_PROFILES.adidas
    local fallback = ANIM_PROFILES.adidas

    stopAllAnimations(char)

    animate.idle.Animation1.AnimationId = profile.idle1 or fallback.idle1
    animate.idle.Animation2.AnimationId = profile.idle2 or fallback.idle2

    if not animate.idle:FindFirstChild("Animation3") then
        local poseAnim = Instance.new("Animation")
        poseAnim.Name = "Animation3"
        poseAnim.AnimationId = profile.pose or fallback.pose
        poseAnim.Parent = animate.idle
    else
        animate.idle.Animation3.AnimationId = profile.pose or fallback.pose
    end

    animate.walk.WalkAnim.AnimationId = profile.walk or fallback.walk
    animate.run.RunAnim.AnimationId = profile.run or fallback.run
    animate.jump.JumpAnim.AnimationId = profile.jump or fallback.jump
    animate.climb.ClimbAnim.AnimationId = profile.climb or fallback.climb
    animate.fall.FallAnim.AnimationId = profile.fall or fallback.fall
    animate.swim.Swim.AnimationId = profile.swim or fallback.swim
    animate.swimidle.SwimIdle.AnimationId = profile.swimidle or fallback.swimidle

    animate.Disabled = true
    wait()
    animate.Disabled = false
end

-- ======================== EMOTE SYSTEM ========================
local currentEmoteTrack = nil

local function playEmote(char, animId)
    if not char then return end
    local animator = getAnimator(char)
    if not animator then return end

    if currentEmoteTrack then
        currentEmoteTrack:Stop()
        currentEmoteTrack = nil
    end

    if not animId then return end

    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local track = animator:LoadAnimation(anim)
    if track then
        track:Play()
        currentEmoteTrack = track
    end
end

-- ======================== SPRINT SYSTEM ========================
local function updateSprint(isSprinting)
    sprintConfig.isSprinting = isSprinting
    local char = player.Character or character
    local humanoid = getHumanoid(char)
    if humanoid then
        humanoid.WalkSpeed = isSprinting and sprintConfig.sprintSpeed or sprintConfig.normalSpeed
    end

    local fov = isSprinting and sprintConfig.sprintFov or sprintConfig.normalFov
    TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = fov }):Play()
end

-- ======================== UI TOGGLE ========================
local uiVisible = true
local uiFrame = nil
local uiObjects = {}

local function getUiObjects()
    local list = { uiFrame }
    for _, child in ipairs(uiFrame:GetDescendants()) do
        if child:IsA("GuiObject") then
            table.insert(list, child)
        end
    end
    return list
end

local function showUI()
    uiFrame.Visible = true
    uiVisible = true
end

local function hideUI()
    uiFrame.Visible = false
    uiVisible = false
end

local function toggleUI()
    if uiVisible then hideUI() else showUI() end
end

-- ======================== GUI CREATION ========================
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KinginulSprintMenu"
    screenGui.ResetOnSpawn = false  -- Important: keep UI after respawn
    screenGui.Parent = CoreGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 380)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -190)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BackgroundTransparency = 0
    mainFrame.BorderSizePixel = 1
    mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 255)
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "KRT (Kinginul Roblox Tools)"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BorderSizePixel = 0
    title.Parent = mainFrame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = mainFrame
    closeBtn.MouseButton1Click:Connect(hideUI)

    local modeBtn = Instance.new("TextButton")
    modeBtn.Size = UDim2.new(0.85, 0, 0, 30)
    modeBtn.Position = UDim2.new(0.075, 0, 0, 40)
    modeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    modeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    modeBtn.Text = "Mode: " .. sprintConfig.mode
    modeBtn.Font = Enum.Font.Gotham
    modeBtn.TextSize = 14
    modeBtn.BorderSizePixel = 0
    modeBtn.Parent = mainFrame
    modeBtn.MouseButton1Click:Connect(function()
        sprintConfig.mode = (sprintConfig.mode == "Hold") and "Toggle" or "Hold"
        modeBtn.Text = "Mode: " .. sprintConfig.mode
    end)

    local animBtn = Instance.new("TextButton")
    animBtn.Size = UDim2.new(0.85, 0, 0, 30)
    animBtn.Position = UDim2.new(0.075, 0, 0, 80)
    animBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    animBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    animBtn.Text = "Anim: " .. currentProfile
    animBtn.Font = Enum.Font.Gotham
    animBtn.TextSize = 14
    animBtn.BorderSizePixel = 0
    animBtn.Parent = mainFrame
    animBtn.MouseButton1Click:Connect(function()
        local profiles = {"adidas", "zombie"}
        local idx = table.find(profiles, currentProfile)
        idx = idx and (idx % #profiles) + 1 or 1
        currentProfile = profiles[idx]
        animBtn.Text = "Anim: " .. currentProfile
        applyAnimationProfile(player.Character or character, currentProfile)
    end)

    local reinjectBtn = Instance.new("TextButton")
    reinjectBtn.Size = UDim2.new(0.85, 0, 0, 30)
    reinjectBtn.Position = UDim2.new(0.075, 0, 0, 120)
    reinjectBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
    reinjectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    reinjectBtn.Text = "Reinject Anim"
    reinjectBtn.Font = Enum.Font.Gotham
    reinjectBtn.TextSize = 14
    reinjectBtn.BorderSizePixel = 0
    reinjectBtn.Parent = mainFrame
    reinjectBtn.MouseButton1Click:Connect(function()
        local char = player.Character
        if char then
            applyAnimationProfile(char, currentProfile)
            reinjectBtn.Text = "Injected!"
            wait(1)
            reinjectBtn.Text = "Reinject Anim"
        else
            reinjectBtn.Text = "No Character"
            wait(1)
            reinjectBtn.Text = "Reinject Anim"
        end
    end)

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 2)
    sep.Position = UDim2.new(0.05, 0, 0, 160)
    sep.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    sep.BorderSizePixel = 0
    sep.Parent = mainFrame

    local emoteTitle = Instance.new("TextLabel")
    emoteTitle.Size = UDim2.new(1, 0, 0, 25)
    emoteTitle.Position = UDim2.new(0, 0, 0, 170)
    emoteTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    emoteTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
    emoteTitle.Text = "  Emotes"
    emoteTitle.Font = Enum.Font.GothamBold
    emoteTitle.TextSize = 14
    emoteTitle.TextXAlignment = Enum.TextXAlignment.Left
    emoteTitle.BorderSizePixel = 0
    emoteTitle.Parent = mainFrame

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(0.9, 0, 0, 160)
    scrollFrame.Position = UDim2.new(0.05, 0, 0, 200)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    scrollFrame.BackgroundTransparency = 0.2
    scrollFrame.BorderSizePixel = 0
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #EMOTES * 35)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = scrollFrame

    for _, emote in ipairs(EMOTES) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = emote.name
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = scrollFrame

        btn.MouseButton1Click:Connect(function()
            local char = player.Character
            if not char then return end
            if emote.id then
                playEmote(char, emote.id)
            else
                playEmote(char, nil)
            end
        end)
    end

    uiFrame = mainFrame
    uiObjects = getUiObjects()
    showUI()  -- Ensure UI is visible immediately
end

-- ======================== INPUT HANDLING ========================
UserInput.InputBegan:Connect(function(input, processed)
    if processed then return end
    local key = input.KeyCode

    if key == Enum.KeyCode.RightShift then
        toggleUI()
        return
    end

    if key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl then
        if sprintConfig.mode == "Hold" then
            updateSprint(true)
        elseif sprintConfig.mode == "Toggle" then
            updateSprint(not sprintConfig.isSprinting)
        end
    end
end)

UserInput.InputEnded:Connect(function(input, processed)
    if processed then return end
    local key = input.KeyCode
    if (key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl) and sprintConfig.mode == "Hold" then
        updateSprint(false)
    end
end)

-- ======================== CHARACTER ADDED ========================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    wait(0.5)
    applyAnimationProfile(newChar, currentProfile)
    updateSprint(sprintConfig.isSprinting)
end)

-- ======================== INIT ========================
if player.Character then
    applyAnimationProfile(player.Character, currentProfile)
end

createUI()
print("Script loaded successfully!")
