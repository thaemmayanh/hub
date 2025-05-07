local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.Modules.DataService)
local BuyEggEvent = ReplicatedStorage.GameEvents.BuyPetEgg

local eggName = "Common Egg"
local waitTime = 1

while true do
    local success, result = pcall(function()
        return DataService:GetData()
    end)

    if success and result.PetEggStock and result.PetEggStock.Stocks then
        local bought = false

        for index, egg in pairs(result.PetEggStock.Stocks) do
            if egg.EggName == eggName and egg.Stock > 0 then
                BuyEggEvent:FireServer(index)
                bought = true
                wait(waitTime)
                break -- chờ lần reload sau khi mua
            end
        end

        if not bought then
            -- Không mua được, chờ 20s rồi thử lại
            wait(5)
        end
    else
        warn("⚠️ Không thể lấy dữ liệu từ DataService.")
        wait(10)
    end
end

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new(0, 0))
end)
