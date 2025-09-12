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
local pendingRecord = nil

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

-- Lấy tiền hiện có
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
    if child.Name == "MoneyChange" and pendingRecord then
        local textObj = child:WaitForChild("text", 1)
        if textObj then
            local raw = textObj.Text
            local clean = raw:gsub("%+", ""):gsub("[^%d%-]", "")
            local num = tonumber(clean) or 0
            if num < 0 then
                pendingRecord.Cost = -num
                warn(("💸 Recorded %s | Cost %d"):format(pendingRecord.UnitId, pendingRecord.Cost))
                pendingRecord = nil
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
        pendingRecord = recordEntry
    end

    return oldNamecall(self, ...)
end
setreadonly(mt, true)

----------------------------------------------------------------
-- Save & Load MacroData
----------------------------------------------------------------
local function saveMacroData(macroName)
    if macroName == "" then
        warn("⚠️ Chưa chọn macro để lưu")
        return
    end
    local path = macroFolder.."/"..macroName..".json"
    writefile(path, HttpService:JSONEncode(MacroData))
    warn(("💾 Đã lưu macro %s | Jobs: %d"):format(macroName, #MacroData))
end

local function loadMacroData(macroName)
    local path = macroFolder.."/"..macroName..".json"
    if not isfile(path) then
        warn("⚠️ Macro chưa tồn tại:", macroName)
        return {}
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and data then
        return data
    else
        return {}
    end
end

----------------------------------------------------------------
-- Play Macro
local function PlayMacro(macroName)
    local data = loadMacroData(macroName)
    if #data == 0 then
        warn("⚠️ Macro rỗng:", macroName)
        return
    end
    warn(("▶️ Play macro %s | Tổng jobs: %d"):format(macroName, #data))
    for _, job in ipairs(data) do
        -- Đợi đủ tiền
        repeat task.wait(0.2) until getCurrentMoney() >= job.Cost

        -- Check lần cuối ngay trước khi đặt
        while getCurrentMoney() < job.Cost do
            task.wait(0.2)
        end

        spawnRemote:InvokeServer(
            job.UnitId,
            {
                Origin    = tableToVec(job.Origin),
                Direction = tableToVec(job.Direction)
            },
            job.Slot
        )
        warn(("✅ Đặt unit %s | Cost %d"):format(job.UnitId, job.Cost))

        -- Delay nhỏ để tránh spam
        task.wait(.7)
    end
    warn("⏹️ Play macro xong:", macroName)
end

----------------------------------------------------------------
--===================  UI PHÍA DƯỚI  ==========================--
----------------------------------------------------------------

--// Tạo Window
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

-- Hàm refresh dropdown
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
            warn("📁 Đã tạo macro:", safeName)
        else
            warn("⚠️ Macro đã tồn tại:", safeName)
        end
        refreshDropdown() -- cập nhật ngay khi tạo
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
        print("Chọn macro:", option)
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
            -- Bắt đầu record
            Recording = true
            MacroData = {}
            warn("🔴 Bắt đầu Record")
        else
            -- Dừng record và lưu
            Recording = false
            saveMacroData(settings.selectedMacro)
            warn("🟢 Dừng Record, dữ liệu đã lưu")
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
