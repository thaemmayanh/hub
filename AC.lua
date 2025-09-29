repeat task.wait() until game:IsLoaded()

-- ⚠️ Ngăn tạo nhiều GUI
if getgenv()._PiaHubarxLoaded then
    return
end
getgenv()._PiaHubarxLoaded = true

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new(0, 0))
end)

--// Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local WS = game:GetService("Workspace")

--// Lib
local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/thaem/main/lib"))()

--// Setup Settings
local folderName   = "PIAHUB"
local macroFolder  = folderName.."/Macro"
local fileName     = "settings.json"

-- Tạo folder nếu chưa có
if not isfolder(folderName) then makefolder(folderName) end
if not isfolder(macroFolder) then makefolder(macroFolder) end

-- Default settings
local defaultSettings = {
    selectedMacro = "",
    playMacro     = false,
    next          = false,
    replay        = false,
    returnLobby   = false,
    selectedGates = {},        
    selectedType = "High Gate",
    autoGate = false,
    autoFindGate = false,
    webhookLink   = "",
    sendWebhook   = false,
    autoJoinMode = "Story",
    autoJoinMap = "",
    autoJoinDiff  = "Normal",
    autoJoin = false,
    autoFind = false,
    autoJoinAct = "Act 1",
    selectedPortal   = "Marine Ford Portal",
    autoJoinPortal   = false,
    smartAutoPlace = false,
    showHistogram = false,
    distancePct = 100,
    hillPct = 100,
    groundPct = 100,
    placeCap = {4,4,4,4,4,4},
    upgradeCap = {10,10,10},
    autoStart = false,
    startDelay = 1,
    ignoreChallenge = {},     
    autoJoinChallenge = false,
    autoLeaveChallenge = false,
    autoExecute = false,
    smoothMap = false,
}

-- Hàm load/save settings
local function loadSettings()
    local path = folderName.."/"..fileName
    if isfile(path) then
        local content = readfile(path)
        if content and content ~= "" then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if ok and type(data) == "table" then
                return data
            end
        end
    end
    writefile(path, HttpService:JSONEncode(defaultSettings))
    return table.clone(defaultSettings)
end

local function saveSettings(tbl)
    writefile(folderName.."/"..fileName, HttpService:JSONEncode(tbl))
end

local settings = loadSettings()

-- Hàm lấy danh sách macro
local function listMacros()
    local files = listfiles(macroFolder)
    local names = {}
    for _, path in ipairs(files) do
        if path:match("%.json$") then
            local name = path:match("([^/\\]+)%.json$")
            if name then table.insert(names, name) end
        end
    end
    table.sort(names)
    return names
end

----------------------------------------------------------------
-- 🆕 Auto Join Logic
----------------------------------------------------------------
local endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")

local requestJoinLobby       = endpoints:WaitForChild("request_join_lobby")
local requestLockLevel       = endpoints:WaitForChild("request_lock_level")
local requestStartGame       = endpoints:WaitForChild("request_start_game")
local requestInfinite        = endpoints:WaitForChild("request_infinite_leaderboard")
local requestMatchmaking     = endpoints:WaitForChild("request_matchmaking")

-- helper start game (chỉ chạy khi Auto Start bật)
local function SafeStart(lobbyId)
    if not settings.autoStart then
        return -- ❌ nếu autoStart tắt thì không start
    end

    task.spawn(function()
        local delaySec = tonumber(settings.startDelay) or 0
        if delaySec > 0 then
            for i = delaySec, 1, -1 do
                warn("[AUTO START] Starting in " .. i .. "s...")
                task.wait(1)
            end
        end
        requestStartGame:InvokeServer(lobbyId)
    end)
end

----------------------------------------------------------------
-- 🆕 Auto Join Logic (Story / Infinite / Legend / Raid)
----------------------------------------------------------------
local function RunAutoJoin()
    -- chỉ hoạt động khi ở lobby
    if game.PlaceId ~= 107573139811370 then return end
    if not settings.autoJoinMode or settings.autoJoinMap == "" then return end

    local mode  = settings.autoJoinMode
    local map   = settings.autoJoinMap
    local act   = settings.autoJoinAct or "Act 1"
    local diff  = settings.autoJoinDiff or "Normal"
    local actIndex = string.match(act, "(%d+)") or "1"

    -- 🏠 Chế độ Join Map
    if settings.autoJoin then
        if mode == "story" then
            requestJoinLobby:InvokeServer("P7")
            local levelName = map.."_level_"..actIndex
            requestLockLevel:InvokeServer("P7", levelName, false, diff)
            SafeStart("P7")

        elseif mode == "infinite" then
            requestJoinLobby:InvokeServer("P7")
            requestInfinite:InvokeServer(map.."_infinite")
             requestLockLevel:InvokeServer("P7", map.."_infinite", false, "Hard")
            SafeStart("P7")

        elseif mode == "legend stage" then
            requestJoinLobby:InvokeServer("P7")
            local levelName = map.."_legend_"..actIndex
            requestLockLevel:InvokeServer("P7", levelName, false, "Hard")
            SafeStart("P7")

        elseif mode == "raid" then
            requestJoinLobby:InvokeServer("R3")
            local levelName = map.."_Raid_"..actIndex
            requestLockLevel:InvokeServer("R3", levelName, false, "Hard")
            SafeStart("R3")
        end
    end

    -- 🔎 Chế độ Find Map
    if settings.autoFind then
        if mode == "story" then
            local levelName = map.."_level_"..actIndex
            local args = {levelName, {Difficulty = diff}}
            requestMatchmaking:InvokeServer(unpack(args))

        elseif mode == "infinite" then
            local args = {map.."_infinite", {Difficulty = "Normal"}}
            requestMatchmaking:InvokeServer(unpack(args))

        elseif mode == "legend stage" then
            local levelName = map.."_legend_"..actIndex
            local args = {levelName, {Difficulty = "Normal"}}
            requestMatchmaking:InvokeServer(unpack(args))

        elseif mode == "raid" then
            local levelName = map.."_Raid_"..actIndex
            local args = {levelName, {Difficulty = "Normal"}}
            requestMatchmaking:InvokeServer(unpack(args))
        end
    end
end

--/// PORTAL
local usePortal = endpoints:WaitForChild("use_portal")
local requestStartGame = endpoints:WaitForChild("request_start_game")

local function AutoJoinPortal()
    if not settings.autoJoinPortal then return end

    local itemFrames = LocalPlayer:WaitForChild("PlayerGui")
        :WaitForChild("items")
        :WaitForChild("grid")
        :WaitForChild("List")
        :WaitForChild("Outer")
        :WaitForChild("ItemFrames")

    for _, frame in ipairs(itemFrames:GetChildren()) do
        if frame.Name:sub(1,7) == "portal_" then
            local uuidVal = frame:FindFirstChild("_uuid_or_id")
            local nameLbl = frame:FindFirstChild("name")

            if uuidVal and nameLbl and nameLbl:IsA("TextLabel") then
                if nameLbl.Text == settings.selectedPortal then
                    local uuid = uuidVal.Value
                    print("[AUTO PORTAL] Found:", nameLbl.Text, uuid)

                    usePortal:InvokeServer(uuid)
                    task.wait(1)
                    requestStartGame:InvokeServer(uuid)

                    break
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Hàm xử lý End Game Jobs
----------------------------------------------------------------
local voteRemote = ReplicatedStorage:WaitForChild("endpoints")
    :WaitForChild("client_to_server")
    :WaitForChild("set_game_finished_vote")

local function DoJobs()
    task.spawn(function()
        while task.wait(1) do
            if game.PlaceId ~= 107573139811370 then
                local gui = LocalPlayer:FindFirstChild("PlayerGui"):FindFirstChild("ResultsUI")
                if gui and gui.Enabled then
                    if settings.next then
                        voteRemote:InvokeServer("next_story")
                        task.wait(1)
                    end
                    if gui.Enabled and settings.replay then
                        voteRemote:InvokeServer("replay")
                        task.wait(1)
                    end
                    if gui.Enabled and settings.returnLobby then
                        game:GetService("TeleportService"):Teleport(107573139811370, LocalPlayer)
                    end
                    repeat task.wait(1) until not gui.Enabled
                end
            end
        end
    end)
end

DoJobs()

----------------------------------------------------------------
-- Hàm Auto Gate / Auto Find
----------------------------------------------------------------
local endpoints = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server")
local gatePriority = {"C","D","B","A","S","National"}

-- Lấy ID Gate dựa trên setting
local function GetGateId()
    local gatesFolder = workspace:WaitForChild("_GATES"):WaitForChild("gates")
    local found = {}
    for _, folder in ipairs(gatesFolder:GetChildren()) do
        local gateType = folder:FindFirstChild("GateType")
        if gateType and table.find(settings.selectedGates, gateType.Value) then
            table.insert(found, {id = tonumber(folder.Name), type = gateType.Value})
        end
    end
    if #found == 0 then return nil end

    table.sort(found, function(a,b)
        return table.find(gatePriority, a.type) < table.find(gatePriority, b.type)
    end)

    if settings.selectedType == "High Gate" then
        return found[#found].id
    elseif settings.selectedType == "Low Gate" then
        return found[1].id
    elseif settings.selectedType == "Random Gate" then
        return found[math.random(1,#found)].id
    end
end

-- Auto ở lobby
local function AutoLobby()
    if game.PlaceId ~= 107573139811370 then return end
    local id = GetGateId()
    if not id then return end

    if settings.autoGate then
        endpoints.request_join_lobby:InvokeServer("_GATE"..id)
        task.wait(1)
        endpoints.request_start_game:InvokeServer("_GATE"..id)
    elseif settings.autoFindGate then
        endpoints.request_matchmaking:InvokeServer("_GATE", { GateUuid = id })
    end
end

-- Auto trong trận
local function AutoInGame()
    if game.PlaceId == 107573139811370 then return end
    local gui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ResultsUI")
    if gui.Enabled then
        local id = GetGateId()
        if not id then return end

        if settings.autoGate then
            endpoints.set_game_finished_vote:InvokeServer("play_gate_next", { GateUuid = id })
        elseif settings.autoFindGate then
            endpoints.request_matchmaking:InvokeServer("_GATE", { GateUuid = id })
        end
    end
end

----------------------------------------------------------------
-- ⚔️ Auto Join Challenge
----------------------------------------------------------------
local function RunAutoJoinChallenge()
    if game.PlaceId ~= 107573139811370 then return false end -- chỉ chạy khi ở lobby
    if not settings.autoJoinChallenge then return false end

    local challengeVal = workspace:WaitForChild("_CHALLENGES")
        :WaitForChild("Challenges")
        :WaitForChild("ChallengePod5")
        :WaitForChild("Challenge").Value

    -- Nếu challenge trong danh sách ignore thì bỏ qua
    if table.find(settings.ignoreChallenge or {}, challengeVal) then
        warn("[CHALLENGE] Ignored:", challengeVal)
        return false -- ignored → cho phép join khác chạy
    end

    -- Ngược lại thì join challenge
    local args = {"ChallengePod5"}
    game:GetService("ReplicatedStorage")
        :WaitForChild("endpoints")
        :WaitForChild("client_to_server")
        :WaitForChild("request_join_lobby")
        :InvokeServer(unpack(args))

    -- Nếu Auto Start bật thì gọi SafeStart
    if settings.autoStart then
        task.delay(1, function()
            SafeStart("ChallengePod5")
        end)
    end

    return true -- đã join challenge → chặn join khác
end

----------------------------------------------------------------
-- 🏃 Auto Leave Challenge
----------------------------------------------------------------
local function RunAutoJoinChallenge()
    if game.PlaceId ~= 107573139811370 then return false end
    if not settings.autoJoinChallenge then return false end

    local challengeVal = workspace:WaitForChild("_CHALLENGES")
        :WaitForChild("Challenges")
        :WaitForChild("ChallengePod5")
        :WaitForChild("Challenge").Value

    if table.find(settings.ignoreChallenge or {}, challengeVal) then
        warn("[CHALLENGE] Ignored:", challengeVal)
        return false
    end

    local args = {"ChallengePod5"}
    game:GetService("ReplicatedStorage")
        :WaitForChild("endpoints")
        :WaitForChild("client_to_server")
        :WaitForChild("request_join_lobby")
        :InvokeServer(unpack(args))

    if settings.autoStart then
        task.delay(1, function()
            SafeStart("ChallengePod5")
        end)
    end

    return true
end

----------------------------------------------------------------
-- 🌐 RunAuto: gom tất cả auto join
----------------------------------------------------------------
local function RunAuto()
    -- Chỉ chạy ở lobby
    if game.PlaceId ~= 107573139811370 then return end

    -- Ưu tiên Challenge
    if settings.autoJoinChallenge then
        local joined = RunAutoJoinChallenge()
        if joined then
            return -- đã join Challenge thì bỏ qua join khác
        end
    end

    -- Nếu challenge bị ignore hoặc toggle off thì join khác
    if settings.autoJoin or settings.autoFind then
        RunAutoJoin()
    end

    if settings.autoGate or settings.autoFindGate then
        AutoLobby()
        AutoInGame()
    end

    if settings.autoJoinPortal then
        AutoJoinPortal()
    end
end

-- Loop chính
task.spawn(function()
    while task.wait(3) do
        RunAuto()
    end
end)

--// Record & Play Macro
local spawnRemote = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server"):WaitForChild("spawn_unit")
local upgradeRemote = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server"):WaitForChild("upgrade_unit_ingame")
local sellRemote = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server"):WaitForChild("sell_unit_ingame")
local voteStartRemote = ReplicatedStorage:WaitForChild("endpoints")
    :WaitForChild("client_to_server")
    :WaitForChild("vote_start")
    
-- Biến điều khiển
local Recording = false
local MacroData = {}
local logCount = 0
local unitData = {}

----------------------------------------------------------------
-- Hàm phụ trợ
----------------------------------------------------------------
local function moneyValue()
    return LocalPlayer:WaitForChild("_stats"):WaitForChild("resource")
end

local function waitForMoney(atLeast)
    atLeast = atLeast or 0
    local res = moneyValue()
    while res.Value < atLeast do
        task.wait(0.15)
    end
end

local function nearModelByCFrame(cf, radius)
    radius = radius or 6
    local target, minD = nil, radius
    for _, m in ipairs(workspace._UNITS:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then
            local stats = m:FindFirstChild("_stats")
            if stats and stats:FindFirstChild("player") and stats.player.Value == LocalPlayer then
                local d = (m.HumanoidRootPart.Position - cf.Position).Magnitude
                if d <= minD then
                    minD, target = d, m
                end
            end
        end
    end
    return target
end

local function vecToTable(v)
    if typeof(v) == "Vector3" then
        return {x=v.X, y=v.Y, z=v.Z}
    end
    return {x=0,y=0,z=0}
end

local function tableToVec(t)
    if t and t.x then
        return Vector3.new(t.x,t.y,t.z)
    end
    return Vector3.new(0,0,0)
end

----------------------------------------------------------------
-- Logging
----------------------------------------------------------------
local function logUpgrade(unitId, diff, cf)
    logCount += 1
    local pos = (typeof(cf) == "CFrame") and cf.Position or Vector3.new()
    MacroData[tostring(logCount)] = {
        Money = diff or 0,
        Type = "upgrade",
        UnitID = unitId,
        Position = vecToTable(pos)
    }
end

local function logSell(unitId, cf)
    logCount += 1
    local pos = (typeof(cf) == "CFrame") and cf.Position or Vector3.new()
    MacroData[tostring(logCount)] = {
        Type = "sell",
        UnitID = unitId,
        Position = vecToTable(pos)
    }
end

local function logPlace(unitIdParam, spawnedId, cost, origin, direction, age)
    logCount += 1
    MacroData[tostring(logCount)] = {
        Money = cost or 0,
        Type = "place",
        UnitIDParam = unitIdParam,
        SpawnedID = spawnedId,
        Origin = vecToTable(origin),
        Direction = vecToTable(direction),
        Age = age or 0
    }
end

----------------------------------------------------------------
-- Track upgrade qua total_spent
----------------------------------------------------------------
local function trackUnit(model)
    if not model:FindFirstChild("_stats") then return end
    local stats = model._stats
    local spent = stats:FindFirstChild("total_spent")
    local idVal = stats:FindFirstChild("id")
    local owner = stats:FindFirstChild("player")

    if spent and idVal and owner and owner.Value == LocalPlayer then
        unitData[model] = spent.Value
        spent.Changed:Connect(function()
            if Recording then
                local oldVal = unitData[model] or 0
                local diff = spent.Value - oldVal
                unitData[model] = spent.Value
                if diff > 0 then
                    local hrp = model:FindFirstChild("HumanoidRootPart")
                    logUpgrade(idVal.Value, diff, hrp and hrp.CFrame or CFrame.new())
                end
            else
                unitData[model] = spent.Value
            end
        end)
    end
end

for _, m in ipairs(workspace._UNITS:GetChildren()) do
    if m:IsA("Model") then trackUnit(m) end
end
workspace._UNITS.ChildAdded:Connect(function(m)
    if m:IsA("Model") then trackUnit(m) end
end)

----------------------------------------------------------------
-- Save & Load MacroData
----------------------------------------------------------------
local function saveMacroData(macroName)
    if macroName == "" then return end
    local path = macroFolder.."/"..macroName..".json"
    writefile(path, HttpService:JSONEncode(MacroData))
end

local function loadMacroData(macroName)
    local path = macroFolder.."/"..macroName..".json"
    if not isfile(path) then return {} end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and data then return data else return {} end
end

----------------------------------------------------------------
-- Play Macro + Stop Macro
----------------------------------------------------------------
local Playing = false
local CurrentSession = 0
local VoteTriggered = false

local function StopMacro()
    Playing = false
    CurrentSession += 1 -- tăng phiên bản, vòng lặp cũ sẽ tự hủy
end

local function PlayMacro(macroName)
    if not macroName or macroName == "" then return end
    if Playing then return end

    local data = loadMacroData(macroName)
    if not data then return end
    Playing = true
    local session = CurrentSession

    local keys = {}
    for k in pairs(data) do table.insert(keys, tonumber(k)) end
    table.sort(keys)

    for _, idx in ipairs(keys) do
        if not Playing or session ~= CurrentSession then break end

        local job = data[tostring(idx)]
        if job then
            if job.Type == "place" or job.Type == "upgrade" then
                waitForMoney(job.Money or 0)
            end
            if not Playing or session ~= CurrentSession then break end

            if job.Type == "place" then
                spawnRemote:InvokeServer(job.UnitIDParam, {
                    Origin = tableToVec(job.Origin),
                    Direction = tableToVec(job.Direction)
                }, job.Age or 0)

            elseif job.Type == "upgrade" then
                local pos = tableToVec(job.Position)
                local target = nearModelByCFrame(CFrame.new(pos), 7)
                if target then upgradeRemote:InvokeServer(target.Name) end

            elseif job.Type == "sell" then
                local pos = tableToVec(job.Position)
                local target = nearModelByCFrame(CFrame.new(pos), 7)
                if target then sellRemote:InvokeServer(target.Name) end
            end

            task.wait(0.5) -- chờ ngắn giữa các job
        end
    end

    if session == CurrentSession then
        Playing = false
        VoteTriggered = false
    end
end

-- hook remote
local function isValidModel(m)
    return m:IsA("Model") and not m.Name:lower():match("^pve")
end

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method, args = getnamecallmethod(), {...}

    -- 🎥 Recording logic (place & sell)
    if Recording then
        if self == spawnRemote and method == "InvokeServer" then
            local unitIdParam, placementData, age = args[1], args[2], args[3]
            task.spawn(function()
                local found
                local conn
                conn = workspace._UNITS.ChildAdded:Connect(function(m)
                    if isValidModel(m) then
                        local st = m:WaitForChild("_stats", 3)
                        if st then
                            local playerVal = st:FindFirstChild("player")
                            if playerVal and playerVal.Value == LocalPlayer then
                                found = m
                                conn:Disconnect()
                            end
                        end
                    end
                end)
                local t0 = tick()
                while not found and tick() - t0 < 2 do
                    task.wait(0.1)
                end
                if found then
                    local st = found._stats
                    logPlace(
                        unitIdParam,
                        st:FindFirstChild("id") and st.id.Value or "",
                        st:FindFirstChild("total_spent") and st.total_spent.Value or 0,
                        placementData.Origin,
                        placementData.Direction,
                        age
                    )
                end
            end)

        elseif self == sellRemote and method == "InvokeServer" then
            local unitId = args[1]
            task.spawn(function()
                local target = workspace._UNITS:FindFirstChild(unitId)
                logSell(
                    unitId,
                    target and target:FindFirstChild("HumanoidRootPart")
                        and target.HumanoidRootPart.CFrame or CFrame.new()
                )
            end)
        end
    end

    -- 🎮 Vote auto-macro logic
    if self == voteStartRemote and (method == "InvokeServer" or method == "FireServer") then
        if not VoteTriggered and settings.playMacro then
            VoteTriggered = true
            task.spawn(function()
                StopMacro()
                task.wait(0.3)
                PlayMacro(settings.selectedMacro)
            end)
        end
    end

    return oldNamecall(self, unpack(args))
end)

setreadonly(mt, true)

--// WEBHOOK
local function collectData()
    local data = {}
    local stats = LocalPlayer:WaitForChild("_stats")

    -- 📊 Stats (EXP, Gold, Gem, Jewels cuối cùng)
    local exp   = stats:FindFirstChild("player_xp") and stats.player_xp.Value or 0
    local gold  = stats:FindFirstChild("gold_amount") and stats.gold_amount.Value or 0
    local gem   = stats:FindFirstChild("gem_amount") and stats.gem_amount.Value or 0
    local jewel = stats:FindFirstChild("_resourceJewels") and stats._resourceJewels.Value or 0

    data.statsText = string.format("EXP: %s\nGold: %s\nGem: %s\nJewels: %s",
        tostring(exp), tostring(gold), tostring(gem), tostring(jewel))

    -- 🎯 Match Info
    local results = LocalPlayer.PlayerGui:WaitForChild("ResultsUI", 10)
    if results and results.Enabled then
        local holder = results:WaitForChild("Holder")

        local title = holder:FindFirstChild("Banner") and holder.Banner:FindFirstChild("Title")
        local mapdata = holder:FindFirstChild("mapdata")
        local middle = holder:FindFirstChild("Middle")

        data.matchResult = (title and title.Text) or ""
        data.world = (mapdata and mapdata:FindFirstChild("LevelName") and mapdata.LevelName.Text) or ""
        data.mode  = (mapdata and mapdata:FindFirstChild("Difficulty") and mapdata.Difficulty.Text) or ""
        data.time  = (middle and middle:FindFirstChild("PlayTime") and middle.PlayTime:FindFirstChild("ValueText")
                      and middle.PlayTime.ValueText.Text) or ""
    end

    -- 🎁 Rewards
    data.rewardsList = {}
    local rewardsRoot = results and results:FindFirstChild("Holder")
                       and results.Holder:FindFirstChild("Rewards")
                       and results.Holder.Rewards:FindFirstChild("Reward")

    if rewardsRoot then
        for _, btn in ipairs(rewardsRoot:GetChildren()) do
            if btn:IsA("ImageButton") then
                local nameLbl = btn:FindFirstChild("name")
                local amtLbl  = btn:FindFirstChild("OwnedAmount")
                if nameLbl and amtLbl then
                    local amt = tostring(amtLbl.Text):gsub("x", "") -- bỏ chữ x
                    table.insert(data.rewardsList, "+" .. amt .. " " .. nameLbl.Text)
                end
            end
        end
    end

    return data
end

local function sendWebhook()
    if not settings.sendWebhook or settings.webhookLink == "" then return end

    local d = collectData()

    -- màu theo kết quả
    local color = 0xffff00
    if d.matchResult:lower():find("victory") then
        color = 0x00ff00
    elseif d.matchResult:lower():find("defeat") then
        color = 0xff0000
    end

    local fields = {
        { name = "Stats", value = d.statsText, inline = false },
        { name = "Rewards", value = #d.rewardsList > 0 and table.concat(d.rewardsList, "\n") or "Không có", inline = true },
        { name = "Match Info", value = string.format("%s\nWorld: %s\nMode: %s\nTime: %s", d.matchResult, d.world, d.mode, d.time), inline = false },
    }

    local payload = {
        embeds = {{
            title = "Pịa Hub - Battle Result",
            color = color,
            fields = fields,
            thumbnail = { url = "https://i.postimg.cc/13L3GdVR/7a21b914-a70c-4af4-87b5-4a96bce7a578.png" },
            footer = { text = "https://discord.gg/eY6gCUAnts -" .. os.date(" %Y-%m-%d %H:%M:%S") },
        }}
    }

    local success, err = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if not req then error("Không có hàm HTTP request") end
        req({
            Url = settings.webhookLink,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if not success then
        warn("❌ Gửi webhook thất bại:", err)
    end
end

-- Lắng nghe ResultsUI Enabled
local results = LocalPlayer.PlayerGui:WaitForChild("ResultsUI")
results:GetPropertyChangedSignal("Enabled"):Connect(function()
    if results.Enabled and settings.sendWebhook then
        task.wait(2)
        sendWebhook()
    end
end)

---------------------------------------------------------------
-- ⚡ Auto Place Logic
---------------------------------------------------------------
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local moduleCache = {}

local function findModule(unitId)
    if moduleCache[unitId] then return moduleCache[unitId] end
    local Units = RS.Framework.Data.Units
    for _, folder in ipairs(Units:GetChildren()) do
        for _, mod in ipairs(folder:GetChildren()) do
            if mod:IsA("ModuleScript") then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    for _, v in pairs(data) do
                        if type(v) == "table" and v.id == unitId then
                            moduleCache[unitId] = {
                                raw = v,
                                id = v.id,
                                cost = v.cost or 0,
                                spawn_cap = v.spawn_cap or 0,
                                hill_unit = v.hill_unit,
                                upgrade = v.upgrade
                            }
                            return moduleCache[unitId]
                        end
                    end
                end
            end
        end
    end
end

local FX_CACHE = RS:WaitForChild("_FX_CACHE")

-- 🔍 Lấy toàn bộ unit equip theo GUI slot
local function getEquippedUnits()
    local equippedList = {}
    local UnitsGui = LP.PlayerGui:WaitForChild("spawn_units").Lives.Frame.Units

    for slot = 1, 6 do
        local slotFrame = UnitsGui:FindFirstChild(tostring(slot))
        if slotFrame 
            and slotFrame:FindFirstChild("Main") 
            and slotFrame.Main:FindFirstChild("petimage") 
            and slotFrame.Main.petimage:FindFirstChild("WorldModel") then

            local wm = slotFrame.Main.petimage.WorldModel
            local model = wm:FindFirstChildWhichIsA("Model")

            if model then
                local unitId = model.Name
                if string.find(unitId, ":") then
                    unitId = string.split(unitId, ":")[1]
                end

                -- tìm uuid trong FX_CACHE
                local uuid
                for _, frame in ipairs(FX_CACHE:GetChildren()) do
                    if frame:IsA("ImageButton") and frame:GetAttribute("ITEMINDEX") == unitId then
                        local uuidObj = frame:FindFirstChild("_uuid")
                        uuid = uuidObj and uuidObj.Value
                    end
                end

                local data = findModule(unitId)
                table.insert(equippedList, {
                    slot = slot,
                    name = unitId,
                    uuid = uuid,
                    cost = data and data.cost or 0,
                    type = data and (data.hill_unit and "HILL" or "GROUND") or "???",
                    spawn_cap = data and data.spawn_cap or 0,
                    upgrades = data and data.upgrade or {}
                })
            end
        end
    end

    return equippedList
end

---------------------------------------------------------------
-- 🛣️ Fake Road Generation (để tránh spawn trên đường đi)
---------------------------------------------------------------
local lanes = WS._BASES.pve.LANES
local roadFolder = WS:FindFirstChild("FakeRoad") or Instance.new("Folder")
roadFolder.Name, roadFolder.Parent = "FakeRoad", WS

local function createRoad(fromPart, toPart)
    if not fromPart or not toPart then return end
    local startPos, endPos = fromPart.Position, toPart.Position
    local distance = (endPos - startPos).Magnitude
    local road = Instance.new("Part")
    road.Size = Vector3.new(2, 0.5, distance)
    road.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance/2)
    road.Anchored, road.CanCollide = true, false
    road.Transparency, road.Color = 1, Color3.fromRGB(50, 50, 50)
    road.Name, road.Parent = "FakeRoad", roadFolder
end

for _, lane in ipairs(lanes:GetChildren()) do
    if lane:FindFirstChild("spawn") and lane:FindFirstChild("final") then
        local checkpoints = { lane.spawn }
        local i = 1
        while lane:FindFirstChild(tostring(i)) do
            table.insert(checkpoints, lane[tostring(i)])
            i += 1
        end
        table.insert(checkpoints, lane.final)
        for idx = 1, #checkpoints-1 do
            createRoad(checkpoints[idx], checkpoints[idx+1])
        end
    end
end
----------------------------------------------------------------
-- ⚡ Auto Place (chuẩn logic gốc + UI placeCap)
----------------------------------------------------------------
if game.PlaceId ~= 107573139811370 then
    local UnitsFolder = WS:WaitForChild("_UNITS")
    local lanes = WS._BASES.pve.LANES
    local FakeRoad = WS:FindFirstChild("FakeRoad")
    local FailedFlags = {}

    -- Collect terrain
    local function collectTerrainParts(parent)
        local list = {}
        for _, obj in ipairs(parent:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                table.insert(list, obj)
            end
        end
        return list
    end

    local GroundAreas = collectTerrainParts(WS._terrain.ground)
    local HillAreas = collectTerrainParts(WS._terrain.hill)

    -- Raycast
    local function getSurfacePos(pos)
        local rayOrigin = pos + Vector3.new(0, 20, 0)
        local rayDir = Vector3.new(0, -100, 0)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {workspace._terrain}
        params.FilterType = Enum.RaycastFilterType.Whitelist
        local result = workspace:Raycast(rayOrigin, rayDir, params)
        return result and (result.Position + Vector3.new(0, 1.5, 0)) or nil
    end

    -- Check valid pos
    local function isValidPos(pos, unitType)
        for _, r in ipairs(FakeRoad:GetChildren()) do
            if r:IsA("BasePart") then
                local localPos = r.CFrame:PointToObjectSpace(pos)
                if math.abs(localPos.X) <= (r.Size.X/2 + 0.5)
                and math.abs(localPos.Y) <= (r.Size.Y/2 + 5)
                and math.abs(localPos.Z) <= (r.Size.Z/2 + 0.5) then
                    return false
                end
            end
        end
        for _, u in ipairs(UnitsFolder:GetChildren()) do
            if u:FindFirstChild("HumanoidRootPart") and u:FindFirstChild("_stats") then
                if u._stats:FindFirstChild("player") and u._stats.player.Value == LP then
                    if (u.HumanoidRootPart.Position - pos).Magnitude < 2 then
                        return false
                    end
                end
            end
        end
        for _, f in ipairs(FailedFlags) do
            if (f - pos).Magnitude < 1 then
                return false
            end
        end
        local surface = getSurfacePos(pos)
        if not surface then return false end
        return true
    end

    -- Count units
    local function countUnits(uuidMain)
        local c = 0
        for _, u in ipairs(UnitsFolder:GetChildren()) do
            if u.Name:sub(1,#uuidMain) == uuidMain then
                c += 1
            end
        end
        return c
    end

    -- Candidates
    local function getCandidatePositions(basePos, step, radius)
        local list = {}
        for x = -radius, radius, step do
            for z = -radius, radius, step do
                table.insert(list, basePos + Vector3.new(x, 0, z))
            end
        end
        return list
    end

    -- Best pos
    local function findBestPos(basePos, unitType)
        local candidates = getCandidatePositions(basePos, 2, 8)
        local best, bestDist
        for _, pos in ipairs(candidates) do
            local surface = getSurfacePos(pos)
            if surface and isValidPos(surface, unitType) then
                local dist = (surface - basePos).Magnitude
                if not best or dist < bestDist then
                    best, bestDist = surface, dist
                end
            end
        end
        return best
    end

    -- Checkpoints
    local function getCheckpoints()
        local cps = {}
        local lane = lanes["1"]
        if not lane then return cps end
        table.insert(cps, lane.spawn)
        local i = 1
        while lane:FindFirstChild(tostring(i)) do
            table.insert(cps, lane[tostring(i)])
            i += 1
        end
        table.insert(cps, lane.final)
        return cps
    end

    -- Enemy progress
    local function getEnemyProgress(enemy, cps)
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        if not hrp then return 0, cps[#cps] end
        for idx = 1, #cps-1 do
            local cp, nextCp = cps[idx], cps[idx+1]
            local d1 = (hrp.Position - cp.Position).Magnitude
            local d2 = (hrp.Position - nextCp.Position).Magnitude
            local segLen = (nextCp.Position - cp.Position).Magnitude
            if d1 < 8 then return idx, nextCp end
            if math.abs((d1 + d2) - segLen) < 10 then
                return idx, nextCp
            end
        end
        return #cps-1, cps[#cps]
    end

    -- Lead enemy
    local function getLeadEnemyAndTarget()
        local cps = getCheckpoints()
        if #cps < 2 then return nil, nil end
        local lead, leadTarget
        local bestProgress = -math.huge
        for _, m in ipairs(UnitsFolder:GetChildren()) do
            if m.Name:sub(1,3) == "pve" and m:FindFirstChild("HumanoidRootPart") then
                local idx, target = getEnemyProgress(m, cps)
                local hrp = m.HumanoidRootPart
                local cp = cps[idx]
                local distFromCp = (hrp.Position - cp.Position).Magnitude
                local progress = idx * 1000 - distFromCp
                if progress > bestProgress then
                    bestProgress = progress
                    lead, leadTarget = m, target
                end
            end
        end
        return lead, leadTarget
    end

    -- Auto Place Unit (dựa theo placeCap)
    local function autoPlace(unit, slotCap)
        if not unit.uuid then return end
        local maxCap = math.min(slotCap, unit.spawn_cap or 0)
        if countUnits(unit.uuid) >= maxCap then return end
        if LP._stats and LP._stats:FindFirstChild("resource") then
            if LP._stats.resource.Value < (unit.cost or 0) then return end
        end

        local lead, targetCp = getLeadEnemyAndTarget()
        if not lead or not targetCp then return end
        local anchorPos = targetCp.Position
        if unit.type == "HILL" then
            local nearest, dist = nil, math.huge
            for _, part in ipairs(HillAreas) do
                local d = (part.Position - lead.HumanoidRootPart.Position).Magnitude
                if d < dist then
                    dist, nearest = d, part
                end
            end
            if nearest then anchorPos = nearest.Position end
        end

        local bestPos = findBestPos(anchorPos, unit.type)
        if not bestPos then return end
        local before = countUnits(unit.uuid)
        RS.endpoints.client_to_server.spawn_unit:InvokeServer(
            unit.uuid,
            { Origin = bestPos, Direction = Vector3.new(0,-1,0) },
            0
        )
        task.wait(0.5)
        if countUnits(unit.uuid) == before then
            table.insert(FailedFlags, bestPos)
        end
    end

    -- Loop chính
    task.spawn(function()
        while task.wait(0.5) do
            if settings.smartAutoPlace then
                local equipped = getEquippedUnits()
                for _, unit in ipairs(equipped) do
                    local slotCap = (settings.placeCap and settings.placeCap[unit.slot]) or 0
                    local maxCap = math.min(slotCap, unit.spawn_cap or 0)

                    if countUnits(unit.uuid) < maxCap then
                        autoPlace(unit, slotCap)
                    end
                end
            end
        end
    end)

    ----------------------------------------------------------------
    -- ⚡ Auto Upgrade (ngay khi đủ tiền)
    ----------------------------------------------------------------
    local upgradeRemote = RS.endpoints.client_to_server:WaitForChild("upgrade_unit_ingame")

    local function getSlotMap()
        local equipped = getEquippedUnits()
        local slotMap = {}
        for _, u in ipairs(equipped) do
            slotMap[u.name] = {slot = u.slot, data = u}
        end
        return slotMap
    end

    local function pickRandomUnit()
        local slotMap = getSlotMap()
        local candidates = {}

        for _, m in ipairs(UnitsFolder:GetChildren()) do
            if m:IsA("Model") and not m.Name:lower():match("^pve") then
                local stats = m:FindFirstChild("_stats")
                if stats 
                    and stats:FindFirstChild("player") 
                    and stats.player.Value == LP
                    and stats:FindFirstChild("id") 
                    and stats:FindFirstChild("upgrade") then

                    local unitId = stats.id.Value
                    local info = slotMap[unitId]
                    if info then
                        local slot = info.slot
                        local currentUpg = stats.upgrade.Value
                        local cap = (settings.upgradeCap and settings.upgradeCap[slot]) or 0
                        local nextUpg = info.data.upgrades[currentUpg+1]

                        if currentUpg < cap and nextUpg then
                            local needCost = nextUpg.cost or 0
                            local money = LP._stats.resource.Value
                            if money >= needCost then
                                table.insert(candidates, {
                                    model = m,
                                    needCost = needCost
                                })
                            end
                        end
                    end
                end
            end
        end

        if #candidates == 0 then return nil end
        return candidates[math.random(1, #candidates)]
    end

    task.spawn(function()
        while task.wait(1) do
            if settings.smartAutoUpgrade then
                local choice = pickRandomUnit()
                if choice then
                    upgradeRemote:InvokeServer(choice.model.Name)
                    task.wait(0.5)
                end
            end
        end
    end)
end

----------------------------------------------------------------
--=================== UI ==========================--
----------------------------------------------------------------

local Window = MacLib:Window({
    Title = "Pịa Hub",
    Subtitle = "Vãi Pịa",
    Size = UDim2.fromOffset(650, 400),
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local TabGroup = Window:TabGroup()
local MainTab = TabGroup:Tab({ Name = "Main" })
local autoJoinSection = MainTab:Section({ Side = "Left", Title = "Auto Join" })
local portalSection   = MainTab:Section({ Side = "Left", Title = "Portal" })
local mainSection = MainTab:Section({ Side = "Right", Title = "End Game Settings" })
local eventSection = MainTab:Section({ Side = "Right", Title = "Event" })
local challengeSection = MainTab:Section({ Side = "Right", Title = "Challenge" })
local MacroTab = TabGroup:Tab({ Name = "Macro" })
local macroSection = MacroTab:Section({ Side = "Left", Title = "Macro Settings" })
local WebhookTab = TabGroup:Tab({ Name = "Webhook" })
local webhookSection = WebhookTab:Section({ Side = "Left", Title = "Webhook" })
local AutoPlayTab = TabGroup:Tab({ Name = "Auto Play" })
local smartSection = AutoPlayTab:Section({ Side = "Left", Title = "Smart Auto Place" })
local placeCapSection = AutoPlayTab:Section({ Side = "Right", Title = "Auto Place Cap" })
local upgradeCapSection = AutoPlayTab:Section({ Side = "Right", Title = "Auto Upgrade Cap" })
local MiscTab = TabGroup:Tab({ Name = "Misc" })
local settingSection = MiscTab:Section({ Side = "Left", Title = "Setting" })

-- Bảng map ứng với từng mode
local mapOptions = {
    story        = {"namek","marineford","karakura","shibuya"},
    infinite     = {"namek","marineford","karakura","shibuya"},
    ["legend stage"] = {"shibuya"},
    raid         = {"Sakamato"},
}

-- Khai báo biến để update dropdown map
local mapDropdown

-- Dropdown chọn Mode
autoJoinSection:Dropdown({
    Name = "Select Mode",
    Multi = false,
    Required = true,
    Options = {"story","infinite","legend stage","raid"},
    Default = settings.autoJoinMode or "story",
    Callback = function(val)
        settings.autoJoinMode = val
        saveSettings(settings)

        -- update dropdown Map theo mode
        local opts = mapOptions[val] or {}
        if mapDropdown then
            mapDropdown:SetDropdown(opts)
            if table.find(opts, settings.autoJoinMap) then
                mapDropdown:SetValue(settings.autoJoinMap)
            else
                -- reset về map đầu tiên nếu map cũ không hợp lệ
                settings.autoJoinMap = opts[1] or ""
                if settings.autoJoinMap ~= "" then
                    mapDropdown:SetValue(settings.autoJoinMap)
                end
                saveSettings(settings)
            end
        end
    end
})

-- Dropdown chọn Map
mapDropdown = autoJoinSection:Dropdown({
    Name = "Select Map",
    Multi = false,
    Required = true,
    Options = mapOptions[settings.autoJoinMode] or {},
    Default = (settings.autoJoinMap and table.find(mapOptions[settings.autoJoinMode] or {}, settings.autoJoinMap)) 
              and settings.autoJoinMap 
              or (mapOptions[settings.autoJoinMode] and mapOptions[settings.autoJoinMode][1]) 
              or "",
    Callback = function(val)
        settings.autoJoinMap = val
        saveSettings(settings)
    end
})

-- Dropdown chọn Difficulty
autoJoinSection:Dropdown({
    Name = "Select Difficulty",
    Multi = false,
    Required = true,
    Options = {"Normal","Hard"},
    Default = settings.autoJoinDiff or "Hard",
    Callback = function(val)
        settings.autoJoinDiff = val
        saveSettings(settings)
    end
})

-- Dropdown chọn Act
autoJoinSection:Dropdown({
    Name = "Select Act",
    Multi = false,
    Required = true,
    Options = {"Act 1","Act 2","Act 3","Act 4","Act 5","Act 6"},
    Default = settings.autoJoinAct or "Act 1",
    Callback = function(val)
        settings.autoJoinAct = val
        saveSettings(settings)
    end
})

-- Toggle Join Map
autoJoinSection:Toggle({
    Name = "Join Map",
    Default = settings.autoJoin or false,
    Callback = function(state)
        settings.autoJoin = state
        saveSettings(settings)
        if state then
            task.delay(1, RunAutoJoin) -- chạy 1 lần khi bật
        end
    end
})

-- Toggle Find Map
autoJoinSection:Toggle({
    Name = "Find Map",
    Default = settings.autoFind or false,
    Callback = function(state)
        settings.autoFind = state
        saveSettings(settings)
        if state then
            task.delay(1, RunAutoJoin) -- chạy 1 lần khi bật
        end
    end
})

-- Toggle Auto Start
autoJoinSection:Toggle({
    Name = "Auto Start",
    Default = settings.autoStart or false,
    Callback = function(state)
        settings.autoStart = state
        saveSettings(settings)
    end
})

-- Input Start In Seconds
autoJoinSection:Input({
    Name = "Start In Seconds",
    Placeholder = "1",
    Default = tostring(settings.startDelay or 1),
    AcceptedCharacters = "Numeric",
    Callback = function(val)
        settings.startDelay = tonumber(val) or 1
        saveSettings(settings)
    end
})

-- Dropdown chọn Portal
portalSection:Dropdown({
    Name = "Select Portal",
    Multi = false,
    Required = true,
    Options = {"Marine Ford Portal"},
    Default = settings.selectedPortal or "Marine Ford Portal",
    Callback = function(val)
        settings.selectedPortal = val
        saveSettings(settings)
    end
})

-- Toggle Auto Join Portal
portalSection:Toggle({
    Name = "Auto Join Portal",
    Default = settings.autoJoinPortal or false,
    Callback = function(state)
        settings.autoJoinPortal = state
        saveSettings(settings)
    end
})

mainSection:Toggle({
    Name = "Next",
    Default = settings.next,
    Callback = function(state)
        settings.next = state
        saveSettings(settings)
    end
})

mainSection:Toggle({
    Name = "Replay",
    Default = settings.replay,
    Callback = function(state)
        settings.replay = state
        saveSettings(settings)
    end
})

mainSection:Toggle({
    Name = "Return to Lobby",
    Default = settings.returnLobby,
    Callback = function(state)
        settings.returnLobby = state
        saveSettings(settings)
    end
})

eventSection:Dropdown({
    Name = "Select Gate",
    Multi = true,
    Required = false,
    Options = {"C","D","B","A","S","National"},
    Default = settings.selectedGates or {}, -- ví dụ {"C","A"}
    Callback = function(selected)
        -- Convert table {["C"]=true,["B"]=false,...} thành array {"C","A"}
        local values = {}
        for v, state in pairs(selected) do
            if state then table.insert(values, v) end
        end
        settings.selectedGates = values
        saveSettings(settings)
    end
})

-- Single Dropdown chọn Type
eventSection:Dropdown({
    Name = "Select Type",
    Multi = false,
    Required = true,
    Options = {"High Gate","Random Gate","Low Gate"},
    Default = settings.selectedType or "High Gate",
    Callback = function(val)
        settings.selectedType = val
        saveSettings(settings)
    end
})

-- Toggle Auto Gate
eventSection:Toggle({
    Name = "Auto Gate",
    Default = settings.autoGate or false,
    Callback = function(state)
        settings.autoGate = state
        saveSettings(settings)
    end
})

-- Toggle Auto Find Gate
eventSection:Toggle({
    Name = "Auto Find Gate",
    Default = settings.autoFindGate or false,
    Callback = function(state)
        settings.autoFindGate = state
        saveSettings(settings)
    end
})

-- Multi Dropdown Ignore Challenge
challengeSection:Dropdown({
    Name = "Ignore Challenge",
    Multi = true,
    Required = false,
    Options = {"double_cost", "short_range", "fast_enemies", "regen_enemies", "tank_enemies", "shield_enemies"},
    Default = settings.ignoreChallenge or {},
    Callback = function(selected)
        -- Convert table {["double_cost"]=true,["fast_enemies"]=false,...} thành array {"double_cost",...}
        local values = {}
        for v, state in pairs(selected) do
            if state then table.insert(values, v) end
        end
        settings.ignoreChallenge = values
        saveSettings(settings)
    end
})

-- Toggle Auto Join Challenge
challengeSection:Toggle({
    Name = "Auto Join Challenge",
    Default = settings.autoJoinChallenge or false,
    Callback = function(state)
        settings.autoJoinChallenge = state
        saveSettings(settings)
    end
})

-- Toggle Auto Leave Challenge
challengeSection:Toggle({
    Name = "Auto Leave Challenge",
    Default = settings.autoLeaveChallenge or false,
    Callback = function(state)
        settings.autoLeaveChallenge = state
        saveSettings(settings)
    end
})

-- Dropdown tham chiếu để update
local macroDropdown
local function refreshDropdown()
    if macroDropdown then
        macroDropdown:SetDropdown(listMacros())
    end
end

macroSection:Input({
    Name        = "create macro",
    Placeholder = "Name Macro",
    Default     = "",
    Callback    = function(val)
        local safeName = val:gsub("[^%w_]", "")
        if safeName == "" then return end
        local path = macroFolder.."/"..safeName..".json"
        if not isfile(path) then
            writefile(path, HttpService:JSONEncode({}))
        end
        refreshDropdown()
    end
})

macroDropdown = macroSection:Dropdown({
    Name     = "select macro",
    Options  = listMacros(),
    Multi    = false,
    Default  = settings.selectedMacro,
    Callback = function(option)
        settings.selectedMacro = option
        saveSettings(settings)
    end
})

task.spawn(function()
    while task.wait(1) do refreshDropdown() end
end)

macroSection:Toggle({
    Name    = "record",
    Default = false,
    Callback = function(state)
        if state then
            Recording = true
            MacroData = {}
        else
            Recording = false
            saveMacroData(settings.selectedMacro)
        end
    end
})

macroSection:Toggle({
    Name    = "play macro",
    Default = settings.playMacro,
    Callback = function(state)
        settings.playMacro = state
        saveSettings(settings)

        if state then
            task.spawn(function()
                PlayMacro(settings.selectedMacro)
            end)
        else
            StopMacro()
        end
    end
})

-- Input link webhook
webhookSection:Input({
    Name = "Link Webhook",
    Placeholder = "Nhập link webhook...",
    Default = settings.webhookLink or "",
    Callback = function(val)
        settings.webhookLink = val
        saveSettings(settings)
    end
})

-- Toggle send webhook
webhookSection:Toggle({
    Name = "Send Webhook",
    Default = settings.sendWebhook or false,
    Callback = function(state)
        settings.sendWebhook = state
        saveSettings(settings)
    end
})

-- Button Test Webhook
webhookSection:Button({
    Name = "Test Webhook",
    Callback = function()
        sendWebhook()
    end
})


local RS = game:GetService("ReplicatedStorage")
local FX_CACHE = RS:WaitForChild("_FX_CACHE")
local moduleCache = {}

local function findModule(unitId)
    if moduleCache[unitId] then
        return moduleCache[unitId]
    end
    local Units = RS.Framework.Data.Units
    for _, folder in ipairs(Units:GetChildren()) do
        for _, mod in ipairs(folder:GetChildren()) do
            if mod:IsA("ModuleScript") then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    for _, v in pairs(data) do
                        if type(v) == "table" and v.id == unitId then
                            moduleCache[unitId] = {
                                raw = v,
                                id = v.id,
                                cost = v.cost or 0,
                                spawn_cap = v.spawn_cap,
                                hill_unit = v.hill_unit,
                                upgrade = v.upgrade
                            }
                            return moduleCache[unitId]
                        end
                    end
                end
            end
        end
    end
end

local function getEquippedUnits()
    local equippedList = {}
    for _, frame in ipairs(FX_CACHE:GetChildren()) do
        if frame:IsA("ImageButton") then
            local equippedFlag = frame:FindFirstChild("EquippedList") 
                and frame.EquippedList:FindFirstChild("Equipped")
            if equippedFlag and equippedFlag.Visible then
                local unitName = frame:GetAttribute("ITEMINDEX")
                local uuidObj = frame:FindFirstChild("_uuid")
                local uuid = uuidObj and uuidObj.Value
                local data = findModule(unitName)
                table.insert(equippedList, {
                    name = unitName,
                    uuid = uuid,
                    cost = data and data.cost,
                    type = data and (data.hill_unit and "HILL" or "GROUND") or "???",
                    spawn_cap = data and data.spawn_cap,
                    upgrades = data and data.upgrade or {}
                })
            end
        end
    end
    return equippedList
end

local roadFolder
local zoneFolder

local function clearZones()
    if zoneFolder then
        zoneFolder:Destroy()
        zoneFolder = nil
    end
end

local function createRoadIfNeeded(lane)
    if not roadFolder or not roadFolder.Parent then
        roadFolder = Instance.new("Folder")
        roadFolder.Name = "DebugRoad"
        roadFolder.Parent = lane

        -- (dùng code createRoad nối checkpoint như trước nhưng set Transparency=1 để ẩn)
    end
end

local function showPlacementZone(checkpoint, units)
    clearZones()
    zoneFolder = Instance.new("Folder")
    zoneFolder.Name = "PlacementZones"
    zoneFolder.Parent = workspace

    -- Vùng tròn
    local totalCap = 0
    for _, u in ipairs(units) do
        totalCap += u.spawn_cap or 0
    end
    local radius = math.max(5, totalCap * 3)

    local zone = Instance.new("Part")
    zone.Shape = Enum.PartType.Cylinder
    zone.Anchored = true
    zone.CanCollide = false
    zone.Size = Vector3.new(radius*2, 0.5, radius*2)
    zone.CFrame = CFrame.new(Vector3.new(checkpoint.Position.X, checkpoint.Position.Y + 0.25, checkpoint.Position.Z)) * CFrame.Angles(0, math.rad(90), 0)
    zone.Color = Color3.fromRGB(0,255,0)
    zone.Transparency = 0.8
    zone.Parent = zoneFolder

    -- Tạo part con đại diện cho unit
    for _, u in ipairs(units) do
        for i = 1, u.spawn_cap or 0 do
            local px = math.random(-radius, radius)
            local pz = math.random(-radius, radius)
            local pos = checkpoint.Position + Vector3.new(px, 2, pz)

            local part = Instance.new("Part")
            part.Anchored = true
            part.CanCollide = false
            part.Size = Vector3.new(0.5,0.5,0.5)
            if u.type == "GROUND" then
                part.Color = Color3.fromRGB(255,0,0)
            else
                part.Color = Color3.fromRGB(0,0,255)
            end
            part.Position = pos
            part.Parent = zoneFolder
        end
    end
end

--// AUTO PLAY UI
smartSection:Toggle({
    Name = "Auto Place",
    Default = settings.smartAutoPlace or false,
    Callback = function(state)
        settings.smartAutoPlace = state
        saveSettings(settings)
    end
})

smartSection:Toggle({
    Name = "Auto Upgrade",
    Default = settings.smartAutoUpgrade or false,
    Callback = function(state)
        settings.smartAutoUpgrade = state
        saveSettings(settings)
    end
})

-- Auto Place Cap
for i = 1, 6 do
    placeCapSection:Input({
        Name = "Unit " .. i,
        Placeholder = "",
        Default = tostring((settings.placeCap and settings.placeCap[i]) or 4),
        AcceptedCharacters = "Numeric",
        Callback = function(val)
            settings.placeCap = settings.placeCap or {}
            settings.placeCap[i] = tonumber(val) or 0
            saveSettings(settings)
        end,
    })
end

-- Auto Upgrade Cap
for i = 1, 6 do
    upgradeCapSection:Input({
        Name = "Unit " .. i,
        Placeholder = "",
        Default = tostring((settings.upgradeCap and settings.upgradeCap[i]) or 0),
        AcceptedCharacters = "Numeric",
        Callback = function(val)
            settings.upgradeCap = settings.upgradeCap or {}
            settings.upgradeCap[i] = tonumber(val) or 0
            saveSettings(settings)
        end,
    })
end

settingSection:Toggle({
    Name = "Auto Execute",
    Default = settings.autoExecute or false,
    Callback = function(state)
        settings.autoExecute = state
        saveSettings(settings)

        if state then
            queue_on_teleport([[
                loadstring(game:HttpGet('https://raw.githubusercontent.com/thaemmayanh/hub/refs/heads/main/AC.lua'))()
            ]])
        end
    end
})

-- Toggle Smooth Map
settingSection:Toggle({
    Name = "Smooth Map",
    Default = settings.smoothMap or false,
    Callback = function(state)
        settings.smoothMap = state
        saveSettings(settings)

        if state then
            -- Khi bật thì load script Smooth Map
            loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/hub/refs/heads/main/smootth.lua"))()
        end
    end
})
