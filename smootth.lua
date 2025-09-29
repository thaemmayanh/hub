-- 🌙 Optimize Map (cho map toàn Mesh)
local WS = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Hàm xoá VFX & texture
local function clearMap(obj)
    for _, v in ipairs(obj:GetDescendants()) do
        -- Xoá hiệu ứng
        if v:IsA("ParticleEmitter")
        or v:IsA("Trail")
        or v:IsA("Beam")
        or v:IsA("Smoke")
        or v:IsA("Fire")
        or v:IsA("Explosion")
        or v:IsA("Sparkles")
        or v:IsA("Highlight") then
            v:Destroy()

        -- Xoá decal/texture
        elseif v:IsA("Decal")
        or v:IsA("Texture")
        or v:IsA("SurfaceAppearance") then
            v:Destroy()

        -- Là MeshPart thì reset
        elseif v:IsA("MeshPart") then
            v.TextureID = ""
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0

        -- UnionOperation
        elseif v:IsA("UnionOperation") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0

        -- SpecialMesh
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        end
    end
end

-- Dọn map
clearMap(WS)

-- Dọn FX folder
pcall(function()
    if WS:FindFirstChild("FX") then WS.FX:ClearAllChildren() end
    if WS:FindFirstChild("_FX_CACHE") then WS._FX_CACHE:ClearAllChildren() end
end)

-- 🔆 Chỉnh Lighting (KHÔNG xoá child để tránh bug GUI game)
Lighting.Brightness = 2
Lighting.GlobalShadows = false
Lighting.FogEnd = 1e9
Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
