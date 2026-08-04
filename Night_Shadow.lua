--[[
	PhysicalAxis Hub - Versión Completa Final
	Descripción: Hub de físicas/ESP/Teleport + Utilidades + Optimizador FPS
]]

-- Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

-- Valores por defecto
local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50
local DEFAULT_GRAVITY = 196.2

-- Variables de estado
local currentWalkSpeed = DEFAULT_WALKSPEED
local currentJumpPower = DEFAULT_JUMPPOWER
local isEspEnabled = false
local isClickTeleportEnabled = false
local isCameraSpyEnabled = false
local customSpawnCFrame = nil
local FpsBoostOn = false

-- Control de conexiones
local physicsConnection = nil
local espConnections = {}
local rejoinConnection = nil

-- Almacenar estado original
local originalLightingEffects = {}
local originalTerrainSettings = {}
local originalMaterials = {}

-- Limpiar GUI anterior
local oldGui = CoreGui:FindFirstChild("PhysicalAxisTabsHub")
if oldGui then
	oldGui:Destroy()
end

-- ==================== FUNCIONES PRINCIPALES ====================

local function updatePhysicsLoop()
	if physicsConnection then
		physicsConnection:Disconnect()
		physicsConnection = nil
	end

	physicsConnection = RunService.RenderStepped:Connect(function()
		local character = LocalPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		if humanoid.WalkSpeed ~= currentWalkSpeed then
			humanoid.WalkSpeed = currentWalkSpeed
		end
		
		humanoid.UseJumpPower = true
		if humanoid.JumpPower ~= currentJumpPower then
			humanoid.JumpPower = currentJumpPower
		end
	end)
end

local function onCharacterAdded(character)
	if not customSpawnCFrame then return end
	
	task.wait(0.1)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and customSpawnCFrame then
		humanoidRootPart.CFrame = customSpawnCFrame
	end
end

local function removeEspFromPlayer(player)
	if espConnections[player] then
		espConnections[player]:Disconnect()
		espConnections[player] = nil
	end
	
	if player.Character then
		local highlight = player.Character:FindFirstChild("ESPHub")
		if highlight then
			highlight:Destroy()
		end
	end
end

local function applyEspToPlayer(player)
	if player == LocalPlayer then return end
	
	removeEspFromPlayer(player)
	
	if not isEspEnabled then return end
	
	local function addHighlight(character)
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end
		
		if character:FindFirstChild("ESPHub") then return end
		
		local highlight = Instance.new("Highlight")
		highlight.Name = "ESPHub"
		
		local isAlly = (player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team)
		highlight.FillColor = isAlly and Color3.fromRGB(50, 220, 100) or Color3.fromRGB(220, 50, 50)
		highlight.FillTransparency = 0.5
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.Parent = character
	end
	
	espConnections[player] = player.CharacterAdded:Connect(function(character)
		if isEspEnabled then
			task.wait(0.1)
			addHighlight(character)
		end
	end)
	
	if player.Character then
		addHighlight(player.Character)
	end
end

local function refreshAllEsp()
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			removeEspFromPlayer(player)
			if isEspEnabled then
				applyEspToPlayer(player)
			end
		end
	end
end

local teleportTool = Instance.new("Tool")
teleportTool.Name = "Click Teleport"
teleportTool.RequiresHandle = false
teleportTool.Activated:Connect(function()
	if not isClickTeleportEnabled then return end
	
	local mouse = LocalPlayer:GetMouse()
	if mouse and mouse.Hit then
		local character = LocalPlayer.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
			end
		end
	end
end)

local function toggleTeleportTool(enabled)
	isClickTeleportEnabled = enabled
	if enabled then
		teleportTool.Parent = LocalPlayer.Backpack
	else
		if teleportTool.Parent then
			teleportTool.Parent = nil
		end
	end
end

local function teleportToPlayer(playerName)
	local searchName = string.lower(playerName)
	if #searchName < 1 then return end
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local nameMatch = string.find(string.lower(player.Name), searchName)
			local displayMatch = string.find(string.lower(player.DisplayName), searchName)
			
			if nameMatch or displayMatch then
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					local localChar = LocalPlayer.Character
					if localChar and localChar:FindFirstChild("HumanoidRootPart") then
						localChar.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
						return
					end
				end
			end
		end
	end
end

local function setSpyCamera(playerName)
	if not isCameraSpyEnabled then return end
	
	local searchName = string.lower(playerName)
	if #searchName < 1 then return end
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			if string.find(string.lower(player.Name), searchName) or string.find(string.lower(player.DisplayName), searchName) then
				if player.Character then
					local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						Workspace.CurrentCamera.CameraSubject = humanoid
						return
					end
				end
			end
		end
	end
end

-- ==================== FUNCIONES DE UTILIDADES ====================

_G.AutoRejoinEnabled = false
_G.RejoinConnected = false

local function toggleAutoRejoin(enabled)
	_G.AutoRejoinEnabled = enabled
	
	if enabled and not _G.RejoinConnected then
		_G.RejoinConnected = true
		rejoinConnection = GuiService.ErrorMessageChanged:Connect(function()
			if _G.AutoRejoinEnabled then
				task.wait(1)
				pcall(function()
					TeleportService:Teleport(game.PlaceId, LocalPlayer)
				end)
			end
		end)
	end
end

local function serverHop()
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Server Hop",
			Text = "Buscando un servidor nuevo...",
			Duration = 3
		})
	end)
	
	local success, result = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
	end)
	
	if success and result then
		local success2, serverList = pcall(function()
			return HttpService:JSONDecode(result)
		end)
		
		if success2 and serverList and serverList.data then
			for _, server in pairs(serverList.data) do
				if server.playing < server.maxPlayers and server.id ~= game.JobId then
					pcall(function()
						TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
					end)
					return
				end
			end
			
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Server Hop",
					Text = "No se encontraron servidores disponibles",
					Duration = 3
				})
			end)
		else
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
		end
	else
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end
end

-- ==================== FUNCIÓN DE OPTIMIZACIÓN FPS ====================

local function saveOriginalLightingState()
	originalLightingEffects = {}
	for _, effect in pairs(Lighting:GetChildren()) do
		if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
			originalLightingEffects[effect] = effect.Enabled
		end
	end
	originalLightingEffects["GlobalShadows"] = Lighting.GlobalShadows
end

local function saveOriginalTerrainState()
	if Terrain then
		originalTerrainSettings = {
			WaterWaveSize = Terrain.WaterWaveSize,
			WaterWaveSpeed = Terrain.WaterWaveSpeed,
			WaterReflectance = Terrain.WaterReflectance,
			WaterTransparency = Terrain.WaterTransparency
		}
	end
end

local function enableFpsBoost()
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Rendimiento Activo",
			Text = "Materiales y efectos simplificados para más fluidez.",
			Duration = 3
		})
	end)
	
	saveOriginalLightingState()
	saveOriginalTerrainState()
	
	for _, effect in pairs(Lighting:GetChildren()) do
		if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = false
		end
	end
	
	Lighting.GlobalShadows = false
	
	if Terrain then
		Terrain.WaterWaveSize = 0
		Terrain.WaterWaveSpeed = 0
		Terrain.WaterReflectance = 0
		Terrain.WaterTransparency = 1
	end
	
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and not obj:IsA("MeshPart") then
			if not originalMaterials[obj] then
				originalMaterials[obj] = obj.Material
			end
			obj.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function disableFpsBoost()
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Rendimiento Normal",
			Text = "Los efectos visuales se han reactivado.",
			Duration = 3
		})
	end)
	
	if originalLightingEffects["GlobalShadows"] ~= nil then
		Lighting.GlobalShadows = originalLightingEffects["GlobalShadows"]
	else
		Lighting.GlobalShadows = true
	end
	
	for effect, wasEnabled in pairs(originalLightingEffects) do
		if effect ~= "GlobalShadows" and typeof(effect) == "Instance" and effect.Parent then
			pcall(function()
				effect.Enabled = wasEnabled
			end)
		end
	end
	
	if Terrain and originalTerrainSettings.WaterWaveSize ~= nil then
		pcall(function()
			Terrain.WaterWaveSize = originalTerrainSettings.WaterWaveSize
			Terrain.WaterWaveSpeed = originalTerrainSettings.WaterWaveSpeed
			Terrain.WaterReflectance = originalTerrainSettings.WaterReflectance
			Terrain.WaterTransparency = originalTerrainSettings.WaterTransparency
		end)
	end
	
	for obj, originalMaterial in pairs(originalMaterials) do
		if obj and obj.Parent then
			pcall(function()
				obj.Material = originalMaterial
			end)
		end
	end
	
	originalMaterials = {}
	originalLightingEffects = {}
	originalTerrainSettings = {}
end

local function toggleFpsBoost(enabled)
	FpsBoostOn = enabled
	
	if FpsBoostOn then
		enableFpsBoost()
	else
		disableFpsBoost()
	end
end

-- ==================== CONSTRUCCIÓN DE LA INTERFAZ ====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PhysicalAxisTabsHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
mainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
mainFrame.Size = UDim2.new(0, 420, 0, 300)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 45, 52)
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, 0, 0, 40)
headerFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
headerFrame.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = headerFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
titleLabel.Position = UDim2.new(0.04, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "PhysicalAxis | Hub"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = headerFrame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 26, 0, 26)
minimizeButton.Position = UDim2.new(0.92, 0, 0.15, 0)
minimizeButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.TextSize = 16
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Parent = headerFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeButton

local restoreButton = Instance.new("TextButton")
restoreButton.Size = UDim2.new(0, 50, 0, 50)
restoreButton.Position = UDim2.new(0.02, 0, 0.4, 0)
restoreButton.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
restoreButton.Text = "AXIS"
restoreButton.TextColor3 = Color3.fromRGB(150, 120, 255)
restoreButton.TextSize = 12
restoreButton.Font = Enum.Font.GothamBold
restoreButton.Visible = false
restoreButton.Parent = screenGui

local restCorner = Instance.new("UICorner")
restCorner.CornerRadius = UDim.new(0, 25)
restCorner.Parent = restoreButton

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.Size = UDim2.new(0, 120, 1, -40)
sidebar.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
sidebar.Parent = mainFrame

local sidebarLine = Instance.new("Frame")
sidebarLine.Position = UDim2.new(1, -1, 0, 0)
sidebarLine.Size = UDim2.new(0, 1, 1, 0)
sidebarLine.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
sidebarLine.BorderSizePixel = 0
sidebarLine.Parent = sidebar

local tabPhysics = Instance.new("ScrollingFrame")
tabPhysics.Position = UDim2.new(0, 125, 0, 45)
tabPhysics.Size = UDim2.new(1, -130, 1, -50)
tabPhysics.BackgroundTransparency = 1
tabPhysics.CanvasSize = UDim2.new(0, 0, 0, 250)
tabPhysics.ScrollBarThickness = 0
tabPhysics.Visible = true
tabPhysics.Parent = mainFrame

local tabExtras = Instance.new("ScrollingFrame")
tabExtras.Position = UDim2.new(0, 125, 0, 45)
tabExtras.Size = UDim2.new(1, -130, 1, -50)
tabExtras.BackgroundTransparency = 1
tabExtras.CanvasSize = UDim2.new(0, 0, 0, 250)
tabExtras.ScrollBarThickness = 0
tabExtras.Visible = false
tabExtras.Parent = mainFrame

local tabTeam = Instance.new("ScrollingFrame")
tabTeam.Position = UDim2.new(0, 125, 0, 45)
tabTeam.Size = UDim2.new(1, -130, 1, -50)
tabTeam.BackgroundTransparency = 1
tabTeam.CanvasSize = UDim2.new(0, 0, 0, 250)
tabTeam.ScrollBarThickness = 0
tabTeam.Visible = false
tabTeam.Parent = mainFrame

local tabUtilities = Instance.new("ScrollingFrame")
tabUtilities.Position = UDim2.new(0, 125, 0, 45)
tabUtilities.Size = UDim2.new(1, -130, 1, -50)
tabUtilities.BackgroundTransparency = 1
tabUtilities.CanvasSize = UDim2.new(0, 0, 0, 250)
tabUtilities.ScrollBarThickness = 0
tabUtilities.Visible = false
tabUtilities.Parent = mainFrame

local function createSidebarButton(text, yPosition)
	local button = Instance.new("TextButton")
	button.Position = UDim2.new(0.05, 0, 0, yPosition)
	button.Size = UDim2.new(0.9, 0, 0, 32)
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextColor3 = Color3.fromRGB(150, 150, 160)
	button.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	button.Parent = sidebar
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	
	return button
end

local btnPhysics = createSidebarButton("Físicas", 10)
local btnExtras = createSidebarButton("Extras", 47)
local btnTeam = createSidebarButton("Equipo 👥", 84)
local btnUtilities = createSidebarButton("Utilidades", 121)

local function switchTab(button, tab)
	btnPhysics.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnPhysics.TextColor3 = Color3.fromRGB(150, 150, 160)
	btnExtras.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnExtras.TextColor3 = Color3.fromRGB(150, 150, 160)
	btnTeam.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnTeam.TextColor3 = Color3.fromRGB(150, 150, 160)
	btnUtilities.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnUtilities.TextColor3 = Color3.fromRGB(150, 150, 160)
	
	tabPhysics.Visible = false
	tabExtras.Visible = false
	tabTeam.Visible = false
	tabUtilities.Visible = false
	
	button.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	tab.Visible = true
end

btnPhysics.MouseButton1Click:Connect(function() switchTab(btnPhysics, tabPhysics) end)
btnExtras.MouseButton1Click:Connect(function() switchTab(btnExtras, tabExtras) end)
btnTeam.MouseButton1Click:Connect(function() switchTab(btnTeam, tabTeam) end)
btnUtilities.MouseButton1Click:Connect(function() switchTab(btnUtilities, tabUtilities) end)

switchTab(btnPhysics, tabPhysics)

local function createInputField(parent, placeholder, buttonText, yPosition, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -10, 0, 40)
	frame.Position = UDim2.new(0.02, 0, 0, yPosition)
	frame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
	frame.Parent = parent
	
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 6)
	frameCorner.Parent = frame
	
	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(0.55, 0, 0.7, 0)
	textBox.Position = UDim2.new(0.03, 0, 0.15, 0)
	textBox.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	textBox.PlaceholderText = placeholder
	textBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
	textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	textBox.TextSize = 11
	textBox.Font = Enum.Font.Gotham
	textBox.Text = ""
	textBox.Parent = frame
	
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = textBox
	
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.35, 0, 0.7, 0)
	button.Position = UDim2.new(0.62, 0, 0.15, 0)
	button.BackgroundColor3 = Color3.fromRGB(130, 90, 255)
	button.Text = buttonText
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 11
	button.Font = Enum.Font.GothamBold
	button.Parent = frame
	
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = button
	
	button.MouseButton1Click:Connect(function()
		if textBox.Text and textBox.Text ~= "" then
			callback(textBox.Text)
		end
	end)
	
	return frame, textBox, button
end

local function createSimpleButton(parent, text, yPosition, color, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -10, 0, 36)
	button.Position = UDim2.new(0.02, 0, 0, yPosition)
	button.BackgroundColor3 = color or Color3.fromRGB(40, 40, 46)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	
	if callback then
		button.MouseButton1Click:Connect(callback)
	end
	
	return button
end

-- ==================== CONTENIDO DE LAS PESTAÑAS ====================

-- === PESTAÑA FÍSICAS ===

createInputField(tabPhysics, "Velocidad (16)", "Fijar", 0, function(text)
	local num = tonumber(text)
	if num and num > 0 then
		currentWalkSpeed = num
	end
end)

createInputField(tabPhysics, "Salto (50)", "Fijar", 47, function(text)
	local num = tonumber(text)
	if num and num > 0 then
		currentJumpPower = num
	end
end)

createInputField(tabPhysics, "Gravedad (196)", "Fijar", 94, function(text)
	local num = tonumber(text)
	if num then
		Workspace.Gravity = num
	end
end)

createSimpleButton(tabPhysics, "Restaurar Físicas Originales", 145, Color3.fromRGB(180, 50, 50), function()
	currentWalkSpeed = DEFAULT_WALKSPEED
	currentJumpPower = DEFAULT_JUMPPOWER
	Workspace.Gravity = DEFAULT_GRAVITY
end)

-- === PESTAÑA EXTRAS ===

local espButton = createSimpleButton(tabExtras, "ESP Visual: DESACTIVADO", 0, nil, nil)

espButton.MouseButton1Click:Connect(function()
	isEspEnabled = not isEspEnabled
	if isEspEnabled then
		espButton.Text = "ESP Visual: ACTIVADO"
		espButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	else
		espButton.Text = "ESP Visual: DESACTIVADO"
		espButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	end
	refreshAllEsp()
end)

local tpButton = createSimpleButton(tabExtras, "Click Teleport: APAGADO", 42, nil, nil)

tpButton.MouseButton1Click:Connect(function()
	isClickTeleportEnabled = not isClickTeleportEnabled
	if isClickTeleportEnabled then
		tpButton.Text = "Click Teleport: EN USO"
		tpButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	else
		tpButton.Text = "Click Teleport: APAGADO"
		tpButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	end
	toggleTeleportTool(isClickTeleportEnabled)
end)

createSimpleButton(tabExtras, "Establecer posición de Spawn", 84, Color3.fromRGB(0, 120, 200), function()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		customSpawnCFrame = char.HumanoidRootPart.CFrame
	end
end)

createSimpleButton(tabExtras, "Eliminar Spawn Personalizado", 126, Color3.fromRGB(50, 50, 58), function()
	customSpawnCFrame = nil
end)

-- === PESTAÑA EQUIPO ===

createInputField(tabTeam, "Nombre de Jugador", "Teleport", 0, function(text)
	teleportToPlayer(text)
end)

local spyButton = createSimpleButton(tabTeam, "Cámara Espía: DESACTIVADO", 47, nil, nil)

spyButton.MouseButton1Click:Connect(function()
	isCameraSpyEnabled = not isCameraSpyEnabled
	if isCameraSpyEnabled then
		spyButton.Text = "Cámara Espía: TRABAJANDO"
		spyButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	else
		spyButton.Text = "Cámara Espía: DESACTIVADO"
		spyButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		local char = LocalPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				Workspace.CurrentCamera.CameraSubject = hum
			end
		end
	end
end)

createInputField(tabTeam, "Nombre a Espiar", "Fijar Objetivo", 94, function(text)
	if isCameraSpyEnabled then
		setSpyCamera(text)
	end
end)

-- === PESTAÑA UTILIDADES ===

local rejoinButton = createSimpleButton(tabUtilities, "Auto-Rejoin: DESACTIVADO", 0, nil, nil)

rejoinButton.MouseButton1Click:Connect(function()
	_G.AutoRejoinEnabled = not _G.AutoRejoinEnabled
	
	if _G.AutoRejoinEnabled then
		rejoinButton.Text = "Auto-Rejoin: ACTIVADO"
		rejoinButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	else
		rejoinButton.Text = "Auto-Rejoin: DESACTIVADO"
		rejoinButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	end
	
	toggleAutoRejoin(_G.AutoRejoinEnabled)
end)

local hopButton = createSimpleButton(tabUtilities, "Cambiador de Servidor (Hop)", 42, Color3.fromRGB(40, 40, 46), nil)

hopButton.MouseButton1Click:Connect(function()
	hopButton.Text = "Buscando servidor..."
	hopButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	
	serverHop()
	
	task.delay(3, function()
		hopButton.Text = "Cambiador de Servidor (Hop)"
		hopButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	end)
end)

local fpsButton = createSimpleButton(tabUtilities, "Optimizar FPS: APAGADO", 84, nil, nil)

fpsButton.MouseButton1Click:Connect(function()
	FpsBoostOn = not FpsBoostOn
	
	if FpsBoostOn then
		fpsButton.Text = "Optimizar FPS: MÁXIMO"
		fpsButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	else
		fpsButton.Text = "Optimizar FPS: APAGADO"
		fpsButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	end
	
	toggleFpsBoost(FpsBoostOn)
end)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 0, 80)
infoLabel.Position = UDim2.new(0.02, 0, 0, 135)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "💡 Auto-Rejoin: Reconecta automáticamente\nal servidor si hay un error de conexión.\n\n🔄 Server Hop: Busca un servidor público\ncon espacio disponible.\n\n⚡ Optimizar FPS: Reduce efectos visuales\npara mejorar el rendimiento."
infoLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
infoLabel.TextSize = 10
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextWrapped = true
infoLabel.Parent = tabUtilities

-- ==================== MINIMIZAR / RESTAURAR ====================

minimizeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	restoreButton.Visible = true
end)

restoreButton.MouseButton1Click:Connect(function()
	restoreButton.Visible = false
	mainFrame.Visible = true
end)

-- ==================== CONEXIONES DE JUGADORES ====================

Players.PlayerAdded:Connect(function(player)
	if isEspEnabled then
		applyEspToPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeEspFromPlayer(player)
end)

-- ==================== INICIALIZACIÓN ====================

updatePhysicsLoop()
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

_G.AutoRejoinEnabled = false
_G.RejoinConnected = false

print("PhysicalAxis Hub - Versión Completa Final cargado correctamente")
print("Pestañas: Físicas | Extras | Equipo 👥 | Utilidades")
print("Funciones: Físicas, ESP, Click Teleport, Spawn, Cámara Espía, Auto-Rejoin, Server Hop, FPS Booster")
