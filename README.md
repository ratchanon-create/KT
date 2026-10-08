# KISTROX HUB

ตัวโหลดกลางสำหรับ Roblox — **ตรวจแมพก่อน แล้วรันสคริปต์ที่ตรงกับแมพนั้น**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<USER>/kistrox-hub/main/main.lua"))()
```

---

## โครงสร้าง

```
kistrox-hub/
├─ main.lua                 ← ตัวโหลดกลาง (ตรวจแมพ + รันสคริปต์ที่ตรง)
├─ games/
│  ├─ anime-dice.lua        ← สคริปต์ของเกม Anime Dice
│  └─ _template.lua         ← เทมเพลตสำหรับเพิ่มเกมใหม่
├─ tools/
│  └─ whereami.lua          ← บอก PlaceId/GameId ของแมพที่กำลังเล่น
└─ README.md
```

## หลักการทำงานของ main.lua

1. อ่าน `game.PlaceId`, `game.GameId` และชื่อเกม (ผ่าน MarketplaceService)
2. เทียบกับตาราง `GAMES` ใน `main.lua`
3. เจอ → โหลดไฟล์สคริปต์ของแมพนั้นจาก `CFG.BaseURL` แล้ว `loadstring(...)()`
4. ไม่เจอ → แจ้งว่าไม่รองรับ (กดปุ่ม "ข้อมูลแมพนี้" เพื่อดู PlaceId ไปแจ้งเพิ่ม)

มี UI เล็ก ๆ โชว์สถานะ + ปุ่มรันซ้ำ/ปิด และมี cache กันโหลดซ้ำ (`kistrox_cache_<PlaceId>.lua`)

---

## วิธีสร้าง repo และอัปโหลด

### ทางที่ 1: ผ่านหน้าเว็บ GitHub (ง่ายสุด)
1. สมัคร/ล็อกอิน GitHub → กด **New repository** → ตั้งชื่อ `kistrox-hub` → เลือก **Public** → Create
2. กด **uploading an existing file** → ลากไฟล์ทั้งหมดในโฟลเดอร์นี้ขึ้นไป (ต้องคงโครงสร้างโฟลเดอร์ `games/`, `tools/`)
3. กด **Commit changes**

### ทางที่ 2: ใช้ git (เครื่องคุณมี git 2.51 แล้ว)
```bash
cd D:\xeno\kistrox-hub
git init
git add .
git commit -m "KISTROX HUB: loader + anime dice"
git branch -M main
git remote add origin https://github.com/<USER>/kistrox-hub.git
git push -u origin main
```
(ตอน push ต้องล็อกอิน GitHub — ใช้ Personal Access Token เป็นรหัสผ่าน หรือให้ Git Credential Manager เด้งหน้าต่างล็อกอิน)

### หลังอัปโหลด: แก้ BaseURL
เปิด `main.lua` บน GitHub → กดดินสอ (Edit) → แก้บรรทัดนี้ให้เป็นชื่อบัญชีคุณ แล้ว Commit
```lua
BaseURL = "https://raw.githubusercontent.com/<USER>/kistrox-hub/main/",
```

### ลิงก์บรรทัดเดียวสำหรับแจก
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<USER>/kistrox-hub/main/main.lua"))()
```

---

## วิธีเพิ่มเกมใหม่

1. เข้าเกมนั้น แล้วรัน `tools/whereami.lua` → จะได้ **PlaceId / GameId / ชื่อเกม**
2. เอาสคริปต์ของเกมนั้นไปวางเป็น `games/<ชื่อเกม>.lua` (ดูโครงจาก `games/_template.lua`)
3. เพิ่มรายการในตาราง `GAMES` ของ `main.lua`:
```lua
{
    label = "ชื่อเกม",
    match = { placeId = 123456789 },   -- แม่นสุด (หรือใช้ name = "คำในชื่อเกม")
    file  = "games/ชื่อเกม.lua",
},
```

---

## หมายเหตุ

- **ไฟล์ใน repo เป็นสาธารณะ** ใครมีลิงก์ก็โหลดได้ ถ้าต้องการให้คนผ่านโฆษณาก่อน ให้แชร์ **ลิงก์ที่ผ่านบริการ ad-gate** (Linkvertise / Lootlabs / Work.ink) ซึ่งพาไปหน้าเว็บที่มีบรรทัด loadstring อยู่ — แต่ตัว raw ของ main.lua เองยังต้องเปิด public จึงกันได้แค่ระดับ "คนทั่วไปไม่รู้ลิงก์ตรง"
- ถ้าสคริปต์ใดดัดแปลงมาจากของคนอื่น **ควรใส่เครดิตเจ้าของเดิม** (เช่นสคริปต์ Anime Dice ต้นทางคือ Zeohub)
- การใช้/แจกจ่ายสคริปต์ประเภทนี้ผิดข้อกำหนดการใช้งานของ Roblox และเสี่ยงต่อบัญชีผู้ใช้
