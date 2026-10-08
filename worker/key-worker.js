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
//    EXP_HOURS    = 8      (คีย์มีอายุ 8 ชั่วโมง)
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
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>KISTROX HUB — Get Key</title>
<style>
 :root{--accent:#22d3ee;--bg:#0b0e12;--card:#14181f;--line:#1e2530;--text:#e6eef5;--sub:#8ea3b5}
 *{box-sizing:border-box}
 body{margin:0;min-height:100vh;background:var(--bg);color:var(--text);
      font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
      display:flex;align-items:center;justify-content:center;padding:18px}
 .card{position:relative;background:var(--card);border:1px solid #22d3ee55;border-radius:18px;
       padding:26px;max-width:560px;width:100%;box-shadow:0 12px 40px #0006}
 .lang{position:absolute;top:14px;right:14px;display:flex;gap:6px}
 .lang button{border:1px solid var(--line);background:#1a1f27;color:var(--sub);
       border-radius:8px;padding:4px 10px;font-size:12px;font-weight:700;cursor:pointer}
 .lang button.on{background:var(--accent);color:#0a141a;border-color:var(--accent)}
 .brand{display:flex;align-items:center;gap:10px;margin-bottom:12px;padding-right:96px}
 .dot{width:10px;height:10px;border-radius:50%;background:var(--accent);box-shadow:0 0 12px var(--accent)}
 h1{font-size:19px;margin:0}
 p{color:var(--sub);font-size:14px;line-height:1.6;margin:8px 0}
 .box{background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:16px;text-align:center;
      font-family:ui-monospace,Consolas,monospace;font-size:19px;letter-spacing:1.5px;word-break:break-all;margin:16px 0}
 button{width:100%;border:0;border-radius:11px;padding:14px;font-size:15px;font-weight:700;cursor:pointer;transition:.15s}
 .primary{background:var(--accent);color:#0a141a}
 .primary:hover{filter:brightness(1.08)}
 .timer{font-size:34px;font-weight:800;color:var(--accent);text-align:center;margin:18px 0 6px;
        font-variant-numeric:tabular-nums}
 .steps{margin-top:14px;border-top:1px solid var(--line);padding-top:12px}
 b{color:var(--text);font-weight:600}
 code{background:#0b0e12;border:1px solid var(--line);border-radius:6px;padding:2px 6px;font-size:12px}
 .warn{color:#ffb86b;font-size:12.5px}
 .hide{display:none}
</style></head><body>
<div class="card">
  <div class="lang" id="lang">
    <button type="button" data-l="en">EN</button><button type="button" data-l="th">TH</button>
  </div>
  <div class="brand"><span class="dot"></span><h1>KISTROX HUB</h1></div>

  <div id="step1">
    <p id="t1"></p>
    <button class="primary" id="adBtn"></button>
    <div class="steps"><p class="warn" id="t2"></p></div>
  </div>

  <div id="step2" class="hide">
    <p id="t3"></p>
    <div class="timer" id="timer">${waitSec}</div>
    <p id="hint" class="warn"></p>
  </div>

  <div id="step3" class="hide">
    <p id="t4"></p>
    <div class="box" id="key">...</div>
    <button class="primary" id="copy"></button>
    <div class="steps"><p id="t5"></p></div>
  </div>
</div>

<script>
  const UID = ${JSON.stringify(uid)};
  const AD  = ${JSON.stringify(adUrl)};
  const WAIT = ${waitSec};

  const T = {
    en: {
      pageTitle: "KISTROX HUB — Get Key",
      t1: "<b>Step 1:</b> Click the button below to open the ad (it opens in a new tab)",
      adBtn: "Watch ad",
      t2: "You must watch the ad before you can get a key. The timer runs for {n} seconds.",
      t3: "<b>Step 2:</b> Counting down — please keep this page open",
      hint: "Wait until the timer reaches zero",
      issuing: "Time is up — issuing your key...",
      t4: "Key ready ✅ Copy it and paste it into the KISTROX HUB window in-game",
      copy: "Copy key",
      copied: "Copied ✓",
      t5: "<b>How to use:</b> copy the key → go in-game → paste it in the key box → press <b>Confirm key + Run script</b>",
      fail: "Something went wrong — please reload this page and try again.",
      conn: "Connection failed: "
    },
    th: {
      pageTitle: "KISTROX HUB — รับคีย์",
      t1: "<b>ขั้นที่ 1:</b> กดปุ่มด้านล่างเพื่อเปิดโฆษณา (จะเปิดแท็บใหม่)",
      adBtn: "เปิดโฆษณา / ดูโฆษณา",
      t2: "ต้องดูโฆษณาให้ครบก่อน จึงจะได้คีย์ (ระบบจะนับเวลา {n} วินาที)",
      t3: "<b>ขั้นที่ 2:</b> กำลังนับเวลา — กรุณาอย่าปิดหน้านี้",
      hint: "รอให้ครบค่อยกดรับคีย์",
      issuing: "ครบเวลาแล้ว กำลังออกคีย์...",
      t4: "ได้คีย์แล้ว ✅ คัดลอกไปวางในหน้าต่าง KISTROX HUB ในเกม",
      copy: "คัดลอกคีย์",
      copied: "คัดลอกแล้ว ✓",
      t5: "<b>วิธีใช้:</b> คัดลอกคีย์ → เข้าเกม → วางในช่องใส่คีย์ → กด <b>Confirm key + Run script</b>",
      fail: "เกิดข้อผิดพลาด — กรุณารีเฟรชหน้านี้แล้วลองใหม่",
      conn: "เชื่อมต่อไม่ได้: "
    }
  };

  const $ = (id) => document.getElementById(id);
  const show = (n) => { ["step1","step2","step3"].forEach((s,i)=> $(s).classList.toggle("hide", i !== n-1)); };
  const fill = (txt) => String(txt).split("{n}").join(String(WAIT));

  let LANG = "en";
  let copyState = "idle";

  function setLang(l) {
    if (!T[l]) l = "en";
    LANG = l;
    const t = T[l];
    for (const k of Object.keys(t)) {
      const el = $(k);
      if (el) el.innerHTML = fill(t[k]);
    }
    document.title = t.pageTitle;
    document.documentElement.lang = l;
    $("copy").textContent = (copyState === "done") ? t.copied : t.copy;
    for (const b of document.querySelectorAll("#lang button")) {
      b.classList.toggle("on", b.dataset.l === l);
    }
  }

  let tick = null;
  function startCountdown(left) {
    show(2);
    let t = left;
    $("timer").textContent = t;
    $("hint").textContent = T[LANG].hint;
    clearInterval(tick);
    tick = setInterval(() => {
      t -= 1;
      $("timer").textContent = Math.max(0, t);
      if (t <= 0) { clearInterval(tick); $("hint").textContent = T[LANG].issuing; issue(); }
    }, 1000);
  }

  async function issue() {
    try {
      const r = await fetch("./issue?uid=" + encodeURIComponent(UID));
      const j = await r.json();
      if (j.ok && j.key) {
        $("key").textContent = j.key;
        show(3);
      } else if (j.wait) {
        startCountdown(j.wait);
      } else {
        console.warn("issue failed:", j);
        $("hint").textContent = T[LANG].fail;
        show(2);
      }
    } catch (e) {
      $("hint").textContent = T[LANG].conn + e;
    }
  }

  $("adBtn").addEventListener("click", async () => {
    window.open(AD, "_blank");
    try { await fetch("./adstart?uid=" + encodeURIComponent(UID)); } catch (e) {}
    startCountdown(WAIT);
  });

  $("copy").addEventListener("click", async () => {
    const t = $("key").textContent;
    try { await navigator.clipboard.writeText(t); }
    catch (err) {
      const r = document.createRange(); r.selectNodeContents($("key"));
      const s = getSelection(); s.removeAllRanges(); s.addRange(r); document.execCommand("copy");
    }
    copyState = "done";
    $("copy").textContent = T[LANG].copied;
    setTimeout(() => { copyState = "idle"; $("copy").textContent = T[LANG].copy; }, 1800);
  });

  for (const b of document.querySelectorAll("#lang button")) {
    b.addEventListener("click", () => setLang(b.dataset.l));
  }

  // always start in English; use the EN / TH buttons to switch
  setLang("en");

  // resume: if the ad was already started or a key exists, continue from there
  (async () => {
    try {
      const r = await fetch("./status?uid=" + encodeURIComponent(UID));
      const j = await r.json();
      if (j.key) { $("key").textContent = j.key; show(3); }
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
    const EXP_HOURS = parseFloat(env.EXP_HOURS || "8");

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
