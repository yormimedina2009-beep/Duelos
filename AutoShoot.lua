-- ============================================
-- KIRITTO AUTO SHOOT - Rayfield UI Edition
-- Juego: DUELOS [SHERIFF VS MURDER]
-- ============================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do task.wait(0.5); LocalPlayer = Players.LocalPlayer end

-- Destruir GUI antigua si existe
if game:GetService("CoreGui"):FindFirstChild("Rayfield") then
    game:GetService("CoreGui").Rayfield:Destroy()
end

-- ============================================
-- CARGAR RAYFIELD UI
-- ============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================
-- CONFIGURACIÓN
-- ============================================
local Config = {
    SilentAim = true,
    AutoShoot = true,
    FOV = 150,
    HitboxPart = "Head",
    VisibleCheck = true,
    Prediction = true,
    AutoFireDelay = 0.1,
    ShowFOV = true,
    ESPColor = Color3.fromRGB(0, 212, 255),
}

local lastShot = 0
local currentTarget = nil

-- ============================================
-- FUNCIONES ÚTILES
-- ============================================
local function getHRP(plr)
    local char = plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getEquippedTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function esEnemigo(plr)
    if plr == LocalPlayer then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if plr.Team and LocalPlayer.Team then
        return plr.Team ~= LocalPlayer.Team
    end
    return true
end

-- ============================================
-- PREDICCIÓN
-- ============================================
local function predecirPosicion(part, velocidadBala)
    if not Config.Prediction then return part.Position end
    local velocidad = part.AssemblyLinearVelocity
    if velocidad.Magnitude < 1 then return part.Position end
    local miHRP = getHRP(LocalPlayer)
    if not miHRP then return part.Position end
    local distancia = (part.Position - miHRP.Position).Magnitude
    local tiempoVuelo = distancia / velocidadBala
    return part.Position + (velocidad * tiempoVuelo)
end

-- ============================================
-- VISIBILIDAD
-- ============================================
local function esVisible(targetPart)
    if not Config.VisibleCheck then return true end
    local miHRP = getHRP(LocalPlayer)
    if not miHRP then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

    local direccion = targetPart.Position - Camera.CFrame.Position
    local resultado = workspace:Raycast(Camera.CFrame.Position, direccion, params)

    if resultado then
        local hitChar = resultado.Instance:FindFirstAncestorOfClass("Model")
        local hitPlr = hitChar and Players:GetPlayerFromCharacter(hitChar)
        return hitPlr and hitPlr == Players:GetPlayerFromCharacter(targetPart.Parent)
    end
    return true
end

-- ============================================
-- BUSCAR OBJETIVO
-- ============================================
local function buscarObjetivo()
    local mejorTarget = nil
    local mejorDistancia = math.huge
    local centro = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if esEnemigo(plr) then
            local char = plr.Character
            local partBuscada = char and char:FindFirstChild(Config.HitboxPart)
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if partBuscada and hum and hum.Health > 0 then
                local posPredicha = Config.Prediction and
                    predecirPosicion(partBuscada, 500) or partBuscada.Position

                local screenPos, onScreen = Camera:WorldToViewportPoint(posPredicha)

                if onScreen then
                    local distPantalla = (Vector2.new(screenPos.X, screenPos.Y) - centro).Magnitude
                    if distPantalla < Config.FOV then
                        if esVisible(partBuscada) then
                            local miHRP = getHRP(LocalPlayer)
                            local distReal = miHRP and (miHRP.Position - partBuscada.Position).Magnitude or math.huge
                            if distReal < mejorDistancia then
                                mejorDistancia = distReal
                                mejorTarget = plr
                            end
                        end
                    end
                end
            end
        end
    end
    return mejorTarget
end

-- ============================================
-- SILENT AIM
-- ============================================
local mt = getrawmetatable(game)
if mt then
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if Config.SilentAim and (method == "FindPartOnRay" or
            method == "FindPartOnRayWithIgnoreList" or
            method == "FindPartOnRayWithWhitelist") then
            if currentTarget then
                local char = currentTarget.Character
                local part = char and char:FindFirstChild(Config.HitboxPart)
                if part then
                    local args = {...}
                    local origin = args[1]
                    if typeof(origin) == "Ray" then
                        local nuevaDireccion = (part.Position - origin.Origin).Unit * 1000
                        args[1] = Ray.new(origin.Origin, nuevaDireccion)
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- ============================================
-- LOOP PRINCIPAL
-- ============================================
RunService.RenderStepped:Connect(function()
    if Config.SilentAim or Config.AutoShoot then
        currentTarget = buscarObjetivo()
    else
        currentTarget = nil
    end

    if Config.AutoShoot and currentTarget then
        if tick() - lastShot < Config.AutoFireDelay then return end
        local tool = getEquippedTool()
        if tool then
            pcall(function() tool:Activate() end)
            lastShot = tick()
        end
    end
end)

-- ============================================
-- CÍRCULO FOV
-- ============================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.NumSides = 80
fovCircle.Radius = Config.FOV
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircle.Color = Config.ESPColor
fovCircle.Visible = false

RunService.RenderStepped:Connect(function()
    if Config.ShowFOV then
        fovCircle.Visible = true
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Radius = Config.FOV
        if currentTarget then
            fovCircle.Color = Color3.fromRGB(255, 50, 50)
            fovCircle.Thickness = 3
        else
            fovCircle.Color = Config.ESPColor
            fovCircle.Thickness = 2
        end
    else
        fovCircle.Visible = false
    end
end)

-- ============================================
-- INTERFAZ RAYFIELD
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "Kiritto Hub",
    LoadingTitle = "Kiritto Hub",
    LoadingSubtitle = "by yormimedina2009",
    Theme = "Default",
    ToggleUIKeybind = "K", -- Tecla para abrir/cerrar la interfaz
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "KirittoHub",
        FileName = "AutoShootConfig"
    },
})

-- Pestaña principal
local MainTab = Window:CreateTab("Combat", 4483362458) -- Icono de espada (ID de Roblox)

-- Sección de Aimbot
MainTab:CreateSection("Aimbot")

local SilentAimToggle = MainTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = Config.SilentAim,
    Flag = "SilentAim",
    Callback = function(value)
        Config.SilentAim = value
    end,
})

local AutoShootToggle = MainTab:CreateToggle({
    Name = "Auto Shoot",
    CurrentValue = Config.AutoShoot,
    Flag = "AutoShoot",
    Callback = function(value)
        Config.AutoShoot = value
    end,
})

local PredictionToggle = MainTab:CreateToggle({
    Name = "Predicción de movimiento",
    CurrentValue = Config.Prediction,
    Flag = "Prediction",
    Callback = function(value)
        Config.Prediction = value
    end,
})

local VisibleCheckToggle = MainTab:CreateToggle({
    Name = "Verificar visibilidad",
    CurrentValue = Config.VisibleCheck,
    Flag = "VisibleCheck",
    Callback = function(value)
        Config.VisibleCheck = value
    end,
})

-- Sección de Configuración
MainTab:CreateSection("Configuración")

local FOVSlider = MainTab:CreateSlider({
    Name = "FOV",
    Range = {30, 500},
    Increment = 10,
    Suffix = "°",
    CurrentValue = Config.FOV,
    Flag = "FOV",
    Callback = function(value)
        Config.FOV = value
    end,
})

local DelaySlider = MainTab:CreateSlider({
    Name = "Delay entre disparos",
    Range = {1, 30},
    Increment = 1,
    Suffix = " ms",
    CurrentValue = Config.AutoFireDelay * 100,
    Flag = "AutoFireDelay",
    Callback = function(value)
        Config.AutoFireDelay = value / 100
    end,
})

-- Sección de Apariencia
MainTab:CreateSection("Apariencia")

local ShowFOVToggle = MainTab:CreateToggle({
    Name = "Mostrar círculo FOV",
    CurrentValue = Config.ShowFOV,
    Flag = "ShowFOV",
    Callback = function(value)
        Config.ShowFOV = value
    end,
})

local ColorPicker = MainTab:CreateColorPicker({
    Name = "Color del FOV",
    Color = Config.ESPColor,
    Flag = "ESPColor",
    Callback = function(color)
        Config.ESPColor = color
    end,
})

-- ============================================
-- NOTIFICACIÓN DE BIENVENIDA
-- ============================================
task.wait(1)
Rayfield:Notify({
    Title = "Kiritto Hub",
    Content = "Auto Shoot cargado correctamente. Presiona K para abrir el menú.",
    Duration = 5,
    Image = 4483362458,
})

print("✅ Kiritto Auto Shoot con Rayfield cargado")
