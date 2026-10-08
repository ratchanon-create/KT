//=====================================================================
//  KISTROX KEY WORKER  (Cloudflare Worker — ฟรี)
//
//  หน้าที่:
//    GET /getkey?uid=<hwid>   -> หน้าเว็บให้ผู้ใช้: กดเปิดโฆษณา -> รอ 30 วิ -> คีย์โผล่ให้คัดลอก
//    GET /adstart?uid=<hwid>  -> บันทึกเวลาที่เริ่มดูโฆษณา
//    GET /issue?uid=<hwid>    -> ออกคีย์ (ถ้าครบ 30 วิแล้ว)
//    GET /status?uid=<hwid>   -> เช็คว่ารอครบหรือยัง (ไว้กู้สถานะตอนรีเฟรชหน้า)
//    GET /checkkey?key=&hwid= -> ให้สคริปต์ในเกมตรวจคีย์
//    GET /script?key=&hwid=&name=  -> แจกโค้ดสคริปต์ "ต้องมีคีย์จริงเท่านั้น" (คนไม่มีคีย์ดูดโค้ดไม่ได้)
//    POST /admin/putscript?name=&token= -> อัปโหลดโค้ดสคริปต์เข้า KV (ใช้ตอนเราแก้สคริปต์เอง)
//
//  ตั้งค่า (Settings -> Variables and Secrets):
//    AD_URL       = https://uplcm.com/4/11984132
//    WAIT_SECONDS = 30
//    EXP_HOURS    = 12
//    ADMIN_KEY    = รหัสลับของเราเอง (Secret) ใช้ตอนอัปโหลดสคริปต์ — ห้ามให้ใครรู้
//  และผูก KV namespace ไว้ที่ตัวแปรชื่อ KEYS (จำเป็น)
//
//  วิธีเก็บโค้ดสคริปต์: KV key = script:<name>  เช่น script:anime-dice
//  (ใช้ tools/upload-script.bat อัปโหลดได้ ไม่ต้องก๊อปวางใน dashboard)
//=====================================================================

const CORS = { "Access-Control-Allow-Origin": "*", "Content-Type": "application/json" };

function makeKey() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const part = (n) => Array.from({ length: n }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
  return `KISTROX-${part(5)}-${part(5)}-${part(5)}`;
}

// ตรวจคีย์กลาง: ใช้ทั้ง /checkkey และ /script
async function checkKey(KV, key, hwid) {
  if (!key) return { ok: false, reason: "ไม่ได้ส่งคีย์มา" };
  const data = await KV.get("key:" + key);
  if (!data) return { ok: false, reason: "ไม่พบคีย์นี้" };
  let rec = {};
  try { rec = JSON.parse(data); } catch (e) {}
  if (rec.exp && Date.now() > rec.exp) {
    await KV.delete("key:" + key);
    return { ok: false, reason: "คีย์หมดอายุ" };
  }
  if (rec.hwid && hwid && rec.hwid !== hwid) return { ok: false, reason: "คีย์นี้ผูกกับเครื่องอื่น" };
  const hours = ((rec.exp || 0) - Date.now()) / 3600000;
  return { ok: true, hours: Number(hours.toFixed(2)) };
}

// ชื่อสคริปต์: กัน path แปลกปลอม
function safeName(v) {
  return (v || "anime-dice").trim().replace(/[^a-zA-Z0-9._-]/g, "").slice(0, 64) || "anime-dice";
}

function page(uid, adUrl, waitSec, expHours) {
  return `<!doctype html><html lang="th"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>KISTROX HUB — รับคีย์</title>
<style>
 :root{--accent:#22d3ee;--bg:#0b0e12;--card:#14181f;--line:#1e2530;--text:#e6eef5;--sub:#8ea3b5}
 *{box-sizing:border-box}
 body{margin:0;min-height:100vh;background:var(--bg);color:var(--text);
      font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
      display:flex;align-items:center;justify-content:center;padding:18px}
 .card{background:var(--card);border:1px solid #22d3ee55;border-radius:18px;
       padding:26px;max-width:560px;width:100%;box-shadow:0 12px 40px #0006}
 .brand{display:flex;align-items:center;gap:10px;margin-bottom:12px}
 .dot{width:10px;height:10px;border-radius:50%;background:var(--accent);box-shadow:0 0 12px var(--accent)}
 h1{font-size:19px;margin:0}
 p{color:var(--sub);font-size:14px;line-height:1.6;margin:8px 0}
 .box{background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:16px;text-align:center;
      font-family:ui-monospace,Consolas,monospace;font-size:19px;letter-spacing:1.5px;word-break:break-all;margin:16px 0}
 button{width:100%;border:0;border-radius:11px;padding:14px;font-size:15px;font-weight:700;cursor:pointer;transition:.15s}
 .primary{background:var(--accent);color:#0a141a}
 .primary:hover{filter:brightness(1.08)}
 .ghost{background:#1a1f27;color:var(--text);border:1px solid var(--line)}
 .timer{font-size:34px;font-weight:800;color:var(--accent);text-align:center;margin:18px 0 6px;
        font-variant-numeric:tabular-nums}
 .steps{margin-top:14px;border-top:1px solid var(--line);padding-top:12px}
 b{color:var(--text);font-weight:600}
 code{background:#0b0e12;border:1px solid var(--line);border-radius:6px;padding:2px 6px;font-size:12px}
 .warn{color:#ffb86b;font-size:12.5px}
 .hide{display:none}
</style></head><body>
<div class="card">
  <div class="brand"><span class="dot"></span><h1>KISTROX HUB</h1></div>

  <div id="step1">
    <p><b>ขั้นที่ 1:</b> กดปุ่มด้านล่างเพื่อเปิดโฆษณา (จะเปิดแท็บใหม่)</p>
    <button class="primary" id="adBtn">เปิดโฆษณา / ดูโฆษณา</button>
    <div class="steps"><p class="warn">ต้องดูโฆษณาให้ครบก่อน จึงจะได้คีย์ (ระบบจะนับเวลา ${waitSec} วินาที)</p></div>
  </div>

  <div id="step2" class="hide">
    <p><b>ขั้นที่ 2:</b> กำลังนับเวลา — กรุณาอย่าปิดหน้านี้</p>
    <div class="timer" id="timer">${waitSec}</div>
    <p id="hint" class="warn">รอให้ครบค่อยกดรับคีย์</p>
  </div>

  <div id="step3" class="hide">
    <p>ได้คีย์แล้ว ✅ คัดลอกไปวางในหน้าต่าง KISTROX HUB ในเกม</p>
    <div class="box" id="key">…</div>
    <button class="primary" id="copy">คัดลอกคีย์</button>
    <div class="steps">
      <p><b>วิธีใช้:</b> คัดลอกคีย์ → เข้าเกม → วางในช่อง <code>วางคีย์ที่นี่</code> → กด <b>ยืนยันคีย์ + รันสคริปต์</b></p>
      <p class="warn" id="note"></p>
    </div>
  </div>
</div>

<script>
  const UID = ${JSON.stringify(uid)};
  const AD  = ${JSON.stringify(adUrl)};
  const WAIT = ${waitSec};
  const $ = (id) => document.getElementById(id);
  const show = (n) => { ["step1","step2","step3"].forEach((s,i)=> $(s).classList.toggle("hide", i !== n-1)); };

  let tick = null;
  function startCountdown(left) {
    show(2);
    let t = left;
    $("timer").textContent = t;
    clearInterval(tick);
    tick = setInterval(() => {
      t -= 1;
      $("timer").textContent = Math.max(0, t);
      if (t <= 0) { clearInterval(tick); $("hint").textContent = "ครบเวลาแล้ว กำลังออกคีย์..."; issue(); }
    }, 1000);
  }

  async function issue() {
    try {
      const r = await fetch("./issue?uid=" + encodeURIComponent(UID));
      const j = await r.json();
      if (j.ok && j.key) {
        $("key").textContent = j.key;
        $("note").textContent = "คีย์นี้ผูกกับเครื่องของคุณ — หมดอายุใน " + j.expires_in_hours + " ชั่วโมง";
        show(3);
      } else if (j.wait) {
        startCountdown(j.wait);
      } else {
        $("hint").textContent = "เกิดข้อผิดพลาด: " + (j.error || "ไม่ทราบสาเหตุ");
        show(2);
      }
    } catch (e) {
      $("hint").textContent = "เชื่อมต่อไม่ได้: " + e;
    }
  }

  $("adBtn").addEventListener("click", async () => {
    window.open(AD, "_blank");                   // เปิดโฆษณาแท็บใหม่
    try { await fetch("./adstart?uid=" + encodeURIComponent(UID)); } catch (e) {}
    startCountdown(WAIT);
  });

  $("copy").addEventListener("click", async (e) => {
    const t = $("key").textContent;
    try { await navigator.clipboard.writeText(t); }
    catch (err) {
      const r = document.createRange(); r.selectNodeContents($("key"));
      const s = getSelection(); s.removeAllRanges(); s.addRange(r); document.execCommand("copy");
    }
    e.target.textContent = "คัดลอกแล้ว ✓";
    setTimeout(() => e.target.textContent = "คัดลอกคีย์", 1800);
  });

  // กู้สถานะ: ถ้าเคยเริ่มดูโฆษณาแล้ว ให้ไปต่อจากจุดนั้น
  (async () => {
    try {
      const r = await fetch("./status?uid=" + encodeURIComponent(UID));
      const j = await r.json();
      if (j.key) { $("key").textContent = j.key; $("note").textContent = "คีย์เดิมของคุณ (ยังไม่หมดอายุ)"; show(3); }
      else if (j.wait > 0) { startCountdown(j.wait); }
      else if (j.started) { issue(); }
    } catch (e) {}
  })();
</script>
</body></html>`;
}

export default {
  async fetch(request, env) {
    // ---- รองรับทั้ง binding ชื่อ KEYS และ KV (ไม่ต้องแก้โค้ด) ----
    const KV = env.KEYS || env.KV;
    if (!KV) {
      return new Response("ยังไม่ได้ผูก KV namespace (ตั้ง Variable name เป็น KEYS หรือ KV)", {
        status: 500,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";
    const AD = env.AD_URL || "https://uplcm.com/4/11984132";
    const WAIT = parseInt(env.WAIT_SECONDS || "30", 10);
    const EXP_HOURS = parseFloat(env.EXP_HOURS || "12");

    // ---------- หน้าเว็บรับคีย์ ----------
    if (path === "/getkey") {
      const uid = url.searchParams.get("uid") || "";
      if (!uid) return new Response("ต้องระบุ uid", { status: 400 });
      return new Response(page(uid, AD, WAIT, EXP_HOURS), { headers: { "Content-Type": "text/html; charset=utf-8" } });
    }

    // ---------- เริ่มดูโฆษณา ----------
    if (path === "/adstart") {
      const uid = url.searchParams.get("uid") || "";
      if (!uid) return new Response(JSON.stringify({ ok: false, error: "no uid" }), { status: 400, headers: CORS });
      await KV.put("ad:" + uid, String(Date.now()), { expirationTtl: 3600 });
      return new Response(JSON.stringify({ ok: true }), { headers: CORS });
    }

    // ---------- เช็คสถานะ (ไว้กู้ตอนรีเฟรช) ----------
    if (path === "/status") {
      const uid = url.searchParams.get("uid") || "";
      const started = await KV.get("ad:" + uid);
      const key = await KV.get("hwid:" + uid);
      let wait = 0;
      if (started) {
        const left = Math.ceil((parseInt(started, 10) + WAIT * 1000 - Date.now()) / 1000);
        wait = Math.max(0, left);
      }
      let keyOk = false;
      if (key) {
        const rec = await KV.get("key:" + key);
        if (rec) { const d = JSON.parse(rec); keyOk = d.exp && Date.now() < d.exp; }
      }
      return new Response(JSON.stringify({ started: !!started, wait, key: keyOk ? key : null }), { headers: CORS });
    }

    // ---------- ออกคีย์ (ต้องครบเวลา) ----------
    if (path === "/issue") {
      const uid = url.searchParams.get("uid") || "";
      if (!uid) return new Response(JSON.stringify({ ok: false, error: "no uid" }), { status: 400, headers: CORS });
      const started = await KV.get("ad:" + uid);
      if (!started) return new Response(JSON.stringify({ ok: false, error: "ยังไม่ได้กดดูโฆษณา" }), { headers: CORS });
      const left = Math.ceil((parseInt(started, 10) + WAIT * 1000 - Date.now()) / 1000);
      if (left > 0) return new Response(JSON.stringify({ ok: false, wait: left }), { headers: CORS });

      const key = makeKey();
      const exp = Date.now() + EXP_HOURS * 3600 * 1000;
      await KV.put("key:" + key, JSON.stringify({ hwid: uid, exp }));
      await KV.put("hwid:" + uid, key);
      return new Response(JSON.stringify({ ok: true, key, expires_in_hours: EXP_HOURS }), { headers: CORS });
    }

    // ---------- ให้สคริปต์ในเกมตรวจคีย์ ----------
    if (path === "/checkkey") {
      const key = (url.searchParams.get("key") || "").trim();
      const hwid = (url.searchParams.get("hwid") || "").trim();
      const res = await checkKey(KV, key, hwid);
      if (!res.ok) return new Response(JSON.stringify({ valid: false, reason: res.reason }), { headers: CORS });
      return new Response(JSON.stringify({ valid: true, expires_in_hours: res.hours }), { headers: CORS });
    }

    // ---------- แจกโค้ดสคริปต์ (ต้องมีคีย์จริง + เครื่องตรงเท่านั้น) ----------
    if (path === "/script") {
      const key = (url.searchParams.get("key") || "").trim();
      const hwid = (url.searchParams.get("hwid") || "").trim();
      const name = safeName(url.searchParams.get("name"));
      if (!hwid) {
        return new Response(JSON.stringify({ ok: false, reason: "ต้องระบุ hwid" }), { status: 403, headers: CORS });
      }
      const res = await checkKey(KV, key, hwid);
      if (!res.ok) {
        // ยังไม่ผ่านด่าน: ไม่แตะ KV ของสคริปต์เลย (คนไม่มีคีย์จะไม่รู้ว่ามีสคริปต์ชื่ออะไรอยู่)
        return new Response(JSON.stringify({ ok: false, reason: res.reason }), { status: 403, headers: CORS });
      }
      const code = await KV.get("script:" + name);
      if (!code) {
        return new Response(JSON.stringify({ ok: false, reason: "ไม่พบสคริปต์นี้บนเซิร์ฟเวอร์ (ยังไม่ได้อัปโหลด)" }),
          { status: 404, headers: CORS });
      }
      return new Response(code, {
        headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
      });
    }

    // ---------- อัปโหลดโค้ดสคริปต์เข้า KV (ใช้ตอนเราแก้สคริปต์) ----------
    if (path === "/admin/putscript") {
      const admin = env.ADMIN_KEY || "";
      const token = url.searchParams.get("token") || "";
      if (!admin || token !== admin) {
        return new Response(JSON.stringify({ ok: false, reason: "ไม่มีสิทธิ์" }), { status: 403, headers: CORS });
      }
      if (request.method !== "POST") {
        return new Response(JSON.stringify({ ok: false, reason: "ต้องใช้ POST" }), { status: 405, headers: CORS });
      }
      const name = safeName(url.searchParams.get("name"));
      const body = await request.text();
      if (!body || body.length < 100) {
        return new Response(JSON.stringify({ ok: false, reason: "เนื้อหาว่างหรือสั้นเกินไป" }), { status: 400, headers: CORS });
      }
      if (body.length > 4 * 1024 * 1024) {
        return new Response(JSON.stringify({ ok: false, reason: "ไฟล์ใหญ่เกิน 4MB" }), { status: 413, headers: CORS });
      }
      await KV.put("script:" + name, body);
      const check = await KV.get("script:" + name);
      return new Response(JSON.stringify({ ok: true, name, sent: body.length, stored: (check || "").length }), { headers: CORS });
    }

    return new Response("KISTROX KEY WORKER — OK (ลอง /getkey?uid=test)", { headers: { "Content-Type": "text/plain; charset=utf-8" } });
  },
};
