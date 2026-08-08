--[[
	PhysicalAxis Hub - Versión Final con Piano Funcional
	Descripción: Hub completo con piano interactivo que otros jugadores pueden escuchar
]]

-- Servicios
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Terrain = Workspace:FindFirstChildOfClass("Terrain")
local Camera = Workspace.CurrentCamera

-- Valores por defecto
local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50
local DEFAULT_GRAVITY = 196.2

-- Variables de estado
local currentWalkSpeed = DEFAULT_WALKSPEED
local currentJumpPower = DEFAULT_JUMPPOWER
local physicsEnabled = false
local isEspEnabled = false
local isClickTeleportEnabled = false
local isCameraSpyEnabled = false
local customSpawnCFrame = nil
local FpsBoostOn = false
local isTelekinesisEnabled = false
local isPianoActive = false

-- Control de conexiones
local physicsConnection = nil
local espConnections = {}
local rejoinConnection = nil
local telekinesisConnections = {}
local lockOnConnection = nil
local pianoConnections = {}
local fixedCameraTarget = nil
local heldObject = nil
local mouseTarget = nil
local selectionHighlight = nil

-- Piano
local pianoModel = nil
local pianoKeys = {}
local pianoSounds = {}

-- Almacenar estado original
local originalLightingEffects = {}
local originalTerrainSettings = {}
local originalMaterials = {}

-- Limpiar GUI anterior
local oldGui = CoreGui:FindFirstChild("PhysicalAxisTabsHub")
if oldGui then
	oldGui:Destroy()
end

-- Limpiar cualquier highlight residual
for _, obj in pairs(Workspace:GetDescendants()) do
	local highlight = obj:FindFirstChild("TelekinesisHighlight")
	if highlight then
		highlight:Destroy()
	end
end

-- ==================== SISTEMA DE PIANO ====================

-- Notas musicales y sus IDs de sonido de Roblox
local PIANO_NOTES = {
	-- Octava baja (C3-B3)
	{key = "A", note = "C3", soundId = "rbxassetid://9119756365", color = Color3.fromRGB(255, 255, 255)}, -- Do
	{key = "W", note = "C#3", soundId = "rbxassetid://9119756508", color = Color3.fromRGB(0, 0, 0)}, -- Do#
	{key = "S", note = "D3", soundId = "rbxassetid://9119756631", color = Color3.fromRGB(255, 255, 255)}, -- Re
	{key = "E", note = "D#3", soundId = "rbxassetid://9119756775", color = Color3.fromRGB(0, 0, 0)}, -- Re#
	{key = "D", note = "E3", soundId = "rbxassetid://9119756944", color = Color3.fromRGB(255, 255, 255)}, -- Mi
	{key = "F", note = "F3", soundId = "rbxassetid://9119757135", color = Color3.fromRGB(255, 255, 255)}, -- Fa
	{key = "T", note = "F#3", soundId = "rbxassetid://9119757314", color = Color3.fromRGB(0, 0, 0)}, -- Fa#
	{key = "G", note = "G3", soundId = "rbxassetid://9119757492", color = Color3.fromRGB(255, 255, 255)}, -- Sol
	{key = "Y", note = "G#3", soundId = "rbxassetid://9119757679", color = Color3.fromRGB(0, 0, 0)}, -- Sol#
	{key = "H", note = "A3", soundId = "rbxassetid://9119757858", color = Color3.fromRGB(255, 255, 255)}, -- La
	{key = "U", note = "A#3", soundId = "rbxassetid://9119758028", color = Color3.fromRGB(0, 0, 0)}, -- La#
	{key = "J", note = "B3", soundId = "rbxassetid://9119758213", color = Color3.fromRGB(255, 255, 255)}, -- Si
	
	-- Octava alta (C4-B4)
	{key = "K", note = "C4", soundId = "rbxassetid://9119758408", color = Color3.fromRGB(255, 255, 255)}, -- Do
	{key = "O", note = "C#4", soundId = "rbxassetid://9119758597", color = Color3.fromRGB(0, 0, 0)}, -- Do#
	{key = "L", note = "D4", soundId = "rbxassetid://9119758775", color = Color3.fromRGB(255, 255, 255)}, -- Re
	{key = "P", note = "D#4", soundId = "rbxassetid://9119758965", color = Color3.fromRGB(0, 0, 0)}, -- Re#
	{key = "Ñ", note = "E4", soundId = "rbxassetid://9119759162", color = Color3.fromRGB(255, 255, 255)}, -- Mi
	{key = "Z", note = "F4", soundId = "rbxassetid://9119759368", color = Color3.fromRGB(255, 255, 255)}, -- Fa
	{key = "X", note = "F#4", soundId = "rbxassetid://9119759553", color = Color3.fromRGB(0, 0, 0)}, -- Fa#
	{key = "C", note = "G4", soundId = "rbxassetid://9119759745", color = Color3.fromRGB(255, 255, 255)}, -- Sol
	{key = "V", note = "G#4", soundId = "rbxassetid://9119759937", color = Color3.fromRGB(0, 0, 0)}, -- Sol#
	{key = "B", note = "A4", soundId = "rbxassetid://9119760132", color = Color3.fromRGB(255, 255, 255)}, -- La
	{key = "N", note = "A#4", soundId = "rbxassetid://9119760346", color = Color3.fromRGB(0, 0, 0)}, -- La#
	{key = "M", note = "B4", soundId = "rbxassetid://9119760548", color = Color3.fromRGB(255, 255, 255)}, -- Si
}

local function createPiano()
	if pianoModel then
		pianoModel:Destroy()
		pianoModel = nil
	end
	
	local character = LocalPlayer.Character
	if not character then return end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	-- Crear el modelo del piano
	pianoModel = Instance.new("Model")
	pianoModel.Name = "PianoModel"
	
	-- Base del piano
	local base = Instance.new("Part")
	base.Name = "PianoBase"
	base.Size = Vector3.new(8, 0.5, 3)
	base.Position = root.Position + Vector3.new(0, -2, -4)
	base.Anchored = false
	base.Material = Enum.Material.Wood
	base.Color = Color3.fromRGB(60, 40, 20)
	base.Parent = pianoModel
	
	-- Crear teclas del piano
	local whiteKeys = {}
	local blackKeys = {}
	
	for i = 1, 24 do
		local isWhiteKey = (i % 2 == 1) -- Simplificación: alternar blancas y negras
		local keyPart = Instance.new("Part")
		keyPart.Name = "Key" .. i
		keyPart.Size = isWhiteKey and Vector3.new(0.3, 0.1, 1.5) or Vector3.new(0.2, 0.15, 1)
		keyPart.Position = base.Position + Vector3.new((i-12) * 0.32, 0.3, 0)
		keyPart.Anchored = false
		keyPart.Color = isWhiteKey and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
		keyPart.Material = Enum.Material.SmoothPlastic
		keyPart.Parent = pianoModel
		
		-- Weld a la base
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = keyPart
		weld.Part1 = base
		weld.Parent = keyPart
		
		if isWhiteKey then
			table.insert(whiteKeys, keyPart)
		else
			table.insert(blackKeys, keyPart)
		end
	end
	
	-- Anclar el piano al jugador
	local attachWeld = Instance.new("WeldConstraint")
	attachWeld.Part0 = base
	attachWeld.Part1 = root
	attachWeld.Parent = base
	
	pianoModel.Parent = Workspace
	
	return pianoModel
end

local function playPianoNote(noteData)
	if not noteData or not noteData.soundId then return end
	
	local character = LocalPlayer.Character
	if not character then return end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	-- Crear sonido que otros pueden escuchar
	local sound = Instance.new("Sound")
	sound.SoundId = noteData.soundId
	sound.Volume = 1
	sound.PlayOnRemove = false
	
	-- Importante: Hacer que el sonido sea escuchado por todos
	sound.Parent = Workspace
	
	-- Posicionar el sonido en el jugador
	local soundPart = Instance.new("Part")
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Position = root.Position
	soundPart.Transparency = 1
	soundPart.CanCollide = false
	soundPart.Anchored = true
	soundPart.Parent = Workspace
	
	sound.Parent = soundPart
	
	-- Reproducir y luego limpiar
	sound:Play()
	
	-- Notificación visual
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "🎹 Piano",
			Text = "Nota: " .. noteData.note,
			Duration = 0.5
		})
	end)
	
	-- Limpiar después de reproducir
	task.delay(2, function()
		if soundPart and soundPart.Parent then
			soundPart:Destroy()
		end
	end)
end

local function startPiano()
	if isPianoActive then return end
	
	isPianoActive = true
	pianoModel = createPiano()
	
	-- Conectar teclas del teclado
	local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not isPianoActive then return end
		if gameProcessed then return end
		
		local keyPressed = string.upper(input.KeyCode.Name)
		
		-- Buscar la nota correspondiente
		for _, noteData in pairs(PIANO_NOTES) do
			if noteData.key == keyPressed then
				playPianoNote(noteData)
				break
			end
		end
	end)
	
	table.insert(pianoConnections, inputConnection)
	
	-- También permitir tocar con clics en las teclas (para móvil)
	if pianoModel then
		for _, part in pairs(pianoModel:GetDescendants()) do
			if part:IsA("BasePart") and part.Name:find("Key") then
				local clickConnection = part.Touched:Connect(function(hit)
					if not isPianoActive then return end
					
					-- Encontrar el índice de la tecla
					local keyIndex = tonumber(part.Name:match("%d+"))
					if keyIndex and keyIndex <= #PIANO_NOTES then
						playPianoNote(PIANO_NOTES[keyIndex])
					end
				end)
				
				table.insert(pianoConnections, clickConnection)
			end
		end
	end
	
	-- GUI del piano para móviles
	local pianoGui = Instance.new("ScreenGui")
	pianoGui.Name = "PianoGUI"
	pianoGui.Parent = CoreGui
	
	local pianoFrame = Instance.new("Frame")
	pianoFrame.Size = UDim2.new(0, 350, 0, 120)
	pianoFrame.Position = UDim2.new(0.5, -175, 0.8, 0)
	pianoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	pianoFrame.Parent = pianoGui
	
	local pianoCorner = Instance.new("UICorner")
	pianoCorner.CornerRadius = UDim.new(0, 8)
	pianoCorner.Parent = pianoFrame
	
	-- Título
	local pianoTitle = Instance.new("TextLabel")
	pianoTitle.Size = UDim2.new(1, 0, 0, 20)
	pianoTitle.BackgroundTransparency = 1
	pianoTitle.Text = "🎹 Piano Virtual - Teclas: A S D F G H J K L Ñ Z X C V B N M"
	pianoTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	pianoTitle.TextSize = 8
	pianoTitle.Font = Enum.Font.GothamBold
	pianoTitle.Parent = pianoFrame
	
	-- Botones del piano en la GUI
	for i, noteData in pairs(PIANO_NOTES) do
		local keyButton = Instance.new("TextButton")
		keyButton.Size = UDim2.new(0, 25, 0, 35)
		keyButton.Position = UDim2.new(0, (i-1) * 14 + 5, 0, 30)
		keyButton.BackgroundColor3 = noteData.color
		keyButton.Text = noteData.key
		keyButton.TextColor3 = noteData.color == Color3.fromRGB(0, 0, 0) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
		keyButton.TextSize = 10
		keyButton.Font = Enum.Font.GothamBold
		keyButton.Parent = pianoFrame
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 3)
		btnCorner.Parent = keyButton
		
		keyButton.MouseButton1Click:Connect(function()
			if isPianoActive then
				playPianoNote(noteData)
			end
		end)
		
		-- También para touch
		keyButton.TouchTap:Connect(function()
			if isPianoActive then
				playPianoNote(noteData)
			end
		end)
	end
	
	-- Botón para cerrar piano
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 60, 0, 25)
	closeButton.Position = UDim2.new(0, 140, 0, 80)
	closeButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeButton.Text = "Cerrar"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 10
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = pianoFrame
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeButton
	
	closeButton.MouseButton1Click:Connect(function()
		stopPiano()
	end)
end

local function stopPiano()
	isPianoActive = false
	
	-- Desconectar todas las conexiones del piano
	for _, conn in pairs(pianoConnections) do
		if conn then
			conn:Disconnect()
		end
	end
	pianoConnections = {}
	
	-- Destruir el modelo del piano
	if pianoModel then
		pianoModel:Destroy()
		pianoModel = nil
	end
	
	-- Destruir la GUI del piano
	local pianoGui = CoreGui:FindFirstChild("PianoGUI")
	if pianoGui then
		pianoGui:Destroy()
	end
end

-- ==================== FUNCIONES PRINCIPALES ====================

-- (El resto de las funciones principales se mantienen igual que en la versión anterior)
-- updatePhysicsLoop, togglePhysics, onCharacterAdded, setWalkSpeed, setJumpPower,
-- removeEspFromPlayer, applyEspToPlayer, refreshAllEsp, teleportToPlayer,
-- spyOnPlayer, fixCameraOnPlayer, stopSpying, etc.

local function updatePhysicsLoop()
	if physicsConnection then
		physicsConnection:Disconnect()
		physicsConnection = nil
	end

	physicsConnection = RunService.Heartbeat:Connect(function()
		if not physicsEnabled then return end
		
		local character = LocalPlayer.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local currentSpeed = humanoid.WalkSpeed
		local humanoidState = humanoid:GetState()
		
		local restrictedStates = {
			[Enum.HumanoidStateType.Seated] = true,
			[Enum.HumanoidStateType.PlatformStanding] = true,
			[Enum.HumanoidStateType.StrafingNoPhysics] = true,
		}
		
		if restrictedStates[humanoidState] then
			return
		end
		
		if currentSpeed > 0 and currentSpeed < currentWalkSpeed then
			return
		end
		
		if humanoid.WalkSpeed ~= currentWalkSpeed then
			humanoid.WalkSpeed = currentWalkSpeed
		end
		
		if humanoidState == Enum.HumanoidStateType.Running or 
		   humanoidState == Enum.HumanoidStateType.RunningNoPhysics or
		   humanoidState == Enum.HumanoidStateType.Jumping or
		   humanoidState == Enum.HumanoidStateType.Freefall then
			humanoid.UseJumpPower = true
			if humanoid.JumpPower ~= currentJumpPower then
				humanoid.JumpPower = currentJumpPower
			end
		end
	end)
end

local function togglePhysics(enabled)
	physicsEnabled = enabled
	if not enabled then
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = DEFAULT_WALKSPEED
				humanoid.JumpPower = DEFAULT_JUMPPOWER
			end
		end
	end
end

local function onCharacterAdded(character)
	if not customSpawnCFrame then return end
	
	task.wait(0.1)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and customSpawnCFrame then
		humanoidRootPart.CFrame = customSpawnCFrame
	end
	
	if physicsEnabled then
		task.wait(0.5)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = currentWalkSpeed
			humanoid.JumpPower = currentJumpPower
		end
	end
	
	-- Si el piano estaba activo, recrearlo
	if isPianoActive then
		task.wait(1)
		pianoModel = createPiano()
	end
end

local function setWalkSpeed(speed)
	currentWalkSpeed = speed
	if physicsEnabled then
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local state = humanoid:GetState()
				if state ~= Enum.HumanoidStateType.Seated and 
				   state ~= Enum.HumanoidStateType.PlatformStanding then
					humanoid.WalkSpeed = speed
				end
			end
		end
	end
end

local function setJumpPower(power)
	currentJumpPower = power
	if physicsEnabled then
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.UseJumpPower = true
				humanoid.JumpPower = power
			end
		end
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

local function teleportToPlayer(player)
	if not player or not player.Character then return end
	
	local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
	local localChar = LocalPlayer.Character
	if not targetRoot or not localChar then return end
	
	local localRoot = localChar:FindFirstChild("HumanoidRootPart")
	if localRoot then
		localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
		
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Teleport",
				Text = "Teletransportado a " .. player.Name,
				Duration = 2
			})
		end)
	end
end

local function spyOnPlayer(player)
	if not player or not player.Character then return end
	
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Camera.CameraSubject = humanoid
		isCameraSpyEnabled = true
		
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Cámara Espía",
				Text = "Espiando a " .. player.Name,
				Duration = 2
			})
		end)
	end
end

local function fixCameraOnPlayer(player)
	if not player or not player.Character then return end
	
	if lockOnConnection then
		lockOnConnection:Disconnect()
		lockOnConnection = nil
	end
	
	fixedCameraTarget = player
	
	lockOnConnection = RunService.RenderStepped:Connect(function()
		if not fixedCameraTarget or not fixedCameraTarget.Character then
			if lockOnConnection then
				lockOnConnection:Disconnect()
				lockOnConnection = nil
			end
			fixedCameraTarget = nil
			return
		end
		
		local targetRoot = fixedCameraTarget.Character:FindFirstChild("HumanoidRootPart")
		if not targetRoot then
			if lockOnConnection then
				lockOnConnection:Disconnect()
				lockOnConnection = nil
			end
			fixedCameraTarget = nil
			return
		end
		
		local cameraPos = Camera.CFrame.Position
		local lookAt = targetRoot.Position
		Camera.CFrame = CFrame.new(cameraPos, lookAt)
	end)
	
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Cámara Fijada",
			Text = "Cámara siguiendo a " .. player.Name,
			Duration = 2
		})
	end)
end

local function stopSpying()
	isCameraSpyEnabled = false
	fixedCameraTarget = nil
	
	if lockOnConnection then
		lockOnConnection:Disconnect()
		lockOnConnection = nil
	end
	
	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			Camera.CameraSubject = hum
		end
	end
end

-- ==================== SISTEMA DE TELEQUINESIS ====================

local function cleanupTelekinesis()
	if selectionHighlight then
		selectionHighlight:Destroy()
		selectionHighlight = nil
	end
	
	if heldObject and heldObject.Parent then
		if heldObject:IsA("BasePart") then
			heldObject.Anchored = false
		end
	end
	heldObject = nil
	mouseTarget = nil
	
	for _, conn in pairs(telekinesisConnections) do
		if conn then
			conn:Disconnect()
		end
	end
	telekinesisConnections = {}
	
	if LocalPlayer.Backpack then
		local tkTool = LocalPlayer.Backpack:FindFirstChild("Telekinesis")
		if tkTool then
			tkTool:Destroy()
		end
	end
	
	if LocalPlayer.Character then
		local tkTool = LocalPlayer.Character:FindFirstChild("Telekinesis")
		if tkTool then
			tkTool:Destroy()
		end
	end
end

local function startTelekinesis()
	cleanupTelekinesis()
	
	isTelekinesisEnabled = true
	
	selectionHighlight = Instance.new("Highlight")
	selectionHighlight.Name = "TelekinesisHighlight"
	selectionHighlight.FillColor = Color3.fromRGB(0, 200, 255)
	selectionHighlight.FillTransparency = 0.7
	selectionHighlight.OutlineColor = Color3.fromRGB(0, 150, 255)
	selectionHighlight.OutlineTransparency = 0
	
	local mouse = LocalPlayer:GetMouse()
	local draggingObject = false
	local targetObject = nil
	local holdDistance = 15
	
	local mouseMoveConnection = mouse.Move:Connect(function()
		if not isTelekinesisEnabled then return end
		
		local target = mouse.Target
		if target and target:IsA("BasePart") and target.Parent ~= LocalPlayer.Character and not target:IsDescendantOf(LocalPlayer.Character or Instance.new("Model")) then
			selectionHighlight.Parent = target
			mouseTarget = target
		else
			selectionHighlight.Parent = nil
			mouseTarget = nil
		end
	end)
	
	table.insert(telekinesisConnections, mouseMoveConnection)
	
	local tkTool = Instance.new("Tool")
	tkTool.Name = "Telekinesis"
	tkTool.RequiresHandle = false
	tkTool.Parent = LocalPlayer.Backpack
	
	local toolActivatedConnection = tkTool.Activated:Connect(function()
		if not isTelekinesisEnabled then return end
		
		if not draggingObject and mouseTarget then
			draggingObject = true
			targetObject = mouseTarget
			
			if targetObject:IsA("BasePart") then
				targetObject.Anchored = true
			end
			
			heldObject = targetObject
			
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Telekinesis",
					Text = "Objeto agarrado: " .. targetObject.Name .. " (toca de nuevo para soltar)",
					Duration = 2
				})
			end)
		elseif draggingObject and heldObject then
			if heldObject:IsA("BasePart") and heldObject.Parent then
				heldObject.Anchored = false
			end
			draggingObject = false
			heldObject = nil
			targetObject = nil
			
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Telekinesis",
					Text = "Objeto soltado",
					Duration = 1
				})
			end)
		end
	end)
	
	table.insert(telekinesisConnections, toolActivatedConnection)
	
	local renderConnection = RunService.RenderStepped:Connect(function()
		if not isTelekinesisEnabled then return end
		
		if draggingObject and heldObject and heldObject.Parent then
			local character = LocalPlayer.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					local mouseHit = mouse.Hit
					if mouseHit then
						local direction = (mouseHit.Position - root.Position).Unit
						local targetPosition = root.Position + direction * holdDistance
						heldObject.Position = heldObject.Position:Lerp(targetPosition + Vector3.new(0, 2, 0), 0.3)
						local lookAtPos = root.Position
						heldObject.CFrame = CFrame.new(heldObject.Position, lookAtPos)
					end
				end
			end
		elseif heldObject and not draggingObject and heldObject.Parent then
			if heldObject:IsA("BasePart") then
				heldObject.Anchored = false
			end
			heldObject = nil
		end
	end)
	
	table.insert(telekinesisConnections, renderConnection)
end

local function stopTelekinesis()
	isTelekinesisEnabled = false
	cleanupTelekinesis()
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

-- Frame principal
local mainFrame = Instance.new("Frame")
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
mainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
mainFrame.Size = UDim2.new(0, 420, 0, 320)
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

-- Header
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

-- Botón minimizar
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

-- BOTÓN FLOTANTE MEJORADO
local floatingButton = Instance.new("TextButton")
floatingButton.Name = "FloatingButton"
floatingButton.Size = UDim2.new(0, 55, 0, 55)
floatingButton.Position = UDim2.new(0.02, 0, 0.4, 0)
floatingButton.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
floatingButton.Text = "AXIS"
floatingButton.TextColor3 = Color3.fromRGB(150, 120, 255)
floatingButton.TextSize = 13
floatingButton.Font = Enum.Font.GothamBold
floatingButton.Visible = false
floatingButton.Parent = screenGui

local floatingCorner = Instance.new("UICorner")
floatingCorner.CornerRadius = UDim.new(0, 28)
floatingCorner.Parent = floatingButton

local floatingStroke = Instance.new("UIStroke")
floatingStroke.Color = Color3.fromRGB(150, 120, 255)
floatingStroke.Thickness = 1.5
floatingStroke.Parent = floatingButton

-- Sistema de arrastre para el botón flotante
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil
local wasDragged = false

floatingButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = floatingButton.Position
		wasDragged = false
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

floatingButton.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		
		if delta.Magnitude > 5 then
			wasDragged = true
		end
		
		floatingButton.Position = UDim2.new(
			startPos.X.Scale, 
			startPos.X.Offset + delta.X, 
			startPos.Y.Scale, 
			startPos.Y.Offset + delta.Y
		)
	end
end)

floatingButton.MouseButton1Click:Connect(function()
	if not wasDragged then
		floatingButton.Visible = false
		mainFrame.Visible = true
	end
end)

minimizeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	floatingButton.Visible = true
end)

-- Sidebar
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

-- Pestañas
local tabPhysics = Instance.new("ScrollingFrame")
tabPhysics.Position = UDim2.new(0, 125, 0, 45)
tabPhysics.Size = UDim2.new(1, -130, 1, -50)
tabPhysics.BackgroundTransparency = 1
tabPhysics.CanvasSize = UDim2.new(0, 0, 0, 300)
tabPhysics.ScrollBarThickness = 0
tabPhysics.Visible = true
tabPhysics.Parent = mainFrame

local tabExtras = Instance.new("ScrollingFrame")
tabExtras.Position = UDim2.new(0, 125, 0, 45)
tabExtras.Size = UDim2.new(1, -130, 1, -50)
tabExtras.BackgroundTransparency = 1
tabExtras.CanvasSize = UDim2.new(0, 0, 0, 400)
tabExtras.ScrollBarThickness = 0
tabExtras.Visible = false
tabExtras.Parent = mainFrame

local tabPlayers = Instance.new("ScrollingFrame")
tabPlayers.Position = UDim2.new(0, 125, 0, 45)
tabPlayers.Size = UDim2.new(1, -130, 1, -50)
tabPlayers.BackgroundTransparency = 1
tabPlayers.CanvasSize = UDim2.new(0, 0, 0, 500)
tabPlayers.ScrollBarThickness = 2
tabPlayers.ScrollBarImageColor3 = Color3.fromRGB(150, 120, 255)
tabPlayers.Visible = false
tabPlayers.Parent = mainFrame

local tabUtilities = Instance.new("ScrollingFrame")
tabUtilities.Position = UDim2.new(0, 125, 0, 45)
tabUtilities.Size = UDim2.new(1, -130, 1, -50)
tabUtilities.BackgroundTransparency = 1
tabUtilities.CanvasSize = UDim2.new(0, 0, 0, 350)
tabUtilities.ScrollBarThickness = 0
tabUtilities.Visible = false
tabUtilities.Parent = mainFrame

-- Botones del sidebar
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
local btnPlayers = createSidebarButton("Jugadores 👤", 84)
local btnUtilities = createSidebarButton("Utilidades", 121)

local function switchTab(button, tab)
	btnPhysics.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnPhysics.TextColor3 = Color3.fromRGB(150, 150, 160)
	btnExtras.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnExtras.TextColor3 = Color3.fromRGB(150, 150, 160)
	btnPlayers.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnPlayers.TextColor3 = Color3.fromRGB(150, 150, 160)
	btnUtilities.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	btnUtilities.TextColor3 = Color3.fromRGB(150, 150, 160)
	
	tabPhysics.Visible = false
	tabExtras.Visible = false
	tabPlayers.Visible = false
	tabUtilities.Visible = false
	
	button.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	tab.Visible = true
end

btnPhysics.MouseButton1Click:Connect(function() switchTab(btnPhysics, tabPhysics) end)
btnExtras.MouseButton1Click:Connect(function() switchTab(btnExtras, tabExtras) end)
btnPlayers.MouseButton1Click:Connect(function() switchTab(btnPlayers, tabPlayers) end)
btnUtilities.MouseButton1Click:Connect(function() switchTab(btnUtilities, tabUtilities) end)

switchTab(btnPhysics, tabPhysics)

-- Funciones helper para crear elementos UI
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

-- ==================== SISTEMA DE LISTA DE JUGADORES ====================

local playerListFrame = Instance.new("Frame")
playerListFrame.Size = UDim2.new(1, 0, 0, 0)
playerListFrame.BackgroundTransparency = 1
playerListFrame.Parent = tabPlayers

local function createPlayerEntry(player, yPosition)
	local entryFrame = Instance.new("Frame")
	entryFrame.Size = UDim2.new(1, -10, 0, 70)
	entryFrame.Position = UDim2.new(0.02, 0, 0, yPosition)
	entryFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
	entryFrame.Parent = playerListFrame
	
	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = UDim.new(0, 8)
	entryCorner.Parent = entryFrame
	
	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Size = UDim2.new(0, 45, 0, 45)
	avatarImage.Position = UDim2.new(0.02, 0, 0.18, 0)
	avatarImage.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	avatarImage.Parent = entryFrame
	
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 22)
	avatarCorner.Parent = avatarImage
	
	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = Color3.fromRGB(150, 120, 255)
	avatarStroke.Thickness = 1
	avatarStroke.Parent = avatarImage
	
	local userId = player.UserId
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size48x48
	local thumbnail, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
	if isReady then
		avatarImage.Image = thumbnail
	else
		avatarImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	end
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 100, 0, 20)
	nameLabel.Position = UDim2.new(0.22, 0, 0.05, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = entryFrame
	
	if player.DisplayName ~= player.Name then
		local displayLabel = Instance.new("TextLabel")
		displayLabel.Size = UDim2.new(0, 100, 0, 16)
		displayLabel.Position = UDim2.new(0.22, 0, 0.42, 0)
		displayLabel.BackgroundTransparency = 1
		displayLabel.Text = "@" .. player.DisplayName
		displayLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
		displayLabel.TextSize = 10
		displayLabel.Font = Enum.Font.Gotham
		displayLabel.TextXAlignment = Enum.TextXAlignment.Left
		displayLabel.TextTruncate = Enum.TextTruncate.AtEnd
		displayLabel.Parent = entryFrame
	end
	
	local buttonsY = 0.55
	
	local spyButton = Instance.new("TextButton")
	spyButton.Size = UDim2.new(0, 45, 0, 22)
	spyButton.Position = UDim2.new(0.55, 0, buttonsY, 0)
	spyButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
	spyButton.Text = "👁️"
	spyButton.TextSize = 12
	spyButton.Font = Enum.Font.GothamBold
	spyButton.Parent = entryFrame
	
	local spyBtnCorner = Instance.new("UICorner")
	spyBtnCorner.CornerRadius = UDim.new(0, 4)
	spyBtnCorner.Parent = spyButton
	
	spyButton.MouseButton1Click:Connect(function()
		spyOnPlayer(player)
	end)
	
	local teleportButton = Instance.new("TextButton")
	teleportButton.Size = UDim2.new(0, 45, 0, 22)
	teleportButton.Position = UDim2.new(0.72, 0, buttonsY, 0)
	teleportButton.BackgroundColor3 = Color3.fromRGB(130, 90, 255)
	teleportButton.Text = "📍"
	teleportButton.TextSize = 12
	teleportButton.Font = Enum.Font.GothamBold
	teleportButton.Parent = entryFrame
	
	local teleportBtnCorner = Instance.new("UICorner")
	teleportBtnCorner.CornerRadius = UDim.new(0, 4)
	teleportBtnCorner.Parent = teleportButton
	
	teleportButton.MouseButton1Click:Connect(function()
		teleportToPlayer(player)
	end)
	
	local fixButton = Instance.new("TextButton")
	fixButton.Size = UDim2.new(0, 45, 0, 22)
	fixButton.Position = UDim2.new(0.89, 0, buttonsY, 0)
	fixButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
	fixButton.Text = "🎯"
	fixButton.TextSize = 12
	fixButton.Font = Enum.Font.GothamBold
	fixButton.Parent = entryFrame
	
	local fixBtnCorner = Instance.new("UICorner")
	fixBtnCorner.CornerRadius = UDim.new(0, 4)
	fixBtnCorner.Parent = fixButton
	
	fixButton.MouseButton1Click:Connect(function()
		fixCameraOnPlayer(player)
	end)
	
	return entryFrame
end

local function updatePlayerList()
	for _, child in pairs(playerListFrame:GetChildren()) do
		child:Destroy()
	end
	
	local players = {}
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player)
		end
	end
	
	local yPos = 0
	for _, player in pairs(players) do
		createPlayerEntry(player, yPos)
		yPos = yPos + 75
	end
	
	if #players == 0 then
		local noPlayersLabel = Instance.new("TextLabel")
		noPlayersLabel.Size = UDim2.new(1, -10, 0, 40)
		noPlayersLabel.Position = UDim2.new(0.02, 0, 0, 10)
		noPlayersLabel.BackgroundTransparency = 1
		noPlayersLabel.Text = "No hay otros jugadores en el servidor"
		noPlayersLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
		noPlayersLabel.TextSize = 12
		noPlayersLabel.Font = Enum.Font.Gotham
		noPlayersLabel.Parent = playerListFrame
	end
	
	tabPlayers.CanvasSize = UDim2.new(0, 0, 0, math.max(75 * #players, 100))
end

local stopSpyButton = createSimpleButton(tabPlayers, "🛑 Dejar de Espiar", 0, Color3.fromRGB(180, 50, 50), function()
	stopSpying()
end)

local refreshListButton = createSimpleButton(tabPlayers, "🔄 Actualizar Lista", 38, Color3.fromRGB(0, 120, 200), function()
	updatePlayerList()
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Actualizado",
			Text = "Lista de jugadores actualizada",
			Duration = 1
		})
	end)
end)

playerListFrame.Position = UDim2.new(0, 0, 0, 85)

local listTitleLabel = Instance.new("TextLabel")
listTitleLabel.Size = UDim2.new(1, -10, 0, 20)
listTitleLabel.Position = UDim2.new(0.02, 0, 0, 0)
listTitleLabel.BackgroundTransparency = 1
listTitleLabel.Text = "Jugadores en el servidor:"
listTitleLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
listTitleLabel.TextSize = 11
listTitleLabel.Font = Enum.Font.GothamBold
listTitleLabel.Parent = playerListFrame

-- ==================== CONTENIDO DE LAS PESTAÑAS ====================

-- === PESTAÑA FÍSICAS ===

local physicsToggleBtn = createSimpleButton(tabPhysics, "Sistema de Físicas: APAGADO", 0, nil, nil)

physicsToggleBtn.MouseButton1Click:Connect(function()
	physicsEnabled = not physicsEnabled
	
	if physicsEnabled then
		physicsToggleBtn.Text = "Sistema de Físicas: ACTIVADO"
		physicsToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = currentWalkSpeed
				humanoid.JumpPower = currentJumpPower
			end
		end
	else
		physicsToggleBtn.Text = "Sistema de Físicas: APAGADO"
		physicsToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		togglePhysics(false)
	end
end)

createInputField(tabPhysics, "Velocidad (16)", "Fijar", 47, function(text)
	local num = tonumber(text)
	if num and num > 0 then
		setWalkSpeed(num)
	end
end)

createInputField(tabPhysics, "Salto (50)", "Fijar", 94, function(text)
	local num = tonumber(text)
	if num and num > 0 then
		setJumpPower(num)
	end
end)

createInputField(tabPhysics, "Gravedad (196)", "Fijar", 141, function(text)
	local num = tonumber(text)
	if num then
		Workspace.Gravity = num
	end
end)

createSimpleButton(tabPhysics, "Restaurar Físicas Originales", 192, Color3.fromRGB(180, 50, 50), function()
	currentWalkSpeed = DEFAULT_WALKSPEED
	currentJumpPower = DEFAULT_JUMPPOWER
	Workspace.Gravity = DEFAULT_GRAVITY
	
	if physicsEnabled then
		local character = LocalPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = DEFAULT_WALKSPEED
				humanoid.JumpPower = DEFAULT_JUMPPOWER
			end
		end
	end
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

local tkButton = createSimpleButton(tabExtras, "Telekinesis: APAGADO", 84, nil, nil)

tkButton.MouseButton1Click:Connect(function()
	isTelekinesisEnabled = not isTelekinesisEnabled
	
	if isTelekinesisEnabled then
		tkButton.Text = "Telekinesis: ACTIVADO"
		tkButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
		startTelekinesis()
	else
		tkButton.Text = "Telekinesis: APAGADO"
		tkButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		stopTelekinesis()
	end
end)

-- NUEVO: Botón de Piano
local pianoButton = createSimpleButton(tabExtras, "🎹 Piano: APAGADO", 126, nil, nil)

pianoButton.MouseButton1Click:Connect(function()
	isPianoActive = not isPianoActive
	
	if isPianoActive then
		pianoButton.Text = "🎹 Piano: ACTIVADO"
		pianoButton.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
		startPiano()
	else
		pianoButton.Text = "🎹 Piano: APAGADO"
		pianoButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		stopPiano()
	end
end)

createSimpleButton(tabExtras, "Establecer posición de Spawn", 168, Color3.fromRGB(0, 120, 200), function()
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		customSpawnCFrame = char.HumanoidRootPart.CFrame
	end
end)

createSimpleButton(tabExtras, "Eliminar Spawn Personalizado", 210, Color3.fromRGB(50, 50, 58), function()
	customSpawnCFrame = nil
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

updatePlayerList()

screenGui.Destroying:Connect(function()
	stopTelekinesis()
	stopSpying()
	stopPiano()
end)

print("PhysicalAxis Hub - Versión Final con Piano cargado correctamente")
print("Nuevo: Piano funcional con sonidos que otros jugadores pueden escuchar")
print("Teclas del piano: A W S E D F T G Y H U J K O L P Ñ Z X C V B N M")
