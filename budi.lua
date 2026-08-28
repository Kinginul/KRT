-- ======================== SERVICES & CONSTANTS ========================
local Players = game:GetService("Players")
local UserInput = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera = Workspace.CurrentCamera

-- ======================== CONFIG ========================
local sprintConfig = {
    mode = "Hold",
    normalSpeed = 16,
    sprintSpeed = 26,
    normalFov = 70,
    sprintFov = 85,
    isSprinting = false,
}

local flyState = {
    enabled = false,
    velocity = nil,
    gyro = nil,
    connection = nil,
}

local currentProfile = "adidas"
local currentEmoteTrack = nil
local sprintBtnRef = nil
local flyBtnRef = nil
local uiVisible = true
local mainFrame = nil
local playerPanelVisible = false
local playerListRef = nil
local mobileUI = UserInput.TouchEnabled
local trollState = {
    enabled = false,
    connection = nil,
    gyro = nil,
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

-- ======================== EMOTE DATA ========================
local EMOTES = {
    { name = "Wave", id = "rbxassetid://138316142522795" },
    { name = "Cheer", id = "rbxassetid://134207822469183" },
    { name = "Dance 1", id = "rbxassetid://14548619594" },
    { name = "Dance 2", id = "rbxassetid://100179668392253" },
    { name = "Spin", id = "rbxassetid://74138045051004" },
    { name = "Boost", id = "rbxassetid://134605189785347" },
    { name = "Power", id = "rbxassetid://74307872045715" },
    { name = "Show", id = "rbxassetid://133486714037697" },
    { name = "Style", id = "rbxassetid://106516971471692" },
    { name = "Groove", id = "rbxassetid://77016863682150" },
    { name = "Vibe", id = "rbxassetid://105930925220838" },
    { name = "Move", id = "rbxassetid://77387643699357" },
    { name = "Chill", id = "rbxassetid://76554449514090" },
    { name = "Ready", id = "rbxassetid://104511578507004" },
    { name = "Loop", id = "rbxassetid://102998462448180" },
    { name = "Stop", id = nil },
}

-- ======================== UTILITY FUNCTIONS ========================
local function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getAnimator(char)
    local humanoid = getHumanoid(char)
    return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function createTeleportEffect(position)
    local effect = Instance.new("Part")
    effect.Name = "TeleportEffect"
    effect.Anchored = true
    effect.CanCollide = false
    effect.CanTouch = false
    effect.CanQuery = false
    effect.Material = Enum.Material.Neon
    effect.Color = Color3.fromRGB(112, 203, 255)
    effect.Shape = Enum.PartType.Cylinder
    effect.Size = Vector3.new(0.5, 0.2, 0.5)
    effect.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    effect.Parent = Workspace

    local tweenIn = TweenService:Create(effect, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(3.5, 0.2, 3.5),
        Transparency = 0.2,
    })
    local tweenOut = TweenService:Create(effect, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Transparency = 1,
    })

    tweenIn:Play()
    tweenIn.Completed:Connect(function()
        tweenOut:Play()
    end)

    task.delay(0.6, function()
        if effect and effect.Parent then
            effect:Destroy()
        end
    end)
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then
        return
    end

    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        return
    end

    local localChar = player.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    if not localChar or not localRoot then
        return
    end

    createTeleportEffect(localRoot.Position)
    localChar:PivotTo(CFrame.new(targetRoot.Position + Vector3.new(0, 4, 0)))
    createTeleportEffect(targetRoot.Position + Vector3.new(0, 4, 0))
end

-- ======================== SMOOTH DRAGGING ========================
local function makeDraggable(frame, dragHandle)
    dragHandle = dragHandle or frame
    local dragging, dragInput, dragStart, startPos

    local function update(input)
        local delta = input.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        TweenService:Create(frame, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = newPos,
        }):Play()
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInput.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- ======================== ANIMATION APPLY ========================
local function stopAllAnimations(char)
    local animator = getAnimator(char)
    if not animator then
        return
    end

    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        track:Stop()
    end
end

local function applyAnimationProfile(char, profileName)
    if not char then
        return
    end

    local humanoid = getHumanoid(char)
    if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return
    end

    local animate = char:FindFirstChild("Animate")
    if not animate then
        return
    end

    local profile = ANIM_PROFILES[profileName] or ANIM_PROFILES.adidas
    local fallback = ANIM_PROFILES.adidas

    stopAllAnimations(char)

    if animate:FindFirstChild("idle") then
        if animate.idle:FindFirstChild("Animation1") then
            animate.idle.Animation1.AnimationId = profile.idle1 or fallback.idle1
        end
        if animate.idle:FindFirstChild("Animation2") then
            animate.idle.Animation2.AnimationId = profile.idle2 or fallback.idle2
        end
        if not animate.idle:FindFirstChild("Animation3") then
            local poseAnim = Instance.new("Animation")
            poseAnim.Name = "Animation3"
            poseAnim.AnimationId = profile.pose or fallback.pose
            poseAnim.Parent = animate.idle
        else
            animate.idle.Animation3.AnimationId = profile.pose or fallback.pose
        end
    end

    if animate:FindFirstChild("walk") and animate.walk:FindFirstChild("WalkAnim") then
        animate.walk.WalkAnim.AnimationId = profile.walk or fallback.walk
    end
    if animate:FindFirstChild("run") and animate.run:FindFirstChild("RunAnim") then
        animate.run.RunAnim.AnimationId = profile.run or fallback.run
    end
    if animate:FindFirstChild("jump") and animate.jump:FindFirstChild("JumpAnim") then
        animate.jump.JumpAnim.AnimationId = profile.jump or fallback.jump
    end
    if animate:FindFirstChild("climb") and animate.climb:FindFirstChild("ClimbAnim") then
        animate.climb.ClimbAnim.AnimationId = profile.climb or fallback.climb
    end
    if animate:FindFirstChild("fall") and animate.fall:FindFirstChild("FallAnim") then
        animate.fall.FallAnim.AnimationId = profile.fall or fallback.fall
    end

    animate.Disabled = true
    task.wait(0.05)
    animate.Disabled = false
end

-- ======================== EMOTE SYSTEM ========================
local function playEmote(char, animId)
    if not char then
        return
    end

    local animator = getAnimator(char)
    if not animator then
        return
    end

    if currentEmoteTrack then
        currentEmoteTrack:Stop()
        currentEmoteTrack = nil
    end

    if not animId then
        return
    end

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
    local currentChar = player.Character or character
    local humanoid = getHumanoid(currentChar)

    if humanoid then
        humanoid.WalkSpeed = isSprinting and sprintConfig.sprintSpeed or sprintConfig.normalSpeed
    end

    local fov = isSprinting and sprintConfig.sprintFov or sprintConfig.normalFov
    TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        FieldOfView = fov,
    }):Play()

    if sprintBtnRef then
        sprintBtnRef.BackgroundColor3 = isSprinting and Color3.fromRGB(160, 32, 240) or Color3.fromRGB(35, 30, 50)
        sprintBtnRef.Text = isSprinting and "RUN ON" or "RUN OFF"
    end
end

local function updateFlyButton()
    if flyBtnRef then
        flyBtnRef.BackgroundColor3 = flyState.enabled and Color3.fromRGB(90, 200, 255) or Color3.fromRGB(32, 26, 48)
        flyBtnRef.Text = flyState.enabled and "Fly: ON" or "Fly: OFF"
    end
end

local function setFlyState(enabled)
    local currentChar = player.Character
    local humanoid = getHumanoid(currentChar)

    if not currentChar or not humanoid then
        return
    end

    local root = currentChar:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    flyState.enabled = enabled

    if enabled then
        if flyState.velocity then
            flyState.velocity:Destroy()
        end
        if flyState.gyro then
            flyState.gyro:Destroy()
        end

        local velocity = Instance.new("BodyVelocity")
        velocity.MaxForce = Vector3.new(4000, 4000, 4000)
        velocity.Velocity = Vector3.zero
        velocity.Parent = root

        local gyro = Instance.new("BodyGyro")
        gyro.MaxTorque = Vector3.new(4000, 4000, 4000)
        gyro.CFrame = root.CFrame
        gyro.Parent = root

        flyState.velocity = velocity
        flyState.gyro = gyro
        humanoid.PlatformStand = true

        if flyState.connection then
            flyState.connection:Disconnect()
        end

        flyState.connection = RunService.RenderStepped:Connect(function()
            if not flyState.enabled then
                return
            end

            local char = player.Character
            if not char then
                return
            end

            local humanoidPart = getHumanoid(char)
            local currentRoot = char:FindFirstChild("HumanoidRootPart")
            if not humanoidPart or not currentRoot then
                return
            end

            local moveX = (UserInput:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInput:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
            local moveZ = (UserInput:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInput:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
            local upward = (UserInput:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInput:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)

            local camForward = camera.CFrame.LookVector
            local camRight = camera.CFrame.RightVector
            local forwardVector = Vector3.new(camForward.X, 0, camForward.Z)
            local rightVector = Vector3.new(camRight.X, 0, camRight.Z)

            local moveDirection = Vector3.zero
            if moveZ ~= 0 then
                moveDirection = moveDirection + (forwardVector.Magnitude > 0 and forwardVector.Unit * moveZ or Vector3.zero)
            end
            if moveX ~= 0 then
                moveDirection = moveDirection + (rightVector.Magnitude > 0 and rightVector.Unit * moveX or Vector3.zero)
            end

            local speed = 28
            local desiredVelocity = moveDirection.Magnitude > 0 and moveDirection.Unit * speed or Vector3.zero
            desiredVelocity = desiredVelocity + Vector3.new(0, upward * speed, 0)

            flyState.velocity.Velocity = desiredVelocity

            local lookTarget = currentRoot.Position + (camera.CFrame.LookVector * Vector3.new(1, 0, 1))
            flyState.gyro.CFrame = CFrame.new(currentRoot.Position, lookTarget)
        end)
    else
        if flyState.connection then
            flyState.connection:Disconnect()
            flyState.connection = nil
        end
        if flyState.velocity then
            flyState.velocity:Destroy()
            flyState.velocity = nil
        end
        if flyState.gyro then
            flyState.gyro:Destroy()
            flyState.gyro = nil
        end

        humanoid.PlatformStand = false
    end

    updateFlyButton()
end

-- ======================== PLAYER LIST PANEL ========================
local function buildPlayerRow(targetPlayer)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(42, 36, 60)
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = playerListRef

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 100, 190)
    stroke.Transparency = 0.4
    stroke.Thickness = 1
    stroke.Parent = row

    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 8, 0, 8)
    badge.Position = UDim2.new(0, 12, 0.5, -4)
    badge.BackgroundColor3 = targetPlayer == player and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(115, 180, 255)
    badge.BorderSizePixel = 0
    badge.Parent = row

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = badge

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -86, 1, 0)
    nameLabel.Position = UDim2.new(0, 28, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    nameLabel.Text = targetPlayer.DisplayName
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = row

    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0, 46, 0, 22)
    tpBtn.Position = UDim2.new(1, -58, 0.5, -11)
    tpBtn.BackgroundColor3 = Color3.fromRGB(118, 81, 255)
    tpBtn.BorderSizePixel = 0
    tpBtn.Text = "TP"
    tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.TextSize = 11
    tpBtn.Parent = row

    local tpCorner = Instance.new("UICorner")
    tpCorner.CornerRadius = UDim.new(0, 7)
    tpCorner.Parent = tpBtn

    tpBtn.MouseButton1Click:Connect(function()
        teleportToPlayer(targetPlayer)
    end)

    row.MouseButton1Click:Connect(function()
        if targetPlayer ~= player then
            teleportToPlayer(targetPlayer)
        end
    end)

    return row
end

local function refreshPlayersList()
    if not playerListRef then
        return
    end

    for _, child in ipairs(playerListRef:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end

    local players = {}
    for _, existingPlayer in ipairs(Players:GetPlayers()) do
        if existingPlayer ~= player then
            table.insert(players, existingPlayer)
        end
    end

    table.sort(players, function(a, b)
        return (a.DisplayName or a.Name):lower() < (b.DisplayName or b.Name):lower()
    end)

    if #players == 0 then
        local emptyText = Instance.new("TextLabel")
        emptyText.Size = UDim2.new(1, 0, 0, 28)
        emptyText.BackgroundTransparency = 1
        emptyText.TextColor3 = Color3.fromRGB(180, 170, 210)
        emptyText.Text = "Tidak ada player lain"
        emptyText.Font = Enum.Font.Gotham
        emptyText.TextSize = 12
        emptyText.Parent = playerListRef
        return
    end

    for _, targetPlayer in ipairs(players) do
        buildPlayerRow(targetPlayer)
    end
end

local function showToast(message)
    if not mainFrame then return end

    local toast = Instance.new("TextLabel")
    toast.Name = "Toast"
    toast.Size = UDim2.new(0, 180, 0, 28)
    toast.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
    toast.BackgroundTransparency = 0.08
    toast.TextColor3 = Color3.fromRGB(235, 240, 248)
    toast.Text = message
    toast.Font = Enum.Font.GothamSemibold
    toast.TextSize = 11
    toast.Parent = mainFrame

    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 8)
    toastCorner.Parent = toast

    local toastStroke = Instance.new("UIStroke")
    toastStroke.Color = Color3.fromRGB(110, 120, 130)
    toastStroke.Thickness = 1
    toastStroke.Transparency = 0.2
    toastStroke.Parent = toast

    toast.Position = UDim2.new(0.5, -90, 1, -52)
    toast.AnchorPoint = Vector2.new(0.5, 1)
    toast.TextTransparency = 0.1

    TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -90, 1, -82),
        BackgroundTransparency = 0.18,
    }):Play()

    task.delay(1.3, function()
        if toast and toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -90, 1, -20),
                TextTransparency = 1,
                BackgroundTransparency = 1,
            }):Play()

            task.delay(0.2, function()
                if toast and toast.Parent then
                    toast:Destroy()
                end
            end)
        end
    end)
end

local function togglePlayerPanel()
    playerPanelVisible = not playerPanelVisible
    local playerPanel = mainFrame and mainFrame:FindFirstChild("PlayerPanel")
    if not playerPanel then
        return
    end

    if playerPanelVisible then
        playerPanel.Visible = true
        playerPanel.Size = UDim2.new(1, 0, 0, 0)
        TweenService:Create(playerPanel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, 180),
        }):Play()
    else
        local tween = TweenService:Create(playerPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(1, 0, 0, 0),
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not playerPanelVisible then
                playerPanel.Visible = false
            end
        end)
    end
end

local function toggleTrollMode()
    trollState.enabled = not trollState.enabled

    if trollState.enabled then
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            trollState.enabled = false
            return
        end

        local gyro = Instance.new("BodyGyro")
        gyro.MaxTorque = Vector3.new(0, 50000, 0)
        gyro.CFrame = root.CFrame
        gyro.Parent = root
        trollState.gyro = gyro

        trollState.connection = RunService.RenderStepped:Connect(function()
            if not trollState.enabled or not player.Character then
                return
            end

            local currentRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if currentRoot then
                currentRoot.CFrame = currentRoot.CFrame * CFrame.Angles(0, math.rad(18), 0)
            end
        end)

        showToast("Troll spin enabled")
    else
        if trollState.connection then
            trollState.connection:Disconnect()
            trollState.connection = nil
        end

        if trollState.gyro then
            trollState.gyro:Destroy()
            trollState.gyro = nil
        end

        showToast("Troll spin disabled")
    end
end

local function resetFlyState()
    if flyState.enabled then
        setFlyState(false)
    end
    showToast("Fly reset")
end

local function resetSpeedState()
    local currentChar = player.Character
    local humanoid = getHumanoid(currentChar)
    if humanoid then
        humanoid.WalkSpeed = sprintConfig.normalSpeed
        showToast("Speed reset")
    end
end

local function closeAllInterface()
    if mainFrame then
        uiVisible = false
        mainFrame.Visible = false
    end
    showToast("UI closed")
end

local function updateDesktopLayout()
    if not mainFrame then return end

    if mobileUI then
        mainFrame.Size = UDim2.new(0, 280, 0, 360)
        mainFrame.Position = UDim2.new(0.5, -140, 0.72, -180)
    else
        mainFrame.Size = UDim2.new(0, 300, 0, 420)
        mainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
    end
end

-- ======================== GUI CREATION ========================
local function createUI()
    if CoreGui:FindFirstChild("KinginulSprintMenu") then
        CoreGui.KinginulSprintMenu:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KinginulSprintMenu"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
    mainFrame.BackgroundColor3 = Color3.fromRGB(17, 18, 22)
    mainFrame.BackgroundTransparency = 0.08
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(129, 134, 145)
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.2
    mainStroke.Parent = mainFrame

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BackgroundTransparency = 0.96
    overlay.BorderSizePixel = 0
    overlay.Parent = mainFrame

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundColor3 = Color3.fromRGB(29, 31, 37)
    header.BorderSizePixel = 0
    header.Parent = mainFrame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = header

    local titleBadge = Instance.new("TextLabel")
    titleBadge.Size = UDim2.new(0, 42, 0, 18)
    titleBadge.Position = UDim2.new(0, 14, 0.5, -9)
    titleBadge.BackgroundColor3 = Color3.fromRGB(99, 104, 115)
    titleBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleBadge.Text = "KRT"
    titleBadge.Font = Enum.Font.GothamBold
    titleBadge.TextSize = 11
    titleBadge.BorderSizePixel = 0
    titleBadge.TextXAlignment = Enum.TextXAlignment.Center
    titleBadge.Parent = header

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent = titleBadge

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -112, 1, 0)
    title.Position = UDim2.new(0, 62, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(235, 238, 242)
    title.Text = "Kinginul Roblox Tools"
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(76, 80, 90)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        uiVisible = false
        mainFrame.Visible = false
    end)

    makeDraggable(mainFrame, header)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 34)
    tabBar.Position = UDim2.new(0, 10, 0, 48)
    tabBar.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 8)
    tabCorner.Parent = tabBar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local tabButtons = {}
    local function createTabButton(label, index)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.25, -5, 1, -8)
        btn.BackgroundColor3 = index == 1 and Color3.fromRGB(82, 87, 100) or Color3.fromRGB(38, 41, 48)
        btn.Text = label
        btn.TextColor3 = Color3.fromRGB(235, 238, 242)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = tabBar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 7)
        btnCorner.Parent = btn

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(110, 116, 128)
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.35
        btnStroke.Parent = btn

        tabButtons[label] = btn

        btn.MouseButton1Click:Connect(function()
            for name, tabBtn in pairs(tabButtons) do
                tabBtn.BackgroundColor3 = name == label and Color3.fromRGB(82, 87, 100) or Color3.fromRGB(38, 41, 48)
            end

            mainPanel.Visible = label == "Main"
            visualPanel.Visible = label == "Visual"
            playerPanelTab.Visible = label == "Player"
            settingsPanel.Visible = label == "Settings"
        end)

        return btn
    end

    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "MainPanel"
    mainPanel.Size = UDim2.new(1, -20, 1, -95)
    mainPanel.Position = UDim2.new(0, 10, 0, 88)
    mainPanel.BackgroundTransparency = 1
    mainPanel.Parent = mainFrame

    local visualPanel = Instance.new("Frame")
    visualPanel.Name = "VisualPanel"
    visualPanel.Size = UDim2.new(1, -20, 1, -95)
    visualPanel.Position = UDim2.new(0, 10, 0, 88)
    visualPanel.BackgroundTransparency = 1
    visualPanel.Visible = false
    visualPanel.Parent = mainFrame

    local playerPanelTab = Instance.new("Frame")
    playerPanelTab.Name = "PlayerPanelTab"
    playerPanelTab.Size = UDim2.new(1, -20, 1, -95)
    playerPanelTab.Position = UDim2.new(0, 10, 0, 88)
    playerPanelTab.BackgroundTransparency = 1
    playerPanelTab.Visible = false
    playerPanelTab.Parent = mainFrame

    local settingsPanel = Instance.new("Frame")
    settingsPanel.Name = "SettingsPanel"
    settingsPanel.Size = UDim2.new(1, -20, 1, -95)
    settingsPanel.Position = UDim2.new(0, 10, 0, 88)
    settingsPanel.BackgroundTransparency = 1
    settingsPanel.Visible = false
    settingsPanel.Parent = mainFrame

    local mainContent = Instance.new("Frame")
    mainContent.Size = UDim2.new(1, 0, 1, 0)
    mainContent.BackgroundTransparency = 1
    mainContent.Parent = mainPanel

    local visualContent = Instance.new("Frame")
    visualContent.Size = UDim2.new(1, 0, 1, 0)
    visualContent.BackgroundTransparency = 1
    visualContent.Parent = visualPanel

    local playerContent = Instance.new("Frame")
    playerContent.Size = UDim2.new(1, 0, 1, 0)
    playerContent.BackgroundTransparency = 1
    playerContent.Parent = playerPanelTab

    local settingsContent = Instance.new("Frame")
    settingsContent.Size = UDim2.new(1, 0, 1, 0)
    settingsContent.BackgroundTransparency = 1
    settingsContent.Parent = settingsPanel

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 7)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = mainContent

    local visualLayout = Instance.new("UIListLayout")
    visualLayout.Padding = UDim.new(0, 7)
    visualLayout.SortOrder = Enum.SortOrder.LayoutOrder
    visualLayout.Parent = visualContent

    local playerLayout = Instance.new("UIListLayout")
    playerLayout.Padding = UDim.new(0, 7)
    playerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    playerLayout.Parent = playerContent

    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 8)
    settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    settingsLayout.Parent = settingsContent

    local function createIconBadge(text, parent)
        local badge = Instance.new("Frame")
        badge.Size = UDim2.new(0, 28, 0, 28)
        badge.BackgroundColor3 = Color3.fromRGB(61, 66, 76)
        badge.BorderSizePixel = 0
        badge.Parent = parent

        local badgeCorner = Instance.new("UICorner")
        badgeCorner.CornerRadius = UDim.new(0, 7)
        badgeCorner.Parent = badge

        local badgeStroke = Instance.new("UIStroke")
        badgeStroke.Color = Color3.fromRGB(135, 141, 152)
        badgeStroke.Thickness = 1
        badgeStroke.Transparency = 0.35
        badgeStroke.Parent = badge

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Text = text
        icon.TextColor3 = Color3.fromRGB(230, 233, 238)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 10
        icon.Parent = badge

        return badge
    end

    local function createStyledButton(text, layoutOrder, parent, callback, iconText)
        local containerBtn = Instance.new("TextButton")
        containerBtn.Size = UDim2.new(1, 0, 0, 36)
        containerBtn.BackgroundColor3 = Color3.fromRGB(30, 33, 39)
        containerBtn.BorderSizePixel = 0
        containerBtn.Text = ""
        containerBtn.LayoutOrder = layoutOrder
        containerBtn.Parent = parent

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 9)
        btnCorner.Parent = containerBtn

        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(94, 100, 110)
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.25
        btnStroke.Parent = containerBtn

        local iconBadge = createIconBadge(iconText or "N", containerBtn)
        iconBadge.Position = UDim2.new(0, 8, 0.5, -14)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -52, 1, 0)
        label.Position = UDim2.new(0, 46, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(235, 238, 242)
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = containerBtn

        containerBtn.MouseEnter:Connect(function()
            TweenService:Create(containerBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(39, 42, 49),
            }):Play()
        end)

        containerBtn.MouseLeave:Connect(function()
            TweenService:Create(containerBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(30, 33, 39),
            }):Play()
        end)

        containerBtn.MouseButton1Click:Connect(function()
            if callback then
                callback()
            end
        end)

        return containerBtn, label, iconBadge
    end

    createTabButton("Main", 1)
    createTabButton("Visual", 2)
    createTabButton("Player", 3)
    createTabButton("Settings", 4)

    local modeBtn, modeLabel = createStyledButton("Mode Sprint: " .. sprintConfig.mode, 1, mainContent, function()
        sprintConfig.mode = sprintConfig.mode == "Hold" and "Toggle" or "Hold"
        modeLabel.Text = "Mode Sprint: " .. sprintConfig.mode
    end, "M")

    local animBtn, animLabel = createStyledButton("Animasi: " .. currentProfile:upper(), 2, mainContent, function()
        local profiles = {"adidas", "zombie"}
        local idx = table.find(profiles, currentProfile)
        idx = idx and (idx % #profiles) + 1 or 1
        currentProfile = profiles[idx]
        animLabel.Text = "Animasi: " .. currentProfile:upper()
        applyAnimationProfile(player.Character, currentProfile)
    end, "A")

    local reinjectBtn, reinjectLabel = createStyledButton("Reinject Animasi", 3, mainContent, function()
        local char = player.Character
        if char then
            applyAnimationProfile(char, currentProfile)
            reinjectLabel.Text = "Animasi Ready"
            task.delay(1, function()
                reinjectLabel.Text = "Reinject Animasi"
            end)
        end
    end, "R")

    flyBtnRef, flyBtnLabel = createStyledButton("Fly: OFF", 4, mainContent, function()
        setFlyState(not flyState.enabled)
    end, "F")

    local refreshBtn, refreshLabel = createStyledButton("Refresh Player", 5, mainContent, function()
        refreshPlayersList()
    end, "P")

    local tpToggleBtn, tpToggleLabel = createStyledButton("Teleport Player", 6, mainContent, function()
        togglePlayerPanel()
    end, "T")

    local visualHeader = Instance.new("TextLabel")
    visualHeader.Size = UDim2.new(1, 0, 0, 24)
    visualHeader.BackgroundTransparency = 1
    visualHeader.Text = "Visual Controls"
    visualHeader.TextColor3 = Color3.fromRGB(210, 214, 220)
    visualHeader.Font = Enum.Font.GothamBold
    visualHeader.TextSize = 12
    visualHeader.TextXAlignment = Enum.TextXAlignment.Left
    visualHeader.LayoutOrder = 1
    visualHeader.Parent = visualContent

    local resetFlyBtn = createStyledButton("Reset Fly", 2, visualContent, function()
        resetFlyState()
    end, "F")

    local resetSpeedBtn = createStyledButton("Reset Speed", 3, visualContent, function()
        resetSpeedState()
    end, "S")

    local closeUIBtn = createStyledButton("Close all UI", 4, visualContent, function()
        closeAllInterface()
    end, "C")

    local trollBtn = createStyledButton("Troll Spin", 5, visualContent, function()
        toggleTrollMode()
    end, "T")

    local playerHeader = Instance.new("TextLabel")
    playerHeader.Size = UDim2.new(1, 0, 0, 24)
    playerHeader.BackgroundTransparency = 1
    playerHeader.Text = "Player List"
    playerHeader.TextColor3 = Color3.fromRGB(210, 214, 220)
    playerHeader.Font = Enum.Font.GothamBold
    playerHeader.TextSize = 12
    playerHeader.TextXAlignment = Enum.TextXAlignment.Left
    playerHeader.LayoutOrder = 1
    playerHeader.Parent = playerContent

    local playerFrame = Instance.new("Frame")
    playerFrame.Size = UDim2.new(1, 0, 1, -28)
    playerFrame.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
    playerFrame.BorderSizePixel = 0
    playerFrame.LayoutOrder = 2
    playerFrame.Parent = playerContent

    local playerFrameCorner = Instance.new("UICorner")
    playerFrameCorner.CornerRadius = UDim.new(0, 10)
    playerFrameCorner.Parent = playerFrame

    playerListRef = Instance.new("ScrollingFrame")
    playerListRef.Size = UDim2.new(1, -12, 1, -12)
    playerListRef.Position = UDim2.new(0, 6, 0, 6)
    playerListRef.BackgroundTransparency = 1
    playerListRef.BorderSizePixel = 0
    playerListRef.ScrollBarThickness = 4
    playerListRef.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerListRef.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerListRef.Parent = playerFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = playerListRef

    refreshPlayersList()

    local settingInfo = Instance.new("TextLabel")
    settingInfo.Size = UDim2.new(1, 0, 0, 24)
    settingInfo.BackgroundTransparency = 1
    settingInfo.TextColor3 = Color3.fromRGB(210, 214, 220)
    settingInfo.Text = "Script Settings"
    settingInfo.Font = Enum.Font.GothamBold
    settingInfo.TextSize = 12
    settingInfo.TextXAlignment = Enum.TextXAlignment.Left
    settingInfo.LayoutOrder = 1
    settingInfo.Parent = settingsContent

    local layoutModeBtn = createStyledButton("Layout: Desktop", 2, settingsContent, function()
        mobileUI = not mobileUI
        layoutModeBtn.TextLabel.Text = mobileUI and "Layout: Mobile" or "Layout: Desktop"
        updateDesktopLayout()
        showToast(mobileUI and "Mobile layout enabled" or "Desktop layout enabled")
    end, "L")

    local killBtn = createStyledButton("Kill Script", 3, settingsContent, function()
        if script then
            script:Destroy()
        end
    end, "K")

    local closeSettingsBtn = createStyledButton("Hide UI", 4, settingsContent, function()
        toggleUI()
    end, "X")

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BackgroundColor3 = Color3.fromRGB(67, 71, 81)
    divider.BorderSizePixel = 0
    divider.LayoutOrder = 5
    divider.Parent = settingsContent

    local settingHint = Instance.new("TextLabel")
    settingHint.Size = UDim2.new(1, 0, 0, 54)
    settingHint.BackgroundTransparency = 1
    settingHint.TextColor3 = Color3.fromRGB(168, 173, 184)
    settingHint.Text = "Shift to toggle UI\nF to toggle fly\nTouch mode can be enabled from settings"
    settingHint.Font = Enum.Font.Gotham
    settingHint.TextSize = 11
    settingHint.TextWrapped = true
    settingHint.TextXAlignment = Enum.TextXAlignment.Left
    settingHint.LayoutOrder = 6
    settingHint.Parent = settingsContent

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "KRTToggle"
    toggleBtn.Size = UDim2.new(0, 48, 0, 48)
    toggleBtn.Position = UDim2.new(0, 15, 0.5, -24)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(89, 94, 106)
    toggleBtn.Text = "KRT"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.Parent = screenGui

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(255, 255, 255)
    toggleStroke.Thickness = 1.2
    toggleStroke.Transparency = 0.2
    toggleStroke.Parent = toggleBtn

    makeDraggable(toggleBtn, toggleBtn)
    toggleBtn.MouseButton1Click:Connect(function()
        if mainFrame then
            uiVisible = not uiVisible
            mainFrame.Visible = uiVisible
            if uiVisible then
                updateDesktopLayout()
            end
        end
    end)

    local sprintBtn = Instance.new("TextButton")
    sprintBtn.Name = "KRTSprintTouch"
    sprintBtn.Size = UDim2.new(0, 98, 0, 36)
    sprintBtn.Position = UDim2.new(1, -108, 0.72, 0)
    sprintBtn.BackgroundColor3 = Color3.fromRGB(48, 51, 59)
    sprintBtn.Text = "RUN OFF"
    sprintBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sprintBtn.Font = Enum.Font.GothamBold
    sprintBtn.TextSize = 11
    sprintBtn.Parent = screenGui
    sprintBtnRef = sprintBtn

    local sprintCorner = Instance.new("UICorner")
    sprintCorner.CornerRadius = UDim.new(0, 18)
    sprintCorner.Parent = sprintBtn

    local sprintStroke = Instance.new("UIStroke")
    sprintStroke.Color = Color3.fromRGB(113, 119, 131)
    sprintStroke.Thickness = 1.2
    sprintStroke.Parent = sprintBtn

    makeDraggable(sprintBtn, sprintBtn)
    sprintBtn.MouseButton1Click:Connect(function()
        updateSprint(not sprintConfig.isSprinting)
    end)

    updateFlyButton()
    updateDesktopLayout()
end

local function toggleUI()
    if mainFrame then
        uiVisible = not uiVisible
        mainFrame.Visible = uiVisible
        if uiVisible then
            mainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
        end
    end
end

-- ======================== INPUT HANDLING ========================
UserInput.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

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

    if key == Enum.KeyCode.F and not processed then
        setFlyState(not flyState.enabled)
    end
end)

UserInput.InputEnded:Connect(function(input, processed)
    if processed then
        return
    end

    local key = input.KeyCode
    if (key == Enum.KeyCode.LeftControl or key == Enum.KeyCode.RightControl) and sprintConfig.mode == "Hold" then
        updateSprint(false)
    end
end)

-- ======================== PLAYER UPDATES ========================
Players.PlayerAdded:Connect(function()
    task.defer(refreshPlayersList)
end)

Players.PlayerRemoving:Connect(function()
    task.defer(refreshPlayersList)
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    task.wait(0.5)
    applyAnimationProfile(newChar, currentProfile)
    updateSprint(sprintConfig.isSprinting)
    if flyState.enabled then
        setFlyState(false)
    end
end)

-- ======================== INIT ========================
if player.Character then
    applyAnimationProfile(player.Character, currentProfile)
end

createUI()
print("Kinginul Tools loaded successfully")
