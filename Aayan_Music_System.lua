--[[
	AAYAN MUSIC SYSTEM  -  LocalScript (client side)

	WHERE TO PUT IT (Roblox Studio):
	  StarterPlayer > StarterPlayerScripts > New LocalScript  (paste this whole file)
	  (StarterGui also works.) It must be a LocalScript, NOT a normal Script,
	  because it builds a GUI and plays audio only for the local player.

	FEATURES
	  * Play / Pause, Next / Previous, Stop, progress bar (seek) with time, volume slider + mute
	  * Editable SoundId box (PLAY / ADD), playlist with search, repeat (off / all / one), shuffle
	  * Piano page (on-screen keys + optional keyboard) -> needs a piano NOTE sample you provide
	  * Draggable window, minimize / restore, close, and a draggable round toggle on the left
	  * Re-running the script rebuilds everything cleanly (no duplicate GUIs / sounds / connections)

	AUDIO NOTE
	  Only audio that Roblox lets your experience play will work. Private, deleted or moderated
	  audio simply fails to load; the GUI shows "Failed to load" instead of erroring.
	  Nothing here tries to bypass audio permissions.
]]

--==================================================
-- SERVICES
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- CONFIG  (edit these)
--==================================================
local GUI_NAME = "AayanMusicSystem"
local SOUND_NAME = "AayanMusicSystem_Sound"
local PIANO_FOLDER_NAME = "AayanMusicSystem_Piano"

-- Piano: paste the SoundId of ONE piano note recorded at C4 (middle C).
-- No ID is invented here: leave "" and paste your own in the PIANO tab at runtime.
local PIANO_SAMPLE_ID = ""

-- Playlist: your tracks. You can also add more in-game with the ADD button.
local TRACKS = {
	{ Name = "FREE WILL FUNK", ID = "rbxassetid://94378181487716" },
	{ Name = "IN THE FUNK A", ID = "rbxassetid://1847557891" },
	{ Name = "TOMA FUNK PHONK", ID = "rbxassetid://129098116998483" },
	{ Name = "BRAZIL DO FUNK", ID = "rbxassetid://133498554139200" },
	{ Name = "BETTER OFF ALONE (FUNK)", ID = "rbxassetid://124383118098366" },
	{ Name = "67 KID FUNK", ID = "rbxassetid://84142247103485" },
	{ Name = "FUTURE FUNK CENTRAL", ID = "rbxassetid://109406849270158" },
	{ Name = "CRYSTAL FUNK!", ID = "rbxassetid://103445348511856" },
	{ Name = "BALLERINA CAPPUCCINA FUNK!", ID = "rbxassetid://139295298658283" },
	{ Name = "GOTH FUNK", ID = "rbxassetid://140704128008979" },
	{ Name = "FUNK SIGCURO", ID = "rbxassetid://96028783423401" },
	{ Name = "GOTH FUNK 2", ID = "rbxassetid://74482331795312" },
	{ Name = "MOH LELU UP BIHAR KE", ID = "rbxassetid://95909411418420" },
	{ Name = "SADIYA KAROYA BHOJPURI SONG", ID = "rbxassetid://140415804746906" },
	{ Name = "SEJIYA PAR PIYA AILE NA", ID = "rbxassetid://87577798625777" },
	{ Name = "NIMBU KHARBUJA BHOJPURI", ID = "rbxassetid://89700384406008" },
	{ Name = "HAMARA MARAD CHAHI", ID = "rbxassetid://131679833636653" },
	{ Name = "BANSURI (BHOJPURI)", ID = "rbxassetid://79568658897083" },
	{ Name = "TAKA TAKI DHER BHAIL", ID = "rbxassetid://117615820552185" },
	{ Name = "VIDEO COLLING PAR HOT", ID = "rbxassetid://126309103230345" },
	{ Name = "SAD END (SOLO PIANO)", ID = "rbxassetid://1838635121" },
	{ Name = "THE STILL, SAD MUSIC", ID = "rbxassetid://9046435309" },
	{ Name = "MEDIEVAL FANTASY SAD", ID = "rbxassetid://1836102253" },
	{ Name = "SAD VIOLIN", ID = "rbxassetid://135308045" },
	{ Name = "LAST TALK", ID = "rbxassetid://9045416584" },
	{ Name = "PHONK", ID = "rbxassetid://140292910030604" },
	{ Name = "PHONK 3", ID = "rbxassetid://139638751795258" },
}

--==================================================
-- CLEAN UP A PREVIOUS RUN (no duplicate GUIs, sounds or connections)
--==================================================
if typeof(_G.AayanMusic_Cleanup) == "function" then
	pcall(_G.AayanMusic_Cleanup)
end

for _, name in ipairs({ GUI_NAME }) do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end
for _, name in ipairs({ SOUND_NAME, PIANO_FOLDER_NAME }) do
	local old = SoundService:FindFirstChild(name)
	if old then old:Destroy() end
end

local alive = true
local connections = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

--==================================================
-- THEME
--==================================================
local C = {
	bg = Color3.fromRGB(12, 10, 24),
	panel = Color3.fromRGB(22, 18, 44),
	panel2 = Color3.fromRGB(32, 26, 62),
	hover = Color3.fromRGB(48, 38, 92),
	purple = Color3.fromRGB(150, 70, 255),
	blue = Color3.fromRGB(40, 170, 255),
	text = Color3.fromRGB(236, 238, 255),
	muted = Color3.fromRGB(148, 148, 190),
	red = Color3.fromRGB(255, 70, 100),
	green = Color3.fromRGB(70, 230, 160),
	warn = Color3.fromRGB(255, 190, 70),
}

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end

local function gradient(p, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(C.purple, C.blue)
	g.Rotation = rot or 0
	g.Parent = p
	return g
end

-- gradient border (UIStroke gradients never tint text)
local function stroke(p, thick, transp)
	local s = Instance.new("UIStroke")
	s.Thickness = thick or 1
	s.Transparency = transp or 0
	s.Color = Color3.new(1, 1, 1)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	local g = gradient(s, 0)
	return s, g
end

local function label(parent, text, size, color, font, xalign)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or C.text
	l.Font = font or Enum.Font.GothamMedium
	l.TextXAlignment = xalign or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function frame(parent, pos, size, color)
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color or C.panel
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function button(parent, text, pos, size, textSize, callback)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = C.panel2
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = C.text
	b.TextSize = textSize or 13
	b.Font = Enum.Font.GothamBold
	b.Parent = parent
	corner(b, 8)
	local s = stroke(b, 1, 0.6)
	local sc = Instance.new("UIScale", b)

	bind(b.MouseEnter, function()
		tween(b, 0.15, { BackgroundColor3 = C.hover })
		tween(s, 0.15, { Transparency = 0 })
	end)
	bind(b.MouseLeave, function()
		tween(b, 0.15, { BackgroundColor3 = b:GetAttribute("Active") and C.hover or C.panel2 })
		tween(s, 0.15, { Transparency = b:GetAttribute("Active") and 0.1 or 0.6 })
		tween(sc, 0.12, { Scale = 1 })
	end)
	bind(b.MouseButton1Down, function()
		tween(sc, 0.08, { Scale = 0.93 })
	end)
	bind(b.MouseButton1Up, function()
		tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if callback then
		bind(b.MouseButton1Click, callback)
	end
	return b
end

local function setActive(b, on)
	b:SetAttribute("Active", on and true or false)
	b.BackgroundColor3 = on and C.hover or C.panel2
	b.TextColor3 = on and C.blue or C.text
end

local function textbox(parent, pos, size, placeholder)
	local t = Instance.new("TextBox")
	t.Position = pos
	t.Size = size
	t.BackgroundColor3 = C.bg
	t.BorderSizePixel = 0
	t.ClearTextOnFocus = false
	t.Text = ""
	t.PlaceholderText = placeholder
	t.PlaceholderColor3 = C.muted
	t.TextColor3 = C.text
	t.TextSize = 12
	t.Font = Enum.Font.GothamMedium
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	corner(t, 8)
	local pad = Instance.new("UIPadding", t)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	local s = stroke(t, 1, 0.7)
	bind(t.Focused, function() tween(s, 0.15, { Transparency = 0 }) end)
	bind(t.FocusLost, function() tween(s, 0.15, { Transparency = 0.7 }) end)
	return t
end

local function fmtTime(sec)
	sec = math.max(0, math.floor((sec or 0) + 0.5))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- accepts "123456789", "rbxassetid://123456789" or a library/asset URL
local function parseSoundId(text)
	if typeof(text) ~= "string" then return nil end
	local digits = string.match(text, "%d+")
	if not digits or #digits < 5 or #digits > 19 then return nil end
	return digits
end

--==================================================
-- SOUND OBJECT
--==================================================
local sound = Instance.new("Sound")
sound.Name = SOUND_NAME
sound.Volume = 0.6
sound.Looped = false
sound.Parent = SoundService

local pianoFolder = Instance.new("Folder")
pianoFolder.Name = PIANO_FOLDER_NAME
pianoFolder.Parent = SoundService

--==================================================
-- STATE
--==================================================
local tracks = {}
for _, t in ipairs(TRACKS) do
	table.insert(tracks, { Name = t.Name, ID = t.ID })
end

local queue = tracks -- tracks currently visible (filtered)
local currentTrack = nil
local state = "stopped" -- stopped | loading | playing | paused | failed
local repeatMode = 0 -- 0 off, 1 all, 2 one
local shuffle = false
local volume = 0.6
local muted = false
local history = {}
local loadToken = 0
local failStreak = 0

--==================================================
-- GUI
--==================================================
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = playerGui

local WIDTH, HEIGHT, HEADER = 340, 500, 40

local main = Instance.new("CanvasGroup")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.Size = UDim2.new(0, WIDTH, 0, HEIGHT)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Visible = false
main.GroupTransparency = 1
main.Parent = gui
corner(main, 16)
local mainStroke, mainStrokeGrad = stroke(main, 2, 0)
do
	-- soft outer glow
	local glow = Instance.new("UIStroke")
	glow.Thickness = 7
	glow.Transparency = 0.82
	glow.Color = Color3.new(1, 1, 1)
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Parent = main
	gradient(glow, 45)
end

local mainScale = Instance.new("UIScale", main)

local bgFill = frame(main, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), Color3.new(1, 1, 1))
bgFill.ZIndex = 0
do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(20, 14, 44), Color3.fromRGB(8, 14, 34))
	g.Rotation = 60
	g.Parent = bgFill
end

local function viewScale()
	local cam = workspace.CurrentCamera
	if not cam then return 1 end
	local v = cam.ViewportSize
	return math.clamp(math.min(v.X / (WIDTH + 30), v.Y / (HEIGHT + 30)), 0.55, 1)
end

-- ===== header (drag handle) =====
local header = frame(main, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, HEADER), C.panel)
header.BackgroundTransparency = 0.25
header.Active = true

local titleL = label(header, "♪  AAYAN MUSIC", 15, C.text, Enum.Font.GothamBlack)
titleL.Position = UDim2.new(0, 14, 0, 0)
titleL.Size = UDim2.new(1, -110, 1, 0)
do
	local g = gradient(titleL, 0)
	g.Color = ColorSequence.new(C.purple, C.blue)
end

local minBtn = button(header, "–", UDim2.new(1, -72, 0.5, -13), UDim2.new(0, 28, 0, 26), 16)
local closeBtn = button(header, "✕", UDim2.new(1, -38, 0.5, -13), UDim2.new(0, 28, 0, 26), 13)

-- ===== tabs =====
local tabBar = frame(main, UDim2.new(0, 10, 0, HEADER + 6), UDim2.new(1, -20, 0, 28), C.bg)
tabBar.BackgroundTransparency = 1
local tabPlayer = button(tabBar, "♫  PLAYER", UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -2, 1, 0), 12)
local tabPiano = button(tabBar, "🎹  PIANO", UDim2.new(0.5, 2, 0, 0), UDim2.new(0.5, -2, 1, 0), 12)

local content = frame(main, UDim2.new(0, 10, 0, HEADER + 40), UDim2.new(1, -20, 1, -(HEADER + 50)), C.bg)
content.BackgroundTransparency = 1
content.ClipsDescendants = true

local pagePlayer = frame(content, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), C.bg)
pagePlayer.BackgroundTransparency = 1
local pagePiano = frame(content, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), C.bg)
pagePiano.BackgroundTransparency = 1
pagePiano.Visible = false

-- toast (small message line at the bottom of the window)
local toastL = label(main, "", 11, C.warn, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
toastL.AnchorPoint = Vector2.new(0.5, 1)
toastL.Position = UDim2.new(0.5, 0, 1, -4)
toastL.Size = UDim2.new(1, -20, 0, 14)
toastL.TextTransparency = 1
toastL.ZIndex = 20
local toastToken = 0
local function toast(text, color)
	toastToken += 1
	local id = toastToken
	toastL.Text = text
	toastL.TextColor3 = color or C.warn
	toastL.TextTransparency = 0
	task.delay(3.2, function()
		if alive and toastToken == id then
			tween(toastL, 0.4, { TextTransparency = 1 })
		end
	end)
end

--==================================================
-- SLIDER HELPER (progress + volume)
--==================================================
local function makeSlider(parent, pos, size, onDrag, onCommit)
	local track = frame(parent, pos, size, Color3.fromRGB(40, 34, 74))
	corner(track, 99)
	local fill = frame(track, UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 1, 0), Color3.new(1, 1, 1))
	corner(fill, 99)
	gradient(fill, 0)
	local knob = frame(track, UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 14, 0, 14), Color3.new(1, 1, 1))
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(knob, 99)
	stroke(knob, 1.5, 0)

	local hit = Instance.new("TextButton")
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.new(0.5, 0, 0.5, 0)
	hit.Size = UDim2.new(1, 10, 0, 26)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Parent = track

	local value, dragging = 0, false
	local api = {}

	function api.set(a)
		a = math.clamp(a, 0, 1)
		value = a
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
	end
	function api.get() return value end
	function api.isDragging() return dragging end

	local function fromX(x)
		local w = track.AbsoluteSize.X
		if w <= 0 then return nil end
		return math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
	end

	bind(hit.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local a = fromX(i.Position.X)
			if a then
				api.set(a)
				if onDrag then onDrag(a) end
			end
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local a = fromX(i.Position.X)
			if a then
				api.set(a)
				if onDrag then onDrag(a) end
			end
		end
	end)
	bind(UserInputService.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if onCommit then onCommit(value) end
		end
	end)
	return api
end

--==================================================
-- PLAYER PAGE
--==================================================
-- now playing card
local card = frame(pagePlayer, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 62), C.panel)
corner(card, 12)
stroke(card, 1, 0.55)

local disc = frame(card, UDim2.new(0, 10, 0.5, -22), UDim2.new(0, 44, 0, 44), Color3.new(1, 1, 1))
corner(disc, 99)
local discGrad = gradient(disc, 0)
local discHole = frame(disc, UDim2.new(0.5, -9, 0.5, -9), UDim2.new(0, 18, 0, 18), C.bg)
corner(discHole, 99)

local nameL = label(card, "No track selected", 14, C.text, Enum.Font.GothamBold)
nameL.Position = UDim2.new(0, 64, 0, 10)
nameL.Size = UDim2.new(1, -140, 0, 20)
local statusL = label(card, "■ Stopped", 11, C.muted, Enum.Font.GothamMedium)
statusL.Position = UDim2.new(0, 64, 0, 33)
statusL.Size = UDim2.new(1, -140, 0, 16)

local eqBars = {}
for i = 1, 5 do
	local b = frame(card, UDim2.new(1, -62 + (i - 1) * 9, 1, -14), UDim2.new(0, 5, 0, 4), Color3.new(1, 1, 1))
	b.AnchorPoint = Vector2.new(0, 1)
	corner(b, 3)
	gradient(b, 90)
	eqBars[i] = b
end

-- progress
local curL = label(pagePlayer, "0:00", 11, C.muted, Enum.Font.GothamMedium)
curL.Position = UDim2.new(0, 2, 0, 66)
curL.Size = UDim2.new(0.5, 0, 0, 14)
local totL = label(pagePlayer, "0:00", 11, C.muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
totL.Position = UDim2.new(0.5, -2, 0, 66)
totL.Size = UDim2.new(0.5, 0, 0, 14)

local progress
progress = makeSlider(pagePlayer, UDim2.new(0, 4, 0, 88), UDim2.new(1, -8, 0, 8), function(a)
	if sound.TimeLength > 0 then
		curL.Text = fmtTime(a * sound.TimeLength)
	end
end, function(a)
	if sound.TimeLength > 0 then
		sound.TimePosition = a * sound.TimeLength
	end
end)

-- controls: shuffle | prev | play | stop | next | repeat
local ctlRow = frame(pagePlayer, UDim2.new(0, 0, 0, 106), UDim2.new(1, 0, 0, 36), C.bg)
ctlRow.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", ctlRow)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center

local function ctl(text, w)
	local b = button(ctlRow, text, UDim2.new(), UDim2.new(0, w or 46, 0, 34), 15)
	return b
end
local shuffleBtn = ctl("🔀")
local prevBtn = ctl("⏮")
local playBtn = ctl("▶", 58)
local stopBtn = ctl("⏹")
local nextBtn = ctl("⏭")
local repeatBtn = ctl("🔁")
playBtn.BackgroundColor3 = C.purple
playBtn.TextColor3 = Color3.new(1, 1, 1)
playBtn:SetAttribute("Active", true)

-- volume
local muteBtn = button(pagePlayer, "🔊", UDim2.new(0, 0, 0, 150), UDim2.new(0, 34, 0, 26), 14)
local volSlider
local volL = label(pagePlayer, "60%", 11, C.text, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
volL.Position = UDim2.new(1, -40, 0, 150)
volL.Size = UDim2.new(0, 40, 0, 26)

local function applyVolume()
	sound.Volume = muted and 0 or volume
	muteBtn.Text = (muted or volume <= 0.001) and "🔇" or (volume < 0.4 and "🔉" or "🔊")
	volL.Text = muted and "MUTE" or (math.floor(volume * 100 + 0.5) .. "%")
end

volSlider = makeSlider(pagePlayer, UDim2.new(0, 46, 0, 159), UDim2.new(1, -96, 0, 8), function(a)
	volume = a
	if a > 0 then muted = false end
	applyVolume()
end)
volSlider.set(volume)
applyVolume()

bind(muteBtn.MouseButton1Click, function()
	muted = not muted
	if not muted and volume <= 0.001 then
		volume = 0.5
		volSlider.set(volume)
	end
	applyVolume()
end)

-- SoundId input
local idBox = textbox(pagePlayer, UDim2.new(0, 0, 0, 184), UDim2.new(1, -98, 0, 28), "Enter SoundId (e.g. 1234567890)")
local playIdBtn = button(pagePlayer, "PLAY", UDim2.new(1, -94, 0, 184), UDim2.new(0, 46, 0, 28), 12)
local addIdBtn = button(pagePlayer, "＋ADD", UDim2.new(1, -44, 0, 184), UDim2.new(0, 44, 0, 28), 12)

-- search
local searchBox = textbox(pagePlayer, UDim2.new(0, 0, 0, 218), UDim2.new(1, 0, 0, 28), "🔎  Search playlist...")

-- playlist
local listFrame = Instance.new("ScrollingFrame")
listFrame.Position = UDim2.new(0, 0, 0, 252)
listFrame.Size = UDim2.new(1, 0, 1, -276)
listFrame.BackgroundColor3 = C.panel
listFrame.BackgroundTransparency = 0.35
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 4
listFrame.ScrollBarImageColor3 = C.purple
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new()
listFrame.ElasticBehavior = Enum.ElasticBehavior.Never
listFrame.Parent = pagePlayer
corner(listFrame, 10)
do
	local l = Instance.new("UIListLayout", listFrame)
	l.Padding = UDim.new(0, 3)
	local p = Instance.new("UIPadding", listFrame)
	p.PaddingTop = UDim.new(0, 4)
	p.PaddingBottom = UDim.new(0, 4)
	p.PaddingLeft = UDim.new(0, 4)
	p.PaddingRight = UDim.new(0, 8)
end
local countL = label(pagePlayer, "", 10, C.muted, Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
countL.AnchorPoint = Vector2.new(0, 1)
countL.Position = UDim2.new(0, 0, 1, -2)
countL.Size = UDim2.new(1, 0, 0, 14)

--==================================================
-- PLAYBACK LOGIC
--==================================================
local itemButtons = {} -- track -> button

local function setState(newState, text, color)
	state = newState
	statusL.Text = text
	statusL.TextColor3 = color or C.muted
	playBtn.Text = (newState == "playing" or newState == "loading") and "⏸" or "▶"
end

local function highlightCurrent()
	for track, b in pairs(itemButtons) do
		local on = (track == currentTrack)
		b.BackgroundColor3 = on and C.hover or C.panel2
		local s = b:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = on and 0 or 0.8 end
		local n = b:FindFirstChild("N")
		if n then n.TextColor3 = on and C.blue or C.text end
	end
end

local playTrack -- forward declaration

local function indexInQueue(track)
	for i, t in ipairs(queue) do
		if t == track then return i end
	end
	return nil
end

local function pickNext(direction)
	if #queue == 0 then return nil end
	if shuffle and direction > 0 then
		if #queue == 1 then return queue[1] end
		local pick
		repeat
			pick = queue[math.random(1, #queue)]
		until pick ~= currentTrack
		return pick
	end
	local idx = indexInQueue(currentTrack)
	if not idx then
		return direction > 0 and queue[1] or queue[#queue]
	end
	local n = idx + direction
	if n > #queue then n = 1 end
	if n < 1 then n = #queue end
	return queue[n]
end

local function stopMusic()
	loadToken += 1
	sound:Stop()
	sound.TimePosition = 0
	progress.set(0)
	curL.Text = "0:00"
	setState("stopped", "■ Stopped", C.muted)
end

function playTrack(track, fromHistoryBack)
	if not alive or not track then return end
	if currentTrack and currentTrack ~= track and not fromHistoryBack then
		table.insert(history, currentTrack)
		if #history > 50 then table.remove(history, 1) end
	end
	currentTrack = track
	nameL.Text = track.Name
	highlightCurrent()

	loadToken += 1
	local token = loadToken

	sound:Stop()
	sound.Looped = (repeatMode == 2)
	sound.TimePosition = 0
	sound.SoundId = track.ID
	progress.set(0)
	curL.Text = "0:00"
	totL.Text = "0:00"
	setState("loading", "⏳ Loading...", C.warn)
	sound:Play()

	task.spawn(function()
		local waited = 0
		while alive and token == loadToken and not sound.IsLoaded and waited < 10 do
			task.wait(0.1)
			waited += 0.1
		end
		if not alive or token ~= loadToken then return end

		if sound.IsLoaded then
			failStreak = 0
			if sound.IsPlaying then
				setState("playing", "▶ Playing", C.green)
			elseif state == "loading" then
				sound:Play()
				setState("playing", "▶ Playing", C.green)
			end
			totL.Text = fmtTime(sound.TimeLength)
		else
			sound:Stop()
			setState("failed", "⚠ Failed to load (private, moderated or unavailable)", C.red)
			toast("Audio unavailable: " .. track.Name, C.red)
			failStreak += 1
			-- skip to the next track, but never loop forever through a fully broken list
			if #queue > 1 and failStreak < #queue and indexInQueue(track) then
				task.wait(1.2)
				if alive and token == loadToken then
					playTrack(pickNext(1))
				end
			end
		end
	end)
end

local function togglePlay()
	if state == "playing" or state == "loading" then
		sound:Pause()
		setState("paused", "⏸ Paused", C.warn)
	elseif state == "paused" and currentTrack and sound.IsLoaded then
		sound:Resume()
		setState("playing", "▶ Playing", C.green)
	else
		playTrack(currentTrack or queue[1])
	end
end

bind(playBtn.MouseButton1Click, togglePlay)
bind(stopBtn.MouseButton1Click, stopMusic)
bind(nextBtn.MouseButton1Click, function()
	local t = pickNext(1)
	if t then playTrack(t) end
end)
bind(prevBtn.MouseButton1Click, function()
	-- more than 3 seconds in: restart; otherwise go back
	if sound.TimePosition > 3 and currentTrack then
		sound.TimePosition = 0
		return
	end
	local t
	if shuffle and #history > 0 then
		t = table.remove(history)
	else
		t = pickNext(-1)
	end
	if t then playTrack(t, true) end
end)

local function refreshToggles()
	setActive(shuffleBtn, shuffle)
	repeatBtn.Text = (repeatMode == 2) and "🔂" or "🔁"
	setActive(repeatBtn, repeatMode > 0)
	sound.Looped = (repeatMode == 2)
end
bind(shuffleBtn.MouseButton1Click, function()
	shuffle = not shuffle
	refreshToggles()
	toast(shuffle and "Shuffle ON" or "Shuffle OFF", C.blue)
end)
bind(repeatBtn.MouseButton1Click, function()
	repeatMode = (repeatMode + 1) % 3
	refreshToggles()
	toast(({ [0] = "Repeat OFF", "Repeat ALL", "Repeat ONE" })[repeatMode], C.blue)
end)
refreshToggles()

bind(sound.Ended, function()
	if not alive or state ~= "playing" then return end
	if repeatMode == 2 then
		sound.TimePosition = 0
		sound:Play()
		return
	end
	local idx = indexInQueue(currentTrack)
	if repeatMode == 0 and not shuffle and idx == #queue then
		stopMusic()
		return
	end
	local t = pickNext(1)
	if t then playTrack(t) else stopMusic() end
end)

--==================================================
-- PLAYLIST UI
--==================================================
local function refreshPlaylist()
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("GuiButton") then c:Destroy() end
	end
	table.clear(itemButtons)

	local q = string.lower(searchBox.Text or "")
	queue = {}
	for _, t in ipairs(tracks) do
		if q == "" or string.find(string.lower(t.Name), q, 1, true) or string.find(t.ID, q, 1, true) then
			table.insert(queue, t)
		end
	end

	for i, t in ipairs(queue) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 34)
		b.BackgroundColor3 = C.panel2
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Text = ""
		b.LayoutOrder = i
		b.Parent = listFrame
		corner(b, 8)
		local s = stroke(b, 1, 0.8)

		local n = label(b, string.format("%02d  %s", i, t.Name), 12, C.text, Enum.Font.GothamBold)
		n.Name = "N"
		n.Position = UDim2.new(0, 8, 0, 3)
		n.Size = UDim2.new(1, -16, 0, 15)
		local idl = label(b, t.ID, 9, C.muted, Enum.Font.Code)
		idl.Position = UDim2.new(0, 8, 0, 18)
		idl.Size = UDim2.new(1, -16, 0, 12)

		bind(b.MouseEnter, function()
			if t ~= currentTrack then tween(b, 0.12, { BackgroundColor3 = C.hover }) end
		end)
		bind(b.MouseLeave, function()
			if t ~= currentTrack then tween(b, 0.12, { BackgroundColor3 = C.panel2 }) end
		end)
		bind(b.MouseButton1Click, function()
			failStreak = 0
			playTrack(t)
		end)
		itemButtons[t] = b
	end
	highlightCurrent()
	countL.Text = (q == "") and (#tracks .. " tracks") or (#queue .. " / " .. #tracks .. " tracks")
end

bind(searchBox:GetPropertyChangedSignal("Text"), refreshPlaylist)
refreshPlaylist()

--==================================================
-- SOUNDID INPUT (PLAY / ADD)
--==================================================
local function readId()
	local digits = parseSoundId(idBox.Text)
	if not digits then
		toast("Invalid SoundId. Use numbers like 1234567890", C.red)
		return nil
	end
	return digits
end

bind(playIdBtn.MouseButton1Click, function()
	local digits = readId()
	if not digits then return end
	local full = "rbxassetid://" .. digits
	for _, t in ipairs(tracks) do
		if t.ID == full then
			failStreak = 0
			playTrack(t)
			return
		end
	end
	failStreak = 0
	-- not in the playlist: play it as a one-off custom track
	playTrack({ Name = "Custom " .. digits, ID = full, Custom = true })
end)

bind(addIdBtn.MouseButton1Click, function()
	local digits = readId()
	if not digits then return end
	local full = "rbxassetid://" .. digits
	for _, t in ipairs(tracks) do
		if t.ID == full then
			toast("Already in the playlist", C.warn)
			return
		end
	end
	local newTrack = { Name = "Custom " .. digits, ID = full }
	table.insert(tracks, newTrack)
	refreshPlaylist()
	toast("Added to playlist", C.green)
	-- try to fetch the real audio name (optional, ignored on failure)
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(tonumber(digits))
		end)
		if alive and ok and info and typeof(info.Name) == "string" and info.Name ~= "" then
			newTrack.Name = string.upper(info.Name)
			refreshPlaylist()
		end
	end)
end)

--==================================================
-- PIANO PAGE
--==================================================
local pianoSample = PIANO_SAMPLE_ID
local octave = 0
local keyboardOn = false

local pInfo = label(pagePiano, "Paste ONE piano note (C4) SoundId, then tap the keys.", 11, C.muted, Enum.Font.GothamMedium)
pInfo.Size = UDim2.new(1, 0, 0, 16)
pInfo.TextWrapped = true
pInfo.TextTruncate = Enum.TextTruncate.None

local sampleBox = textbox(pagePiano, UDim2.new(0, 0, 0, 22), UDim2.new(1, -60, 0, 28), "Piano note SoundId (C4)")
sampleBox.Text = pianoSample
local setSampleBtn = button(pagePiano, "SET", UDim2.new(1, -56, 0, 22), UDim2.new(0, 56, 0, 28), 12)

local octMinus = button(pagePiano, "−", UDim2.new(0, 0, 0, 58), UDim2.new(0, 34, 0, 28), 16)
local octL = label(pagePiano, "OCTAVE 0", 12, C.text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
octL.Position = UDim2.new(0, 38, 0, 58)
octL.Size = UDim2.new(0, 90, 0, 28)
local octPlus = button(pagePiano, "+", UDim2.new(0, 132, 0, 58), UDim2.new(0, 34, 0, 28), 16)
local kbBtn = button(pagePiano, "⌨ KEYS: OFF", UDim2.new(1, -140, 0, 58), UDim2.new(0, 140, 0, 28), 11)

local keysFrame = frame(pagePiano, UDim2.new(0, 0, 0, 98), UDim2.new(1, 0, 0, 170), C.bg)
keysFrame.BackgroundTransparency = 1

local WHITE = {
	{ 0, "C", Enum.KeyCode.Z }, { 2, "D", Enum.KeyCode.X }, { 4, "E", Enum.KeyCode.C },
	{ 5, "F", Enum.KeyCode.V }, { 7, "G", Enum.KeyCode.B }, { 9, "A", Enum.KeyCode.N },
	{ 11, "B", Enum.KeyCode.M }, { 12, "C", Enum.KeyCode.Comma }, { 14, "D", Enum.KeyCode.Period },
	{ 16, "E", Enum.KeyCode.Slash },
}
-- black keys sit after white key index i
local BLACK = {
	{ 1, 1, "C#", Enum.KeyCode.S }, { 2, 3, "D#", Enum.KeyCode.D }, { 4, 6, "F#", Enum.KeyCode.G },
	{ 5, 8, "G#", Enum.KeyCode.H }, { 6, 10, "A#", Enum.KeyCode.J }, { 8, 13, "C#", Enum.KeyCode.L },
	{ 9, 15, "D#", Enum.KeyCode.Semicolon },
}

local activeNotes = 0
local MAX_NOTES = 16
local function playNote(semitone)
	if pianoSample == "" then
		toast("Paste a piano note SoundId above first", C.warn)
		return
	end
	if activeNotes >= MAX_NOTES then return end
	local s = Instance.new("Sound")
	s.SoundId = pianoSample
	s.Volume = muted and 0 or math.clamp(volume + 0.2, 0, 1)
	s.PlaybackSpeed = math.clamp(2 ^ ((semitone + octave * 12) / 12), 0.1, 10)
	s.Parent = pianoFolder
	activeNotes += 1
	local done = false
	local function finish()
		if done then return end
		done = true
		activeNotes = math.max(0, activeNotes - 1)
		if s.Parent then s:Destroy() end
	end
	s.Ended:Once(finish)
	s:Play()
	Debris:AddItem(s, 6)
	task.delay(6.2, finish)
end

local keyVisual = {} -- keycode -> function(pressed)
local function makeKey(parent, pos, size, color, semitone, text, textColor, z, keyCode)
	local k = Instance.new("TextButton")
	k.Position = pos
	k.Size = size
	k.BackgroundColor3 = color
	k.BorderSizePixel = 0
	k.AutoButtonColor = false
	k.Text = ""
	k.ZIndex = z
	k.Parent = parent
	corner(k, 5)
	local l = label(k, text, 10, textColor, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -4)
	l.Size = UDim2.new(1, 0, 0, 12)
	l.ZIndex = z + 1
	local function visual(pressed)
		tween(k, pressed and 0.04 or 0.18, { BackgroundColor3 = pressed and C.purple or color })
	end
	bind(k.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			visual(true)
			playNote(semitone)
			local c
			c = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					visual(false)
					c:Disconnect()
				end
			end)
		end
	end)
	if keyCode then
		keyVisual[keyCode] = { visual = visual, semitone = semitone }
	end
	return k
end

do
	local total = #WHITE
	local gap = 2
	local ww = 1 / total
	for i, w in ipairs(WHITE) do
		makeKey(
			keysFrame,
			UDim2.new(ww * (i - 1), (i == 1) and 0 or gap / 2, 0, 0),
			UDim2.new(ww, (i == 1 or i == total) and -gap / 2 or -gap, 1, 0),
			Color3.fromRGB(238, 238, 252), w[1], w[2] .. "\n" .. string.upper(w[3].Name == "Comma" and "," or w[3].Name == "Period" and "." or w[3].Name == "Slash" and "/" or w[3].Name),
			Color3.fromRGB(40, 30, 80), 2, w[3]
		)
	end
	for _, b in ipairs(BLACK) do
		local after = b[1]
		local kc = b[4]
		local nm = kc.Name == "Semicolon" and ";" or kc.Name
		local k = makeKey(
			keysFrame,
			UDim2.new(ww * after, -11, 0, 0),
			UDim2.new(0, 22, 0.6, 0),
			Color3.fromRGB(26, 20, 52), b[2], nm,
			Color3.fromRGB(200, 190, 255), 5, kc
		)
		stroke(k, 1, 0.4)
	end
end
-- the two-line labels on white keys
for _, d in ipairs(keysFrame:GetChildren()) do
	local l = d:FindFirstChildOfClass("TextLabel")
	if l and l.Text:find("\n") then
		l.TextWrapped = true
		l.Size = UDim2.new(1, 0, 0, 26)
		l.TextTruncate = Enum.TextTruncate.None
	end
end

local pHint = label(pagePiano, "Tip: the keyboard keys only work while KEYS is ON and a text box is not focused.", 10, C.muted, Enum.Font.GothamMedium)
pHint.Position = UDim2.new(0, 0, 0, 274)
pHint.Size = UDim2.new(1, 0, 0, 28)
pHint.TextWrapped = true
pHint.TextTruncate = Enum.TextTruncate.None

local function setOctave(n)
	octave = math.clamp(n, -2, 2)
	octL.Text = "OCTAVE " .. (octave > 0 and "+" or "") .. octave
end
bind(octMinus.MouseButton1Click, function() setOctave(octave - 1) end)
bind(octPlus.MouseButton1Click, function() setOctave(octave + 1) end)
setOctave(0)

bind(setSampleBtn.MouseButton1Click, function()
	local digits = parseSoundId(sampleBox.Text)
	if not digits then
		toast("Invalid piano SoundId", C.red)
		return
	end
	pianoSample = "rbxassetid://" .. digits
	sampleBox.Text = digits
	toast("Piano sample set", C.green)
	-- test that it loads (pcall-safe preload)
	task.spawn(function()
		local t = Instance.new("Sound")
		t.SoundId = pianoSample
		t.Volume = 0
		t.Parent = pianoFolder
		local waited = 0
		while alive and not t.IsLoaded and waited < 8 do
			task.wait(0.1)
			waited += 0.1
		end
		local ok = t.IsLoaded
		t:Destroy()
		if alive and not ok then
			toast("That piano audio could not be loaded", C.red)
		end
	end)
end)

bind(kbBtn.MouseButton1Click, function()
	keyboardOn = not keyboardOn
	kbBtn.Text = keyboardOn and "⌨ KEYS: ON" or "⌨ KEYS: OFF"
	setActive(kbBtn, keyboardOn)
end)

bind(UserInputService.InputBegan, function(input)
	if not keyboardOn or not pagePiano.Visible or not main.Visible then return end
	if UserInputService:GetFocusedTextBox() then return end
	local k = keyVisual[input.KeyCode]
	if k then
		k.visual(true)
		playNote(k.semitone)
	end
end)
bind(UserInputService.InputEnded, function(input)
	local k = keyVisual[input.KeyCode]
	if k then k.visual(false) end
end)

--==================================================
-- TABS
--==================================================
local function showTab(which)
	pagePlayer.Visible = (which == "player")
	pagePiano.Visible = (which == "piano")
	setActive(tabPlayer, which == "player")
	setActive(tabPiano, which == "piano")
end
bind(tabPlayer.MouseButton1Click, function() showTab("player") end)
bind(tabPiano.MouseButton1Click, function() showTab("piano") end)
showTab("player")

--==================================================
-- WINDOW: drag / minimize / close / toggle
--==================================================
local mainOpen = false
local minimized = false
local winTweens = {}

local function cancelWin()
	for _, t in ipairs(winTweens) do t:Cancel() end
	table.clear(winTweens)
end

local function setMainOpen(open)
	mainOpen = open
	cancelWin()
	local base = viewScale()
	if open then
		main.Visible = true
		mainScale.Scale = base * 0.88
		main.GroupTransparency = 1
		table.insert(winTweens, tween(main, 0.25, { GroupTransparency = 0 }))
		table.insert(winTweens, tween(mainScale, 0.35, { Scale = base }, Enum.EasingStyle.Back))
	else
		table.insert(winTweens, tween(main, 0.18, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		local t = tween(mainScale, 0.18, { Scale = base * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		table.insert(winTweens, t)
		t.Completed:Connect(function(st)
			if st == Enum.PlaybackState.Completed and not mainOpen then
				main.Visible = false
			end
		end)
	end
end

local function setMinimized(min)
	minimized = min
	minBtn.Text = min and "▢" or "–"
	if min then
		tabBar.Visible = false
		content.Visible = false
		toastL.Visible = false
		tween(main, 0.25, { Size = UDim2.new(0, WIDTH, 0, HEADER) }, Enum.EasingStyle.Quint)
	else
		local t = tween(main, 0.3, { Size = UDim2.new(0, WIDTH, 0, HEIGHT) }, Enum.EasingStyle.Back)
		t.Completed:Connect(function()
			if not minimized then
				tabBar.Visible = true
				content.Visible = true
				toastL.Visible = true
			end
		end)
	end
end

bind(minBtn.MouseButton1Click, function() setMinimized(not minimized) end)
bind(closeBtn.MouseButton1Click, function() setMainOpen(false) end)

-- generic drag (window header + toggle). Returns a function telling if the last gesture moved.
local function makeDraggable(target, handle, onClick)
	local dragging, moved = false, false
	local startInput, startPos
	bind(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			startInput = i.Position
			startPos = target.Position
		end
	end)
	bind(UserInputService.InputChanged, function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - startInput
			if d.Magnitude > 6 then moved = true end
			if moved then
				target.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y
				)
			end
		end
	end)
	bind(UserInputService.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved and onClick then onClick() end
		end
	end)
end

makeDraggable(main, header)

-- ===== left-side draggable toggle =====
local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.AnchorPoint = Vector2.new(0, 0.5)
toggle.Position = UDim2.new(0, 12, 0.5, 0)
toggle.Size = UDim2.new(0, 54, 0, 54)
toggle.BackgroundColor3 = C.panel
toggle.AutoButtonColor = false
toggle.Text = "♪"
toggle.TextSize = 26
toggle.TextColor3 = C.text
toggle.Font = Enum.Font.GothamBlack
toggle.ZIndex = 30
toggle.Parent = gui
corner(toggle, 99)
local toggleStroke, toggleGrad = stroke(toggle, 3, 0)
local toggleScale = Instance.new("UIScale", toggle)

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.new(0.5, 0, 0.5, 0)
ring.Size = UDim2.new(1, 0, 1, 0)
ring.BackgroundTransparency = 1
ring.ZIndex = 29
ring.Parent = toggle
corner(ring, 99)
local ringStroke = stroke(ring, 2, 0.2)
local ringTween = TweenService:Create(ring, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Size = UDim2.new(1, 30, 1, 30) })
local ringFade = TweenService:Create(ringStroke, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 })
ringTween:Play()
ringFade:Play()

bind(toggle.MouseEnter, function() tween(toggleScale, 0.15, { Scale = 1.1 }) end)
bind(toggle.MouseLeave, function() tween(toggleScale, 0.15, { Scale = 1 }) end)
makeDraggable(toggle, toggle, function()
	setMainOpen(not mainOpen)
end)

--==================================================
-- ANIMATION LOOP
--==================================================
local t0 = os.clock()
local uiTick = 0
bind(RunService.Heartbeat, function(dt)
	if not alive then return end
	local t = os.clock() - t0

	toggleGrad.Rotation = (t * 90) % 360
	if main.Visible then
		mainStrokeGrad.Rotation = (t * 40) % 360
	end
	if not main.Visible or minimized or not pagePlayer.Visible then return end

	local playing = (state == "playing") and sound.IsPlaying
	if playing then
		discGrad.Rotation = (discGrad.Rotation + 120 * dt) % 360
	end
	for i, b in ipairs(eqBars) do
		local h = playing and (5 + (math.sin(t * (4 + i * 1.3) + i) * 0.5 + 0.5) * 22) or 4
		b.Size = UDim2.new(0, 5, 0, h)
	end

	uiTick += dt
	if uiTick >= 0.1 then
		uiTick = 0
		local len = sound.TimeLength
		if len > 0 and not progress.isDragging() then
			progress.set(sound.TimePosition / len)
			curL.Text = fmtTime(sound.TimePosition)
			totL.Text = fmtTime(len)
		end
	end
end)

do
	local function hookCamera()
		local cam = workspace.CurrentCamera
		if cam then
			bind(cam:GetPropertyChangedSignal("ViewportSize"), function()
				if mainOpen then mainScale.Scale = viewScale() end
			end)
		end
	end
	hookCamera()
end

--==================================================
-- CLEANUP (called automatically if the script is run again)
--==================================================
_G.AayanMusic_Cleanup = function()
	alive = false
	loadToken += 1
	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(connections)
	pcall(function() ringTween:Cancel() end)
	pcall(function() ringFade:Cancel() end)
	pcall(function() sound:Stop() end)
	pcall(function() sound:Destroy() end)
	pcall(function() pianoFolder:Destroy() end)
	pcall(function() gui:Destroy() end)
	_G.AayanMusic_Cleanup = nil
end

bind(gui.Destroying, function()
	alive = false
end)

-- open the window at start
setMainOpen(true)
toast("Welcome! Pick a track or paste a SoundId", C.blue)
