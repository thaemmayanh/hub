repeat task.wait() until game:IsLoaded()

-- 🧼 Xoá GUI cũ nếu tồn tại
if getgenv()._PiaHubarxLoaded then return end
getgenv()._PiaHubarxLoaded = true

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new(0, 0))
end)

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
    selectedActs = {},
    autoClaimQuest = false,
    autoEvolveRare = false,
    slots = {
        place = {true, true, true, true, true, true},
        upgrade = {0, 0, 0, 0, 0, 0}
    },
        selectPotential = {},
    selectStats     = {},
    selectUnit      = "",
    startRoll       = false,
    autoReloadOnTeleport = false,
    autoJoinChallenge = false,
    deleteMap = false,
	autoBuLiem = false,
    autoRejoin = false,
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
    local hasFired = false

    while true do
        if settings.autoStart and not workspace:FindFirstChild("Lobby") and not hasFired then
            task.wait(2) -- đợi 2s sau khi vào trận
            game.ReplicatedStorage.Remote.Server.OnGame.Voting.VotePlaying:FireServer()
            hasFired = true
        elseif workspace:FindFirstChild("Lobby") then
            -- reset lại nếu quay về lobby (sẵn sàng cho trận sau)
            hasFired = false
        end

        task.wait(1)
    end
end)

-- ✅ Act cố định (Map_Stage → Tên hiển thị)
local ActMapping = {
    OnePiece_RangerStage1 = "Voocha Village Act 1",
    OnePiece_RangerStage2 = "Voocha Village Act 2",
    OnePiece_RangerStage3 = "Voocha Village Act 3",

    Namek_RangerStage1 = "Green Planet Act 1",
    Namek_RangerStage2 = "Green Planet Act 2",
    Namek_RangerStage3 = "Green Planet Act 3",

    DemonSlayer_RangerStage1 = "Demon Forest Act 1",
    DemonSlayer_RangerStage2 = "Demon Forest Act 2",
    DemonSlayer_RangerStage3 = "Demon Forest Act 3",

    Naruto_RangerStage1 = "Leaf Village Act 1",
    Naruto_RangerStage2 = "Leaf Village Act 2",
    Naruto_RangerStage3 = "Leaf Village Act 3",

    OPM_RangerStage1 = "Z City Act 1",
    OPM_RangerStage2 = "Z City Act 2",
    OPM_RangerStage3 = "Z City Act 3",

    TokyoGhoul_RangerStage1 = "Goul Act 1",
    TokyoGhoul_RangerStage2 = "Goul Act 2",
    TokyoGhoul_RangerStage3 = "Goul Act 3",
    TokyoGhoul_RangerStage4 = "Goul Act 4",	
    TokyoGhoul_RangerStage5 = "Goul Act 5",
}

local function getActKeyFromLabel(label, mapKey)
    for key, val in pairs(ActMapping) do
        if val == label and key:find(mapKey) then
            return key
        end
    end
    return nil
end

function runAutoRanger()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local PlayRoomEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")

    task.spawn(function()
        while settings.autoRanger do
            if not workspace:FindFirstChild("Lobby") then
                task.wait(1)
                continue
            end

            for _, actLabel in ipairs(settings.selectedActs or {}) do
                -- Lấy actKey từ label
                local actKey = nil
                for key, label in pairs(ActMapping) do
                    if label == actLabel then
                        actKey = key
                        break
                    end
                end

                if actKey then
                    -- Tách mapKey từ actKey
                    local mapKey = actKey:match("^(.-)_")
                    if mapKey then
                        PlayRoomEvent:FireServer(unpack({ "Create" }))
                        PlayRoomEvent:FireServer(unpack({ "Change-Mode", { Mode = "Ranger Stage" } }))
                        PlayRoomEvent:FireServer(unpack({ "Change-World", { World = mapKey } }))
                        PlayRoomEvent:FireServer(unpack({ "Change-Chapter", { Chapter = actKey } }))
                        PlayRoomEvent:FireServer(unpack({ "Submit" }))
                        PlayRoomEvent:FireServer(unpack({ "Start" }))

                        local hasSystemMessage = PlayerGui:FindFirstChild("SystemMessage")
                        if hasSystemMessage and hasSystemMessage.Enabled then
                            return
                        end

                        task.wait(1)
                    end
                end
            end

            task.wait(0.5)
        end
    end)
end

--// auto rejoin
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

local PlayRoomEvent = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Server"):WaitForChild("PlayRoom"):WaitForChild("Event")

local MapLabelToName = {
    ["Voocha Village"] = "OnePiece",
    ["Green Planet"] = "Namek",
    ["Demon Forest"] = "DemonSlayer",
    ["Leaf Village"] = "Naruto",
    ["Z City"] = "OPM",
    ["Ghoul City"] = "TokyoGhoul",
}

-- Hàm parse map và chapter từ GUI text
local function parseMapChapterFromGui(guiText)
    local mapLabel, chapterLabel = guiText:match("^%s*(.-)%s*%-%s*(Chapter%s*%d+)%s*$")
    if not mapLabel or not chapterLabel then
        return nil, nil
    end

    local mapKey = MapLabelToName[mapLabel]
    if not mapKey then
        return nil, nil
    end

    local chapterNum = chapterLabel:match("Chapter%s*(%d+)")
    if not chapterNum then
        return nil, nil
    end

    local chapterKey = mapKey .. "_Chapter" .. chapterNum

    return mapKey, chapterKey
end

-- Hàm tạo phòng tự động theo GUI text
local function autoCreateRoomFromGui()
    if workspace:FindFirstChild("Lobby") then
        return  -- Đang trong lobby, không chạy
    end

    local guiLabel = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD"):WaitForChild("InGame"):WaitForChild("Main")
                    :WaitForChild("GameInfo"):WaitForChild("Stage"):WaitForChild("Label")

    local guiText = guiLabel.Text

    local mapKey, chapterKey = parseMapChapterFromGui(guiText)
    if not mapKey or not chapterKey then return end

    PlayRoomEvent:FireServer("Create")
    task.wait(0.2)

    PlayRoomEvent:FireServer("Change-World", { World = mapKey })
    task.wait(0.2)

    PlayRoomEvent:FireServer("Change-Chapter", { Chapter = chapterKey })
    task.wait(0.2)

    PlayRoomEvent:FireServer("Submit")
    task.wait(0.2)

    PlayRoomEvent:FireServer("Start")
end

-- Hàm lấy uptime server (giây)
local serverStartTime = os.time()

local function getServerUptime()
    return os.time() - serverStartTime
end

-- Hàm check FPS trung bình trong 1 giây
local function checkFPS(durationSeconds)
    local frameCount = 0
    local startTime = tick()

    local conn
    local fps = 0

    conn = RunService.Heartbeat:Connect(function()
        frameCount = frameCount + 1
    end)

    task.wait(durationSeconds)

    conn:Disconnect()

    local elapsed = tick() - startTime
    if elapsed > 0 then
        fps = frameCount / elapsed
    end

    return fps
end

-- Vòng lặp kiểm tra FPS và rejoin nếu cần
local function fpsMonitorLoop()
    while settings.autoRejoin do
        -- Nếu đang trong Lobby thì không làm gì, đợi lobby biến mất
        if workspace:FindFirstChild("Lobby") then
            task.wait(5)
        else
            local uptime = getServerUptime()
            if uptime >= 8000 then  -- 3 tiếng = 10800 giây
                local fps = checkFPS(1)
                if fps <= 10 then
                    pcall(autoCreateRoomFromGui)
                    task.wait(15)
                else
                    task.wait(10)
                end
            else
                task.wait(30)
            end
        end
    end
end

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

	local slot = player.PlayerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
	if not slot then return false end

	local folderObj = slot:FindFirstChild("Frame") and slot.Frame:FindFirstChild("UnitFrame") and
		slot.Frame.UnitFrame:FindFirstChild("Info") and slot.Frame.UnitFrame.Info:FindFirstChild("Folder")

	if not folderObj or not folderObj:IsA("ObjectValue") or not folderObj.Value then return false end

	local unitName = folderObj.Value.Name
	local unitObject = unitsFolder:FindFirstChild(unitName)
	if not unitObject then return false end

	local upgradeFolder = unitObject:FindFirstChild("Upgrade_Folder")
	if not upgradeFolder then return false end

	local level = upgradeFolder:FindFirstChild("Level")
	local cost = upgradeFolder:FindFirstChild("Upgrade_Cost")
	if not level or not cost then return false end

	local currentLevel = level.Value
	if currentLevel >= targetUpgrade then return false end

	local yen = getYen()
	if yen < cost.Value then return false end

	local success = pcall(function()
		game.ReplicatedStorage.Remote.Server.Units.Upgrade:FireServer(unitObject)
	end)

	return success
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

	local player = game.Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local unitsFolder = player:WaitForChild("UnitsFolder")

	-- Kiểm tra xem có đang ở màn chọn tướng trước trận không
	local preGameUI = playerGui:FindFirstChild("HUD")
		and playerGui.HUD:FindFirstChild("UnitSelectBeforeGameRunning_UI")

	if preGameUI then
		isUpgrading = false
		return
	end

	local function waitForGameEndToDisappear()
		if not playerGui:FindFirstChild("GameEndedAnimationUI") then return false end

		settings.autoUpgrade = false
		saveSettings(settings)

		while playerGui:FindFirstChild("GameEndedAnimationUI") do
			task.wait(0.5)
		end

		settings.autoUpgrade = true
		saveSettings(settings)
		return true
	end

	local paused = waitForGameEndToDisappear()
	if paused then task.wait(1) end

	while true do
		local anyNeedsUpgrade = false

		for i = 1, 6 do
			if settings.slots.place[i] then
				local slot = playerGui:WaitForChild("UnitsLoadout"):WaitForChild("Main"):FindFirstChild("UnitLoadout"..i)
				if slot then
					local folderObj = slot:FindFirstChild("Frame") and slot.Frame:FindFirstChild("UnitFrame") and
						slot.Frame.UnitFrame:FindFirstChild("Info") and slot.Frame.UnitFrame.Info:FindFirstChild("Folder")

					if folderObj and folderObj:IsA("ObjectValue") and folderObj.Value then
						local unitName = folderObj.Value.Name
						local unitObject = unitsFolder:FindFirstChild(unitName)

						if unitObject then
							local level = unitObject:WaitForChild("Upgrade_Folder"):WaitForChild("Level").Value
							local targetUpgrade = settings.slots.upgrade[i]

							if level < targetUpgrade then
								anyNeedsUpgrade = true
								local didUpgrade = tryUpgradeSlot(i)
								if didUpgrade then
									task.wait(0.5)
                                    break 
								end
							end
						end
					end
				end
			end
		end

		-- Nếu tất cả đều đạt upgrade yêu cầu thì thoát vòng lặp
		if not anyNeedsUpgrade then break end
        task.wait(0.3)
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

    -- 🎁 Rewards list with total (corrected for Player_Data[LocalPlayer.Name].Items)
    data.rewardsList = {}
    local rewardsRoot = LocalPlayer:FindFirstChild("RewardsShow")
    local playerData = game:GetService("ReplicatedStorage"):FindFirstChild("Player_Data")
    local itemsFolder = playerData and playerData:FindFirstChild(LocalPlayer.Name)
                        and playerData[LocalPlayer.Name]:FindFirstChild("Items")

    if rewardsRoot and itemsFolder then
        for _, folder in ipairs(rewardsRoot:GetChildren()) do
            if folder:IsA("Folder") then
                local name = folder.Name
                local amt = (folder:FindFirstChild("Amount") and folder.Amount.Value) or 0

                local itemData = itemsFolder:FindFirstChild(name)
                local total = (itemData and itemData:FindFirstChild("Amount") and itemData.Amount.Value) or 0

                table.insert(data.rewardsList, "+" .. amt .. " " .. name .. " [total: " .. total .. "]")
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
            title     = "Anime Rangers X - Pịa Hub",
            description = "https://discord.gg/QAmCkmBpN2",
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

--//auto tier
local TierUnitNames = {
    "Naruto",
    "Naruto:Shiny",
    "Zoro",
    "Zoro:Shiny",
    "Chaozi:Shiny",
    "Chaozi",
    "Goku",
    "Goku:Shiny",
    "Krillin",
    "Luffy",
    "Nezuko",
    "Sanji",
    "Usopp",
    "Yamcha",
    "Krillin:Shiny",
    "Luffy:Shiny",
    "Nezuko:Shiny",
    "Sanji:Shiny",
    "Usopp:Shiny",
    "Yamcha:Shiny",
}

local function evolveRareUnits()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local collection = ReplicatedStorage:FindFirstChild("Player_Data")
        and ReplicatedStorage.Player_Data:FindFirstChild(LocalPlayer.Name)
        and ReplicatedStorage.Player_Data[LocalPlayer.Name]:FindFirstChild("Collection")

    if not collection then return end

    for _, unitFolder in ipairs(collection:GetChildren()) do
        if unitFolder:IsA("Folder") and table.find(TierUnitNames, unitFolder.Name) then
            local tag = unitFolder:FindFirstChild("Tag")
            local evolveTier = unitFolder:FindFirstChild("EvolveTier")

            if tag and tag:IsA("StringValue") and tag.Value ~= "" then
                local tier = evolveTier and evolveTier.Value or ""
                if tier == "" then
                    local args = { tag.Value, "Hyper" }
                    ReplicatedStorage.Remote.Server.Units.EvolveTier:FireServer(unpack(args))
                    task.wait(0.1) -- ⏱ Delay giữa mỗi lần tiến hoá
                end
            end
        end
    end
end

-- Biến điều khiển vòng lặp
local isRolling = false

-- Hàm chính để spam roll
local function autoRoll()
    local rs  = game:GetService("ReplicatedStorage")
    local plr = game:GetService("Players").LocalPlayer
    local collection = rs:WaitForChild("Player_Data")
                         :WaitForChild(plr.Name)
                         :WaitForChild("Collection")
    local rerollRemote = rs
        :WaitForChild("Remote")
        :WaitForChild("Server")
        :WaitForChild("Gambling")
        :WaitForChild("RerollPotential")
    local unitEntry = settings.selectUnit
    local unitName = unitEntry:match("^(.-)%s*%[") or unitEntry
    local folder = collection:FindFirstChild(unitName)
    if not folder then
        warn("Không tìm thấy folder của unit:", unitName)
        return
    end

    local pending = {}
    for _, potential in ipairs(settings.selectPotential) do
        local resultNV = folder:FindFirstChild(potential .. "Potential")
        local resultVal = resultNV and resultNV.Value or ""

        local matched = false
        for _, desired in ipairs(settings.selectStats) do
            if resultVal == desired then
                matched = true
                break
            end
        end

        if not matched then
            pending[potential] = true
        end
    end

    if not next(pending) then
        statsSection:SetValue("start roll", false)
        settings.startRoll = false
        saveSettings(settings)
        return
    end

    isRolling = true
    while isRolling and next(pending) do
        for potential in pairs(pending) do
            if not isRolling then break end

            local tagNV = folder:FindFirstChild("Tag")
            if not tagNV then
                warn("Không tìm thấy tag của unit:", unitName)
                isRolling = false
                return
            end

            local tagStr = tagNV.Value
            rerollRemote:FireServer(potential, tagStr, "Selective")

            wait(0.3)

            local resultNV = folder:FindFirstChild(potential .. "Potential")
            local resultVal = resultNV and resultNV.Value or ""

            for _, desired in ipairs(settings.selectStats) do
                if resultVal == desired then
                    pending[potential] = nil
                    break
                end
            end
        end
    end

    isRolling = false
    statsSection:SetValue("start roll", false)
    settings.startRoll = false
    saveSettings(settings)
end

--//auto bú liếm
local function autoBuLiemFunc()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    local function getCharacter()
        local char = player.Character or player.CharacterAdded:Wait()
        while not char:FindFirstChild("HumanoidRootPart") do
            char.ChildAdded:Wait()
        end
        return char
    end

    local function getAllParts(folder)
        local parts = {}
        for _, obj in ipairs(folder:GetChildren()) do
            if obj:IsA("Part") then
                table.insert(parts, obj)
            end
        end
        return parts
    end

    local function activatePrompt(prompt)
        for i = 1, 10 do -- chỉ gọi trong 1s, tránh spam
            if prompt:IsA("ProximityPrompt") then
                fireproximityprompt(prompt)
            end
            task.wait(0.1)
        end
    end

    task.spawn(function()
        local character = getCharacter()
        local hrp = character:WaitForChild("HumanoidRootPart")

        while settings.autoBuLiem do
            local portalFolder = workspace:FindFirstChild("Portal")
            if portalFolder then
                local parts = getAllParts(portalFolder)
                if #parts > 0 then
                    local selectedPart = parts[math.random(1, #parts)]
                    hrp.CFrame = selectedPart.CFrame + Vector3.new(0, 5, 0)

                    local prompt = selectedPart:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        activatePrompt(prompt)
                    end
                end
            end
            task.wait(1) -- delay 1s mỗi vòng
        end
    end)
end

--// Create Window
local Window = MacLib:Window({
    Title = "Pịa Hub",
    Subtitle = "Vãi Pịa",
    Size = UDim2.fromOffset(650, 400),
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

pcall(function()
	window.Instance.Name = "PiaHubUIarx"
end)

local TabGroup = Window:TabGroup()
local MainTab = TabGroup:Tab({ Name = "Main" })
local AutoPlayTab = TabGroup:Tab({ Name = "Auto Play" })
local WebhookTab = TabGroup:Tab({ Name = "Webhook" })
local ShopTab = TabGroup:Tab({ Name = "Shop" })
local PortalTab = TabGroup:Tab({ Name = "Portal" }) -- ID icon có thể thay

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

--//auto load script
controlSection:Toggle({
    Name = "Auto Excute",
    Default = settings.autoReloadOnTeleport or false,
    Callback = function(val)
        settings.autoReloadOnTeleport = val
        saveSettings(settings)

        if val then
            queue_on_teleport([[
                repeat task.wait() until game:IsLoaded()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/thaemmayanh/hub/refs/heads/main/arx.lua'))()
            ]])
        end
    end
})

--//delete map
controlSection:Toggle({
    Name = "Delete Map",
    Default = settings.deleteMap or false,
    Callback = function(val)
        settings.deleteMap = val
        saveSettings(settings)

        if val then
            task.spawn(function()
                local building = workspace:FindFirstChild("Building")
                if not building then return end

                local mapFolder = building:FindFirstChild("Map")
                if not mapFolder then return end

                -- 🔥 Xoá mọi thứ trong Building.Map.Map trừ Baseplate
                local innerMap = mapFolder:FindFirstChild("Map")
                if innerMap then
                    for _, obj in ipairs(innerMap:GetChildren()) do
                        if obj.Name ~= "Baseplate" then
                            obj:Destroy()
                        end
                    end
                end

                -- 🔥 Xoá mọi thứ trong Building.Map.VFX trừ Baseplate
                local vfxFolder = mapFolder:FindFirstChild("VFX")
                if vfxFolder then
                    for _, obj in ipairs(vfxFolder:GetChildren()) do
                        if obj.Name ~= "Baseplate" then
                            obj:Destroy()
                        end
                    end
                end
            end)
        end
    end
})

-- Misc Section (bên trái Main Tab)
local miscSection = MainTab:Section({ Side = "Left", Title = "Misc" })

miscSection:Toggle({
    Name = "Auto Claim Quest",
    Default = settings.autoClaimQuest or false,
    Callback = function(val)
        settings.autoClaimQuest = val
        saveSettings(settings)

        if val then
            task.spawn(function()
                while settings.autoClaimQuest do
                    local lobbyFolder = workspace:FindFirstChild("Lobby")

                    if lobbyFolder and lobbyFolder:IsA("Folder") then
                        local args = { "ClaimAll" }
                        game:GetService("ReplicatedStorage")
                            :WaitForChild("Remote")
                            :WaitForChild("Server")
                            :WaitForChild("Gameplay")
                            :WaitForChild("QuestEvent")
                            :FireServer(unpack(args))
                    end

                    task.wait(10) -- kiểm tra mỗi 10s
                end
            end)
        end
    end
})

-- 📦 UI Section
local section = MainTab:Section({ Side = "Right", Title = "Auto Ranger" })

-- 🎯 Dropdown: Select Act
local actLabelList = {}
for _, label in pairs(ActMapping) do
    table.insert(actLabelList, label)
end

section:Dropdown({
    Name = "Select Act",
    Search = true,
    Multi = true,
    Required = false,
    Options = actLabelList,
    Default = settings.selectedActs or {},
    Callback = function(selectedDict)
        local selectedArray = {}
        for key, val in pairs(selectedDict) do
            if val then table.insert(selectedArray, key) end
        end
        settings.selectedActs = selectedArray
        saveSettings(settings)
    end
})

-- 🔁 Toggle: Auto Ranger
section:Toggle({
    Name = "Auto Ranger",
    Default = settings.autoRanger or false,
    Callback = function(val)
        settings.autoRanger = val
        saveSettings(settings)
        if val then
            task.spawn(runAutoRanger)
        end
    end
})

local challengeSection = MainTab:Section({ Side = "Right", Title = "Challenge" })

challengeSection:Toggle({
    Name = "Auto Join Challenge",
    Default = settings.autoJoinChallenge or false,
    Callback = function(val)
        settings.autoJoinChallenge = val
        saveSettings(settings)

        if val then
            task.spawn(function()
                local PlayRoomEvent = game:GetService("ReplicatedStorage")
                    :WaitForChild("Remote")
                    :WaitForChild("Server")
                    :WaitForChild("PlayRoom")
                    :WaitForChild("Event")

                while settings.autoJoinChallenge do
                    -- Đảm bảo đang ở trong lobby
                    if workspace:FindFirstChild("Lobby") then
                        local args1 = {
                            "Create",
                            {
                                CreateChallengeRoom = true
                            }
                        }
                        PlayRoomEvent:FireServer(unpack(args1))

                        task.wait(0.5)

                        local args2 = { "Start" }
                        PlayRoomEvent:FireServer(unpack(args2))
                    end

                    task.wait(3) -- delay để tránh spam server
                end
            end)
        end
    end
})

-- Toggle UI phần Auto Rejoin trong tab Main, cột phải
local autoRejoinSection = MainTab:Section({ Side = "Right", Title = "Auto Rejoin" })

autoRejoinSection:Toggle({
    Name = "Auto Rejoin When FPS Drop",
    Default = settings.autoRejoin or false,
    Callback = function(val)
        settings.autoRejoin = val
        saveSettings(settings)
        if val then
            task.spawn(fpsMonitorLoop)
        end
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

                    -- Nếu bật Play After Upgrade → đợi upgrade xong trước khi deploy
                    if settings.playAfterUpgrade and settings.autoUpgrade then
                        if not isUpgrading then
                            upgradeUnits()
                        end
                        while isUpgrading do
                            task.wait(0.2)
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
        sendWebhook()
    end
})

local tierSection = ShopTab:Section({ Side = "Left", Title = "Auto Tier(Rare)" })

tierSection:Toggle({
    Name = "Auto Evolve Tier (Rare)",
    Default = settings.autoEvolveRare,
    Callback = function(val)
        settings.autoEvolveRare = val
        saveSettings(settings)

        if val then
            evolveRareUnits()
        end
    end
})

-- 📦 Section: Summon (Left)
local summonSection = ShopTab:Section({ Side = "Left", Title = "Summon" })

-- 🏷 Dropdown: Select Banner (không lưu)
summonSection:Dropdown({
    Name = "Select Banner",
    Options = { "Standard", "Rateup" },
    Multi = false,
    Default = settings.selectBanner or "Standard",
    Callback = function(val)
        settings.selectBanner = val
    end
})

-- 🧹 Dropdown: Select Auto Sell (không lưu)
summonSection:Dropdown({
    Name = "Select Auto Sell",
    Options = { "Rare", "Epic", "Legendary", "Shiny" },
    Multi = true,
    Default = settings.autoSellTiers or {},
    Callback = function(selectedDict)
        settings.autoSellTiers = selectedDict
    end
})

-- 🔁 Toggle: Auto Summon x10 (không lưu)
summonSection:Toggle({
    Name = "Auto Summon x10",
    Default = settings.autoSummonX10,
    Callback = function(val)
        settings.autoSummonX10 = val

        if val then
            task.spawn(function()
                while settings.autoSummonX10 do
                    local args = {
                        "x10",
                        settings.selectBanner or "Standard"
                    }

                    if settings.autoSellTiers and next(settings.autoSellTiers) ~= nil then
                        table.insert(args, settings.autoSellTiers)
                    end

                    game:GetService("ReplicatedStorage")
                        :WaitForChild("Remote")
                        :WaitForChild("Server")
                        :WaitForChild("Gambling")
                        :WaitForChild("UnitsGacha")
                        :FireServer(unpack(args))

                    task.wait(0.3)
                end
            end)
        end
    end
})

-- 🔁 Toggle: Auto Summon x1 (không lưu)
summonSection:Toggle({
    Name = "Auto Summon x1",
    Default = settings.autoSummonX1,
    Callback = function(val)
        settings.autoSummonX1 = val

        if val then
            task.spawn(function()
                while settings.autoSummonX1 do
                    local args = {
                        "x1",
                        settings.selectBanner or "Standard"
                    }

                    if settings.autoSellTiers and next(settings.autoSellTiers) ~= nil then
                        table.insert(args, settings.autoSellTiers)
                    end

                    game:GetService("ReplicatedStorage")
                        :WaitForChild("Remote")
                        :WaitForChild("Server")
                        :WaitForChild("Gambling")
                        :WaitForChild("UnitsGacha")
                        :FireServer(unpack(args))

                    task.wait(0.3)
                end
            end)
        end
    end
})

-- Sau phần summonSection trong ShopTab
local statsSection = ShopTab:Section({ Side = "Right", Title = "Stats" })

-- MultiDropdown: select Potential
statsSection:Dropdown({
    Name     = "select Potential",
    Options  = { "Damage", "Health", "Speed", "Range", "AttackCooldown" },
    Multi    = true,
    Default  = settings.selectPotential or {},
    Callback = function(selectedDict)
        settings.selectPotential = {}
        for key, val in pairs(selectedDict) do
            if val then table.insert(settings.selectPotential, key) end
        end
        saveSettings(settings)
    end
})

-- MultiDropdown: select Stats
statsSection:Dropdown({
    Name     = "select Stats",
    Options  = { "S", "SS", "SSS", "O-", "O", "O+" },
    Multi    = true,
    Default  = settings.selectStats or {},
    Callback = function(selectedDict)
        settings.selectStats = {}
        for key, val in pairs(selectedDict) do
            if val then table.insert(settings.selectStats, key) end
        end
        saveSettings(settings)
    end
})

-- SingleDropdown: select unit (hiển thị "UnitName [Level]")
statsSection:Dropdown({
    Name     = "select unit",
    Options  = (function()
        local rs  = game:GetService("ReplicatedStorage")
        local plr = game:GetService("Players").LocalPlayer
        local col = rs:WaitForChild("Player_Data")
                       :WaitForChild(plr.Name)
                       :WaitForChild("Collection")
        local names = {}
        for _, folder in ipairs(col:GetChildren()) do
            local lvlNV = folder:FindFirstChild("Level")
            local lvl = (lvlNV and lvlNV.Value) or 0
            table.insert(names, string.format("%s [%d]", folder.Name, lvl))
        end
        return names
    end)(),
    Multi    = false,
    Default  = settings.selectUnit or "",
    Callback = function(val)
        settings.selectUnit = val
        saveSettings(settings)
    end
})

-- Toggle: start roll
statsSection:Toggle({
    Name     = "start roll",
    Default  = settings.startRoll or false,
    Callback = function(val)
        settings.startRoll = val
        saveSettings(settings)
        if val then
            if not isRolling then
                isRolling = true
                coroutine.wrap(autoRoll)()
            end
        else
            isRolling = false
        end
    end
})

    --//roll traill
    local rerollConfig = {
        unit = nil,
        trail = {},
        start = false,
    }

    function autoRollTrail(unitEntry, desiredTrails)
        local rs = game:GetService("ReplicatedStorage")
        local plr = game:GetService("Players").LocalPlayer
        local unitName = unitEntry:match("^(.-)%s*%[") or unitEntry -- Tách tên không lấy level
        local collection = rs:WaitForChild("Player_Data")
                            :WaitForChild(plr.Name)
                            :WaitForChild("Collection")
        local rerollRemote = rs:WaitForChild("Remote")
                            :WaitForChild("Server")
                            :WaitForChild("Gambling")
                            :WaitForChild("RerollTrait")

        local folder = collection:FindFirstChild(unitName)
        if not folder then
            warn("Không tìm thấy unit:", unitName)
            return
        end

        local function hasDesiredTrail()
            local primary = folder:FindFirstChild("PrimaryTrait")
            local secondary = folder:FindFirstChild("SecondaryTrait")
            local pVal = primary and primary.Value or ""
            local sVal = secondary and secondary.Value or ""

            for _, desired in ipairs(desiredTrails) do
                if pVal == desired or sVal == desired then
                    return true
                end
            end
            return false
        end

        -- Nếu đã có trail mong muốn thì không roll
        if hasDesiredTrail() then
            print("🎉 Đã có trail mong muốn trước khi roll:", unitName)
            return
        end

        print("🔁 Bắt đầu roll trail cho:", unitName)

        while rerollConfig.start do
            local args = {
                folder, -- Folder của unit
                "Reroll",
                "Main",
                "Shards"
            }

            rerollRemote:FireServer(unpack(args))
            task.wait(0.3)

            if hasDesiredTrail() then
                print("✅ Roll thành công:", unitName)
                rerollConfig.start = false -- dừng toggle
                break
            end
        end
    end

--\\roll trail
local trailRerollSection = ShopTab:Section({ Side = "Right", Title = "Trail Reroll" })

-- 🔽 Dropdown: Select Unit
trailRerollSection:Dropdown({
    Name = "Select Unit",
    Options = (function()
        local rs = game:GetService("ReplicatedStorage")
        local plr = game:GetService("Players").LocalPlayer
        local collection = rs:WaitForChild("Player_Data")
                             :WaitForChild(plr.Name)
                             :WaitForChild("Collection")

        local unitList = {}
        for _, unit in ipairs(collection:GetChildren()) do
            local levelVal = unit:FindFirstChild("Level")
            local label = unit.Name
            if levelVal then
                label = label .. " [" .. levelVal.Value .. "]"
            end
            table.insert(unitList, label)
        end
        return unitList
    end)(),
    Multi = false,
    Callback = function(val)
        rerollConfig.unit = val
    end
})

-- 🔽 MultiDropdown: Select Trail
trailRerollSection:Dropdown({
    Name = "Select Trail",
    Options = {
        "Blitz", "Juggernaut", "Millionaire", "Violent",
        "Seraph", "Capitalist", "Duplicator", "Sovereign"
    },
    Multi = true,
    Default = {},
    Callback = function(selectedDict)
        rerollConfig.trail = {}
        for key, val in pairs(selectedDict) do
            if val then
                table.insert(rerollConfig.trail, key)
            end
        end
    end
})

-- ✅ Toggle: Start Roll Trail
trailRerollSection:Toggle({
    Name = "Start Roll Trail",
    Default = false,
    Callback = function(val)
        rerollConfig.start = val
        if val then
            print("🔁 Bắt đầu roll trail:", rerollConfig.unit, "với trail:", rerollConfig.trail)
            coroutine.wrap(function()
                autoRollTrail(rerollConfig.unit, rerollConfig.trail)
            end)()
        else
            print("⛔ Dừng roll trail")
            -- Gắn logic dừng tại đây nếu có
        end
    end
})

local buliemSection = PortalTab:Section({ Side = "Left", Title = "thánh bú liếm" })

buliemSection:Toggle({
    Name = "Auto bú liếm",
    Default = settings.autoBuLiem or false,
    Callback = function(val)
        settings.autoBuLiem = val
        saveSettings(settings)

        if val then
            task.spawn(autoBuLiemFunc)
        end
    end
})
