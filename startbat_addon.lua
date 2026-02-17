-- StarBat + FlyPose Addon for GGCMD
-- Execute only after GGCMD has already been executed.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
local ggcmdGui = playerGui and playerGui:FindFirstChild("GGCMD")
local genv = (getgenv and getgenv()) or _G

if not ggcmdGui then
	warn("[StarBat Addon] GGCMD not found. Execute GGCMD first.")
	return
end

if not genv.foundRemote then
	warn("[StarBat Addon] GGCMD remote missing (getgenv().foundRemote). Execute GGCMD first.")
	return
end

local PREFIX = ";"
local TAG = "GGCMD_STARBAT_ADDON"

local state = {
	tools = {},
	effects = {},
	armPoseCon = nil,
	flyFxEnabled = false,
	flyFx = {}
}

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 3
		})
	end)
end

local function sendGGCMDCommand(raw)
	local msg = PREFIX .. raw
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if channel then
			pcall(function()
				channel:SendAsync(msg)
			end)
			return
		end
	end

	local legacy = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	local say = legacy and legacy:FindFirstChild("SayMessageRequest")
	if say then
		pcall(function()
			say:FireServer(msg, "All")
		end)
	end
end

local function trackEffect(inst, life)
	table.insert(state.effects, inst)
	if life and life > 0 then
		Debris:AddItem(inst, life)
	end
	return inst
end

local function clearEffects()
	for _, inst in ipairs(state.effects) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(state.effects)
end

local function clearTools()
	for _, tool in ipairs(state.tools) do
		if tool and tool.Parent then
			tool:Destroy()
		end
	end
	table.clear(state.tools)
end

local function getCharacter()
	local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return char, hum, hrp
end

local function stopFlyPoseFx()
	state.flyFxEnabled = false
	if state.armPoseCon then
		state.armPoseCon:Disconnect()
		state.armPoseCon = nil
	end
	for _, inst in ipairs(state.flyFx) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(state.flyFx)
end

local function startFlyPoseFx()
	stopFlyPoseFx()
	state.flyFxEnabled = true

	local char = localPlayer.Character
	if not char then return end

	local leftArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
	local rightArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local function addArmFx(part)
		if not part then return end
		local a0 = Instance.new("Attachment")
		a0.Name = TAG .. "_ARMATT"
		a0.Parent = part
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = TAG .. "_SMOKE"
		smoke.Texture = "rbxassetid://1185246"
		smoke.Rate = 24
		smoke.Speed = NumberRange.new(0.8, 1.8)
		smoke.Lifetime = NumberRange.new(0.4, 0.8)
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 0)
		})
		smoke.Color = ColorSequence.new(Color3.fromRGB(245, 245, 255))
		smoke.Parent = a0
		local sparkle = Instance.new("Sparkles")
		sparkle.Name = TAG .. "_GLITTER"
		sparkle.SparkleColor = Color3.fromRGB(255, 255, 255)
		sparkle.Parent = part
		table.insert(state.flyFx, a0)
		table.insert(state.flyFx, smoke)
		table.insert(state.flyFx, sparkle)
	end

	addArmFx(leftArm)
	addArmFx(rightArm)

	state.armPoseCon = RunService.RenderStepped:Connect(function()
		if not state.flyFxEnabled then return end
		local c = localPlayer.Character
		if not c then return end
		local l = c:FindFirstChild("LeftUpperArm") or c:FindFirstChild("Left Arm")
		local r = c:FindFirstChild("RightUpperArm") or c:FindFirstChild("Right Arm")
		local root = c:FindFirstChild("HumanoidRootPart")
		if not root then return end
		if l and l:IsA("BasePart") then
			l.CFrame = root.CFrame * CFrame.new(-0.8, 0.1, 0.8) * CFrame.Angles(math.rad(-20), math.rad(10), math.rad(90))
		end
		if r and r:IsA("BasePart") then
			r.CFrame = root.CFrame * CFrame.new(0.8, 0.1, 0.8) * CFrame.Angles(math.rad(-20), math.rad(-10), math.rad(-90))
		end
	end)

	task.delay(4.5, function()
		stopFlyPoseFx()
	end)
end

local function nearestTargetInFront(maxDistance)
	local char, _, hrp = getCharacter()
	if not char or not hrp then return nil end

	local look = hrp.CFrame.LookVector
	local best, bestScore = nil, -1
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == localPlayer then continue end
		local tChar = plr.Character
		local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
		if not tRoot then continue end
		local delta = tRoot.Position - hrp.Position
		local dist = delta.Magnitude
		if dist > maxDistance then continue end
		local dir = delta.Unit
		local dot = look:Dot(dir)
		if dot < 0.2 then continue end
		local score = dot * (1 - (dist / maxDistance))
		if score > bestScore then
			best = plr
			bestScore = score
		end
	end
	return best
end

local function spawnFlashbang(position)
	local flash = trackEffect(Instance.new("Part"), 0.5)
	flash.Name = TAG .. "_FLASH"
	flash.Anchored = true
	flash.CanCollide = false
	flash.Transparency = 0.15
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 255, 255)
	flash.Size = Vector3.new(4, 4, 4)
	flash.Shape = Enum.PartType.Ball
	flash.CFrame = CFrame.new(position)
	flash.Parent = workspace

	local light = Instance.new("PointLight")
	light.Brightness = 15
	light.Range = 22
	light.Color = Color3.fromRGB(255, 255, 255)
	light.Parent = flash

	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://231917758"
	snd.Volume = 1
	snd.PlayOnRemove = true
	snd.Parent = flash
	snd:Destroy()
end

local function flyToolActivate()
	sendGGCMDCommand("fly")
	startFlyPoseFx()
	notify("StarFly", "Fly ON + back-arm FX", 2)
end

local function batToolActivate()
	local target = nearestTargetInFront(12)
	if not target then
		notify("StarBat", "No target in front", 2)
		return
	end

	local tChar = target.Character
	local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
	if not tRoot then return end

	local myChar, _, myRoot = getCharacter()
	if not myChar or not myRoot then return end

	local dir = (tRoot.Position - myRoot.Position).Unit
	tRoot.AssemblyLinearVelocity = dir * 160 + Vector3.new(0, 70, 0)
	spawnFlashbang(tRoot.Position)

	-- Also trigger GGCMD side attack flow for stronger FE behavior when possible.
	sendGGCMDCommand("fling " .. target.Name)
	notify("StarBat", "Slammed " .. target.Name, 2)
end

local function makeTool(name, color, meshId, textureId, onActivated)
	local backpack = localPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "GGCMD Addon"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 3)
	handle.CanCollide = false
	handle.Material = Enum.Material.Neon
	handle.Color = color
	handle.Parent = tool

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = meshId
	mesh.TextureId = textureId
	mesh.Scale = Vector3.new(1.2, 1.2, 1.2)
	mesh.Parent = handle

	if name == "Star Bat" then
		local att = Instance.new("Attachment")
		att.Parent = handle
		local stars = Instance.new("ParticleEmitter")
		stars.Texture = "rbxassetid://1323306"
		stars.Rate = 18
		stars.Speed = NumberRange.new(0, 0.7)
		stars.Lifetime = NumberRange.new(0.8, 1.4)
		stars.Rotation = NumberRange.new(0, 360)
		stars.RotSpeed = NumberRange.new(30, 80)
		stars.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0)
		})
		stars.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 255, 255))
		stars.Parent = att
		table.insert(state.effects, att)
		table.insert(state.effects, stars)
	end

	tool.Activated:Connect(onActivated)
	tool.Parent = backpack
	table.insert(state.tools, tool)
end

local function enableAddon()
	clearTools()
	clearEffects()
	stopFlyPoseFx()

	-- tool 1: fly trigger with arm pose/smoke/glitter
	makeTool(
		"Star Fly",
		Color3.fromRGB(240, 240, 255),
		"rbxassetid://9756362",
		"rbxassetid://9756362",
		flyToolActivate
	)

	-- tool 2: 2h-like baseball bat style + stars + knockback/flashbang
	makeTool(
		"Star Bat",
		Color3.fromRGB(255, 220, 90),
		"rbxassetid://55386973",
		"rbxassetid://55386973",
		batToolActivate
	)

	notify("StarBat Addon", "Tools added: Star Fly + Star Bat", 4)
end

enableAddon()

localPlayer.Chatted:Connect(function(msg)
	local m = msg:lower()
	if m == PREFIX .. "staraddon" then
		enableAddon()
	elseif m == PREFIX .. "unstaraddon" then
		clearTools()
		clearEffects()
		stopFlyPoseFx()
		notify("StarBat Addon", "Disabled", 2)
	end
end)
