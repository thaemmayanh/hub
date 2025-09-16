repeat task.wait() until game:IsLoaded()

-- 🧼 Xoá GUI cũ nếu tồn tại
if getgenv()._PiaHubarxLoaded then return end
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
local voteRemote = ReplicatedStorage:WaitForChild("endpoints"):WaitForChild("client_to_server"):WaitForChild("set_game_finished_vote")

local function DoJobs()
    task.spawn(function()
        local gui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ResultsUI")
        while task.wait(1) do
            -- Bỏ qua nếu đang ở lobby
            if game.PlaceId ~= 107573139811370 and gui.Enabled then
                -- Ưu tiên next → replay → return
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
                -- Đợi GUI tắt rồi mới quay lại vòng tiếp theo
                repeat task.wait(1) until not gui.Enabled
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
            local d = (m.HumanoidRootPart.Position - cf.Position).Magnitude
            if d <= minD then
                minD, target = d, m
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
    if spent and idVal then
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

            task.wait(0.5)
        end
    end

    if session == CurrentSession then
        Playing = false
        VoteTriggered = false
    end
end

-- hook remote
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
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
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)

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
