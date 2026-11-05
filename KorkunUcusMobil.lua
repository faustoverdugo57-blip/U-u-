-- LocalScript (SADECE MOBİL) - KORKUNÇ UÇUŞ
-- Yeri: StarterPlayer > StarterPlayerScripts
-- Joystick = yön | Kamera kaydırma = bakış
-- Butonlar: UÇ/İNİŞ, MAX (en yüksek hız), MIN (en düşük hız), ▲ yüksel, ▼ alçal, X kapat

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Telefon veya tablet değilse çalışma
if not UserInputService.TouchEnabled then return end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- AYARLAR --------------------------------------------------
local MAX_SPEED = 999999   -- MAX butonunun hızı
local MIN_SPEED = 10       -- MIN butonunun hızı
local START_SPEED = 100    -- uçmaya başlayınca hız
local SMOOTHNESS = 6       -- yüksek = daha keskin hızlanma
local MAX_LEAN = 70        -- öne eğilme açısı (derece), yüksek = daha korkunç duruş
local BASE_FOV = 70
local BOOST_FOV = 100      -- hızlanınca kamera açısı
local SHAKE = 0.9          -- kamera titremesi (0 = kapalı)
-------------------------------------------------------------

local flying = false
local currentSpeed = START_SPEED
local velocity = Vector3.zero
local lastFlat = Vector3.new(0, 0, -1)
local fx = {}
local connections = {}
local loop, linearVel, align, trail
local gui, flyButton, speedLabel
local holdUp, holdDown = false, false

-- Joystick girdisi
local controls
task.spawn(function()
	local ok, result = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
		return require(module):GetControls()
	end)
	if ok then controls = result end
end)

local function getJoystick(hum)
	if controls then
		local v = controls:GetMoveVector()
		return Vector2.new(v.X, -v.Z) -- x: sağ/sol, y: ileri/geri
	end
	local dir = hum.MoveDirection
	local cf = camera.CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	return Vector2.new(dir:Dot(right), dir:Dot(look))
end

local function getParts()
	local char = player.Character
	if not char then return end
	return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function updateUI()
	if flyButton then
		flyButton.Text = flying and "İNİŞ" or "UÇ"
		flyButton.BackgroundColor3 = flying and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(190, 20, 40)
	end
	if speedLabel then
		speedLabel.Text = "Hız: " .. tostring(math.floor(currentSpeed))
	end
end

-- Hızı anında değiştirir
local function setSpeed(newSpeed)
	local old = math.max(currentSpeed, 1)
	currentSpeed = newSpeed
	if flying then
		velocity = velocity * (newSpeed / old)
	end
	updateUI()
end

local function stopFlying()
	if not flying then return end
	flying = false

	if loop then loop:Disconnect() loop = nil end
	for _, obj in ipairs(fx) do obj:Destroy() end
	table.clear(fx)

	velocity = Vector3.zero
	holdUp, holdDown = false, false
	camera.FieldOfView = BASE_FOV
	updateUI()

	local hum = getParts()
	if hum then
		hum.CameraOffset = Vector3.zero
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function startFlying()
	local hum, root = getParts()
	if not hum or not root or flying then return end
	flying = true
	hum.PlatformStand = true
	updateUI()

	local char = root.Parent

	-- Hareket
	local att = Instance.new("Attachment")
	att.Parent = root
	table.insert(fx, att)

	linearVel = Instance.new("LinearVelocity")
	linearVel.Attachment0 = att
	linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVel.MaxForce = math.huge
	linearVel.VectorVelocity = Vector3.zero
	linearVel.Parent = root
	table.insert(fx, linearVel)

	-- Dönüş / eğilme
	align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.MaxTorque = math.huge
	align.Responsiveness = 25
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	table.insert(fx, align)

	-- Kan kırmızısı -> siyah iz
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0.5)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0.5)
	a1.Parent = root

	trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.4
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 0, 0), Color3.fromRGB(0, 0, 0))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Enabled = false
	trail.Parent = root
	table.insert(fx, a0)
	table.insert(fx, a1)
	table.insert(fx, trail)

	-- Karakterin etrafında kırmızı parlayan çizgi (aura)
	local hl = Instance.new("Highlight")
	hl.Adornee = char
	hl.FillColor = Color3.fromRGB(0, 0, 0)
	hl.FillTransparency = 0.65
	hl.OutlineColor = Color3.fromRGB(255, 0, 0)
	hl.OutlineTransparency = 0.2
	hl.Parent = char
	table.insert(fx, hl)

	-- Kırmızı ışık
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 0, 0)
	light.Range = 20
	light.Brightness = 2
	light.Parent = root
	table.insert(fx, light)

	-- Arkada kalan siyah duman
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 8),
	})
	smoke.Lifetime = NumberRange.new(0.8, 1.6)
	smoke.Speed = NumberRange.new(0, 2)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.LightInfluence = 0
	smoke.Rate = 0
	smoke.Parent = root
	table.insert(fx, smoke)

	-- Kırmızı kıvılcımlar
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 30, 0))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Lifetime = NumberRange.new(0.4, 0.9)
	embers.Speed = NumberRange.new(2, 8)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Rate = 0
	embers.Parent = root
	table.insert(fx, embers)

	-- Ekran efektleri: soluk, kırmızımsı, bulanık görüntü
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Parent = camera
	table.insert(fx, cc)

	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = camera
	table.insert(fx, blur)

	loop = RunService.RenderStepped:Connect(function(dt)
		if not root.Parent then
			stopFlying()
			return
		end

		local t = os.clock()
		local cf = camera.CFrame
		local stick = getJoystick(hum)

		-- Yön = kamera yönü x joystick + yukarı/aşağı butonu
		local move = cf.LookVector * stick.Y + cf.RightVector * stick.X
		move += Vector3.yAxis * ((holdUp and 1 or 0) - (holdDown and 1 or 0))
		if move.Magnitude > 1 then move = move.Unit end

		local target = move * currentSpeed
		velocity = velocity:Lerp(target, 1 - math.exp(-SMOOTHNESS * dt))
		linearVel.VectorVelocity = velocity

		local speed = velocity.Magnitude
		local power = math.clamp(speed / 150, 0, 1)   -- efektlerin şiddeti
		local intensity = 0.4 + 0.6 * power

		-- Kameraya dön, avcı gibi öne eğil, hızlanınca titre
		local look = cf.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.05 then lastFlat = flat.Unit end
		local base = CFrame.lookAt(Vector3.zero, lastFlat)

		local ref = math.max(currentSpeed, 1)
		local fwd = math.clamp(velocity:Dot(lastFlat) / ref, -1, 1)
		local side = math.clamp(velocity:Dot(base.RightVector) / ref, -1, 1)
		local twitchP = math.noise(t * 14, 3.1) * math.rad(8) * power
		local twitchR = math.noise(t * 14, 9.7) * math.rad(12) * power
		align.CFrame = base * CFrame.Angles(
			-math.rad(MAX_LEAN * fwd) + twitchP,
			0,
			-math.rad(MAX_LEAN * side) + twitchR
		)

		-- Kamera: açı, titreme
		local targetFov = BASE_FOV + (BOOST_FOV - BASE_FOV) * power
		camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 8, 1)
		hum.CameraOffset = Vector3.new(math.noise(t * 25, 1.3), math.noise(t * 25, 7.7), 0) * SHAKE * power

		-- Korku efektleri
		local pulse = (math.sin(t * 6) + 1) / 2
		hl.OutlineTransparency = 0.5 * (1 - pulse)
		light.Brightness = 1 + 3 * pulse

		cc.Saturation = -0.8 * intensity
		cc.Contrast = 0.35 * intensity
		cc.Brightness = -0.08 * intensity
		cc.TintColor = Color3.new(1, 1 - 0.55 * intensity, 1 - 0.55 * intensity)
		blur.Size = 8 * power

		smoke.Rate = 70 * power
		embers.Rate = 40 * power
		trail.Enabled = speed > 20
	end)
end

-- HER ŞEYİ KAPAT VE SİL
local function closeAll()
	stopFlying() -- uçuyorsa uçmayı kapatır, efektleri siler
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	camera.FieldOfView = BASE_FOV
	if gui then
		gui:Destroy()
		gui = nil
	end
end

-- ARAYÜZ ----------------------------------------------------
gui = Instance.new("ScreenGui")
gui.Name = "UcmaKontrol"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.new(1, -150, 1, -24) -- butonların yeri
holder.Size = UDim2.fromOffset(202, 132)
holder.BackgroundTransparency = 1
holder.Parent = gui

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(62, 62)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.FillDirectionMaxCells = 3
grid.Parent = holder

speedLabel = Instance.new("TextLabel")
speedLabel.AnchorPoint = Vector2.new(1, 1)
speedLabel.Position = UDim2.new(1, -150, 1, -160)
speedLabel.Size = UDim2.fromOffset(202, 24)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextScaled = true
speedLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
speedLabel.TextStrokeTransparency = 0.3
speedLabel.Parent = gui

local function makeButton(text, color, order)
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.15
	b.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = b

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 40, 40)
	stroke.Transparency = 0.3
	stroke.Thickness = 2
	stroke.Parent = b
	return b
end

local function bindHold(button, setter)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then setter(true) end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then setter(false) end
	end)
end

-- Üst sıra: UÇ | MAX | MIN
flyButton = makeButton("UÇ", Color3.fromRGB(190, 20, 40), 1)
flyButton.Activated:Connect(function()
	if flying then stopFlying() else startFlying() end
end)

makeButton("MAX", Color3.fromRGB(120, 0, 0), 2).Activated:Connect(function()
	setSpeed(MAX_SPEED)
end)

makeButton("MIN", Color3.fromRGB(40, 40, 50), 3).Activated:Connect(function()
	setSpeed(MIN_SPEED)
end)

-- Alt sıra: ▲ | ▼ | X (kapat)
bindHold(makeButton("▲", Color3.fromRGB(30, 30, 40), 4), function(v) holdUp = v end)
bindHold(makeButton("▼", Color3.fromRGB(30, 30, 40), 5), function(v) holdDown = v end)
makeButton("X", Color3.fromRGB(0, 0, 0), 6).Activated:Connect(closeAll)

table.insert(connections, player.CharacterRemoving:Connect(stopFlying))

updateUI()
