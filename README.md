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

## ระบบคีย์ (Cloudflare Worker) — ใช้อยู่จริง

หน้าเว็บขอคีย์ทำงานบน Cloudflare Worker ตัวเดียว ทำหน้าที่ **โฆษณา -> รอ 30 วิ -> ออกคีย์ -> ตรวจคีย์** ไม่ต้องมีเซิร์ฟเวอร์ของตัวเอง

**URL ที่ใช้**
| ส่วน | ค่า |
|---|---|
| ขอคีย์ (เปิดในเบราว์เซอร์) | `https://nirnim.ratchanon439990.workers.dev/getkey?uid=<HWID>` |
| ตรวจคีย์ (สคริปต์เรียกเอง) | `https://nirnim.ratchanon439990.workers.dev/checkkey?key=<คีย์>&hwid=<HWID>` |

**endpoint ทั้งหมด**
| path | ทำอะไร |
|---|---|
| `GET /` | หน้าเช็คว่า Worker ยังทำงาน |
| `GET /getkey?uid=` | หน้าเว็บผู้ใช้: ปุ่มเปิดโฆษณา -> นับถอยหลัง -> โชว์คีย์ + ปุ่มคัดลอก |
| `GET /adstart?uid=` | บันทึกเวลาเริ่มดูโฆษณา (TTL 1 ชม.) |
| `GET /status?uid=` | ดูว่าเหลืออีกกี่วิ |
| `GET /issue?uid=` | ออกคีย์ (ถ้ายังไม่ครบ 30 วิ จะตอบ `{"ok":false,"wait":N}`) |
| `GET /checkkey?key=&hwid=` | ตรวจว่าคีย์จริง/ไม่หมดอายุ/ผูกกับเครื่องนี้ |

**ค่าที่ตั้งใน Cloudflare (Settings ของ Worker)**
| ชื่อ | ชนิด | ค่า |
|---|---|---|
| `AD_URL` | Variable | `https://uplcm.com/4/11984132` |
| `WAIT_SECONDS` | Variable | `30` |
| `EXP_HOURS` | Variable | `8` (อายุคีย์ 8 ชั่วโมง) |
| `KEYS` | **KV Namespace binding** | ชื่อ binding ต้องเป็น `KEYS` (เก็บคีย์ + เวลาที่เริ่มดูโฆษณา) |

**ถ้าจะแก้โค้ด Worker**: แก้ `worker/key-worker.js` แล้วเอาไปวางทับในหน้า Edit code ของ Cloudflare (ต้อง redeploy)

**ฝั่งสคริปต์** ตั้งใน `main.lua` -> `CFG`:
```lua
KeyGetAPI = "https://nirnim.ratchanon439990.workers.dev/getkey",
KeyAPI    = "https://nirnim.ratchanon439990.workers.dev/checkkey",
ScriptAPI = "https://nirnim.ratchanon439990.workers.dev/script",
KeyGetMode = "url",        -- ปุ่มในเกมจะเปิด <KeyGetAPI>?uid=<HWID> ให้เอง
LocalKeyMode = false,      -- false = ต้องผ่าน Worker จริง (กันบายพาส)
KeyLifetimeHours = 0,      -- 0 = ให้ Worker คุมอายุ (8 ชม.)
AutoLogin = true,          -- จำคีย์ไว้ ครั้งต่อไปรันแล้วคีย์ยังไม่หมดอายุ = เข้าให้เลย
KeyFile   = "kistrox_key.txt",   -- ไฟล์ที่เก็บคีย์ที่จำไว้ (อยู่ในเครื่องผู้ใช้)
```

ลำดับการใช้งานของผู้เล่น: กด **Copy link getkey** -> เบราว์เซอร์เปิดหน้า Worker -> ดูโฆษณา 30 วิ -> กดคัดลอกคีย์ -> เอามาวางในช่องในเกม -> กด **ยืนยันคีย์ + รันสคริปต์**

---

## กันคนอื่นดูดสคริปต์ (โค้ดไม่ขึ้น GitHub)

ปกติถ้าเอา `games/<เกม>.lua` ขึ้น GitHub สาธารณะ ใครอ่าน `main.lua` ก็รู้ path แล้วโหลดโค้ดตรง ๆ ข้ามโฆษณาไปเลย
วิธีที่ใช้อยู่: **โค้ดสคริปต์เก็บใน Cloudflare KV ไม่ขึ้นเว็บ** และดึงผ่าน `/script` ที่ต้องมีคีย์จริง + เครื่องตรงเท่านั้น

**หลักการ**
| ของ | อยู่ที่ไหน | ใครเห็น |
|---|---|---|
| `main.lua` (ตัวโหลด UI) | GitHub สาธารณะ | ทุกคน (ไม่เป็นไร ไม่มีโค้ดเกม) |
| `games/<เกม>.lua` (โค้ดจริง) | Cloudflare KV (`script:<ชื่อ>`) | เฉพาะคนมีคีย์ + เครื่องเดิม |
| คีย์ | Cloudflare KV (`key:<คีย์>`) | ออกให้หลังดูโฆษณาครบ 30 วิ |

ใน `main.lua` ตั้งที่รายการใน `GAMES`:
```lua
{
    label = "Anime Dice",
    match = { placeId = 113290951185459 },
    protected = true,            -- true = ดึงโค้ดผ่าน Worker (ห้ามขึ้น GitHub)
    script    = "anime-dice",    -- ชื่อใน KV: script:anime-dice
    file      = "games/anime-dice.lua",   -- ใช้เป็นที่แก้โค้ดในเครื่องเท่านั้น
},
```

**ขั้นตอน deploy (ทำตามลำดับ ห้ามสลับ)**
1. Cloudflare -> Worker -> Settings -> Variables and Secrets เพิ่ม **`ADMIN_KEY`** เป็นชนิด **Secret** ตั้งเป็นรหัสลับอะไรก็ได้ (เช่น `kistrox-9f3a71`) — เก็บไว้ใช้ตอนอัปโหลด ห้ามบอกใคร
2. เอาโค้ดใหม่จาก `worker/key-worker.js` ไปวางทับในหน้า Edit code แล้ว **Deploy**
3. อัปโหลดโค้ดสคริปต์เข้า KV — ดับเบิลคลิก `tools/upload-script.bat` แล้ววาง `ADMIN_KEY` (หรือใช้คำสั่งใน Git Bash):
```bash
curl -X POST "https://nirnim.ratchanon439990.workers.dev/admin/putscript?name=anime-dice&token=<ADMIN_KEY>"      --data-binary "@games/anime-dice.lua"
```
   เห็น `{"ok":true,...}` = สำเร็จ
4. ทดสอบ: เอาโค้ดในเกมรัน -> กด Copy link getkey -> วางคีย์ -> ต้องโหลดสคริปต์ได้
5. ค่อย push เรพ (ครั้งนี้ `games/anime-dice.lua` จะถูกลบออกจากเว็บ แต่ยังอยู่ในเครื่อง)

**แก้โค้ดสคริปต์ครั้งต่อไป**: แก้ `games/anime-dice.lua` ในเครื่อง -> รัน `tools/upload-script.bat` -> ไม่ต้อง push GitHub

**ข้อจำกัดที่ต้องรู้**
- คนที่มีคีย์อยู่แล้วดูดโค้ดไปเก็บได้ (เขาได้รับโค้ดไปรันอยู่ดี) — วิธีนี้กัน "คนที่ไม่มีคีย์" ไม่ได้กันคนที่มีคีย์แล้วเอาไปแจก
- โค้ดเก่ายังค้างใน **ประวัติ git** ของเรพ ถ้าจะลบให้หมดต้องเขียนประวัติใหม่ หรือสร้างเรพใหม่ (ดูหัวข้อถัดไป)
- `CFG.LocalKeys` (เช่น `TEST-1234`) ผ่านได้แค่ด่าน UI แต่ **ดึงโค้ดไม่ได้** เพราะไม่มีคีย์จริงใน KV

**ลบโค้ดออกจากประวัติ git (ถ้าต้องการจริงจัง)**
```bash
cd <โฟลเดอร์เรพ>
git checkout --orphan clean      # เริ่มประวัติใหม่จากไฟล์ปัจจุบัน
git add -A
git commit -m "KISTROX HUB loader (no game script)"
git branch -D main
git branch -m main
git push -f origin main
```

---

## Auto login (จำคีย์ไว้ใช้ครั้งต่อไป)

หลังผู้ใช้ใส่คีย์และรันสคริปต์สำเร็จ ระบบจะเก็บคีย์ไว้ที่ไฟล์ `kistrox_key.txt` ในเครื่องผู้ใช้
ครั้งต่อไปที่รันโหลดเดอร์ จะทำงานแบบนี้:

```
เปิดโหลดเดอร์
   └─ มีคีย์ที่จำไว้ไหม?
        ├─ ไม่มี            -> โชว์หน้าขอคีย์ปกติ (กด Copy link getkey)
        ├─ มี + ยังไม่หมดอายุ -> ตรวจกับ Worker แล้วรันสคริปต์ให้ทันที (ไม่ต้องดูโฆษณาซ้ำ)
        └─ มี + หมดอายุ/ใช้ไม่ได้ -> ล้างคีย์ทิ้ง แล้วโชว์หน้าขอคีย์ให้กด Copy link getkey ใหม่
```

จุดที่ต้องรู้
- ระบบจะ**จำคีย์เฉพาะหลังรันสคริปต์สำเร็จ**เท่านั้น (ถ้าคีย์ผิดจะไม่ถูกจำ)
- คีย์ผูกกับเครื่อง (HWID) ถ้าเอาไฟล์ `kistrox_key.txt` ไปวางเครื่องอื่นจะใช้ไม่ได้ — ระบบจะล้างทิ้งแล้วให้ขอคีย์ใหม่
- ปิดระบบนี้ได้โดยตั้ง `CFG.AutoLogin = false`
- อยากให้ผู้ใช้ล้างคีย์เอง: ลบไฟล์ `kistrox_key.txt` ในโฟลเดอร์ workspace ของ executor


---

## หมายเหตุ

- **ไฟล์ใน repo เป็นสาธารณะ** ใครมีลิงก์ก็โหลดได้ ถ้าต้องการให้คนผ่านโฆษณาก่อน ให้แชร์ **ลิงก์ที่ผ่านบริการ ad-gate** (Linkvertise / Lootlabs / Work.ink) ซึ่งพาไปหน้าเว็บที่มีบรรทัด loadstring อยู่ — แต่ตัว raw ของ main.lua เองยังต้องเปิด public จึงกันได้แค่ระดับ "คนทั่วไปไม่รู้ลิงก์ตรง"
- ถ้าสคริปต์ใดดัดแปลงมาจากของคนอื่น **ควรใส่เครดิตเจ้าของเดิม** (เช่นสคริปต์ Anime Dice ต้นทางคือ Zeohub)
- การใช้/แจกจ่ายสคริปต์ประเภทนี้ผิดข้อกำหนดการใช้งานของ Roblox และเสี่ยงต่อบัญชีผู้ใช้
