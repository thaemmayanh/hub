repeat wait() until game:IsLoaded()

local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/thaemmayanh/thaem/refs/heads/main/lib"))()

local Window = MacLib:Window({
    Title = "Dril",
    Size = UDim2.fromOffset(500, 400),
    Keybind = Enum.KeyCode.RightControl
})

local MainTabGroup = Window:TabGroup()
local MainTab = MainTabGroup:Tab({ Name = "Main" })
local Section = MainTab:Section({ Side = "Left" })

-- Auto Drill
local autoDrill = false
Section:Toggle({
    Name = "Auto Drill",
    Callback = function(state)
        autoDrill = state
        task.spawn(function()
            while autoDrill do
                game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit")
                    :WaitForChild("Services"):WaitForChild("OreService"):WaitForChild("RE")
                    :WaitForChild("RequestRandomOre"):FireServer()
                task.wait(0.01)
            end
        end)
    end
})

-- Auto Collect với logic mới
local autoCollect = false
Section:Toggle({
    Name = "Auto Collect",
    Callback = function(state)
        autoCollect = state
        task.spawn(function()
            while autoCollect do
                local player = game.Players.LocalPlayer
                local myPlot = nil

                -- Tìm plot của bạn
                for _, plot in pairs(workspace.Plots:GetChildren()) do
                    if plot:FindFirstChild("Owner") and plot.Owner.Value == player then
                        myPlot = plot
                        break
                    end
                end

                if not myPlot then
                    warn("Không tìm thấy plot của bạn.")
                    return
                end

                -- Hàm collect
                local function collect(obj)
                    local re = game:GetService("ReplicatedStorage")
                        :WaitForChild("Packages")
                        :WaitForChild("Knit")
                        :WaitForChild("Services")
                        :WaitForChild("PlotService")
                        :WaitForChild("RE")
                        :WaitForChild("CollectDrill")
                    re:FireServer(obj)
                end

                -- Duyệt qua Storage và Drills
                for _, folderName in ipairs({ "Storage", "Drills" }) do
                    local folder = myPlot:FindFirstChild(folderName)
                    if folder then
                        for _, obj in pairs(folder:GetChildren()) do
                            if obj:IsA("Model") or obj:IsA("Part") then
                                collect(obj)
                            end
                        end
                    end
                end

                task.wait(1)
            end
        end)
    end
})
