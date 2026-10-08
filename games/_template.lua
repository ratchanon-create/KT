--=====================================================================
--  เทมเพลตสคริปต์ของเกมใหม่ (คัดลอกไฟล์นี้ไปเป็น games/<ชื่อเกม>.lua)
--  ตัวโหลดกลาง (main.lua) จะโหลดไฟล์นี้เมื่อตรวจพบว่าเข้าแมพนั้น
--  ตัวแปรที่ใช้ได้เลย: game, Players, LocalPlayer (คัดลอกจากด้านล่าง)
--=====================================================================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local UIS     = game:GetService("UserInputService")
local LP      = Players.LocalPlayer

print("[KISTROX] โหลดสคริปต์เกม: <ใส่ชื่อเกมตรงนี้>")

-- TIP: ถ้าอยากให้มี UI เปิด/ปิดของตัวเอง ให้สร้าง ScreenGui ที่นี่
--      หรือคัดลอกโครง UI จากสคริปต์เกมอื่นมาใช้

--[[
    ตัวอย่างโครง:
    local gui = Instance.new("ScreenGui")
    gui.Name = "KISTROX_<เกม>"
    gui.ResetOnSpawn = false
    gui.Parent = LP:WaitForChild("PlayerGui")
    ...
]]

-- อย่าลืม: ถ้าใช้สคริปต์ของคนอื่นเป็นฐาน ใส่เครดิตเจ้าของเดิมไว้ด้วย
