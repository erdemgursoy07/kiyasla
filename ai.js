// Bu dosya sunucuda çalışır. Gemini API anahtarın burada gizli kalır, uygulamayı kullananlar göremez.
// Cloudflare ayarlarında GEMINI_API_KEY adında bir gizli değişken tanımlaman gerekir.
// İstersen GEMINI_MODEL değişkeniyle model adını değiştirebilirsin.

const VARSAYILAN_MODEL = 'gemini-2.5-flash';
const MAKS_UZUNLUK = 60000;

function cevap(veri, durum = 200) {
  return new Response(JSON.stringify(veri), {
    status: durum,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }
  });
}

export async function onRequestPost({ request, env }) {
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

export function onRequest() {
  return cevap({ error: 'invalid_request' }, 405);
}
