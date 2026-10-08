--=====================================================================
--  KISTROX HUB — ตัวโหลดกลาง (มีระบบ Key + โหมดดูโฆษณา)
--
--  โหมดการป้องกันก่อนรันสคริปต์ (ตั้งที่ CFG.GateMode):
--     "key"  = ผู้ใช้ต้องไปเอาคีย์จากหน้าเว็บ (ผ่านโฆษณา) แล้วมากรอก
--     "ad"   = เด้งไปลิงก์โฆษณา + นับถอยหลัง 10 วิ แล้วรัน (แบบเดิม)
--     "none" = รันทันทีเมื่อกดปุ่ม
--
--  วิธีใช้แบบ key:
--     1) ตั้ง CFG.KeyPage = ลิงก์หน้าเว็บขอคีย์ของคุณ
--     2) ตั้ง CFG.KeyAPI  = endpoint ตรวจคีย์ (ดูวิธีเลือกบริการด้านล่าง)
--     3) ถ้ายังไม่มี API ให้ใส่คีย์ทดสอบใน CFG.LocalKeys (ไว้ลองระบบ)
--=====================================================================
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local LP      = Players.LocalPlayer

--------------------------------------------------------------------
-- ตั้งค่า
--------------------------------------------------------------------
local CFG = {
    BaseURL   = "https://raw.githubusercontent.com/ratchanon-create/KT/main/",
    Title     = "KISTROX HUB",

    GateMode  = "key",                            -- "key" / "ad" / "none"

    -- === โหมด key (Cloudflare Worker: ดูโฆษณา + รอ 30 วิ แล้วได้คีย์) ===
    KeyGetAPI = "https://nirnim.ratchanon439990.workers.dev/getkey",    -- Worker ของคุณ (ดูคีย์/ดูโฆษณา)
    KeyAPI    = "https://nirnim.ratchanon439990.workers.dev/checkkey",  -- Worker ของคุณ (ตรวจคีย์)
    ScriptAPI = "https://nirnim.ratchanon439990.workers.dev/script",   -- ดึงโค้ดสคริปต์ (ต้องมีคีย์จริงเท่านั้น)
    KeyAPIInPath = false,                              -- false = ส่งเป็น ?key=..&hwid=..
    KeyGetMode   = "url",                              -- "url" = ลิงก์ที่ให้ผู้ใช้เปิด = KeyGetAPI?uid=<HWID>
    KeyGetAPIParam = "uid",                             -- ชื่อพารามิเตอร์ที่ส่ง HWID ไป
    KeyAPIKind = "json",                               -- Worker ตอบ {"valid":true}
    KeyAuth   = "",        -- ใส่ถ้าต้องใช้ API key (ปกติไม่ต้อง)
    KeyLifetimeHours = 0,                              -- 0 = let the Worker control expiry (8 hours)
    UnlimitedTestKeys = true,
    -- (โหมดทางเลือก: Work.ink ตรงๆ — ไม่ใช้แล้ว เว้นว่างไว้)
    KeyPage = "", KeyLink = "", OverrideURL = "", TokenPage = "",


    -- คีย์ทดสอบในเครื่อง (ใช้ตอนยังไม่ตั้ง API)
    LocalKeys = {
        "TEST-1234",          -- คีย์ทดสอบ (ใช้ตอนนี้ได้เลย)
    },

    -- === โหมด ad ===
    AdLink    = "https://uplcm.com/4/11984132",       -- ลิงก์โฆษณา
    AdWait    = 30,                                    -- ต้องรอกี่วินาทีก่อนได้คีย์
    LocalKeyMode = false,                              -- false = ใช้ Worker ตรวจคีย์จริง (กันบายพาส)

    -- จำคีย์ไว้ ครั้งต่อไปที่รัน ถ้าคีย์ยังไม่หมดอายุจะเข้าสู่ระบบให้อัตโนมัติ
    AutoLogin = true,

    UseCache  = true,
    LogFile   = "kistrox_log.txt",
    KeyFile   = "kistrox_key.txt",
}

--------------------------------------------------------------------
-- ตารางแมพที่รองรับ
--------------------------------------------------------------------
local GAMES = {
    {
        label = "Anime Dice",
        match = { placeId = 113290951185459, gameId = 10708913337, name = "Anime Dice" },
        protected = true,                  -- true = โค้ดไม่ขึ้น GitHub ดึงผ่าน Worker (ต้องมีคีย์)
        script    = "anime-dice",          -- ชื่อใน KV: script:anime-dice
        file  = "games/anime-dice.lua",    -- ไม่ใช้แล้วตอน protected=true (เก็บไว้เป็นที่แก้โค้ด)
    },
}
local DEFAULT_FILE = nil

--------------------------------------------------------------------
-- log + status
--------------------------------------------------------------------
writefile(CFG.LogFile, "")
local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    pcall(function() appendfile(CFG.LogFile, os.date("%H:%M:%S") .. "  " .. table.concat(parts, "  |  ") .. "\n") end)
    print("[KISTROX] " .. table.concat(parts, "  |  "))
end

local gui, statusLabel, countLabel, keyBox, keyBtn, confirmBtn
local function setStatus(t)
    if statusLabel then statusLabel.Text = t end
    log(t)
end

--------------------------------------------------------------------
-- ตรวจแมพ
--------------------------------------------------------------------
local function gameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    if ok and type(info) == "table" and info.Name then return info.Name end
    return ""
end

local function detect()
    local placeId, gameId, name = game.PlaceId, game.GameId, gameName()
    log("Map check: PlaceId =", placeId, "| GameId =", gameId, "| name =", name)
    for _, g in ipairs(GAMES) do
        local m = g.match or {}
        if (m.placeId and placeId == m.placeId) or (m.gameId and gameId == m.gameId) then
            return g, name
        end
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
-- เปิด/คัดลอกลิงก์
--------------------------------------------------------------------
local OPENERS = {
    { name = "GuiService:OpenBrowserWindow", fn = function(u)
        game:GetService("GuiService"):OpenBrowserWindow(u)
    end },
    { name = "openbrowser()", fn = function(u) openbrowser(u) end },
    { name = "open_url()",    fn = function(u) open_url(u) end },
    { name = "openurl()",     fn = function(u) openurl(u) end },
    { name = "request()",     fn = function(u) request({ Url = u, Method = "GET" }) end },
}

local function openLink(url)
    for _, o in ipairs(OPENERS) do
        local ok, err = pcall(o.fn, url)
        if ok then
            log("Opened link via " .. o.name)
            return true, o.name
        end
        log("Failed via " .. o.name .. ":", tostring(err):sub(1, 90))
    end
    if setclipboard then
        pcall(setclipboard, url)
        log("Copied link to clipboard:", url)
    end
    return false, "clipboard"
end

--------------------------------------------------------------------
-- HWID (ใช้ผูกคีย์กับเครื่อง)
--------------------------------------------------------------------
local function getHWID()
    local ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and type(id) == "string" and #id > 0 then return id end
    if gethwid then
        local ok2, id2 = pcall(gethwid)
        if ok2 and type(id2) == "string" then return id2 end
    end
    return tostring(LP.UserId)   -- สำรอง
end

--------------------------------------------------------------------
-- HTTP ที่ใส่ header ได้ (Work.ink ต้องใช้ Authorization: Bearer ...)
--------------------------------------------------------------------
local function httpGetJson(url, headers)
    -- 1) request ของ executor (Xeno มี)
    if request then
        local ok, res = pcall(request, { Url = url, Method = "GET", Headers = headers or {} })
        if ok and type(res) == "table" and res.Body then return tostring(res.Body) end
    end
    -- 2) syn.request / http_request
    if syn and syn.request then
        local ok, res = pcall(syn.request, { Url = url, Method = "GET", Headers = headers or {} })
        if ok and type(res) == "table" and res.Body then return tostring(res.Body) end
    end
    if http_request then
        local ok, res = pcall(http_request, { Url = url, Method = "GET", Headers = headers or {} })
        if ok and type(res) == "table" and res.Body then return tostring(res.Body) end
    end
    -- 3) สำรอง: HttpGet ธรรมดา (ใส่ header ไม่ได้)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then return tostring(body) end
    return nil, tostring(body)
end

--------------------------------------------------------------------
-- โหลดสคริปต์
--------------------------------------------------------------------
-- เข้ารหัส URL (ใช้ encodeURL ของ executor ถ้ามี)
local function urlEncode(str)
    if encodeURL then
        local ok, res = pcall(encodeURL, str)
        if ok and type(res) == "string" then return res end
    end
    return (tostring(str):gsub("[^%w%-%.%_%~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function looksLikeCode(code)
    if type(code) ~= "string" or #code < 100 then return false end
    if code:find("^<!DOCTYPE", 1, true) then return false end
    if code:find("404: Not Found", 1, true) then return false end
    if code:find("<html", 1, true) then return false end
    return true
end

local function fetch(url, noCache)
    if CFG.UseCache and not noCache then
        local cacheName = "kistrox_cache_" .. tostring(game.PlaceId) .. ".lua"
        if isfile and isfile(cacheName) then
            local ok, data = pcall(readfile, cacheName)
            if ok and looksLikeCode(data) then
                log("Using cached script:", cacheName)
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

-- ดึงสคริปต์ที่ป้องกันไว้: ต้องมีคีย์จริง + เครื่องตรง ไม่งั้น Worker ไม่คืนโค้ด
local function fetchProtected(g, key)
    if CFG.ScriptAPI == "" then
        return nil, "CFG.ScriptAPI is not set"
    end
    local url = CFG.ScriptAPI
        .. "?key=" .. urlEncode(key or "")
        .. "&hwid=" .. urlEncode(getHWID())
        .. "&name=" .. urlEncode(g.script or "")
    log("Requesting protected script:", tostring(g.script))
    local code, err = fetch(url, true)   -- ห้าม cache: ไม่ให้โค้ดค้างอยู่ในเครื่อง
    if not code then return nil, tostring(err) end
    if looksLikeCode(code) then return code end
    -- ที่ได้ไม่ใช่โค้ด = คีย์ไม่ผ่าน -> ดึงเหตุผลจาก JSON มาโชว์
    return nil, (code:match('"reason"%s*:%s*"([^"]+)"') or "Key not accepted / no permission to load this script")
end

local function runFor(g, key)
    local code, lastErr
    if g.protected and g.script then
        code, lastErr = fetchProtected(g, key)
    else
        local tries = { g.file }
        local base = g.file:match("([^/]+)$")
        if base and base ~= g.file then tries[#tries + 1] = base end
        for _, rel in ipairs(tries) do
            local url = CFG.BaseURL .. rel
            log("Loading script for map:", g.label, "->", url)
            code, lastErr = fetch(url)
            if code then break end
        end
    end
    if not code then
        log("Failed to load script:", tostring(lastErr))
        setStatus("Failed to load script -- " .. tostring(lastErr))
        return false
    end

    local fn, cerr = loadstring(code, g.label)
    if not fn then
        log("Compile failed:", tostring(cerr))
        setStatus("This map script has a problem (see log)")
        return false
    end
    log("Running map script:", g.label, "| size", #code, "chars")
    setStatus("Running script: " .. g.label)
    local ok, rerr = pcall(fn)
    if not ok then
        log("Runtime error:", tostring(rerr))
        setStatus("Script error (see log)")
        return false
    end
    return true
end

--------------------------------------------------------------------
local verified = false

-- อายุคีย์ (ชั่วโมง) — จำเวลาที่คีย์ถูกใช้ครั้งแรกไว้ในเครื่อง
--------------------------------------------------------------------
local KEYSTATE = "kistrox_keyinfo.txt"

local function keyStateText()
    if not (isfile and isfile(KEYSTATE)) then return "(none)" end
    local ok, d = pcall(readfile, KEYSTATE)
    if not ok or type(d) ~= "string" then return "(unreadable)" end
    return (tostring(d):gsub("\n", " / "))
end

local function readKeyState()
    if not (isfile and isfile(KEYSTATE)) then return nil end
    local ok, data = pcall(readfile, KEYSTATE)
    if not ok or type(data) ~= "string" then return nil end
    local k, t = data:match("^(.-)\n(%d+)$")
    if k and t then return k, tonumber(t) end
    return nil
end

local function writeKeyState(k, t)
    pcall(function() writefile(KEYSTATE, tostring(k) .. "\n" .. tostring(t)) end)
end

-- ไฟล์จำคีย์ไว้ใช้ครั้งต่อไป (auto login)
local function saveKey(k)
    if not writefile then return end
    pcall(function() writefile(CFG.KeyFile, tostring(k)) end)
end

local function loadKey()
    if not (isfile and isfile(CFG.KeyFile)) then return "" end
    local ok, d = pcall(readfile, CFG.KeyFile)
    if not ok or type(d) ~= "string" then return "" end
    return (d:gsub("%s", ""))
end

local function clearKey()
    if not writefile then return end
    pcall(function() writefile(CFG.KeyFile, "") end)
end

-- คืนค่า: (ผ่านไหม, ข้อความ)
local function checkLifetime(key)
    local hrs = tonumber(CFG.KeyLifetimeHours) or 0
    if hrs <= 0 then return true, "no time limit" end
    local savedKey, firstUse = readKeyState()
    if savedKey == key and firstUse then
        local left = hrs * 3600 - (os.time() - firstUse)
        if left <= 0 then
            return false, ("this key reached its %d-hour limit -- get a new key"):format(hrs)
        end
        return true, ("time left %dh %dm"):format(math.floor(left / 3600), math.floor((left % 3600) / 60))
    end
    writeKeyState(key, os.time())
    return true, ("timer restarted: %d hours"):format(hrs)
end

-- เรียกเมื่อคีย์ผ่าน: ตรวจอายุ + คืนสถานะ
local function passKey(key, extraText, skipLifetime)
    local msg
    if skipLifetime then
        msg = "test key (no timer)"
    else
        local okLife
        okLife, msg = checkLifetime(key)
        if not okLife then
            verified = false
            setStatus(msg)
            return false
        end
    end
    verified = true
    setStatus("Key OK" .. (extraText and (" (" .. extraText .. ")") or "") .. " | " .. msg .. " -- running script")
    return true
end

local localKey = nil          -- คีย์ที่สร้างหลังดูโฆษณาครบ (โหมดในเครื่อง)

--------------------------------------------------------------------
-- ตรวจคีย์
--------------------------------------------------------------------

local function verifyKey(key, silent)
    key = tostring(key or ""):gsub("%s", "")
    if #key < 4 then
        if not silent then setStatus("Paste your key first (copy it from the getkey page)") end
        return false
    end

    -- 1) คีย์ทดสอบในเครื่อง
    for _, k in ipairs(CFG.LocalKeys or {}) do
        if k == key then
            pcall(function() writefile(KEYSTATE, "") end)   -- ล้างเวลาที่จำไว้
            return passKey(key, "from test list", CFG.UnlimitedTestKeys)
        end
    end

    -- 1.5) โหมดคีย์ในเครื่อง (สร้างหลังดูโฆษณาครบ)
    if CFG.LocalKeyMode then
        if localKey and key == localKey then
            return passKey(key, "local key", true)
        end
        if not silent then
            setStatus("Invalid key -- press Copy link getkey to get one")
        end
        return false
    end

    -- 2) ตรวจผ่าน API (Worker ของเรา)
    if CFG.KeyAPI ~= "" then
        local url
        if CFG.KeyAPIInPath then
            url = CFG.KeyAPI .. urlEncode(key)
        else
            url = CFG.KeyAPI .. "?key=" .. urlEncode(key) .. "&hwid=" .. urlEncode(getHWID())
        end
        local headers = {}
        if CFG.KeyAuth and CFG.KeyAuth ~= "" and not CFG.KeyAuth:find("PASTE_") then
            headers["Authorization"] = CFG.KeyAuth
            headers["Content-Type"] = "application/json"
        end
        log("Checking key with server:", url)
        local body, err = httpGetJson(url, headers)
        if not body then
            if not silent then setStatus("Cannot reach API: " .. tostring(err):sub(1, 80)) end
            return false
        end
        log("API response:", tostring(body):sub(1, 200))

        local low = tostring(body):lower()
        local pass
        if CFG.KeyAPIKind == "json" then
            pass = low:find('"valid"%s*:%s*true') ~= nil
                or low:find('"success"%s*:%s*true') ~= nil
                or low:find('"ok"%s*:%s*true') ~= nil
        else
            pass = low:find("valid") ~= nil or low:find("success") ~= nil
                or low:find("true") ~= nil or low:find("ok") ~= nil
        end

        if pass then
            return passKey(key, "from getkey page")
        end
        local why = tostring(body):sub(1, 120)
        if not silent then
            setStatus("Invalid or expired key (" .. why .. ") -- get a new key from the getkey page")
        end
        return false
    end

    if not silent then
        setStatus("KeyAPI is not configured (set CFG.KeyAPI or CFG.LocalKeys)")
    end
    return false
end

--------------------------------------------------------------------
-- ขอลิงก์เฉพาะตัวจาก Worker (/getlink?uid=<hwid>)
--------------------------------------------------------------------
local function fetchPersonalLink(cb)
    -- โหมด url: ลิงก์ = <worker>/getkey?uid=<HWID> (ผู้ใช้เปิดในเบราว์เซอร์เอง)
    if CFG.KeyGetMode == "url" and CFG.KeyGetAPI ~= "" then
        cb(CFG.KeyGetAPI .. "?" .. (CFG.KeyGetAPIParam or "uid") .. "=" .. getHWID())
        return
    end

    -- ทางที่ 1: มี Worker -> ใช้ Worker (แนะนำถ้ามี)
    if CFG.KeyGetAPI == "" and CFG.OverrideURL == "" then
        cb(nil, "OverrideURL / KeyGetAPI is not set")
        return
    end
    if CFG.KeyGetAPI ~= "" then
        -- ... ใช้ Worker ตามด้านล่าง
    else
        -- ทางที่ 2: เรียก Override API ของ Work.ink เอง แล้วให้ผู้ใช้เอาโค้ดจากหน้าเว็บมากรอก
        local dest = CFG.TokenPage .. "?token={TOKEN}&uid=" .. getHWID()
        local url = CFG.OverrideURL .. "?destination=" .. urlEncode(dest)
        log("Requesting sr from Work.ink:", url)
        task.spawn(function()
            local body = httpGetJson(url, {})
            if not body then
                cb(nil, "Cannot reach Work.ink")
                return
            end
            log("Override response:", tostring(body):sub(1, 200))
            local sr = tostring(body):match('"sr"%s*:%s*"(.-)"')
            if not sr then
                cb(nil, "Work.ink said: " .. tostring(body):sub(1, 140))
                return
            end
            cb(CFG.KeyLink .. "?sr=" .. sr)
        end)
        return
    end
    local url = CFG.KeyGetAPI .. "?uid=" .. getHWID()
    log("Requesting personal link:", url)
    task.spawn(function()
        local body = httpGetJson(url, {})
        if not body then
            cb(nil, "Cannot reach Worker")
            return
        end
        log("Worker response:", tostring(body):sub(1, 160))
        local link = tostring(body):match('"link"%s*:%s*"(.-)"')
        if link then
            cb(link)
        else
            cb(nil, "Worker said: " .. tostring(body):sub(1, 120))
        end
    end)
end

--------------------------------------------------------------------
-- ขั้นตอนรวม: ตรวจคีย์ -> รันสคริปต์
--------------------------------------------------------------------
local gating, confirmed = false, false

local function makeLocalKey()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local function part(n)
        local t = {}
        for i = 1, n do
            local k = math.random(1, #chars)
            t[i] = chars:sub(k, k)
        end
        return table.concat(t)
    end
    return ("KISTROX-%s-%s-%s"):format(part(5), part(5), part(5))
end

-- กด -> เปิดโฆษณา -> นับถอยหลัง -> คีย์โผล่
local function startAdGate()
    if gating then return end
    gating = true
    local opened = openLink(CFG.AdLink)
    if setclipboard then pcall(setclipboard, CFG.AdLink) end
    setStatus(opened and "Ad opened -- please watch it fully" or "Cannot open automatically -- link copied, open it in your browser")

    for i = CFG.AdWait, 1, -1 do
        task.wait(1)
    end

    localKey = makeLocalKey()
    if keyBox then keyBox.Text = localKey end
    if setclipboard then pcall(setclipboard, localKey) end
    setStatus("Key ready (copied) -- press Confirm key + Run script")
    gating = false
end
local detected, detectedName = nil, ""

local function startFlow(preKey)
    local g = detected or (DEFAULT_FILE and { label = "default", file = DEFAULT_FILE } or nil)
    if not g then
        setStatus("This map is not supported yet -- send the PlaceId to the developer")
        return
    end
    if gating then return end
    gating, confirmed = true, false
    local usedKey = ""      -- คีย์ที่ผ่านแล้ว เอาไปใช้ขอดึงโค้ดสคริปต์

    if preKey and preKey ~= "" then
        usedKey = preKey                 -- คีย์ที่ตรวจมาแล้ว (auto login)
    elseif CFG.GateMode == "key" then
        -- ตรวจคีย์ที่ผู้ใช้กรอกก่อน
        local key = keyBox and keyBox.Text or ""
        if not verifyKey(key) then
            gating = false
            return
        end
        usedKey = key

    elseif CFG.GateMode == "ad" then
        local opened, how = openLink(CFG.AdLink)
        if not opened then
            setStatus("Cannot open the browser automatically -- press Open link / Continue below")
            if confirmBtn then confirmBtn.Visible = true end
            local t0 = os.clock()
            while gating and not confirmed and (os.clock() - t0) < 180 do task.wait(0.2) end
            if confirmBtn then confirmBtn.Visible = false end
            if not gating then return end
            if not confirmed then
                setStatus("Link was not opened -- run cancelled")
                gating = false
                return
            end
        else
            setStatus("Link opened (" .. tostring(how) .. ") -- please wait for the timer")
        end
        for i = CFG.AdWait, 1, -1 do
            task.wait(1)
        end
    end

    local okRun = runFor(g, usedKey)
    if okRun and usedKey ~= "" then
        saveKey(usedKey)                 -- รันผ่านแล้วค่อยจำ ครั้งต่อไป auto login ได้
        log("Saved key for next time")
    end
    gating = false
end

--------------------------------------------------------------------
-- จำคีย์ไว้ใช้ครั้งต่อไป (auto login)
--------------------------------------------------------------------
-- ถ้ามีคีย์เดิมที่ยังไม่หมดอายุ -> เข้าให้เลย / ถ้าหมดอายุ -> ล้างทิ้งแล้วให้ไปกด Copy link getkey ใหม่
local function tryAutoLogin()
    if not CFG.AutoLogin then return end
    local saved = loadKey()
    if saved == "" then return end

    log("Saved key found -- verifying automatically")
    setStatus("Saved key found -- logging you in automatically...")
    if keyBox then keyBox.Text = saved end

    if not verifyKey(saved, true) then
        clearKey()
        if keyBox then keyBox.Text = "" end
        setStatus("Saved key expired or is no longer valid -- press Copy link getkey")
        log("Saved key is no longer valid -- cleared")
        return
    end

    log("Auto login OK -- running script")
    startFlow(saved)
end

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local function mkButton(parent, txt, x, y, w, h, color, txtColor, textSize)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.Text = txt
    b.TextColor3 = txtColor or Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 12
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local function buildUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "KISTROX_Loader"
    gui.ResetOnSpawn = false
    gui.Parent = LP:WaitForChild("PlayerGui")

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 380, 0, 244)
    f.Position = UDim2.new(0, 24, 0, 90)
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



    -- กล่องบนสุด: โชว์แค่ชื่อแมพที่ตรวจเจอ
    local mapBox = Instance.new("TextLabel")
    mapBox.Size = UDim2.new(1, -24, 0, 46)
    mapBox.Position = UDim2.new(0, 12, 0, 36)
    mapBox.BackgroundColor3 = Color3.fromRGB(20, 24, 31)
    mapBox.TextColor3 = Color3.fromRGB(34, 211, 238)
    mapBox.Font = Enum.Font.GothamBlack
    mapBox.TextSize = 18
    mapBox.Text = "Checking map..."
    mapBox.TextWrapped = true
    mapBox.TextXAlignment = Enum.TextXAlignment.Center
    mapBox.TextYAlignment = Enum.TextYAlignment.Center
    mapBox.Parent = f
    Instance.new("UICorner", mapBox).CornerRadius = UDim.new(0, 8)
    local mbStroke = Instance.new("UIStroke")
    mbStroke.Color = Color3.fromRGB(34, 211, 238)
    mbStroke.Thickness = 1
    mbStroke.Transparency = 0.75
    mbStroke.Parent = mapBox

    -- ปุ่มเดียว: คัดลอกลิงก์ไปหน้า getkey
    local acceptBtn = mkButton(f, "Copy link getkey", 12, 92, 356, 40, Color3.fromRGB(34, 211, 238), Color3.fromRGB(10, 20, 26), 14)

    keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -24, 0, 36)
    keyBox.Position = UDim2.new(0, 12, 0, 142)
    keyBox.BackgroundColor3 = Color3.fromRGB(20, 24, 31)
    keyBox.TextColor3 = Color3.fromRGB(230, 238, 245)
    keyBox.PlaceholderText = "Paste your key here"
    keyBox.PlaceholderColor3 = Color3.fromRGB(110, 125, 140)
    keyBox.Font = Enum.Font.Code
    keyBox.TextSize = 13
    keyBox.Text = ""
    keyBox.ClearTextOnFocus = false
    keyBox.Parent = f
    Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 7)

    keyBtn = mkButton(f, "Confirm key + Run script", 12, 188, 356, 42, Color3.fromRGB(34, 211, 238), Color3.fromRGB(10, 20, 26), 14)

    confirmBtn = mkButton(f, "Open link / Continue", 12, 188, 356, 42, Color3.fromRGB(255, 170, 60), Color3.fromRGB(30, 20, 5), 13)
    confirmBtn.Visible = false

    -- ลากหน้าต่าง
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            local dragging, start, sp = true, i.Position, f.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
            UIS.InputChanged:Connect(function(m)
                if dragging and (m.UserInputType == Enum.UserInputType.MouseMovement
                    or m.UserInputType == Enum.UserInputType.Touch) then
                    local d = m.Position - start
                    f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
                end
            end)
        end
    end)

    detected, detectedName = detect()
    if detected then
        mapBox.Text = detected.label
        setStatus("")
        task.spawn(tryAutoLogin)         -- มีคีย์เดิมที่ยังไม่หมดอายุ = เข้าให้เลย
    else
        mapBox.Text = "No supported map"
        setStatus("PlaceId: " .. tostring(game.PlaceId) .. " -- send this to the developer to add this map")
    end

    acceptBtn.MouseButton1Click:Connect(function()
        -- กดแล้วเปลี่ยนปุ่มเป็น Copied แล้วค่อยกลับเป็นข้อความเดิม
        local function flashCopied()
            acceptBtn.Text = "Copied"
            task.delay(2, function()
                if acceptBtn and acceptBtn.Parent then
                    acceptBtn.Text = "Copy link getkey"
                end
            end)
        end

        if CFG.LocalKeyMode then
            task.spawn(startAdGate)
            flashCopied()
            return
        end
        if CFG.KeyGetAPI ~= "" then
            setStatus("Requesting your personal link from the Worker...")
            fetchPersonalLink(function(link, err)
                if not link then
                    if setclipboard then pcall(setclipboard, tostring(CFG.KeyPage or CFG.KeyLink or "")) end
                    setStatus("Auto request failed (" .. tostring(err) .. ") -- copied the plain link instead")
                    return
                end
                if setclipboard then pcall(setclipboard, link) end
                openLink(link)
                flashCopied()
                setStatus("Link copied -- open the page, watch the ad, then paste your key")
            end)
        else
            if setclipboard then pcall(setclipboard, tostring(CFG.KeyPage or CFG.KeyLink or "")) end
            flashCopied()
            setStatus("Copied the getkey link: " .. tostring(CFG.KeyPage or CFG.KeyLink or ""))
        end
    end)
    keyBtn.MouseButton1Click:Connect(function()
        if gating then return end
        task.spawn(startFlow)
    end)
    confirmBtn.MouseButton1Click:Connect(function()
        openLink(CFG.AdLink)
        if setclipboard then pcall(setclipboard, CFG.AdLink) end
        confirmed = true
    end)
    close.MouseButton1Click:Connect(function()
        if gui then gui:Destroy() end
    end)
end

buildUI()
log("Config: GateMode =", CFG.GateMode, "| LocalKeys =", tostring(#(CFG.LocalKeys or {})),
    "| KeyAPI =", (CFG.KeyAPI ~= "" and CFG.KeyAPI or "(empty)"), "| KeyLifetimeHours =", tostring(CFG.KeyLifetimeHours))
log("Saved key state:", keyStateText())
log("KISTROX HUB ready | GateMode =", CFG.GateMode, "| PlaceId =", game.PlaceId)
