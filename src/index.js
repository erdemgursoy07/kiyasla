// Cloudflare Workers için sunucu kodu.
// /api/ai adresine gelen istekleri Gemini'ye iletir, diğer her şeyde uygulamanın dosyalarını gösterir.
// Cloudflare ayarlarındaki değişkenler:
//   GEMINI_API_KEY   (Secret, zorunlu)  Gemini anahtarı
//   GEMINI_MODEL     (isteğe bağlı)     belirli bir model
//   TURNSTILE_SITE   (isteğe bağlı)     Turnstile site anahtarı (herkese açık)
//   TURNSTILE_SECRET (Secret, isteğe bağlı) Turnstile gizli anahtarı; ikisi de varsa bot koruması açılır

const MODELLER = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-flash-lite-latest', 'gemini-2.0-flash'];
const TEKRAR_DENE = [404, 500, 503];
const MAKS_UZUNLUK = 60000;

// Kıyasla'nın kendi adresi her zaman izinli; ek olarak:
const EK_IZINLI = ['https://erdemgursoy07.github.io'];

// İstek sınırı: aynı internet adresinden dakikada en fazla 8, günde en fazla 120 istek
const DAKIKA_SINIRI = 8, GUN_SINIRI = 120;
const sayac = new Map();
function sinirAsildi(ip) {
  const simdi = Date.now();
  let k = sayac.get(ip);
  if (!k || simdi - k.gunBas > 86400000) k = { gunBas: simdi, gun: 0, dakika: [] };
  k.dakika = k.dakika.filter(x => simdi - x < 60000);
  if (k.dakika.length >= DAKIKA_SINIRI || k.gun >= GUN_SINIRI) { sayac.set(ip, k); return true; }
  k.dakika.push(simdi); k.gun++; sayac.set(ip, k);
  if (sayac.size > 5000) for (const [a, v] of sayac) if (simdi - v.gunBas > 86400000) sayac.delete(a);
  return false;
}

function izinliMi(request) {
  const origin = request.headers.get('Origin');
  if (!origin) return false;
  return origin === new URL(request.url).origin || EK_IZINLI.includes(origin);
}
function cors(request) {
  const origin = request && request.headers.get('Origin');
  if (!origin || !EK_IZINLI.includes(origin)) return {};
  return { 'Access-Control-Allow-Origin': origin, 'Access-Control-Allow-Methods': 'POST, GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Max-Age': '86400', 'Vary': 'Origin' };
}

let aktifIstek = null;
function cevap(veri, durum = 200) {
  return new Response(JSON.stringify(veri), {
    status: durum,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...cors(aktifIstek) }
  });
}

async function turnstileDogrula(env, token, ip) {
  if (!token || typeof token !== 'string') return false;
  const f = new FormData();
  f.append('secret', env.TURNSTILE_SECRET); f.append('response', token); if (ip) f.append('remoteip', ip);
  try {
    const r = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', { method: 'POST', body: f });
    const v = await r.json();
    return !!v.success;
  } catch { return false; }
}

async function geminiyeSor(model, anahtar, prompt, json, ara) {
  const generationConfig = { temperature: json || ara ? 0.2 : 0.7, maxOutputTokens: 4096 };
  const govde = { contents: [{ role: 'user', parts: [{ text: prompt }] }], generationConfig };
  // Google araması açıkken yapılandırılmış JSON çıktısı kullanılamıyor; JSON'u metinden ayıklıyoruz
  if (ara) govde.tools = [{ google_search: {} }];
  else if (json) generationConfig.responseMimeType = 'application/json';
  return fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': anahtar },
    body: JSON.stringify(govde)
  });
}

async function hataMetni(yanit) {
  try {
    const v = await yanit.json();
    return `Gemini ${yanit.status}: ${(v.error && v.error.message) || 'bilinmeyen hata'}`.slice(0, 300);
  } catch {
    return `Gemini ${yanit.status}`;
  }
}

async function yapayZeka(request, env) {
  const turnstileAcik = !!(env.TURNSTILE_SITE && env.TURNSTILE_SECRET);
  if (request.method === 'GET') {
    return cevap({ calisiyor: true, anahtar_var: !!env.GEMINI_API_KEY, model: env.GEMINI_MODEL || MODELLER[0], ts_site: turnstileAcik ? env.TURNSTILE_SITE : null });
  }
  if (request.method !== 'POST') return cevap({ error: 'invalid_request' }, 405);
  if (!izinliMi(request)) return cevap({ error: 'forbidden' }, 403);
  const ip = request.headers.get('CF-Connecting-IP') || 'bilinmiyor';
  if (sinirAsildi(ip)) return cevap({ error: 'too_many' }, 429);
  if (!env.GEMINI_API_KEY) return cevap({ error: 'not_configured' }, 500);

  let govde;
  try { govde = await request.json(); } catch { return cevap({ error: 'invalid_request' }, 400); }
  const prompt = typeof govde.prompt === 'string' ? govde.prompt : '';
  if (!prompt || prompt.length > MAKS_UZUNLUK) return cevap({ error: 'invalid_request' }, 400);
  if (turnstileAcik && !(await turnstileDogrula(env, govde.ts, ip))) return cevap({ error: 'bot_check' }, 403);

  const denenecek = env.GEMINI_MODEL ? [env.GEMINI_MODEL, ...MODELLER] : MODELLER;
  let yanit, sonHata = '', sonDurum = 0;
  for (const model of denenecek) {
    try {
      yanit = await geminiyeSor(model, env.GEMINI_API_KEY, prompt, !!govde.json, !!govde.ara);
    } catch (e) {
      return cevap({ error: 'upstream_error', detail: 'Gemini’ye bağlanılamadı' }, 502);
    }
    if (!TEKRAR_DENE.includes(yanit.status)) break;
    sonDurum = yanit.status;
    sonHata = await hataMetni(yanit);
    yanit = null;
  }
  if (!yanit) {
    if (sonDurum === 503 || sonDurum === 500) return cevap({ error: 'busy', detail: sonHata }, 503);
    return cevap({ error: 'upstream_error', detail: sonHata || 'Uygun model bulunamadı' }, 502);
  }
  if (yanit.status === 429) return cevap({ error: 'rate_limited', detail: await hataMetni(yanit) }, 429);
  if (!yanit.ok) return cevap({ error: 'upstream_error', detail: await hataMetni(yanit) }, 502);

  const veri = await yanit.json();
  const aday = veri.candidates && veri.candidates[0];
  if (!aday || aday.finishReason === 'SAFETY') return cevap({ error: 'refused' }, 422);
  const metin = ((aday.content && aday.content.parts) || []).filter(p => !p.thought).map(p => p.text || '').join('');
  if (!metin) return cevap({ error: 'empty_completion', detail: 'Gemini boş yanıt verdi' }, 502);
  // Google aramasında kullanılan kaynaklar
  const parcalar = (aday.groundingMetadata && aday.groundingMetadata.groundingChunks) || [];
  const kaynaklar = parcalar.map(c => c.web).filter(w => w && /^https:\/\//.test(w.uri || '')).slice(0, 8).map(w => ({ u: w.uri, t: String(w.title || '').slice(0, 120) }));
  return cevap({ text: metin, kaynaklar });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/api/ai') {
      aktifIstek = request;
      if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(request) });
      return yapayZeka(request, env);
    }
    return env.ASSETS.fetch(request);
  }
};
