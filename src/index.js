// Cloudflare Workers için sunucu kodu.
// /api/ai adresine gelen istekleri Gemini'ye iletir, diğer her şeyde uygulamanın dosyalarını gösterir.
// Gemini anahtarı Cloudflare ayarlarında GEMINI_API_KEY adıyla gizli değişken olarak durur.

const VARSAYILAN_MODEL = 'gemini-2.5-flash';
const MAKS_UZUNLUK = 60000;

function cevap(veri, durum = 200) {
  return new Response(JSON.stringify(veri), {
    status: durum,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }
  });
}

async function yapayZeka(request, env) {
  if (request.method !== 'POST') return cevap({ error: 'invalid_request' }, 405);
  if (!env.GEMINI_API_KEY) return cevap({ error: 'not_configured' }, 500);

  let govde;
  try { govde = await request.json(); } catch { return cevap({ error: 'invalid_request' }, 400); }
  const prompt = typeof govde.prompt === 'string' ? govde.prompt : '';
  if (!prompt || prompt.length > MAKS_UZUNLUK) return cevap({ error: 'invalid_request' }, 400);

  const model = env.GEMINI_MODEL || VARSAYILAN_MODEL;
  const generationConfig = { temperature: govde.json ? 0.2 : 0.7, maxOutputTokens: 4096 };
  if (govde.json) generationConfig.responseMimeType = 'application/json';

  let yanit;
  try {
    yanit = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
      body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }], generationConfig })
    });
  } catch {
    return cevap({ error: 'upstream_error' }, 502);
  }
  if (yanit.status === 429) return cevap({ error: 'rate_limited' }, 429);
  if (!yanit.ok) return cevap({ error: 'upstream_error' }, 502);

  const veri = await yanit.json();
  const aday = veri.candidates && veri.candidates[0];
  if (!aday || aday.finishReason === 'SAFETY') return cevap({ error: 'refused' }, 422);
  const metin = ((aday.content && aday.content.parts) || []).map(p => p.text || '').join('');
  if (!metin) return cevap({ error: 'empty_completion' }, 502);
  return cevap({ text: metin });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/api/ai') return yapayZeka(request, env);
    return env.ASSETS.fetch(request);
  }
};
