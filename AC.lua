repeat task.wait() until game:IsLoaded()

-- 🧼 Xoá GUI cũ nếu tồn tại
pcall(function()
    local oldUI = game.CoreGui:FindFirstChild("MacLib")
    if oldUI then oldUI:Destroy() end
    local oldWin = game.CoreGui:FindFirstChild("ScreenGui")
    if oldWin then oldWin:Destroy() end
end)

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

--// Lib
local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/thaem/refs/heads/main/lib"))()

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
}

-- Hàm load/save settings
local function loadSettings()
    if isfile(folderName.."/"..fileName) then
        return HttpService:JSONDecode(readfile(folderName.."/"..fileName))
    else
        writefile(folderName.."/"..fileName, HttpService:JSONEncode(defaultSettings))
        return table.clone(defaultSettings)
    end
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

-- Loop chạy auto
task.spawn(function()
    while task.wait(3) do
        if settings.autoGate or settings.autoFindGate then
            AutoLobby()
            AutoInGame()
        end
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
local mainSection = MainTab:Section({ Side = "Left", Title = "End Game Settings" })
local eventSection = MainTab:Section({ Side = "Right", Title = "Event" })
local MacroTab = TabGroup:Tab({ Name = "Macro" })
local macroSection = MacroTab:Section({ Side = "Left", Title = "Macro Settings" })
local WebhookTab = TabGroup:Tab({ Name = "Webhook" })
local webhookSection = WebhookTab:Section({ Side = "Left", Title = "Webhook" })

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
