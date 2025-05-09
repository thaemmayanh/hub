repeat task.wait() until game:IsLoaded()

if getgenv()._PiaHubLoaded then return end
getgenv()._PiaHubLoaded = true

-- 💤 Anti-AFK
local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
	vu:CaptureController()
	vu:ClickButton2(Vector2.new(0, 0))
end)

-- 📁 Thiết lập thư mục cài đặt
local folderName = "piahub"
local subFolder = "dungeonheros"
local settingFile = "setting.json"

if not isfolder(folderName) then makefolder(folderName) end
if not isfolder(folderName .. "/" .. subFolder) then makefolder(folderName .. "/" .. subFolder) end

local settingPath = folderName .. "/" .. subFolder .. "/" .. settingFile
local defaultSetting = {
	Height = 50,
	Speed = 50,
	FollowEnabled = false,
	KillAuraEnabled = false,
	GoAgainEnabled = false,
	AutoStartDungeon = false,
	autoReloadOnTeleport = false,
	ReturnEnabled = false,
	SelectedMap = "ForestDungeon",
	SelectedMode = 1,
	AutoJoinEnabled = false,
	}

	-- 📄 Hàm lưu / tải setting
local function SaveSetting(tbl)
	writefile(settingPath, game:GetService("HttpService"):JSONEncode(tbl))
end

local function LoadSetting()
	if not isfile(settingPath) then
		SaveSetting(defaultSetting)
		return defaultSetting
	end
	local success, result = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(settingPath))
	end)
	return success and result or defaultSetting
end

-- 🎮 Dịch vụ và khởi tạo nhân vật
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local mobsFolder = workspace:WaitForChild("Mobs")
local PlayerAttack = ReplicatedStorage:WaitForChild("Systems"):WaitForChild("Combat"):WaitForChild("PlayerAttack")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
	character = char
	hrp = char:WaitForChild("HumanoidRootPart")
end)

-- 🧲 Biến điều khiển
local TweenSettings = LoadSetting()
local followLoop, noclipConnection

-- 🧠 Các hàm chức năng
function GetValidMob()
	if not hrp then return nil end
	local closest, closestDist = nil, math.huge
	for _, mob in pairs(mobsFolder:GetChildren()) do
		if mob:IsA("Model") and not mob:GetAttribute("Owner") then
			local hp = mob:GetAttribute("HP")
			local docile = mob:GetAttribute("Docile")
			local mobHRP = mob:FindFirstChild("HumanoidRootPart")
			if hp and hp > 0 and docile == false and mobHRP and mobHRP:IsDescendantOf(workspace) then
				local dist = (mobHRP.Position - hrp.Position).Magnitude
				if dist < closestDist then
					closest = mob
					closestDist = dist
				end
			end
		end
	end
	return closest
end

function GetMobsInRange()
	local valid = {}
	for _, mob in pairs(mobsFolder:GetChildren()) do
		if mob:IsA("Model") and not mob:GetAttribute("Owner") then
			local hp = mob:GetAttribute("HP")
			local docile = mob:GetAttribute("Docile")
			local mobHRP = mob:FindFirstChild("HumanoidRootPart")
			if hp and hp > 0 and docile == false and mobHRP then
				local dist = (mobHRP.Position - hrp.Position).Magnitude
				if dist <= 300 then
					table.insert(valid, mob)
				end
			end
		end
	end
	return valid
end

function EnableNoClip()
	noclipConnection = RunService.Stepped:Connect(function()
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)
end

function StartFollowOnly()
	EnableNoClip()
	followLoop = true

	task.spawn(function()
		local bp = nil

		while followLoop do
			character = player.Character
			hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				task.wait(0.1)
				continue
			end

			if not bp or bp.Parent ~= hrp then
				if bp then
					bp:Destroy()
				end
				bp = Instance.new("BodyPosition")
				bp.Name = "HoverForce"
				bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
				bp.P = 5000
				bp.D = 1000
				bp.Position = hrp.Position
				bp.Parent = hrp
			end

			local mob = GetValidMob()
			if mob then
				local part = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
				if part and part:IsDescendantOf(workspace) then
					local goal = part.Position + Vector3.new(0, TweenSettings.Height, 0)
					local direction = (goal - hrp.Position).Unit
					local distance = (goal - hrp.Position).Magnitude

					local step = TweenSettings.Speed * 1  -- speed (studs/second) × 0.1s
					if distance < step then
						bp.Position = goal
					else
						bp.Position = hrp.Position + direction * step
					end
				end
			end

			task.wait(0.2)
		end
	end)
end

function StopFollow()
	followLoop = false

	local bp = hrp:FindFirstChild("HoverForce")
	if bp then bp:Destroy() end

	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
end

--//kill aura	
function StartKillAura()
	if killAuraLoop then return end
	killAuraLoop = true

	task.spawn(function()
		while killAuraLoop do
			local mobs = GetMobsInRange()
			if #mobs > 0 then
				PlayerAttack:FireServer(mobs)
			end
			task.wait(0.3)
		end
	end)
end

function StopKillAura()
	killAuraLoop = false
end

--// auto retry
function StartGoAgain()
	if goAgainLoop then return end
	goAgainLoop = true

	task.spawn(function()
		while goAgainLoop do
			local remote = game:GetService("ReplicatedStorage")
				:WaitForChild("Systems")
				:WaitForChild("Dungeons")
				:WaitForChild("SetExitChoice")

			remote:FireServer("GoAgain")
			task.wait(3) -- 3 giây giữa mỗi lần spam
		end
	end)
end

function StopGoAgain()
	goAgainLoop = false
end

--// auto Leave
function StartReturn()
	if ReturnLoop then return end
	ReturnLoop = true

	task.spawn(function()
		while ReturnLoop do
			local remote = game:GetService("ReplicatedStorage")
				:WaitForChild("Systems")
				:WaitForChild("Dungeons")
				:WaitForChild("SetExitChoice")

			remote:FireServer("Return")
			task.wait(3)
		end
	end)
end

function StopReturn()
	ReturnLoop = false
end

--//auto join
function TryAutoJoin()
	if game.PlaceId ~= 94845773826960 then return end

	local args = {
		TweenSettings.SelectedMap or "ForestDungeon",
		TweenSettings.SelectedMode or 1,
		1,
		true
	}

	game:GetService("ReplicatedStorage")
		:WaitForChild("Systems")
		:WaitForChild("Parties")
		:WaitForChild("SetSettings")
		:FireServer(unpack(args))
end

-- 🖼️ Giao diện người dùng
local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/thaem/refs/heads/main/lib"))()

local window = MacLib:Window({
	Title = "Pịa Hub",
	Subtitle = "VÃI-PỊA",
	Size = UDim2.fromOffset(750, 500),
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = true,
	Scale = 0.7
})

-- Nếu MacLib tạo ScreenGui tên "MacLib", bạn có thể rename lại:
pcall(function()
	window.Instance.Name = "PiaHubUI"
end)

local tab = window:TabGroup():Tab({ Name = "main" })
local section = tab:Section({ Side = "Left", Title = "Auto Farm" })

section:Slider({
	Name = "Độ cao",
	Minimum = 1,
	Maximum = 100,
	Default = TweenSettings.Height,
	DisplayMethod = "Value",
	Callback = function(val)
		TweenSettings.Height = val
		SaveSetting(TweenSettings)
	end
})

section:Slider({
	Name = "Tốc độ tween",
	Minimum = 1,
	Maximum = 100,
	Default = TweenSettings.Speed,
	DisplayMethod = "Value",
	Callback = function(val)
		TweenSettings.Speed = val
		SaveSetting(TweenSettings)
	end
})

section:Toggle({
	Name = "Bật tween tới mob gần nhất",
	Default = TweenSettings.FollowEnabled,
	Callback = function(state)
		TweenSettings.FollowEnabled = state
		SaveSetting(TweenSettings)

		if state then
			StartFollowOnly()
		else
			StopFollow()
		end
	end
})

section:Toggle({
	Name = "Kill Aura",
	Default = TweenSettings.KillAuraEnabled,
	Callback = function(state)
		TweenSettings.KillAuraEnabled = state
		SaveSetting(TweenSettings)

		if state then
			StartKillAura()
		else
			StopKillAura()
		end
	end
})

local gameSection = tab:Section({ Side = "Left", Title = "Game Setting" })

gameSection:Toggle({
	Name = "Auto retry",
	Default = TweenSettings.GoAgainEnabled,
	Callback = function(state)
		TweenSettings.GoAgainEnabled = state
		SaveSetting(TweenSettings)

		if state then
			StartGoAgain()
		else
			StopGoAgain()
		end
	end
})

gameSection:Toggle({
	Name = "Auto Leave",
	Default = TweenSettings.ReturnEnabled,
	Callback = function(state)
		TweenSettings.ReturnEnabled = state
		SaveSetting(TweenSettings)

		if state then
			StartReturn()
		else
			StopReturn()
		end
	end
})

gameSection:Toggle({
	Name = "Auto start",
	Default = TweenSettings.AutoStartDungeon,
	Callback = function(state)
		TweenSettings.AutoStartDungeon = state
		SaveSetting(TweenSettings)

		if state then
			local remote = game:GetService("ReplicatedStorage")
				:WaitForChild("Systems")
				:WaitForChild("Dungeons")
				:WaitForChild("TriggerStartDungeon")

			remote:FireServer()
		end
	end
})

gameSection:Toggle({
    Name = "Auto Execute",
    Default = TweenSettings.autoReloadOnTeleport or false,
    Callback = function(val)
        TweenSettings.autoReloadOnTeleport = val
        SaveSetting(TweenSettings)

        if val then
            queue_on_teleport([[
                repeat task.wait() until game:IsLoaded()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/thaemmayanh/hub/refs/heads/main/dungeonshero.lua'))()
            ]])
        end
    end
})

local lobbySection = tab:Section({ Side = "Right", Title = "Lobby" })

local mapOptions = {}

local success, queueRings = pcall(function()
	return workspace:WaitForChild("QueueRings", 1) -- chờ tối đa 3 giây
end)

if success and queueRings then
	for _, model in ipairs(queueRings:GetChildren()) do
		if model:IsA("Model") then
			table.insert(mapOptions, model.Name)
		end
	end
end

-- fallback nếu không có map
if #mapOptions == 0 then
	mapOptions = { TweenSettings.SelectedMap or "ForestDungeon" }
end

lobbySection:Dropdown({
	Name = "Select Map",
	Default = TweenSettings.SelectedMap,
	Options = mapOptions,
	Multi = false,
	Callback = function(val)
		TweenSettings.SelectedMap = val
		SaveSetting(TweenSettings)
	end
})

local modeMap = {
	["Normal"] = 1,
	["Medium"] = 2,
	["Hard"] = 3,
	["Insane"] = 4
}

local modeNames = {}
for k, _ in pairs(modeMap) do
	table.insert(modeNames, k)
end

lobbySection:Dropdown({
	Name = "Select Mode",
	Default = "Normal", -- bạn có thể map lại từ số nếu cần
	Options = modeNames,
	Multi = false,
	Callback = function(val)
		TweenSettings.SelectedMode = modeMap[val]
		SaveSetting(TweenSettings)
	end
})

lobbySection:Toggle({
	Name = "Auto Join",
	Default = TweenSettings.AutoJoinEnabled,
	Callback = function(state)
		TweenSettings.AutoJoinEnabled = state
		SaveSetting(TweenSettings)

		if state then
			TryAutoJoin()
		end
	end
})
