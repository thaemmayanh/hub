repeat task.wait() until game:IsLoaded()

-- 🧼 Xoá GUI cũ nếu tồn tại
pcall(function()
    local oldUI = game.CoreGui:FindFirstChild("MacLib")
    if oldUI then oldUI:Destroy() end
end)

getgenv()._PiaHubarxLoaded = true

--// Services
local HttpService = game:GetService("HttpService")

--// Lib
local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/thaem/refs/heads/main/lib"))()

--// Setup Settings
local folderName   = "PIAHUB"
local macroFolder  = folderName.."/Macro"
local fileName     = "settings.json"

-- Tạo folder nếu chưa có
if not isfolder(folderName) then makefolder(folderName) end
if not isfolder(macroFolder) then makefolder(macroFolder) end

-- Default settings (chỉ giữ 2 key cơ bản)
local defaultSettings = {
    selectedMacro = "",
    playMacro     = false,
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Hàm lấy danh sách macro (không kèm .json)
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

--// Record & Play Macro
local spawnRemote = ReplicatedStorage
    :WaitForChild("endpoints")
    :WaitForChild("client_to_server")
    :WaitForChild("spawn_unit")

-- Biến điều khiển
local Recording = false
local MacroData = {}
local pendingRecords = {}

----------------------------------------------------------------
-- Hàm phụ trợ
----------------------------------------------------------------
-- Chuyển Vector3 -> table
local function vecToTable(v)
    return {x = v.X, y = v.Y, z = v.Z}
end

-- Chuyển table -> Vector3
local function tableToVec(t)
    if not t then return Vector3.new(0,0,0) end
    return Vector3.new(t.x, t.y, t.z)
end

-- Lấy tiền hiện có từ resource
local function getCurrentMoney()
    local stats = LocalPlayer:FindFirstChild("_stats")
    if stats and stats:FindFirstChild("resource") then
        return stats.resource.Value
    end
    return 0
end

----------------------------------------------------------------
-- Bắt Cost từ GUI MoneyChange
----------------------------------------------------------------
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local moneyFolder = PlayerGui:WaitForChild("spawn_units")
    :WaitForChild("Lives")
    :WaitForChild("Frame")
    :WaitForChild("Resource")
    :WaitForChild("Money")

moneyFolder.ChildAdded:Connect(function(child)
    if child.Name == "MoneyChange" and #pendingRecords > 0 then
        local textObj = child:WaitForChild("text", 1)
        if textObj then
            local raw = textObj.Text
            local clean = raw:gsub("%+", ""):gsub("[^%d%-]", "")
            local num = tonumber(clean) or 0
            if num < 0 then
                -- lấy record đầu tiên trong queue
                local rec = table.remove(pendingRecords, 1)
                rec.Cost = -num
            end
        end
    end
end)

----------------------------------------------------------------
-- Hook đặt unit để log vào MacroData
----------------------------------------------------------------
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if self == spawnRemote and method == "InvokeServer" and Recording then
        local recordEntry = {
            UnitId    = args[1],
            Origin    = vecToTable(args[2].Origin),
            Direction = vecToTable(args[2].Direction),
            Slot      = args[3],
            Cost      = 0 -- cập nhật sau khi MoneyChange xuất hiện
        }
        table.insert(MacroData, recordEntry)
        table.insert(pendingRecords, recordEntry)
    end

    return oldNamecall(self, ...)
end
setreadonly(mt, true)

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
-- Play Macro
----------------------------------------------------------------
local function PlayMacro(macroName)
    local data = loadMacroData(macroName)
    if #data == 0 then return end

    for _, job in ipairs(data) do
        -- Chờ đủ tiền
        repeat task.wait(0.2) until getCurrentMoney() >= job.Cost

        spawnRemote:InvokeServer(
            job.UnitId,
            {
                Origin    = tableToVec(job.Origin),
                Direction = tableToVec(job.Direction)
            },
            job.Slot
        )

        task.wait(0.5) -- delay nhỏ để tránh spam
    end
end

----------------------------------------------------------------
--===================  UI PHÍA DƯỚI  ==========================--
----------------------------------------------------------------

local Window = MacLib:Window({
    Title = "Pịa Hub",
    Subtitle = "Vãi Pịa",
    Size = UDim2.fromOffset(650, 400),
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local TabGroup     = Window:TabGroup()
local MacroTab     = TabGroup:Tab({ Name = "Macro" })
local macroSection = MacroTab:Section({ Side = "Left", Title = "Macro Settings" })

-- Dropdown tham chiếu để update
local macroDropdown
local function refreshDropdown()
    if not macroDropdown then return end
    macroDropdown:SetDropdown(listMacros())
end

-- Input: Create Macro
macroSection:Input({
    Name        = "create macro",
    Placeholder = "Nhập tên macro...",
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

-- Dropdown: Select Macro
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

-- Auto refresh mỗi 1 giây
task.spawn(function()
    while task.wait(1) do
        refreshDropdown()
    end
end)

-- Toggle: Record
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

-- Toggle: Play
macroSection:Toggle({
    Name    = "play macro",
    Default = settings.playMacro,
    Callback = function(state)
        settings.playMacro = state
        saveSettings(settings)
        if state then
            PlayMacro(settings.selectedMacro)
            settings.playMacro = false
            saveSettings(settings)
        end
    end
})
