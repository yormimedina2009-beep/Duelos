-- ============================================
-- KIRITTO AUTO SHOOT v2.0
-- Juego: DUELOS [SHERIFF VS MURDER]
-- Optimizado para móvil
-- ============================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do task.wait(0.5); LocalPlayer = Players.LocalPlayer end

if CoreGui:FindFirstChild("KirittoAutoShoot") then
    CoreGui.KirittoAutoShoot:Destroy()
end

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
    -- Mobile
    ButtonSize = 55,
    ButtonPosition = UDim2.new(0, 20, 0.5, -30),
}

-- ============================================
-- VARIABLES
-- ============================================
local lastShot = 0
local currentTarget = nil
local guiOpen = false

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
-- FOV CIRCLE (más grande para móvil)
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
-- GUI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KirittoAutoShoot"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- ============================================
-- BOTÓN FLOTANTE (abrir/cerrar)
-- ============================================
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingBtn"
FloatingBtn.Size = UDim2.new(0, Config.ButtonSize, 0, Config.ButtonSize)
FloatingBtn.Position = Config.ButtonPosition
FloatingBtn.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
FloatingBtn.Text = "🎯"
FloatingBtn.TextColor3 = Color3.fromRGB(0, 212, 255)
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 22
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.Parent = ScreenGui

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(1, 0)
BtnCorner.Parent = FloatingBtn

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(0, 212, 255)
BtnStroke.Thickness = 2
BtnStroke.Transparency = 0.2
BtnStroke.Parent = FloatingBtn

-- Indicador de estado (punto rojo/verde)
local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 10, 0, 10)
StatusDot.Position = UDim2.new(1, -12, 0, 2)
StatusDot.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = FloatingBtn
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

-- ============================================
-- VENTANA PRINCIPAL
-- ============================================
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 420)
Main.Position = UDim2.new(0.5, -150, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Visible = false
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 212, 255)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.5
MainStroke.Parent = Main

-- ============================================
-- BARRA SUPERIOR
-- ============================================
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.Parent = Main
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 14)

local Fix = Instance.new("Frame")
Fix.Size = UDim2.new(1, 0, 0, 15)
Fix.Position = UDim2.new(0, 0, 1, -15)
Fix.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
Fix.BorderSizePixel = 0
Fix.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎯 KIRITTO AUTO SHOOT"
Title.TextColor3 = Color3.fromRGB(0, 212, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- ============================================
-- SCROLLING FRAME (para móviles pequeños)
-- ============================================
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -10, 1, -50)
Scroll.Position = UDim2.new(0, 5, 0, 45)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 212, 255)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.Parent = Main

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Padding = UDim.new(0, 8)
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Parent = Scroll
ScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 15)
end)

local ScrollPad = Instance.new("UIPadding")
ScrollPad.PaddingTop = UDim.new(0, 5)
ScrollPad.PaddingLeft = UDim.new(0, 5)
ScrollPad.PaddingRight = UDim.new(0, 5)
ScrollPad.Parent = Scroll

-- ============================================
-- COMPONENTES
-- ============================================
local function crearSeccion(texto, orden)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = texto
    lbl.TextColor3 = Color3.fromRGB(0, 212, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = orden
    lbl.Parent = Scroll
end

local function crearToggle(texto, key, callback, orden)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.BackgroundColor3 = Color3.fromRGB(26, 29, 41)
    f.BorderSizePixel = 0
    f.LayoutOrder = orden
    f.Parent = Scroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = texto
    label.TextColor3 = Color3.fromRGB(230, 230, 235)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = f
    
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 44, 0, 24)
    sw.Position = UDim2.new(1, -56, 0.5, -12)
    sw.BackgroundColor3 = Config[key] and Color3.fromRGB(0, 212, 255) or Color3.fromRGB(60, 65, 80)
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.Parent = f
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
    
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = Config[key] and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.BorderSizePixel = 0
    circle.Parent = sw
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    
    sw.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        local a = Config[key]
        TweenService:Create(sw, TweenInfo.new(0.2), {
            BackgroundColor3 = a and Color3.fromRGB(0, 212, 255) or Color3.fromRGB(60, 65, 80)
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.2), {
            Position = a and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
        if callback then callback(a) end
    end)
end

local function crearSlider(texto, key, min, max, callback, orden)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 58)
    f.BackgroundColor3 = Color3.fromRGB(26, 29, 41)
    f.BorderSizePixel = 0
    f.LayoutOrder = orden
    f.Parent = Scroll
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 22)
    label.Position = UDim2.new(0, 12, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = texto
    label.TextColor3 = Color3.fromRGB(230, 230, 235)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = f
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.3, 0, 0, 22)
    valLabel.Position = UDim2.new(0.65, 0, 0, 6)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(Config[key])
    valLabel.TextColor3 = Color3.fromRGB(0, 212, 255)
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 12
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = f
    
    -- Barra TÁCTIL más grande
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 10)
    bar.Position = UDim2.new(0, 12, 0, 40)
    bar.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    
    local pct = (Config[key] - min) / (max - min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 212, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local drag = Instance.new("TextButton")
    drag.Size = UDim2.new(1, 0, 3, 0)
    drag.Position = UDim2.new(0, 0, -1, 0)
    drag.BackgroundTransparency = 1
    drag.Text = ""
    drag.Parent = bar
    
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos)
        Config[key] = val
        valLabel.Text = tostring(val)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        if callback then callback(val) end
    end
    
    drag.MouseButton1Down:Connect(function()
        dragging = true
        update({Position = UserInputService:GetMouseLocation()})
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i)
        end
    end)
end

local function crearBoton(texto, callback, orden)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
    b.Text = texto
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.LayoutOrder = orden
    b.Parent = Scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function() if callback then callback() end end)
end

-- ============================================
-- CONTENIDO
-- ============================================
crearSeccion("🎯 COMBATE", 1)
crearToggle("Silent Aim", "SilentAim", nil, 2)
crearToggle("Auto Shoot", "AutoShoot", nil, 3)
crearToggle("Predicción", "Prediction", nil, 4)
crearToggle("Verificar Visibilidad", "VisibleCheck", nil, 5)

crearSeccion("⚙️ CONFIGURACIÓN", 6)
crearSlider("FOV (campo de visión)", "FOV", 30, 500, nil, 7)
crearSlider("Delay entre disparos", "AutoFireDelay", 1, 30, nil, 8)

crearSeccion("🎨 APARIENCIA", 9)
crearToggle("Mostrar círculo FOV", "ShowFOV", nil, 10)

-- Botones de color
local ColorFrame = Instance.new("Frame")
ColorFrame.Size = UDim2.new(1, 0, 0, 45)
ColorFrame.BackgroundColor3 = Color3.fromRGB(26, 29, 41)
ColorFrame.BorderSizePixel = 0
ColorFrame.LayoutOrder = 11
ColorFrame.Parent = Scroll
Instance.new("UICorner", ColorFrame).CornerRadius = UDim.new(0, 8)

local ColorLabel = Instance.new("TextLabel")
ColorLabel.Size = UDim2.new(0.5, 0, 1, 0)
ColorLabel.Position = UDim2.new(0, 12, 0, 0)
ColorLabel.BackgroundTransparency = 1
ColorLabel.Text = "Color del FOV"
ColorLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
ColorLabel.Font = Enum.Font.Gotham
ColorLabel.TextSize = 12
ColorLabel.TextXAlignment = Enum.TextXAlignment.Left
ColorLabel.Parent = ColorFrame

local ColorsLayout = Instance.new("UIListLayout")
ColorsLayout.FillDirection = Enum.FillDirection.Horizontal
ColorsLayout.Padding = UDim.new(0, 6)
ColorsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ColorsLayout.Parent = ColorFrame

local ColorContainer = Instance.new("Frame")
ColorContainercrearSeccion("🎨 APARIENCIA", 9)
crearToggle("Mostrar círculo FOV", "ShowFOV", nil, 10)

-- Botones de color
local ColorFrame = Instance.new("Frame")
ColorFrame.Size = UDim2.new(1, 0, 0, 45)
ColorFrame.BackgroundColor3 = Color3.fromRGB(26, 29, 41)
ColorFrame.BorderSizePixel = 0
ColorFrame.LayoutOrder = 11
ColorFrame.Parent = Scroll
Instance.new("UICorner", ColorFrame).CornerRadius = UDim.new(0, 8)

local ColorLabel = Instance.new("TextLabel")
ColorLabel.Size = UDim2.new(0.5, 0, 1, 0)
ColorLabel.Position = UDim2.new(0, 12, 0, 0)
ColorLabel.BackgroundTransparency = 1
ColorLabel.Text = "Color del FOV"
ColorLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
ColorLabel.Font = Enum.Font.Gotham
ColorLabel.TextSize = 12
ColorLabel.TextXAlignment = Enum.TextXAlignment.Left
ColorLabel.Parent = ColorFrame

local ColorContainer = Instance.new("Frame")
ColorContainer.Size = UDim2.new(0, 140, 1, 0)
ColorContainer.Position = UDim2.new(1, -145, 0, 0)
ColorContainer.BackgroundTransparency = 1
ColorContainer.Parent = ColorFrame

local ColorsLayout = Instance.new("UIListLayout")
ColorsLayout.FillDirection = Enum.FillDirection.Horizontal
ColorsLayout.Padding = UDim.new(0, 6)
ColorsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ColorsLayout.Parent = ColorContainer

local colores = {
    Color3.fromRGB(0, 212, 255),
    Color3.fromRGB(255, 50, 50),
    Color3.fromRGB(50, 255, 50),
    Color3.fromRGB(255, 220, 0),
}

for _, c in ipairs(colores) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 26)
    b.BackgroundColor3 = c
    b.Text = ""
    b.Parent = ColorContainer
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    b.MouseButton1Click:Connect(function()
        Config.ESPColor = c
    end)
end

crearSeccion("📊 ESTADO", 12)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 50)
InfoLabel.BackgroundColor3 = Color3.fromRGB(26, 29, 41)
InfoLabel.BorderSizePixel = 0
InfoLabel.Text = "Sin objetivo"
InfoLabel.TextColor3 = Color3.fromRGB(160, 165, 180)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 12
InfoLabel.LayoutOrder = 13
InfoLabel.Parent = Scroll
Instance.new("UICorner", InfoLabel).CornerRadius = UDim.new(0, 8)

RunService.RenderStepped:Connect(function()
    if currentTarget then
        InfoLabel.Text = "🎯 Objetivo: " .. currentTarget.Name
        InfoLabel.TextColor3 = Color3.fromRGB(0, 220, 100)
        StatusDot.BackgroundColor3 = Color3.fromRGB(0, 220, 100)
    else
        InfoLabel.Text = "Sin objetivo"
        InfoLabel.TextColor3 = Color3.fromRGB(160, 165, 180)
        StatusDot.BackgroundColor3 = Color3.fromRGB(100, 105, 120)
    end
end)

-- ============================================
-- ABRIR / CERRAR GUI
-- ============================================
local function toggleGUI()
    guiOpen = not guiOpen
    if guiOpen then
        Main.Visible = true
        Main.Size = UDim2.new(0, 250, 0, 300)
        TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 300, 0, 420)
        }):Play()
    else
        TweenService:Create(Main, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 250, 0, 300)
        }):Play()
        task.wait(0.2)
        Main.Visible = false
    end
end

FloatingBtn.MouseButton1Click:Connect(toggleGUI)

CloseBtn.MouseButton1Click:Connect(function()
    if guiOpen then toggleGUI() end
end)

-- ============================================
-- NOTIFICACIÓN INICIAL
-- ============================================
task.wait(0.5)
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "🎯 Kiritto Auto Shoot",
        Text = "Toca el botón flotante para abrir el menú",
        Duration = 5
    })
end)

print("✅ Kiritto Auto Shoot v2.0 cargado")
