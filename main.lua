--=====================================================================
--  KISTROX HUB — ตัวโหลดกลาง (ตรวจแมพก่อน แล้วรันสคริปต์ที่ตรงกับแมพนั้น)
--
--  วิธีใช้ (บรรทัดเดียวสำหรับแจก):
--     loadstring(game:HttpGet("https://raw.githubusercontent.com/<USER>/kistrox-hub/main/main.lua"))()
--
--  หลักการทำงาน:
--     1) อ่าน PlaceId / GameId / ชื่อเกม ของแมพที่กำลังเล่น
--     2) เทียบกับตาราง GAMES ด้านล่าง
--     3) ถ้าเจอ -> โหลดไฟล์สคริปต์ของแมพนั้นจาก BASE_URL แล้วรัน
--     4) ถ้าไม่เจอ -> แจ้งว่าไม่รองรับ (ไม่รันอะไร)
--
--  การเพิ่มเกมใหม่: ใส่รายการใน GAMES + อัปไฟล์สคริปต์ในโฟลเดอร์ games/
--=====================================================================
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local LP      = Players.LocalPlayer

--------------------------------------------------------------------
-- ตั้งค่า
--------------------------------------------------------------------
local CFG = {
    -- เปลี่ยน <USER> เป็นชื่อบัญชี GitHub ของคุณ
    BaseURL   = "https://raw.githubusercontent.com/ratchanon-create/kistrox-hub/main/",
    Title     = "KISTROX HUB",
    LogFile   = "kistrox_log.txt",
    UseCache  = true,        -- จำสคริปต์ที่โหลดไว้ ครั้งต่อไปไม่ต้องโหลดซ้ำ
    AutoRun   = true,        -- ตรวจแมพ + รันสคริปต์อัตโนมัติทันทีที่ Execute
}

--------------------------------------------------------------------
-- ตารางแมพที่รองรับ
--   match.name    = ข้อความในชื่อเกม (ไม่ต้องตรงทั้งชื่อ ใช้แบบ "มีคำนี้")
--   match.placeId = PlaceId (ถ้ารู้) — แม่นสุด
--   match.gameId  = Universe/GameId (ถ้ารู้)
--------------------------------------------------------------------
local GAMES = {
    {
        label = "Anime Dice",
        match = {
            placeId = 113290951185459,          -- แม่นสุด (ตรงกับเกมนี้)
            gameId  = 10708913337,
            name    = "Anime Dice",             -- เผื่อไว้ ถ้าเกมเปลี่ยน PlaceId
        },
        file  = "games/anime-dice.lua",
    },
    -- ตัวอย่างการเพิ่มเกมใหม่:
    -- {
    --     label = "Blox Fruits",
    --     match = { placeId = 2753915549, name = "Blox Fruits" },
    --     file  = "games/blox-fruits.lua",
    -- },
}
local DEFAULT_FILE = nil    -- ถ้าไม่เจอแมพใดเลย จะรันไฟล์นี้ (nil = ไม่รัน)

--------------------------------------------------------------------
-- log
--------------------------------------------------------------------
writefile(CFG.LogFile, "")
local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    pcall(function() appendfile(CFG.LogFile, os.date("%H:%M:%S") .. "  " .. table.concat(parts, "  |  ") .. "\n") end)
    print("[KISTROX] " .. table.concat(parts, "  |  "))
end

-- status ต้องประกาศก่อน เพราะ runFor เรียกใช้
local gui, statusLabel
local function setStatus(t)
    if statusLabel then statusLabel.Text = t end
    log(t)
end

--------------------------------------------------------------------
-- ตรวจแมพปัจจุบัน
--------------------------------------------------------------------
local function gameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name then return info.Name end
    return ""
end

local function detect()
    local placeId = game.PlaceId
    local gameId  = game.GameId
    local name    = gameName()
    log("ตรวจแมพ: PlaceId =", placeId, "| GameId =", gameId, "| ชื่อ =", name)
    for _, g in ipairs(GAMES) do
        local m = g.match or {}
        if m.placeId and placeId == m.placeId then return g, name end
        if m.gameId and gameId == m.gameId then return g, name end
    end
    if name ~= "" then
        local lower = name:lower()
        for _, g in ipairs(GAMES) do
            local m = g.match or {}
            if m.name and lower:find(m.name:lower(), 1, true) then return g, name end
        end
    end
    return nil, name
end

--------------------------------------------------------------------
-- โหลด + รันสคริปต์ของแมพนั้น
--------------------------------------------------------------------
local function looksLikeCode(code)
	if type(code) ~= "string" or #code < 100 then return false end
	if code:find("^<!DOCTYPE", 1, true) then return false end
	if code:find("404: Not Found", 1, true) then return false end
	if code:find("<html", 1, true) then return false end
	return true
end

local function fetch(url)
    if CFG.UseCache then
        local cacheName = "kistrox_cache_" .. tostring(game.PlaceId) .. ".lua"
        if isfile and isfile(cacheName) then
            local ok, data = pcall(readfile, cacheName)
            if ok and looksLikeCode(data) then
                log("ใช้สคริปต์จาก cache:", cacheName)
                return data
            end
        end
        local ok, code = pcall(function() return game:HttpGet(url) end)
        if ok and looksLikeCode(code) then
            pcall(function() writefile(cacheName, code) end)
            return code
        end
        return nil, tostring(code)
    end
    local ok, code = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil, tostring(code) end
    return code
end

local function runFor(g)
    setStatus("ตรวจพบแมพ: " .. g.label .. " -- กำลังโหลดสคริปต์...")

    -- ลอง path ที่ตั้งไว้ก่อน ถ้าไม่ได้ลองชื่อไฟล์ที่วางไว้ที่ root (เผื่ออัปโหลดแล้วโฟลเดอร์หาย)
    local tries = { g.file }
    local base = g.file:match("([^/]+)$")
    if base and base ~= g.file then tries[#tries + 1] = base end

    local code, lastErr
    for _, rel in ipairs(tries) do
        local url = CFG.BaseURL .. rel
        log("กำลังโหลดสคริปต์ของแมพ:", g.label, "->", url)
        code, lastErr = fetch(url)
        if code then break end
    end
    if not code then
        log("โหลดสคริปต์ไม่สำเร็จ:", tostring(lastErr))
        setStatus("โหลดสคริปต์ไม่สำเร็จ -- เช็ค BaseURL / ชื่อไฟล์ใน repo (ดู log)")
        return false
    end
    local fn, cerr = loadstring(code, g.label)
    if not fn then
        log("คอมไพล์ไม่สำเร็จ:", tostring(cerr))
        setStatus("สคริปต์ของแมพนี้มีปัญหา (ดู log)")
        return false
    end
    log("รันสคริปต์แมพ:", g.label, "| ขนาด", #code, "ตัวอักษร")
    setStatus("รันสคริปต์: " .. g.label)
    local ok, rerr = pcall(fn)
    if not ok then
        log("รันแล้ว error:", tostring(rerr))
        setStatus("รันแล้ว error (ดู log)")
        return false
    end
    return true
end

--------------------------------------------------------------------
-- UI เล็กๆ (สถานะ + ปุ่มรัน/ปิด)
--------------------------------------------------------------------
local function buildUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "KISTROX_Loader"
    gui.ResetOnSpawn = false
    gui.Parent = LP:WaitForChild("PlayerGui")

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 300, 0, 108)
    f.Position = UDim2.new(0, 24, 0, 96)
    f.BackgroundColor3 = Color3.fromRGB(11, 14, 18)
    f.BorderSizePixel = 0
    f.Active = true
    f.Parent = gui
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(34, 211, 238)
    st.Thickness = 1.5
    st.Transparency = 0.5
    st.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(20, 24, 31)
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = CFG.Title
    title.TextColor3 = Color3.fromRGB(230, 238, 245)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = bar

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 24, 0, 20)
    close.Position = UDim2.new(1, -30, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(120, 40, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 200, 200)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 12
    close.Parent = bar
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -24, 0, 32)
    statusLabel.Position = UDim2.new(0, 12, 0, 36)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "กำลังตรวจแมพ..."
    statusLabel.TextColor3 = Color3.fromRGB(124, 139, 153)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = f

    local runBtn = Instance.new("TextButton")
    runBtn.Size = UDim2.new(0, 130, 0, 26)
    runBtn.Position = UDim2.new(0, 12, 0, 72)
    runBtn.BackgroundColor3 = Color3.fromRGB(34, 211, 238)
    runBtn.Text = "▶  รันสคริปต์แมพนี้"
    runBtn.TextColor3 = Color3.fromRGB(10, 20, 26)
    runBtn.Font = Enum.Font.GothamBold
    runBtn.TextSize = 12
    runBtn.Parent = f
    Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 8)

    local logBtn = Instance.new("TextButton")
    logBtn.Size = UDim2.new(0, 130, 0, 26)
    logBtn.Position = UDim2.new(1, -142, 0, 72)
    logBtn.BackgroundColor3 = Color3.fromRGB(26, 31, 39)
    logBtn.Text = "ข้อมูลแมพนี้"
    logBtn.TextColor3 = Color3.fromRGB(230, 238, 245)
    logBtn.Font = Enum.Font.Gotham
    logBtn.TextSize = 12
    logBtn.Parent = f
    Instance.new("UICorner", logBtn).CornerRadius = UDim.new(0, 8)

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            local dragging, start, sp = true, i.Position, f.Position
            local c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false c:Disconnect() end
            end)
            local cc
            cc = UIS.InputChanged:Connect(function(m)
                if dragging and (m.UserInputType == Enum.UserInputType.MouseMovement
                    or m.UserInputType == Enum.UserInputType.Touch) then
                    local d = m.Position - start
                    f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
                end
            end)
        end
    end)

    local detected, gname = detect()
    local info = ("PlaceId %d | GameId %d | %s"):format(game.PlaceId, game.GameId,
        (gname ~= "" and gname or "ไม่ทราบชื่อ"))
    if detected then
        setStatus("ตรวจพบแมพที่รองรับ: " .. detected.label)
    else
        setStatus("ไม่พบแมพนี้ในรายการที่รองรับ (กด 'ข้อมูลแมพนี้' เพื่อดู PlaceId)")
    end

    runBtn.MouseButton1Click:Connect(function()
        local g = detected or (DEFAULT_FILE and { label = "default", file = DEFAULT_FILE } or nil)
        if not g then
            setStatus("แมพนี้ยังไม่รองรับ — ส่ง PlaceId ให้แอดมินเพิ่ม")
            return
        end
        task.spawn(function() runFor(g) end)
    end)
    logBtn.MouseButton1Click:Connect(function()
        setStatus(info)
    end)
    close.MouseButton1Click:Connect(function()
        if gui then gui:Destroy() end
    end)
end

--------------------------------------------------------------------
buildUI()
if CFG.AutoRun then
    task.spawn(function()
        task.wait(1)
        local g = detect()
        if g then
            runFor(g)
        else
            setStatus("แมพนี้ยังไม่รองรับ (กด 'ข้อมูลแมพนี้' เพื่อดู PlaceId แล้วแจ้งเพิ่ม)")
        end
    end)
end
log("KISTROX HUB พร้อมใช้งาน | PlaceId =", game.PlaceId)
