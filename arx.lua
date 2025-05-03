repeat task.wait() until game:IsLoaded()

-- 🧼 Xoá GUI cũ nếu tồn tại
local CoreGui = game:GetService("CoreGui")

for _, gui in ipairs(CoreGui:GetChildren()) do
    if gui:IsA("ScreenGui") and (gui.Name == "MacLib" or gui.Name == "ScreenGui") then
        gui:Destroy()
    end
end

local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/thaem/refs/heads/main/lib"))()

--// Setup Settings
local folderName = "animerangerx"
local fileName = "settings.json"

if not isfolder(folderName) then
    makefolder(folderName)
end

local defaultSettings = {
    autoPlay = false,
    autoUpgrade = false,
    autoStart = false,
    autoNext = false,
    autoRetry = false,
    autoLeave = false,
    webhookURL = "",
    webhookEnabled = false,
    playAfterUpgrade = false,
    slots = {
        place = {true, true, true, true, true, true},
        upgrade = {0, 0, 0, 0, 0, 0}
    }
}

local function loadSettings()
    if isfile(folderName.."/"..fileName) then
        return game:GetService("HttpService"):JSONDecode(readfile(folderName.."/"..fileName))
    else
        writefile(folderName.."/"..fileName, game:GetService("HttpService"):JSONEncode(defaultSettings))
        return defaultSettings
    end
end

local function saveSettings(tbl)
    writefile(folderName.."/"..fileName, game:GetService("HttpService"):JSONEncode(tbl))
end

local settings = loadSettings()

--realclcick
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- 🖱 Click thật giữa màn hình
local function clickScreen()
	local viewport = workspace.CurrentCamera.ViewportSize
	local x = viewport.X / 2
	local y = viewport.Y / 2
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

-- 🕹 Native click nút (bật viền + Enter)
local function nativeClick(button)
	if not button or not button:IsA("GuiButton") then return end
	if not button.Visible or not button.Active then return end
	if button.Name == "Retry" and button.Text:match("0/") then return end

	GuiService.SelectedObject = button

	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

	task.wait(0.3)
	GuiService.SelectedObject = nil
end

local function handleGameEndedUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local max = LocalPlayer:FindFirstChild("Summon_Maximum") or LocalPlayer:WaitForChild("Summon_Maximum", 5)

	-- 🖱 Spam click khi còn Summon_Maximum
	while LocalPlayer:FindFirstChild("Summon_Maximum") do
		clickScreen()
		task.wait(0.25)
	end

	task.wait(0.5)

	-- 🧩 Tìm phần tử UI chứa nút
	local success, buttonContainer = pcall(function()
		return playerGui:WaitForChild("RewardsUI", 5):WaitForChild("Main", 5)
			:WaitForChild("LeftSide", 5):WaitForChild("Button", 5)
	end)

	if not success or not buttonContainer then return end

	-- 🔁 Thực hiện click các nút phù hợp
	repeat
		if settings.autoRetry then
			nativeClick(buttonContainer:FindFirstChild("Retry"))
		end
		if settings.autoNext then
			nativeClick(buttonContainer:FindFirstChild("Next"))
		end
		if settings.autoLeave then
			nativeClick(buttonContainer:FindFirstChild("Leave"))
		end
		task.wait(0.5)
	until not playerGui:FindFirstChild("GameEndedAnimationUI")
end

task.spawn(function()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("GameEndedAnimationUI")
	if existing then
		task.wait(1)
		handleGameEndedUI()
	end

	playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and child.Name == "GameEndedAnimationUI" then
			task.wait(1)
			handleGameEndedUI()
		end
	end)
end)

task.spawn(function()
	while true do
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local endUI = playerGui and playerGui:FindFirstChild("GameEndedAnimationUI")
		local ready = endUI and not LocalPlayer:FindFirstChild("Summon_Maximum")

		if ready and (settings.autoRetry or settings.autoNext or settings.autoLeave) then
			handleGameEndedUI()
			repeat task.wait(0.5) until not playerGui:FindFirstChild("GameEndedAnimationUI")
		end

		task.wait(1)
	end
end)

task.spawn(function()
    while true do
        if settings.autoStart then
            game.ReplicatedStorage.Remote.Server.OnGame.Voting.VotePlaying:FireServer()
        end
        task.wait(3)
    end
end)

--// Logic: Get and Deploy Units
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local unitNames = {}

local function getEquippedUnits()
    unitNames = {}
    for i = 1, 6 do
        local slotPath = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
        if slotPath and slotPath:FindFirstChild("Frame") and slotPath.Frame:FindFirstChild("UnitFrame") then
            local info = slotPath.Frame.UnitFrame:FindFirstChild("Info")
            if info and info:FindFirstChild("Folder") and info.Folder:IsA("ObjectValue") and info.Folder.Value then
                table.insert(unitNames, info.Folder.Value.Name)
            end
        end
    end
end

local function deployUnits()
    local player = game.Players.LocalPlayer
    local yen = player:FindFirstChild("Yen") and player.Yen.Value or 0

    for i = 1, 6 do
        if settings.slots.place[i] then
            local slot = player.PlayerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
            if slot then
                local frame = slot:FindFirstChild("Frame")
                local unitFrame = frame and frame:FindFirstChild("UnitFrame")
                local info = unitFrame and unitFrame:FindFirstChild("Info")
                local folderObj = info and info:FindFirstChild("Folder")
                local costLabel = info and info:FindFirstChild("Cost")

                local isCooledDown = frame and not frame:FindFirstChild("CD_FRAME")

                if folderObj and folderObj:IsA("ObjectValue") and folderObj.Value and costLabel and isCooledDown then
                    -- 🧠 Tách số từ text: "60 ¥" => 60
                    local costText = costLabel.Text
                    local costNumber = tonumber(costText:match("%d+"))

                    if costNumber and yen >= costNumber then
                        game.ReplicatedStorage.Remote.Server.Units.Deployment:FireServer(folderObj.Value)
                    end
                end
            end
        end
    end
end

--upgrade
local upgradeState = {0, 0, 0, 0, 0, 0}

local function getYen()
    local success, yen = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.HUD.InGame.Main.Stats.Yen.YenValue.Value
    end)
    return success and yen or 0
end

function tryUpgradeSlot(i)
	local player = game.Players.LocalPlayer
	local unitsFolder = player:WaitForChild("UnitsFolder")
	local upgradeInput = settings.slots.upgrade
	local targetUpgrade = upgradeInput[i]

	if not settings.slots.place[i] or targetUpgrade <= 0 then return false end
	if upgradeState[i] >= targetUpgrade then return false end

	local slot = player.PlayerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
	if not slot then return false end

	local folderObj = slot:FindFirstChild("Frame") and slot.Frame:FindFirstChild("UnitFrame") and
		slot.Frame.UnitFrame:FindFirstChild("Info") and slot.Frame.UnitFrame.Info:FindFirstChild("Folder")

	if not folderObj or not folderObj:IsA("ObjectValue") or not folderObj.Value then return false end

	local unitName = folderObj.Value.Name
	local unitObject = unitsFolder:FindFirstChild(unitName)
	if not unitObject then return false end

	local cost = 0
	local ok = pcall(function()
		cost = unitObject:WaitForChild("Upgrade_Folder"):WaitForChild("Upgrade_Cost").Value
	end)
	if not ok or cost <= 0 then return false end

	local yen = getYen()
	if yen < cost then return false end

	local success = pcall(function()
		game.ReplicatedStorage.Remote.Server.Units.Upgrade:FireServer(unitObject)
	end)

	if success then
		upgradeState[i] += 1
		return true
	end

	return false
end

local function waitForGameEndToDisappear()
	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

	if not playerGui:FindFirstChild("GameEndedAnimationUI") then
		return false
	end

	for i = 1, 6 do
		upgradeState[i] = 0
	end
	settings.autoUpgrade = false
	saveSettings(settings)

	while playerGui:FindFirstChild("GameEndedAnimationUI") do
		task.wait(0.5)
	end

	settings.autoUpgrade = true
	saveSettings(settings)

	return true
end

local isUpgrading = false

function upgradeUnits()
	if isUpgrading then return end
	isUpgrading = true

	local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local preGameUI = playerGui:FindFirstChild("HUD")
		and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")

	if preGameUI then
		isUpgrading = false
		return
	end

	-- 🧠 Reset nếu vừa hết ván
	local paused = waitForGameEndToDisappear()
	if paused then
		-- ✅ Đợi 2s rồi tiếp tục chạy upgrade lại
		task.wait(1)
	end

	while true do
		local upgraded = false

		for i = 1, 6 do
			local targetUpgrade = settings.slots.upgrade[i]
			if settings.slots.place[i] and upgradeState[i] < targetUpgrade then
				local didUpgrade = tryUpgradeSlot(i)
				if didUpgrade then
					upgraded = true
					task.wait(0.5)
					break
				end
			end
		end

		if not upgraded then break end
	end

	isUpgrading = false
end

--send 
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Hàm thu thập dữ liệu từ UI
local function collectData()
    local data = {}

    -- ⚙ Level & XP
    local expBar = LocalPlayer.PlayerGui:WaitForChild("HUD"):FindFirstChild("ExpBar")
    if expBar and expBar:FindFirstChild("Numbers") then
        local raw = expBar.Numbers.Text
        local lvl = raw:match("Level%s*(%d+)") or "0"
        local xp  = raw:match("%[(.-)%]</font>") or "0/0"
        data.levelText = "Level " .. lvl .. " [" .. xp .. "]"
    else
        data.levelText = "Level 0 [0/0]"
    end

    -- 💰 Gems / Gold / Egg
    local menu = LocalPlayer.PlayerGui:FindFirstChild("HUD")
                 and LocalPlayer.PlayerGui.HUD:FindFirstChild("MenuFrame")
                 and LocalPlayer.PlayerGui.HUD.MenuFrame:FindFirstChild("LeftSide")
                 and LocalPlayer.PlayerGui.HUD.MenuFrame.LeftSide:FindFirstChild("Frame")
    data.gems = (menu and menu:FindFirstChild("Gems")
                 and menu.Gems:FindFirstChildWhichIsA("TextLabel").Text) or "0"
    data.gold = (menu and menu:FindFirstChild("Gold")
                 and menu.Gold:FindFirstChildWhichIsA("TextLabel").Text) or "0"
    data.egg  = (menu and menu:FindFirstChild("Egg")
                 and menu.Egg:FindFirstChildWhichIsA("TextLabel").Text) or "0"

    -- 🎯 Match Info
    data.matchInfo = {}
    local leftSide = LocalPlayer.PlayerGui:FindFirstChild("RewardsUI")
                   and LocalPlayer.PlayerGui.RewardsUI:FindFirstChild("Main")
                   and LocalPlayer.PlayerGui.RewardsUI.Main:FindFirstChild("LeftSide")
    if leftSide then
        for _, key in ipairs({"GameStatus","Chapter","Difficulty","Mode","World","TotalTime"}) do
            local lbl = leftSide:FindFirstChild(key)
            data.matchInfo[key] = (lbl and lbl:IsA("TextLabel") and lbl.Text) or ""
        end
    end

    -- 🎁 Rewards list
    data.rewardsList = {}
    local rewardsRoot = LocalPlayer:FindFirstChild("RewardsShow")
    if rewardsRoot then
        for _, folder in ipairs(rewardsRoot:GetChildren()) do
            if folder:IsA("Folder") then
                local amt = (folder:FindFirstChild("Amount") and folder.Amount.Value) or 0
                table.insert(data.rewardsList, "+" .. amt .. " " .. folder.Name)
            end
        end
    end

    return data
end

-- Hàm gửi webhook lên Discord
local function sendWebhook()
    local d = collectData()

    -- Chọn màu theo GameStatus
    local status = (d.matchInfo.GameStatus or ""):lower()
    local color = 0xffff00
    if status:find("won") then
        color = 0x00ff00
    elseif status:find("defect") then
        color = 0xff0000
    end

    -- Chuẩn bị fields
    local fields = {
        {
            name   = "Stats",
            value  = string.format("%s\nGems: %s\nGold: %s\nEgg: %s",
                       d.levelText, d.gems, d.gold, d.egg),
            inline = false
        },
        {
            name   = "Rewards",
            value  = #d.rewardsList > 0 and table.concat(d.rewardsList, "\n") or "Không có",
            inline = true
        },
        {
            name   = "Match Info",
            value  = table.concat({
                       d.matchInfo.GameStatus,
                       d.matchInfo.Chapter,
                       d.matchInfo.Difficulty,
                       d.matchInfo.Mode,
                       d.matchInfo.World,
                       d.matchInfo.TotalTime
                   }, "\n"),
            inline = false
        },
    }

    -- Payload JSON
    local payload = {
        embeds = {{
            title     = "Anime Rangers X",
            color     = color,
            fields    = fields,
            thumbnail = { url = "https://i.imgur.com/CK7zYZy.jpeg" },
            footer    = { text = "Sent at " .. os.date("%Y-%m-%d %H:%M:%S") },
        }}
    }

    -- Gửi request
    local success, err = pcall(function()
        local req = (syn and syn.request)
                 or (http and http.request)
                 or http_request
                 or request
        if not req then error("Không có hàm HTTP request") end
        req({
            Url     = settings.webhookURL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(payload),
        })
    end)

    if not success then
        warn("❌ Gửi webhook thất bại:", err)
    end
end

-- Luôn lắng nghe, mỗi lần GameEndedAnimationUI thêm vào thì chờ 2s và gửi
LocalPlayer.PlayerGui.ChildAdded:Connect(function(gui)
    if gui.Name == "GameEndedAnimationUI" then
        task.wait(2)  -- đợi 2 giây để UI cập nhật xong
        sendWebhook()
    end
end)

--// Create Window
local Window = MacLib:Window({
    Title = "Pịa Hub",
    Subtitle = "Vãi Pịa",
    Size = UDim2.fromOffset(650, 400),
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()
local MainTab = TabGroup:Tab({ Name = "Main" })
local AutoPlayTab = TabGroup:Tab({ Name = "Auto Play" })
local WebhookTab = TabGroup:Tab({ Name = "Webhook" })
--main
local controlSection = MainTab:Section({ Side = "Left", Title = "Auto Options" })

controlSection:Toggle({
    Name = "Auto Start",
    Default = settings.autoStart,
    Callback = function(val)
        settings.autoStart = val
        saveSettings(settings)
    end
})

controlSection:Toggle({
    Name = "Auto Next",
    Default = settings.autoNext,
    Callback = function(val)
        settings.autoNext = val
        saveSettings(settings)
    end
})

controlSection:Toggle({
    Name = "Auto Retry",
    Default = settings.autoRetry,
    Callback = function(val)
        settings.autoRetry = val
        saveSettings(settings)
    end
})

controlSection:Toggle({
    Name = "Auto Leave",
    Default = settings.autoLeave,
    Callback = function(val)
        settings.autoLeave = val
        saveSettings(settings)
    end
})

--// Left Side: Auto Toggles
local leftSection = AutoPlayTab:Section({ Side = "Left", Title = "Auto Options" })

leftSection:Toggle({
    Name = "Auto Play",
    Default = settings.autoPlay,
    Callback = function(val)
        settings.autoPlay = val
        saveSettings(settings)

        if val then
            getEquippedUnits()
            task.spawn(function()
                local playerGui = LocalPlayer:WaitForChild("PlayerGui")

                while settings.autoPlay do
                    local isPreGame = playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")
                    local isEndGame = playerGui:FindFirstChild("GameEndedAnimationUI")

                    -- Nếu đang ở màn chọn tướng hoặc vừa kết thúc game thì tạm dừng auto play
                    if isPreGame or isEndGame then
                        repeat
                            task.wait(0.5)
                            isPreGame = playerGui:FindFirstChild("HUD") and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")
                            isEndGame = playerGui:FindFirstChild("GameEndedAnimationUI")
                        until not isPreGame and not isEndGame

                        -- Đợi 1.5s để game ổn định
                        task.wait(1.5)
                    end

                    -- Nếu bật Play After Upgrade → đợi upgrade xong
                    if settings.playAfterUpgrade and settings.autoUpgrade then
                        while isUpgrading do
                            task.wait(0.5)
                        end
                    end

                    deployUnits()
                    task.wait(1)
                end
            end)
        end
    end
})

leftSection:Toggle({
    Name = "Auto Upgrade",
    Default = settings.autoUpgrade,
    Callback = function(val)
        settings.autoUpgrade = val
        saveSettings(settings)

        if val then
            task.spawn(function()
                while settings.autoUpgrade do
                    upgradeUnits()
                    task.wait(1) -- delay nhẹ giữa mỗi vòng
                end
            end)
        end
    end
})

leftSection:Toggle({
    Name = "Play After Upgrade",
    Default = settings.playAfterUpgrade,
    Callback = function(val)
        settings.playAfterUpgrade = val
        saveSettings(settings)
    end
})

--// Right Side: Place Slot Toggles
local rightSection = AutoPlayTab:Section({ Side = "Right", Title = "Place Slot" })

for i = 1, 6 do
    rightSection:Toggle({
        Name = "Slot " .. i,
        Default = settings.slots.place[i],
        Callback = function(val)
            settings.slots.place[i] = val
            saveSettings(settings)
        end
    })
end

--// Bottom Side: Upgrade Slot Inputs
local upgradeSection = AutoPlayTab:Section({ Side = "Right", Title = "Upgrade Slot" })

for i = 1, 6 do
    upgradeSection:Input({
        Name = "Slot " .. i,
        Placeholder = "0",
        AcceptedCharacters = "Numeric",
        Default = tostring(settings.slots.upgrade[i] or 0),
        Callback = function(value)
            settings.slots.upgrade[i] = tonumber(value) or 0
            saveSettings(settings)
        end
    })
end

local webhookSection = WebhookTab:Section({ Side = "Left", Title = "Webhook Settings" })

webhookSection:Input({
    Name = "Webhook Link",
    Placeholder = "https://discord.com/api/webhooks/...",
    Default = settings.webhookURL or "",
    Callback = function(value)
        settings.webhookURL = value
        saveSettings(settings)
    end
})

webhookSection:Toggle({
    Name = "Result Webhook",
    Default = settings.webhookEnabled,
    Callback = function(val)
        settings.webhookEnabled = val
        saveSettings(settings)
    end
})

webhookSection:Button({
    Name = "Test Webhook",
    Callback = function()
        sendRewardWebhook()
    end
})
