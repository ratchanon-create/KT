--[[ Anime-Dice | KISTROX HUB Custom UI (no external UI library)
     Toggle menu: RightShift or the floating "N" button ]]

if not game:IsLoaded() then game.Loaded:Wait() end

local env = (getgenv and getgenv()) or _G
if type(env.kistrox_AnimeDice_Unload) == "function" then
	pcall(env.kistrox_AnimeDice_Unload)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

--======================================================================
-- LOW PLAYER COUNT CHECK
--======================================================================
do
	local count = #Players:GetPlayers()
	if count <= 2 then
		pcall(function()
			LocalPlayer:Kick(("Only %d player(s) in this server.\nPlease Join on a Public server to prevent being banned from using this."):format(count))
		end)
		task.wait(1)
		error("KISTROX HUB: low player count.", 0)
	end
end

--======================================================================
-- CUSTOM UI LIBRARY
--======================================================================
local Theme = {
	Bg = Color3.fromRGB(11, 14, 18),
	Side = Color3.fromRGB(15, 19, 25),
	Card = Color3.fromRGB(20, 24, 31),
	Row = Color3.fromRGB(26, 31, 39),
	RowHi = Color3.fromRGB(35, 42, 52),
	Stroke = Color3.fromRGB(30, 37, 48),
	Text = Color3.fromRGB(230, 238, 245),
	Sub = Color3.fromRGB(124, 139, 153),
	Accent = Color3.fromRGB(34, 211, 238),
	Off = Color3.fromRGB(51, 59, 69),
}

local LEFT, CENTER, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right

local function new(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if o:IsA("GuiButton") then o.AutoButtonColor = false end
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function stroke(o, col, thick, trans) return new("UIStroke", { Color = col or Theme.Stroke, Thickness = thick or 1, Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function pad(o, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0)
	}, o)
end
local function list(o, gap, dir)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = dir or Enum.FillDirection.Vertical
	}, o)
end
local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function mkLabel(props, parent)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamMedium
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 12
	props.Text = props.Text or ""
	return new("TextLabel", props, parent)
end
local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function MakeUI(cfg)
	local W = {}
	local Conns, Flags = {}, {}
	local current
	local loading, dirty = false, false
	local toastOrder = 0

	local function connect(sig, fn)
		local c = sig:Connect(fn)
		Conns[#Conns + 1] = c
		return c
	end

	local function fire(cb, ...)
		if not cb then return end
		local args = { ... }
		task.spawn(function()
			local ok, err = pcall(cb, table.unpack(args))
			if not ok then warn("[KISTROX HUB] callback error: " .. tostring(err)) end
		end)
	end

	local canFile = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"

	local function save()
		if not canFile then return end
		local data = {}
		for flag, obj in pairs(Flags) do data[flag] = obj.Value end
		pcall(function()
			if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(cfg.Folder) then
				makefolder(cfg.Folder)
			end
			writefile(cfg.Folder .. "/" .. cfg.File, HttpService:JSONEncode(data))
		end)
	end

	local function changed()
		if loading or dirty then return end
		dirty = true
		task.delay(0.6, function()
			dirty = false
			save()
		end)
	end

	local function cleanOld()
		local spots = {}
		pcall(function() spots[#spots + 1] = gethui() end)
		pcall(function() spots[#spots + 1] = game:GetService("CoreGui") end)
		spots[#spots + 1] = LocalPlayer:FindFirstChild("PlayerGui")
		for _, s in ipairs(spots) do
			local old = s and s:FindFirstChild(cfg.GuiName)
			if old then old:Destroy() end
		end
	end
	cleanOld()

	local gui = new("ScreenGui", {
		Name = cfg.GuiName, ResetOnSpawn = false, DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true
	})
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	local okParent = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
	if not okParent or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1024, 768)
	local w, h = math.min(680, vp.X - 24), math.min(410, vp.Y - 24)

	local main = new("Frame", {
		Name = "Main", Active = true, ClipsDescendants = true,
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
		BackgroundColor3 = Theme.Bg
	}, gui)
	corner(main, 16)
	stroke(main, Theme.Accent, 1.5, 0.55)

	local side = new("Frame", { Size = UDim2.new(0, 176, 1, -22), BackgroundColor3 = Theme.Side }, main)
	new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = Theme.Stroke }, side)

	local brandRow = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1 }, side)
	local brandDot = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(14, 15), BackgroundColor3 = Theme.Accent }, brandRow)
	corner(brandDot, 5)
	stroke(brandDot, Theme.Accent, 3, 0.45)
	local title = mkLabel({ Text = cfg.Name, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Theme.Text,
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(32, 9), TextXAlignment = LEFT }, brandRow)
	mkLabel({ Text = "neon build", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.Accent,
		Size = UDim2.new(1, -32, 0, 14), Position = UDim2.fromOffset(32, 27), TextXAlignment = LEFT }, brandRow)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 50), BackgroundColor3 = Theme.Stroke }, side)

	local tabList = new("Frame", {
		Size = UDim2.new(1, -16, 1, -64), Position = UDim2.fromOffset(8, 58), BackgroundTransparency = 1
	}, side)
	list(tabList, 3)

	local header = new("Frame", {
		Active = true, Size = UDim2.new(1, -176, 0, 50), Position = UDim2.fromOffset(150, 0), BackgroundTransparency = 1
	}, main)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Stroke }, header)

	local searchBox = new("Frame", {
		Size = UDim2.new(1, -100, 0, 32), Position = UDim2.fromOffset(12, 9), BackgroundColor3 = Theme.Row
	}, header)
	corner(searchBox, 10)
	stroke(searchBox, Theme.Stroke, 1, 0.15)
	mkLabel({ Text = "🔍", Size = UDim2.fromOffset(26, 32), TextSize = 12, TextColor3 = Theme.Accent }, searchBox)

	local search = new("TextBox", {
		Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(30, 0), BackgroundTransparency = 1,
		Text = "", PlaceholderText = "Search", PlaceholderColor3 = Theme.Sub, TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = LEFT, ClearTextOnFocus = false
	}, searchBox)

	local hideBtn = new("TextButton", {
		Text = "—", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Sub,
		Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -78, 0, 10), BackgroundColor3 = Theme.Row
	}, header)
	corner(hideBtn, 9)
	mkLabel({ Text = "✥", Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 7), TextColor3 = Theme.Sub, TextSize = 15 }, header)

	local content = new("Frame", {
		Size = UDim2.new(1, -176, 1, -72), Position = UDim2.fromOffset(176, 50), BackgroundTransparency = 1
	}, main)

	local footer = new("Frame", {
		Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), BackgroundColor3 = Theme.Side
	}, main)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke }, footer)
	mkLabel({ Text = "▍KISTROX HUB", Size = UDim2.new(0.5, -8, 1, 0), Position = UDim2.fromOffset(10, 0),
		TextSize = 10, TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextXAlignment = LEFT }, footer)
	mkLabel({ Text = cfg.Version, Size = UDim2.new(0.5, -30, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
		TextSize = 10, TextColor3 = Theme.Sub, TextXAlignment = RIGHT }, footer)

	local grip = new("TextButton", {
		Text = "◢", TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = Theme.Sub,
		BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -22, 0, 0)
	}, footer)

	local function draggable(handle, target)
		local dragging, startIn, startPos
		connect(handle.InputBegan, function(i)
			if isPress(i) then
				dragging, startIn, startPos = true, i.Position, target.Position
				local c
				c = i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						dragging = false
						c:Disconnect()
					end
				end)
			end
		end)
		connect(UIS.InputChanged, function(i)
			if dragging and isMove(i) then
				local d = i.Position - startIn
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
	end
	draggable(header, main)
	draggable(title, main)

	do
		local resizing, startIn, startSize
		connect(grip.InputBegan, function(i)
			if isPress(i) then
				resizing, startIn, startSize = true, i.Position, main.AbsoluteSize
				local c
				c = i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						resizing = false
						c:Disconnect()
					end
				end)
			end
		end)
		connect(UIS.InputChanged, function(i)
			if resizing and isMove(i) then
				local d = i.Position - startIn
				local nw = math.clamp(startSize.X + d.X, 520, math.max(vp.X - 10, 520))
				local nh = math.clamp(startSize.Y + d.Y, 300, math.max(vp.Y - 10, 300))
				main.Size = UDim2.fromOffset(nw, nh)
			end
		end)
	end

	local function setOpen(v) main.Visible = v end
	connect(hideBtn.MouseButton1Click, function() setOpen(false) end)

	do
		local fb = new("TextButton", {
			Text = "N", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 14, 0.5, -21), BackgroundColor3 = Theme.Accent
		}, gui)
		corner(fb, 21)
		stroke(fb, Theme.Accent)
		local down, moved, sp, si = false, false, nil, nil
		connect(fb.InputBegan, function(i)
			if isPress(i) then
				down, moved, sp, si = true, false, fb.Position, i.Position
				local c
				c = i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						if down and not moved then setOpen(not main.Visible) end
						down = false
						c:Disconnect()
					end
				end)
			end
		end)
		connect(UIS.InputChanged, function(i)
			if down and isMove(i) then
				local d = i.Position - si
				if d.Magnitude > 6 then moved = true end
				if moved then
					fb.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
				end
			end
		end)
	end

	connect(UIS.InputBegan, function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.RightShift then setOpen(not main.Visible) end
	end)

	local toasts = new("Frame", {
		Size = UDim2.new(0, 250, 1, -24), Position = UDim2.new(1, -14, 0, 12),
		AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1
	}, gui)
	local tl = list(toasts, 6)
	tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Right

	function W:Notify(t, msg, dur)
		toastOrder += 1
		local f = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Card, LayoutOrder = toastOrder
		}, toasts)
		corner(f, 8)
		stroke(f, Theme.Accent)
		pad(f, 10, 8, 10, 8)
		list(f, 2)
		mkLabel({
			Text = t, Font = Enum.Font.GothamBold, TextColor3 = Theme.Accent, TextXAlignment = LEFT,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 1
		}, f)
		mkLabel({
			Text = msg, TextColor3 = Theme.Text, TextSize = 11, TextXAlignment = LEFT,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, LayoutOrder = 2
		}, f)
		task.delay(dur or 3, function()
			if f.Parent then f:Destroy() end
		end)
	end

	local function applySearch()
		if not current then return end
		local q = search.Text:lower()
		for _, c in ipairs(current.Cards) do
			local titleMatch = q == "" or c.Title:lower():find(q, 1, true) ~= nil
			local any = false
			for _, it in ipairs(c.Items) do
				local m = titleMatch or it.Name:find(q, 1, true) ~= nil
				it.Row.Visible = m
				if m then any = true end
			end
			c.Frame.Visible = any or #c.Items == 0
		end
	end
	connect(search:GetPropertyChangedSignal("Text"), applySearch)

	local function setActive(t, on)
		t.page.Visible = on
		t.ind.Visible = on
		t.btn.BackgroundTransparency = on and 0 or 1
		t.ic.TextColor3 = on and Theme.Accent or Theme.Sub
		t.tx.TextColor3 = on and Theme.Text or Theme.Sub
	end

	local function select(t)
		if current == t then return end
		if current then setActive(current, false) end
		current = t
		setActive(t, true)
		search.Text = ""
		applySearch()
	end

	function W:Tab(name, icon)
		local tab = { Cards = {}, Count = 0 }
		tab.btn = new("TextButton", {
			Text = "", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.RowHi, BackgroundTransparency = 1
		}, tabList)
		corner(tab.btn, 10)
		tab.ind = new("Frame", {
			Size = UDim2.fromOffset(4, 20), Position = UDim2.new(0, 0, 0.5, -10),
			BackgroundColor3 = Theme.Accent, Visible = false
		}, tab.btn)
		corner(tab.ind, 2)
		local hasIcon = icon ~= nil and icon ~= ""
		tab.ic = mkLabel({ Text = hasIcon and icon or "", Visible = hasIcon,
			Size = UDim2.fromOffset(30, 34), Position = UDim2.fromOffset(11, 0),
			TextColor3 = Theme.Sub, TextSize = 14 }, tab.btn)
		tab.tx = mkLabel({ Text = name, Size = UDim2.new(1, hasIcon and -48 or -24, 1, 0),
			Position = UDim2.fromOffset(hasIcon and 44 or 16, 0), TextXAlignment = LEFT,
			TextColor3 = Theme.Sub }, tab.btn)

		local page = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Stroke,
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y
		}, content)
		pad(page, 10, 10, 10, 10)
		tab.page = page

		local cols = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, page)
		local cl = list(cols, 8, Enum.FillDirection.Vertical)
		cl.VerticalAlignment = Enum.VerticalAlignment.Top

		local left = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 }, cols)
		list(left, 8)
		local right = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = 2 }, cols)
		list(right, 8)

		connect(tab.btn.MouseButton1Click, function() select(tab) end)

		function tab:Card(cardTitle, sideName)
			tab.Count += 1
			local col = left        -- การ์ดทุกใบเรียงเป็นคอลัมน์เดียว (บนลงล่าง)
			local card = {}
			local items = {}
			local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card }, col)
			corner(frame, 12)
			stroke(frame)
			list(frame, 0)

			local head = new("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 1 }, frame)
			new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -1),
				BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.35 }, head)
			mkLabel({ Text = cardTitle, Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, -38, 1, 0), Position = UDim2.fromOffset(14, 0), TextXAlignment = LEFT }, head)
			local chev = mkLabel({ Text = "▼", TextSize = 9, TextColor3 = Theme.Accent, Size = UDim2.fromOffset(20, 36), Position = UDim2.new(1, -26, 0, 0) }, head)

			local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, frame)
			pad(body, 8, 0, 8, 8)
			list(body, 6)

			connect(head.MouseButton1Click, function()
				body.Visible = not body.Visible
				chev.Text = body.Visible and "▼" or "▶"
			end)

			tab.Cards[#tab.Cards + 1] = { Title = cardTitle, Frame = frame, Items = items }

			local function mkRow(hgt)
				local r = new("Frame", { Size = UDim2.new(1, 0, 0, hgt), BackgroundColor3 = Theme.Row }, body)
				corner(r, 10)
				return r
			end
			local function reg(f, name)
				items[#items + 1] = { Row = f, Name = tostring(name or ""):lower() }
			end

			function card:Toggle(o)
				local r = mkRow(30)
				mkLabel({ Text = o.Name, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(10, 0), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, r)
				local sw = new("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = Theme.Off }, r)
				corner(sw, 10)
				local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1) }, sw)
				corner(knob, 8)
				local btn = new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, r)
				local obj = { Value = o.Default and true or false }
				local function render(instant)
					local col = obj.Value and Theme.Accent or Theme.Off
					local pos = obj.Value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)
					if instant then
						sw.BackgroundColor3, knob.Position = col, pos
					else
						tween(sw, 0.15, { BackgroundColor3 = col })
						tween(knob, 0.15, { Position = pos })
					end
				end
				render(true)
				function obj:Set(v, silent)
					obj.Value = v and true or false
					render(false)
					if not silent then
						fire(o.Callback, obj.Value)
						changed()
					end
				end
				connect(btn.MouseButton1Click, function() obj:Set(not obj.Value) end)
				if o.Flag then Flags[o.Flag] = obj end
				reg(r, o.Name)
				return obj
			end

			function card:Button(o)
				local b = new("TextButton", {
					Text = o.Name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text,
					Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Row
				}, body)
				corner(b, 10)
				connect(b.MouseEnter, function() tween(b, 0.12, { BackgroundColor3 = Theme.RowHi }) end)
				connect(b.MouseLeave, function() tween(b, 0.12, { BackgroundColor3 = Theme.Row }) end)
				connect(b.MouseButton1Click, function()
					b.BackgroundColor3 = Theme.Accent
					tween(b, 0.3, { BackgroundColor3 = Theme.Row })
					fire(o.Callback)
				end)
				reg(b, o.Name)
				return b
			end

			function card:Label(text)
				local l = mkLabel({
					Text = text, TextColor3 = Theme.Sub, TextSize = 11, TextXAlignment = LEFT, TextWrapped = true,
					Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y
				}, body)
				pad(l, 4, 2, 4, 2)
				reg(l, text)
				return l
			end

			function card:Paragraph(o)
				local r = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Row }, body)
				corner(r, 6)
				pad(r, 10, 8, 10, 8)
				list(r, 3)
				local t = mkLabel({ Text = o.Title or "", Font = Enum.Font.GothamBold, TextXAlignment = LEFT, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, r)
				local c = mkLabel({ Text = o.Content or "", TextColor3 = Theme.Sub, TextSize = 11, TextXAlignment = LEFT, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, r)
				local obj = {}
				function obj:Set(v)
					if type(v) ~= "table" then return end
					if v.Title then t.Text = v.Title end
					if v.Content then c.Text = v.Content end
				end
				reg(r, (o.Title or "") .. " " .. (o.Content or ""))
				return obj
			end

			function card:Slider(o)
				local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
				local r = mkRow(44)
				mkLabel({ Text = o.Name, Size = UDim2.new(1, -74, 0, 14), Position = UDim2.fromOffset(10, 7), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, r)
				local val = mkLabel({ Size = UDim2.new(0, 64, 0, 14), Position = UDim2.new(1, -74, 0, 7), TextXAlignment = RIGHT, TextColor3 = Theme.Accent }, r)
				local bar = new("Frame", { Size = UDim2.new(1, -20, 0, 8), Position = UDim2.fromOffset(10, 29), BackgroundColor3 = Theme.Off }, r)
				corner(bar, 4)
				local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent }, bar)
				corner(fill, 4)
				local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1) }, bar)
				corner(knob, 7)
				local hit = new("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 18), BackgroundTransparency = 1 }, r)
				local obj = { Value = math.clamp(o.Default or min, min, max) }
				local function render()
					local rel = max > min and (obj.Value - min) / (max - min) or 0
					fill.Size = UDim2.fromScale(rel, 1)
					knob.Position = UDim2.new(rel, 0, 0.5, 0)
					val.Text = tostring(obj.Value) .. (o.Suffix and (" " .. o.Suffix) or "")
				end
				render()
				local function apply(v, silent, force)
					v = tonumber(v) or min
					v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
					local ch = v ~= obj.Value
					obj.Value = v
					render()
					if (ch or force) and not silent then
						fire(o.Callback, v)
						changed()
					end
				end
				function obj:Set(v, silent) apply(v, silent, true) end
				local dragging = false
				local function fromX(x)
					local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
					apply(min + rel * (max - min))
				end
				connect(hit.InputBegan, function(i)
					if isPress(i) then
						dragging = true
						page.ScrollingEnabled = false
						fromX(i.Position.X)
						local c
						c = i.Changed:Connect(function()
							if i.UserInputState == Enum.UserInputState.End then
								dragging = false
								page.ScrollingEnabled = true
								c:Disconnect()
							end
						end)
					end
				end)
				connect(UIS.InputChanged, function(i)
					if dragging and isMove(i) then fromX(i.Position.X) end
				end)
				if o.Flag then Flags[o.Flag] = obj end
				reg(r, o.Name)
				return obj
			end

			function card:Input(o)
				local r = mkRow(32)
				mkLabel({ Text = o.Name, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, r)
				local tb = new("TextBox", {
					Size = UDim2.new(0.5, -10, 0, 22), Position = UDim2.new(0.5, 0, 0.5, -11), BackgroundColor3 = Theme.Bg,
					Text = tostring(o.Default or ""), PlaceholderText = o.Placeholder or "", PlaceholderColor3 = Theme.Sub,
					TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false
				}, r)
				corner(tb, 5)
				stroke(tb)
				local obj = { Value = tb.Text }
				function obj:Set(v, silent)
					tb.Text = tostring(v or "")
					obj.Value = tb.Text
					if not silent then
						fire(o.Callback, obj.Value)
						changed()
					end
				end
				connect(tb.FocusLost, function() obj:Set(tb.Text) end)
				if o.Flag then Flags[o.Flag] = obj end
				reg(r, o.Name)
				return obj
			end

			function card:Dropdown(o)
				local multi = o.Multi and true or false
				local options = o.Options or {}
				local sel, single = {}, nil
				local obj = { Value = multi and {} or nil }
				local buttons = {}
				local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Row }, body)
				corner(box, 6)
				list(box, 0)

				local dh = new("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
				mkLabel({ Text = o.Name, Size = UDim2.new(1, -30, 0, 14), Position = UDim2.fromOffset(10, 6), TextXAlignment = LEFT, TextColor3 = Theme.Sub, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd }, dh)
				local valLbl = mkLabel({ Size = UDim2.new(1, -30, 0, 16), Position = UDim2.fromOffset(10, 20), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, dh)
				local arrow = mkLabel({ Text = "▼", Size = UDim2.fromOffset(16, 40), Position = UDim2.new(1, -22, 0, 0), TextColor3 = Theme.Sub, TextSize = 9 }, dh)

				local panel = new("ScrollingFrame", {
					Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ScrollBarThickness = 3,
					ScrollBarImageColor3 = Theme.Stroke, AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(), Visible = false, LayoutOrder = 2, ScrollingDirection = Enum.ScrollingDirection.Y
				}, box)
				pad(panel, 4, 0, 4, 6)
				list(panel, 2)

				local function selectedValue()
					if not multi then return single end
					local arr, seen = {}, {}
					for _, n in ipairs(options) do
						if sel[n] then arr[#arr + 1] = n seen[n] = true end
					end
					for n in pairs(sel) do
						if not seen[n] then arr[#arr + 1] = n end
					end
					return arr
				end
				local function refreshHead()
					if multi then
						local n = 0
						for _ in pairs(sel) do n += 1 end
						valLbl.Text = n > 0 and (n .. " selected") or "None"
					else
						valLbl.Text = single and tostring(single) or "None"
					end
				end
				local function paint()
					for name, b in pairs(buttons) do
						local on = multi and sel[name] or (not multi and single == name)
						b.txt.TextColor3 = on and Theme.Accent or Theme.Text
						b.chk.Visible = on and true or false
					end
				end
				local function commit(silent)
					obj.Value = selectedValue()
					refreshHead()
					paint()
					if not silent then
						fire(o.Callback, obj.Value)
						changed()
					end
				end
				local function pick(name)
					if multi then
						sel[name] = (not sel[name]) or nil
					else
						single = name
						panel.Visible = false
						arrow.Text = "▼"
					end
					commit()
				end
				local function rebuild()
					for _, b in pairs(buttons) do b.btn:Destroy() end
					buttons = {}
					for i, name in ipairs(options) do
						local b = new("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.RowHi, BackgroundTransparency = 1, LayoutOrder = i }, panel)
						corner(b, 4)
						local t = mkLabel({ Text = tostring(name), Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(8, 0), TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 11 }, b)
						local c = mkLabel({ Text = "✓", Size = UDim2.fromOffset(18, 24), Position = UDim2.new(1, -22, 0, 0), TextColor3 = Theme.Accent, TextSize = 12 }, b)
						buttons[name] = { btn = b, txt = t, chk = c }
						b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 end)
						b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
						b.MouseButton1Click:Connect(function() pick(name) end)
					end
					panel.Size = UDim2.new(1, 0, 0, math.min(#options * 26 + 6, 146))
					paint()
				end

				if multi then
					for _, n in ipairs(o.Default or {}) do sel[tostring(n)] = true end
				else
					local d = o.Default
					if type(d) == "table" then d = d[1] end
					single = d ~= nil and tostring(d) or nil
				end
				obj.Value = selectedValue()
				refreshHead()
				rebuild()

				function obj:Set(v, silent)
					if multi then
						sel = {}
						if type(v) == "table" then
							for _, n in ipairs(v) do sel[tostring(n)] = true end
						elseif type(v) == "string" then
							sel[v] = true
						end
					else
						if type(v) == "table" then v = v[1] end
						single = v ~= nil and tostring(v) or nil
					end
					commit(silent)
				end
				function obj:Refresh(newOptions)
					options = newOptions or {}
					rebuild()
				end
				connect(dh.MouseButton1Click, function()
					panel.Visible = not panel.Visible
					arrow.Text = panel.Visible and "▲" or "▼"
				end)
				if o.Flag then Flags[o.Flag] = obj end
				reg(box, o.Name)
				return obj
			end
			return card
		end

		if not current then select(tab) end
		return tab
	end

	function W:LoadConfig()
		if not canFile then return end
		local ok, data = pcall(function()
			local path = cfg.Folder .. "/" .. cfg.File
			if isfile(path) then return HttpService:JSONDecode(readfile(path)) end
		end)
		if not ok or type(data) ~= "table" then return end
		loading = true
		for flag, val in pairs(data) do
			local o = Flags[flag]
			if o then pcall(o.Set, o, val) end
		end
		loading = false
	end

	function W:Destroy()
		for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
		pcall(function() gui:Destroy() end)
	end
	return W
end

--======================================================================
-- WINDOW + TABS
--======================================================================
local UI = MakeUI({
	Name = "kistrox",
	GuiName = "KISTROX_AnimeDice",
	Version = "v1.0 · Anime Dice",
	Folder = "NemoHubs",
	File = "AnimeDice.json",
})

local AutoTab = UI:Tab("main")
local HubTab = UI:Tab("Auto")
local LevelTab = UI:Tab("LevelUp")
local PotionTab = UI:Tab("Potions")
local SellTab = UI:Tab("Auto Sell")
local MiscTab = UI:Tab("Misc")

--======================================================================
-- Game references
--======================================================================
local Network = ReplicatedStorage:WaitForChild("Network")
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Features = Framework:WaitForChild("Features")

local Remotes = {
	RollDice = Network.RollService.RF.RollDice,
	SellInventory = Network.SellService.RF.SellInventory,
	CollectBalance = Network.PlotService.RE.CollectBalance,
	EquipBest = Network.PlotService.RE.EquipBest,
	LevelUpSlot = Network.PlotService.RE.LevelUpSlot,
	BuyDice = Network.DiceShopService.RE.BuyDice,
	EquipDice = Network.DiceShopService.RE.EquipDice,
	Rebirth = Network.RebirthService.RE.Rebirth,
	BuyUpgrade = Network.RE.BuyUpgrade,
	ClaimQuest = Network.QuestService.RE.Claim,
	PlayTower = Network.Towers.RF.PlayTower,
	CompleteFloor = Network.Towers.RF.CompleteTowerFloor,
	CancelTower = Network.Towers.RF.CancelTower,
	EquipTowerTeam = Network.Towers.RE.EquipBestTowerTeam,
	GradeRoll = Network.GradeService.RE.Roll,
	TraitRoll = Network.TraitService.RE.Roll,
	UseBoost = Network.BoostService.RE.Use,
}

local RARITIES = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical",
	"Divine", "Exotic", "Celestial", "Exclusive", "Secret1", "Secret2"
}
local MUTATIONS = { "Silver", "Gold", "Emerald", "Diamond", "Ruby", "Rainbow" }
local BRANCHES = { "Luck", "Fortune", "Roll Speed", "Unit Storage", "Money", "Sell", "Damage", "Health", "Walkspeed" }
local ROMAN = {
	I = true, II = true, III = true, IV = true, V = true, VI = true,
	VII = true, VIII = true, IX = true, X = true, XI = true, XII = true
}

--======================================================================
-- Helpers
--======================================================================
local unloaded = false
local Loops, Toggles = {}, {}
local afkConn

local function alive() return not unloaded and LocalPlayer.Parent ~= nil end
local function notify(title, content)
	task.spawn(function()
		pcall(function() UI:Notify(title, content, 3) end)
	end)
end
local function setSafe(obj, value)
	if not obj then return end
	task.spawn(function()
		pcall(function() obj:Set(value) end)
	end)
end
local function toSet(list)
	local s = {}
	if type(list) == "table" then
		for _, v in ipairs(list) do s[tostring(v)] = true end
	elseif type(list) == "string" then
		s[list] = true
	end
	return s
end
local function first(v)
	if type(v) == "table" then return v[1] end
	return v
end
local function fmtMoney(n)
	n = tonumber(n) or 0
	local steps = { { 1e15, "Q" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "k" } }
	for _, s in ipairs(steps) do
		if n >= s[1] then return ("%.2f%s"):format(n / s[1], s[2]) end
	end
	return tostring(math.floor(n))
end
local CHANCE_SUFFIX = { "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }
local function fmtChance(n)
	n = tonumber(n) or 0
	local i = 0
	while n >= 1000 and i < #CHANCE_SUFFIX do
		n /= 1000
		i += 1
	end
	local str
	if n >= 100 or i == 0 then
		str = tostring(math.floor(n + 0.5))
	else
		str = (("%.1f"):format(n):gsub("%.0$", ""))
	end
	return str .. (CHANCE_SUFFIX[i] or "")
end
local moduleCache = {}
local function getModule(path, root)
	local inst = root or Features
	for part in path:gmatch("[^%.]+") do
		inst = inst and inst:FindFirstChild(part)
	end
	if not inst then return nil end
	if moduleCache[inst] then return moduleCache[inst] end
	local ok, res = pcall(require, inst)
	if ok and res then
		moduleCache[inst] = res
		return res
	end
	return nil
end
local function getData(name)
	local D = getModule("Data.DataController")
	if not D then return nil end
	local ok, res = pcall(function() return D[name]() end)
	if ok then return res end
	return nil
end
local function entryConfig(name)
	local Reg = getModule("Inventory.EntryRegistry")
	if not Reg then return nil end
	local ok, cfg = pcall(Reg.getEntryConfig, name)
	return ok and cfg or nil
end

local function newLoop(name, fn, delay, hidden)
	local gen, on = 0, false
	local loop = { Name = name, Hidden = hidden }
	function loop.IsOn() return on end
	function loop.Set(state)
		on = state and true or false
		gen += 1
		if not on then return end
		local id = gen
		local function active() return on and id == gen and alive() end
		task.spawn(function()
			while active() do
				local ok, res = pcall(fn, active)
				if not ok then warn("[KISTROX HUB] " .. name .. ": " .. tostring(res)) end
				local d = (ok and type(res) == "number") and res
					or (type(delay) == "function" and delay() or delay or 1)
				task.wait(math.max(tonumber(d) or 1, 0.1))
			end
		end)
	end
	Loops[#Loops + 1] = loop
	return loop
end

local function addToggle(card, name, flag, loop, onChange)
	local t = card:Toggle({
		Name = name,
		Flag = flag,
		Callback = function(v)
			local was = loop.IsOn()
			loop.Set(v)
			if onChange then onChange(v, was) end
		end
	})
	Toggles[#Toggles + 1] = t
	return t
end

local statusPara

local function stopAll()
	for _, t in ipairs(Toggles) do pcall(function() t:Set(false) end) end
	for _, l in ipairs(Loops) do l.Set(false) end
end

local function unload()
	unloaded = true
	for _, l in ipairs(Loops) do l.Set(false) end
	if afkConn then afkConn:Disconnect() afkConn = nil end
	pcall(function() UI:Destroy() end)
	env.kistrox_AnimeDice_Unload = nil
end
env.kistrox_AnimeDice_Unload = unload

--======================================================================
-- AUTO · Roll
--======================================================================
local rollCard = AutoTab:Card("Roll")
local rollCount, rollStart, lastRoll = 0, os.clock(), "—"
local rollPara = rollCard:Paragraph({ Title = "Fast Roll", Content = "Idle." })

local function rollCooldown()
	local BC = getModule("Buffs.BuffController")
	if not BC then return 2.5 end
	local ok, r = pcall(BC.GetBuff, "Roll Duration")
	if ok and type(r) == "number" then return math.max(r, 0) end
	return 2.5
end
local function inventoryUsage()
	local BC = getModule("Buffs.BuffController")
	local inv = getData("Inventory")
	if not BC or type(inv) ~= "table" then return nil end
	local n = 0
	for _, item in pairs(inv) do
		local cfg = entryConfig(item.name)
		if cfg and cfg.kind == "Unit" then n += 1 end
	end
	local _, storage = pcall(BC.GetBuff, "Unit Storage")
	local _, extra = pcall(BC.GetBuff, "Rolls")
	return n, (tonumber(storage) or 100) + (tonumber(extra) or 1) - 1
end
local function refreshRoll(note)
	local n, cap = inventoryUsage()
	local elapsed = os.clock() - rollStart
	local perMin = elapsed > 1 and rollCount / elapsed * 60 or 0
	local lines = {
		("Server cooldown: %.2fs"):format(rollCooldown()),
		("Rolls: %d (%.1f/min)"):format(rollCount, perMin),
		"Last: " .. lastRoll,
		n and ("Inventory: %d/%d units"):format(n, cap) or "Inventory: ?",
	}
	if n and cap and n >= cap then
		lines[#lines + 1] = "Inventory full — enable Auto Sell."
	end
	if note then lines[#lines + 1] = note end
	setSafe(rollPara, { Title = "Fast Roll", Content = table.concat(lines, "\n") })
end

local rollLoop = newLoop("Fast Roll", function()
	local ok, res = pcall(function() return Remotes.RollDice:InvokeServer() end)
	if ok and type(res) == "table" and #res > 0 then
		rollCount += #res
		local parts = {}
		for _, r in ipairs(res) do
			parts[#parts + 1] = r.mutation and (r.mutation .. " " .. tostring(r.result)) or tostring(r.result)
		end
		lastRoll = table.concat(parts, ", ")
		if #lastRoll > 60 then lastRoll = lastRoll:sub(1, 57) .. "..." end
		return math.max(rollCooldown() - 0.25, 0.1)
	end
	return 0.2
end, 0.2)

local rollStatusLoop = newLoop("Roll status", function()
	refreshRoll()
	return 2
end, 2, true)

addToggle(rollCard, "Fast Roll", "AnimeDiceFastRoll", rollLoop, function(v)
	if v then
		rollCount, rollStart = 0, os.clock()
		rollStatusLoop.Set(true)
	else
		rollStatusLoop.Set(false)
		refreshRoll("Stopped.")
	end
end)
rollCard:Button({
	Name = "Reset roll counter",
	Callback = function()
		rollCount, rollStart, lastRoll = 0, os.clock(), "—"
		refreshRoll()
	end
})

--======================================================================
-- AUTO · Plot
--======================================================================
local plotCard = AutoTab:Card("Plot")
local collectInterval, equipInterval = 15, 10

local function collectableSlots()
	local PlotConfig = getModule("Plot.PlotConfig")
	local slots = getData("Slots")
	if not PlotConfig or type(slots) ~= "table" then return {}, 0 end
	local rebirth = tonumber(getData("Rebirth")) or 0
	local okMax, max = pcall(PlotConfig.GetMaxSlots)
	max = okMax and tonumber(max) or 13
	local list, total = {}, 0
	for i = 1, max do
		local okReq, req = pcall(PlotConfig.GetSlotRebirthRequirement, i)
		req = okReq and tonumber(req) or math.huge
		if req <= rebirth then
			local slot = slots[tostring(i)]
			local bal = slot and tonumber(slot.balance) or 0
			if bal > 0 then
				list[#list + 1] = i
				total += bal
			end
		end
	end
	return list, total
end
local function collectNow()
	local list, total = collectableSlots()
	for _, i in ipairs(list) do
		pcall(function() Remotes.CollectBalance:FireServer(i) end)
		task.wait(0.05)
	end
	return #list, total
end
local collectLoop = newLoop("Auto Collect", function()
	collectNow()
	return collectInterval
end, 15)
local equipLoop = newLoop("Auto Equip Best", function()
	pcall(function() Remotes.EquipBest:FireServer() end)
	return equipInterval
end, 10)

addToggle(plotCard, "Auto Collect", "AnimeDiceAutoCollect", collectLoop)
plotCard:Slider({
	Name = "Collect interval", Min = 1, Max = 60, Default = 15, Step = 1, Suffix = "s",
	Flag = "AnimeDiceCollectInterval",
	Callback = function(v) collectInterval = math.max(tonumber(v) or 15, 1) end
})
addToggle(plotCard, "Auto Equip Best", "AnimeDiceAutoEquipBest", equipLoop)
plotCard:Slider({
	Name = "Equip interval", Min = 2, Max = 120, Default = 10, Step = 1, Suffix = "s",
	Flag = "AnimeDiceEquipInterval",
	Callback = function(v) equipInterval = math.max(tonumber(v) or 10, 2) end
})
plotCard:Button({
	Name = "Collect now",
	Callback = function()
		task.spawn(function()
			local n, total = collectNow()
			notify("Collect", n > 0 and ("%d slots · +$%s"):format(n, fmtMoney(total)) or "Nothing to collect.")
		end)
	end
})

--======================================================================
-- AUTO · Dice
--======================================================================
local diceCard = AutoTab:Card("Dice")

local function diceList()
	local Dice = getModule("Rolling.Dice")
	if not Dice then return {} end
	local ok, all = pcall(Dice.GetAll)
	if not ok or type(all) ~= "table" then return {} end
	local list = {}
	for name, d in pairs(all) do
		if type(d) == "table" and d.price then
			list[#list + 1] = { name = name, price = d.price, luck = d.luck or 0 }
		end
	end
	table.sort(list, function(a, b) return a.price > b.price end)
	return list
end
local function diceState()
	local owned = getData("OwnedDice")
	local money = tonumber(getData("Money")) or 0
	local equipped = getData("Dice")
	return type(owned) == "table" and owned or {}, money, equipped
end
local function equipBestDice()
	local owned, _, equipped = diceState()
	local bestName, bestLuck
	for _, d in ipairs(diceList()) do
		if owned[d.name] and (not bestLuck or d.luck > bestLuck) then
			bestName, bestLuck = d.name, d.luck
		end
	end
	if bestName and equipped ~= bestName then
		pcall(function() Remotes.EquipDice:FireServer(bestName) end)
		return bestName
	end
	return nil
end
local function buyDice()
	local owned, money = diceState()
	local bought = 0
	for _, d in ipairs(diceList()) do
		if not owned[d.name] and money >= d.price then
			pcall(function() Remotes.BuyDice:FireServer(d.name) end)
			money -= d.price
			bought += 1
			task.wait(0.6)
		end
	end
	if bought > 0 then
		task.wait(0.6)
		equipBestDice()
	end
	return bought
end

local diceLoop = newLoop("Auto Buy Dice", function()
	buyDice()
	return 5
end, 5)
addToggle(diceCard, "Auto Buy Dice", "AnimeDiceAutoBuyDice", diceLoop)
diceCard:Button({
	Name = "Equip best owned dice",
	Callback = function()
		task.spawn(function()
			local name = equipBestDice()
			notify("Dice", name and ("Equipped: " .. name) or "Already the best.")
		end)
	end
})

--======================================================================
-- AUTO · Upgrades
--======================================================================
local upgradeCard = AutoTab:Card("Upgrades")
local branchSet = toSet(BRANCHES)
local function branchOf(name)
	local base, numeral = tostring(name):match("^(.*)%s+(%S+)$")
	if base and ROMAN[numeral] then return base end
	return nil
end
local function buyUpgrades(active)
	local Upg = getModule("Upgrades.Upgrades")
	local Tree = getModule("Upgrades.TreeStructure")
	local ownedRaw = getData("Upgrades")
	if not Upg or not Tree or type(ownedRaw) ~= "table" or type(Upg) ~= "table" then return 0 end
	local money = tonumber(getData("Money")) or 0
	local owned = {}
	for k, v in pairs(ownedRaw) do
		if v then owned[k] = true end
	end
	local list = {}
	for name, up in pairs(Upg) do
		local branch = branchOf(name)
		if branch and branchSet[branch] and not owned[name] and type(up) == "table" and up.price then
			list[#list + 1] = { name = name, price = up.price }
		end
	end
	table.sort(list, function(a, b) return a.price < b.price end)
	local bought, changed = 0, true
	while changed and active() do
		changed = false
		for _, up in ipairs(list) do
			if not owned[up.name] and money >= up.price then
				local okP, parent = pcall(Tree.GetParent, up.name)
				if not okP or not parent or parent == "Start" or owned[parent] then
					pcall(function() Remotes.BuyUpgrade:FireServer(up.name) end)
					owned[up.name] = true
					money -= up.price
					bought += 1
					changed = true
					task.wait(0.1)
				end
			end
		end
	end
	return bought
end

local upgradeLoop = newLoop("Auto Upgrades", function(active)
	buyUpgrades(active)
	return 5
end, 5)
addToggle(upgradeCard, "Auto Upgrades", "AnimeDiceAutoUpgrades", upgradeLoop)
upgradeCard:Dropdown({
	Name = "Branches to upgrade", Options = BRANCHES, Default = table.clone(BRANCHES), Multi = true,
	Flag = "AnimeDiceUpgradeBranches",
	Callback = function(v) branchSet = toSet(v) end
})
upgradeCard:Button({
	Name = "Buy available upgrades",
	Callback = function()
		task.spawn(function()
			local n = buyUpgrades(function() return true end)
			notify("Upgrades", n > 0 and ("%d upgrade(s) bought"):format(n) or "Nothing affordable.")
		end)
	end
})

--======================================================================
-- AUTO · Quests
--======================================================================
local questCard = AutoTab:Card("Quests")
local function claimQuests()
	local D = getModule("Data.DataController")
	local Cfg = getModule("Quests.QuestConfig")
	if not D or not Cfg then return 0 end
	local periods = Cfg.Periods or {}
	local claimed = 0
	for _, period in ipairs({ "Daily", "Weekly" }) do
		local ok, state = pcall(function() return D.Quests[period]() end)
		if ok and type(state) == "table" then
			local progress, done = state.progress or {}, state.claimed or {}
			local pcfg = periods[period]
			for _, q in ipairs(pcfg and pcfg.quests or {}) do
				if (progress[q.id] or 0) >= q.target and not done[q.id] then
					pcall(function() Remotes.ClaimQuest:FireServer(period, q.id, state.expiresAt) end)
					claimed += 1
					task.wait(0.25)
				end
			end
		end
	end
	return claimed
end
local questLoop = newLoop("Auto Claim Quests", function()
	claimQuests()
	return 10
end, 10)
addToggle(questCard, "Auto Claim Quests", "AnimeDiceAutoClaimQuests", questLoop)
questCard:Button({
	Name = "Claim now",
	Callback = function()
		task.spawn(function()
			local n = claimQuests()
			notify("Quests", n > 0 and ("%d quest(s) claimed"):format(n) or "Nothing to claim.")
		end)
	end
})

--======================================================================
-- AUTO · Rebirth
--======================================================================
local rebirthCard = AutoTab:Card("Rebirth")
local function rebirthInfo()
	local R = getModule("Rebirth.Rebirths")
	if not R then return nil end
	local current = tonumber(getData("Rebirth")) or 0
	local money = tonumber(getData("Money")) or 0
	local ok, nxt = pcall(R.GetNext, current)
	return current, money, (ok and nxt) or nil
end
local function tryRebirth()
	local current, money, nxt = rebirthInfo()
	if not current or not nxt or money < nxt.cost then return false end
	pcall(function() Remotes.Rebirth:FireServer() end)
	task.wait(1)
	local after = rebirthInfo()
	if after and current < after then
		notify("Rebirth", ("Rebirth %d · luck x%s"):format(after, tostring(nxt.luckMultiplier)))
		return true
	end
	return false
end
local rebirthLoop = newLoop("Auto Rebirth", function()
	tryRebirth()
	return 3
end, 3)
addToggle(rebirthCard, "Auto Rebirth", "AnimeDiceAutoRebirth", rebirthLoop)
rebirthCard:Button({
	Name = "Rebirth now",
	Callback = function()
		task.spawn(function()
			local current, money, nxt = rebirthInfo()
			if not current then
				notify("Rebirth", "Game data not loaded yet.")
			elseif not nxt then
				notify("Rebirth", ("Max level reached (%d)."):format(current))
			elseif not tryRebirth() then
				if money >= nxt.cost then
					notify("Rebirth", "Rebirth did not go through.")
				else
					notify("Rebirth", ("Missing $%s."):format(fmtMoney(nxt.cost - money)))
				end
			end
		end)
	end
})

--======================================================================
-- LEVELUP
--======================================================================
local levelCard = LevelTab:Card("Auto Level Up")
local levelSettings = LevelTab:Card("Settings")
local levelMinRarity, levelTarget = "Common", 10
local function levelPass(active)
	local Reg = getModule("Inventory.EntryRegistry")
	local Rar = getModule("Other.Rarities", Framework)
	local UU = getModule("Inventory.Kinds.Unit.UnitUtil")
	local slots, inv = getData("Slots"), getData("Inventory")
	if not Reg or not Rar or not UU or type(slots) ~= "table" or type(inv) ~= "table" then return 0 end
	local okMin, minOrder = pcall(function() return Rar.Get(levelMinRarity).sortOrder end)
	minOrder = okMin and minOrder or 0
	local count = 0
	for key, slot in pairs(slots) do
		local num = tonumber(key)
		if num and slot.unitId then
			local unit = inv[slot.unitId]
			local cfg = unit and entryConfig(unit.name)
			if cfg and cfg.kind == "Unit" then
				local okR, order = pcall(function() return Rar.Get(cfg.getRarity(unit.attributes or {})).sortOrder end)
				if okR and order >= minOrder then
					local lastLevel, stuck = nil, 0
					while active() do
						local cur = getData("Inventory")
						local u = type(cur) == "table" and cur[slot.unitId]
						if not u then break end
						local level = tonumber((u.attributes or {}).level) or 1
						if level >= levelTarget then break end
						if level == lastLevel then stuck += 1 else stuck = 0 end
						lastLevel = level
						if stuck >= 8 then break end
						local money = tonumber(getData("Money")) or 0
						local okP, price = pcall(UU.GetLevelPrice, u.name, u.attributes)
						if not okP or type(price) ~= "number" or price > money then break end
						pcall(function() Remotes.LevelUpSlot:FireServer(num) end)
						count += 1
						task.wait(0.15)
					end
				end
			end
		end
	end
	return count
end
local levelLoop = newLoop("Auto Level Up", function(active)
	levelPass(active)
	return 6
end, 6)
addToggle(levelCard, "Auto Level Up", "AnimeDiceAutoLevelUp", levelLoop)
levelCard:Button({
	Name = "Run a pass",
	Callback = function()
		task.spawn(function()
			local n = levelPass(function() return true end)
			notify("Level Up", n > 0 and ("%d level(s)"):format(n) or "Nothing to level.")
		end)
	end
})
levelSettings:Dropdown({
	Name = "Minimum rarity (plotted units)", Options = RARITIES, Default = "Common",
	Flag = "AnimeDiceLevelUpRarity",
	Callback = function(v) levelMinRarity = first(v) or "Common" end
})
levelSettings:Input({
	Name = "Target level", Placeholder = "10", Default = "10",
	Flag = "AnimeDiceLevelUpTarget",
	Callback = function(v)
		local n = tonumber(v)
		if n and n >= 1 then
			levelTarget = math.floor(n)
		else
			notify("Level Up", "Invalid target level.")
		end
	end
})

--======================================================================
-- AUTOHUB · Towers
--======================================================================
local towerCard = HubTab:Card("Towers")
local towerDifficulty, towerReEquip = "Dragon Tower", true
local function towerNames()
	local T = getModule("Towers.Towers")
	local list = {}
	if T then
		local ok, all = pcall(T.GetAll)
		if ok and type(all) == "table" then
			for name, t in pairs(all) do
				list[#list + 1] = { name = name, order = type(t) == "table" and t.order or 0 }
			end
			table.sort(list, function(a, b) return a.order < b.order end)
		end
	end
	local names = {}
	for _, t in ipairs(list) do names[#names + 1] = t.name end
	if #names == 0 then names = { "Dragon Tower" } end
	return names
end
local function pollFloor()
	local ok, res = pcall(function() return Remotes.CompleteFloor:InvokeServer() end)
	if not ok or type(res) ~= "table" then return nil end
	for _, ev in ipairs(res) do
		if ev.action == "ended" then return "ended" end
	end
	return "running"
end
local function runTower(active)
	while active() do
		local s = pollFloor()
		if s ~= "running" then break end
		task.wait(0.5)
	end
	if not active() then return end
	local ok, started = pcall(function() return Remotes.PlayTower:InvokeServer(towerDifficulty) end)
	if not ok or not started then return end
	local lastGood = os.clock()
	while active() do
		local s = pollFloor()
		if s == "ended" then return end
		if s == "running" then
			lastGood = os.clock()
		elseif os.clock() - lastGood > 180 then
			return
		end
		task.wait(0.5)
	end
end
local towerLoop = newLoop("Auto Tower", function(active)
	if towerReEquip then
		pcall(function() Remotes.EquipTowerTeam:FireServer() end)
		task.wait(1.1)
	end
	runTower(active)
	return 3.1
end, 3.1)
addToggle(towerCard, "Auto Tower", "AnimeDiceAutoTower", towerLoop, function(v, was)
	if not v and was then
		task.spawn(function()
			pcall(function() Remotes.CancelTower:InvokeServer() end)
		end)
	end
end)
towerCard:Dropdown({
	Name = "Difficulty", Options = towerNames(), Default = "Dragon Tower",
	Flag = "AnimeDiceTowerDifficulty",
	Callback = function(v) towerDifficulty = first(v) or "Dragon Tower" end
})
towerCard:Toggle({
	Name = "Re-equip before each run", Default = true, Flag = "AnimeDiceTowerReEquip",
	Callback = function(v) towerReEquip = v end
})
towerCard:Button({
	Name = "Equip best team",
	Callback = function()
		task.spawn(function()
			pcall(function() Remotes.EquipTowerTeam:FireServer() end)
			task.wait(1.1)
			notify("Towers", "Team updated.")
		end)
	end
})

--======================================================================
-- AUTOHUB · Grade / Trait
--======================================================================
local function buildRoller(cfg)
	local selected, target, overwrite = {}, cfg.defaultTarget, false
	local warnedEmpty = false
	local card = HubTab:Card(cfg.name)
	local function tiersSorted()
		local tiers = getModule(cfg.tiersPath)
		local list = {}
		if type(tiers) == "table" then
			for name, t in pairs(tiers) do
				list[#list + 1] = { name = name, order = t.order or 0, protected = t.protected }
			end
			table.sort(list, function(a, b) return a.order < b.order end)
		end
		return list
	end
	local function unitEntries()
		local inv = getData("Inventory")
		if type(inv) ~= "table" then return {} end
		local out = {}
		for key, item in pairs(inv) do
			local ucfg = entryConfig(item.name)
			if ucfg and ucfg.kind == "Unit" then
				local attrs = item.attributes or {}
				local okC, chance = pcall(ucfg.chance, attrs)
				chance = okC and tonumber(chance) or 0
				local label = ("1 in %s · %s%s"):format(
					fmtChance(chance), item.name,
					attrs.mutation and (" (" .. tostring(attrs.mutation) .. ")") or ""
				)
				out[#out + 1] = { key = key, label = label, chance = chance }
			end
		end
		table.sort(out, function(a, b)
			if a.chance ~= b.chance then return a.chance > b.chance end
			return a.label < b.label
		end)
		return out
	end
	local function labels()
		local out, seen = {}, {}
		for _, u in ipairs(unitEntries()) do
			if not seen[u.label] then
				seen[u.label] = true
				out[#out + 1] = u.label
			end
		end
		return out
	end
	local function rollPass(active)
		local tiers = getModule(cfg.tiersPath)
		local inv = getData("Inventory")
		if type(tiers) ~= "table" or type(inv) ~= "table" then return 0 end
		local cur = inv[cfg.currency]
		local budget = cur and tonumber(cur.amount) or 0
		if budget <= 0 then return 0 end
		if not next(selected) then
			if not warnedEmpty then
				warnedEmpty = true
				notify(cfg.name, "ยังไม่ได้เลือก unit (ถ้ารายการว่าง กด Refresh unit list)")
			end
			return 0
		end
		warnedEmpty = false
		local targetOrder = (tiers[target] or {}).order or 0
		local count = 0
		for _, u in ipairs(unitEntries()) do
			if budget <= 0 or not active() then return count end
			if selected[u.label] then
				while budget > 0 and active() do
					local now = getData("Inventory")
					local item = type(now) == "table" and now[u.key]
					if not item then break end
					local tierName = item.attributes and item.attributes[cfg.attribute]
					local tier = tierName and tiers[tierName]
					if ((tier and tier.order) or 0) >= targetOrder then break end
					if tier and tier.protected and not overwrite then break end
					pcall(function() cfg.remote:FireServer(u.key, overwrite) end)
					budget -= 1
					count += 1
					task.wait(0.3)
				end
			end
		end
		return count
	end
	local loop = newLoop("Auto " .. cfg.name, function(active)
		rollPass(active)
		return 6
	end, 6)
	addToggle(card, "Auto " .. cfg.name, cfg.flags.enabled, loop)

	local unitDropdown = card:Dropdown({
		Name = "Units to " .. cfg.name:lower() .. " (rarest first)",
		Options = labels(), Default = {}, Multi = true, Flag = cfg.flags.units,
		Callback = function(v) selected = toSet(v) end
	})
	card:Button({
		Name = "Refresh unit list",
		Callback = function()
			local list = labels()
			task.spawn(function() pcall(function() unitDropdown:Refresh(list) end) end)
		end
	})

	-- อัตโนมัติ: รอข้อมูลกระเป๋าโหลด แล้วเติมรายการ unit ให้เอง (เดิมลิสต์ว่างจนต้องกด Refresh เอง)
	task.spawn(function()
		local lastCount = -1
		while true do
			task.wait(2)
			local list = labels()
			if #list > 0 and #list ~= lastCount then
				lastCount = #list
				pcall(function() unitDropdown:Refresh(list) end)
				notify(cfg.name, ("โหลดรายการ unit แล้ว %d รายการ"):format(#list))
			end
		end
	end)

	local tierNames, protectedName = {}, "?"
	for _, t in ipairs(tiersSorted()) do
		tierNames[#tierNames + 1] = t.name
		if t.protected and protectedName == "?" then protectedName = t.name end
	end
	card:Dropdown({
		Name = "Minimum " .. cfg.name:lower(), Options = tierNames, Default = cfg.defaultTarget,
		Flag = cfg.flags.target,
		Callback = function(v) target = first(v) or cfg.defaultTarget end
	})
	card:Toggle({
		Name = ("Overwrite protected (%s+)"):format(protectedName), Flag = cfg.flags.overwrite,
		Callback = function(v) overwrite = v end
	})
	card:Button({
		Name = "Run a pass",
		Callback = function()
			task.spawn(function()
				local n = rollPass(function() return alive() end)
				notify(cfg.name, n > 0 and ("%d roll(s)"):format(n) or "Nothing to roll.")
			end)
		end
	})
end

buildRoller({
	name = "Grade", attribute = "grade", currency = "Gems",
	remote = Remotes.GradeRoll, tiersPath = "Grades.Grades", defaultTarget = "S",
	flags = {
		enabled = "AnimeDiceAutoGrade", units = "AnimeDiceGradeUnits",
		target = "AnimeDiceGradeTarget", overwrite = "AnimeDiceGradeOverwrite"
	}
})
buildRoller({
	name = "Trait", attribute = "trait", currency = "Trait Reroll",
	remote = Remotes.TraitRoll, tiersPath = "Traits.Traits", defaultTarget = "Damage I",
	flags = {
		enabled = "AnimeDiceAutoTrait", units = "AnimeDiceTraitUnits",
		target = "AnimeDiceTraitTarget", overwrite = "AnimeDiceTraitOverwrite"
	}
})

--======================================================================
-- POTIONS
--======================================================================
local potionCard = PotionTab:Card("Auto Use")
local potionTypes = PotionTab:Card("Potion Types")
local POTION_BASES = { "Normal", "Dragon", "Cursed", "Pirate", "Leaf" }
local CATEGORY_SUFFIX = { Luck = "Luck", Money = "Income", Damage = "Damage" }
local potionPicks = { Luck = {}, Money = {}, Damage = {} }
local wantedCategories = {}
local potionStackMinutes = 0
local function rebuildWanted()
	local set = {}
	for kind, picks in pairs(potionPicks) do
		local suffix = CATEGORY_SUFFIX[kind]
		for prefix in pairs(picks) do
			set[prefix == "Normal" and suffix or (prefix .. " " .. suffix)] = true
		end
	end
	wantedCategories = set
end
local potionOptions = table.clone(POTION_BASES)
pcall(function()
	local Reg = getModule("Inventory.EntryRegistry")
	local seen, extra = toSet(POTION_BASES), {}
	for id in pairs(Reg.entriesOfKind("Boost")) do
		local cfg = Reg.getEntryConfig(id)
		local prefix = cfg and cfg.category and cfg.category:match("^(.+) %a+$")
		if prefix and not seen[prefix] then
			seen[prefix] = true
			extra[#extra + 1] = prefix
		end
	end
	table.sort(extra)
	for _, p in ipairs(extra) do potionOptions[#potionOptions + 1] = p end
end)
local function usePotions(force)
	local inv = getData("Inventory")
	if type(inv) ~= "table" then return 0 end
	local activeEntries = getData("ActiveEntries")
	if type(activeEntries) ~= "table" then activeEntries = {} end
	local now = workspace:GetServerTimeNow()
	local remaining = {}
	for _, e in pairs(activeEntries) do
		local cfg = entryConfig(e.name)
		if cfg and cfg.kind == "Boost" then
			local left = tonumber(e.remaining) or 0
			if type(e.startedAt) == "number" then left -= now - e.startedAt end
			if left > 0 then remaining[cfg.category] = (remaining[cfg.category] or 0) + left end
		end
	end
	local byCat = {}
	for key, item in pairs(inv) do
		local cfg = entryConfig(item.name)
		if cfg and cfg.kind == "Boost" and (item.amount or 0) > 0 and wantedCategories[cfg.category] then
			local list = byCat[cfg.category] or {}
			list[#list + 1] = {
				key = key, tier = cfg.tier or 0,
				duration = tonumber(cfg.duration) or 0, amount = item.amount
			}
			byCat[cfg.category] = list
		end
	end
	local goal = math.max(potionStackMinutes * 60, 1)
	local used = 0
	for cat, list in pairs(byCat) do
		table.sort(list, function(a, b) return a.tier > b.tier end)
		local left = remaining[cat] or 0
		for _, p in ipairs(list) do
			while p.amount > 0 and (force or left < goal) do
				pcall(function() Remotes.UseBoost:FireServer(p.key) end)
				p.amount -= 1
				left += (p.duration > 0) and p.duration or goal
				used += 1
				task.wait(0.15)
			end
		end
	end
	return used
end
local potionLoop = newLoop("Auto Use Potions", function()
	usePotions(false)
	return 5
end, 5)
addToggle(potionCard, "Auto Use Potions", "AnimeDiceAutoPotions", potionLoop)
potionCard:Slider({
	Name = "Keep stacked per type", Min = 0, Max = 180, Default = 0, Step = 5, Suffix = "min",
	Flag = "AnimeDicePotionStackMinutes",
	Callback = function(v) potionStackMinutes = tonumber(v) or 0 end
})
potionCard:Button({
	Name = "Use potions now",
	Callback = function()
		task.spawn(function()
			local n = usePotions(false)
			notify("Potions", n > 0 and ("%d potion(s) used"):format(n) or "Nothing to use.")
		end)
	end
})
potionCard:Button({
	Name = "Use ALL selected (stack everything)",
	Callback = function()
		task.spawn(function()
			local n = usePotions(true)
			notify("Potions", n > 0 and ("%d potion(s) used"):format(n) or "Nothing to use.")
		end)
	end
})
for _, kind in ipairs({ "Luck", "Money", "Damage" }) do
	potionTypes:Dropdown({
		Name = kind .. " potions", Options = table.clone(potionOptions), Default = {}, Multi = true,
		Flag = "AnimeDicePotion" .. kind,
		Callback = function(v)
			potionPicks[kind] = toSet(v)
			rebuildWanted()
		end
	})
end

--======================================================================
-- AUTO SELL
--======================================================================
local sellCard = SellTab:Card("Auto Sell")
local sellAllCard = SellTab:Card("Sell whole rarity")
local sellMutCard = SellTab:Card("Sell by mutation")
local sellRarityAll, sellRarityMut, sellMutations = {}, {}, {}
local sellInterval = 5

local function sellableKeys()
	local inv, slots = getData("Inventory"), getData("Slots")
	if type(inv) ~= "table" or type(slots) ~= "table" then return {} end
	local equipped = {}
	for _, s in pairs(slots) do
		if s.unitId then equipped[s.unitId] = true end
	end
	local keys = {}
	for key, item in pairs(inv) do
		local cfg = entryConfig(item.name)
		if cfg and cfg.kind == "Unit" and (item.amount or 0) > 0 and not equipped[key] then
			local attrs = item.attributes or {}
			if not attrs.locked then
				local okR, rarity = pcall(function() return cfg.getRarity(attrs) end)
				if not okR or not rarity then rarity = cfg.rarity end
				local r = tostring(rarity)
				local mutation = attrs.mutation and tostring(attrs.mutation) or "No mutation"
				if sellRarityAll[r] or (sellRarityMut[r] and sellMutations[mutation]) then
					keys[#keys + 1] = key
				end
			end
		end
	end
	return keys
end
local function sellNow()
	local keys = sellableKeys()
	if #keys == 0 then return 0, 0 end
	local ok, money, count = pcall(function() return Remotes.SellInventory:InvokeServer(keys) end)
	if not ok then return 0, 0 end
	return tonumber(money) or 0, tonumber(count) or 0
end
local sellLoop = newLoop("Auto Sell", function()
	sellNow()
	return sellInterval
end, 5)
addToggle(sellCard, "Auto Sell", "AnimeDiceAutoSell", sellLoop)
sellCard:Slider({
	Name = "Interval", Min = 1, Max = 30, Default = 5, Step = 1, Suffix = "s",
	Flag = "AnimeDiceSellInterval",
	Callback = function(v) sellInterval = math.max(tonumber(v) or 5, 1) end
})
sellCard:Button({
	Name = "Sell now",
	Callback = function()
		task.spawn(function()
			local money, count = sellNow()
			notify("Sell", count > 0 and ("%d units · +$%s"):format(count, fmtMoney(money)) or "Nothing to sell.")
		end)
	end
})
sellAllCard:Dropdown({
	Name = "Rarities to sell (any mutation)", Options = RARITIES, Default = {}, Multi = true,
	Flag = "AnimeDiceSellRaritiesAll",
	Callback = function(v) sellRarityAll = toSet(v) end
})
sellMutCard:Dropdown({
	Name = "Rarities", Options = RARITIES, Default = {}, Multi = true,
	Flag = "AnimeDiceSellMutatedRarities",
	Callback = function(v) sellRarityMut = toSet(v) end
})
do
	local muts = { "No mutation" }
	for _, m in ipairs(MUTATIONS) do muts[#muts + 1] = m end
	sellMutCard:Dropdown({
		Name = "Mutations to sell", Options = muts, Default = {}, Multi = true,
		Flag = "AnimeDiceSellMutations",
		Callback = function(v) sellMutations = toSet(v) end
	})
end

--======================================================================
-- MISC
--======================================================================
local utilCard = MiscTab:Card("Utility")
local scriptCard = MiscTab:Card("Script")

local function antiAfkTick()
	pcall(function()
		local vp = workspace.CurrentCamera.ViewportSize
		VirtualInputManager:SendMouseMoveEvent(vp.X / 2 + 2, vp.Y / 2, game)
		task.wait(0.05)
		VirtualInputManager:SendMouseMoveEvent(vp.X / 2, vp.Y / 2, game)
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F13, false, game)
		task.wait(0.05)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F13, false, game)
	end)
end
local afkLoop = newLoop("Anti-AFK", function()
	antiAfkTick()
	return 60
end, 60)
addToggle(utilCard, "Anti-AFK", "AnimeDiceAntiAfk", afkLoop, function(v)
	if v then
		if not afkConn then afkConn = LocalPlayer.Idled:Connect(antiAfkTick) end
	elseif afkConn then
		afkConn:Disconnect()
		afkConn = nil
	end
end)
utilCard:Label("Sends a virtual mouse move + key press every 60s (works with Roblox in background).")
utilCard:Button({
	Name = "Rejoin server",
	Callback = function()
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end)
	end
})

statusPara = scriptCard:Paragraph({ Title = "Running now", Content = "Nothing running." })
scriptCard:Button({
	Name = "Stop all automation",
	Callback = function()
		stopAll()
		notify("KISTROX HUB", "All automation stopped.")
	end
})
scriptCard:Button({ Name = "Unload script", Callback = unload })
scriptCard:Label("Toggle the menu with RightShift or the floating N button.")

--======================================================================
-- Load saved settings + status updater
--======================================================================
UI:LoadConfig()

task.spawn(function()
	while alive() do
		local names = {}
		for _, l in ipairs(Loops) do
			if l.IsOn() and not l.Hidden then names[#names + 1] = l.Name end
		end
		setSafe(statusPara, {
			Title = "Running now",
			Content = #names > 0 and table.concat(names, "\n") or "Nothing running."
		})
		task.wait(3)
	end
end)

task.spawn(function()
	task.wait(1)
	refreshRoll()
end)

notify("KISTROX HUB", "Anime-Dice loaded.")