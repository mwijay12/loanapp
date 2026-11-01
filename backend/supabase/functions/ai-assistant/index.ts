// The assistant's online half.
//
// The Flutter bundle is public: anything compiled into it can be read out of
// the browser in a minute, so an LLM key cannot live there. This function holds
// the key in Supabase secrets, checks that the caller is a signed-in member of
// the shop, and forwards only what the prompt needs.
//
// Deploy:
//   supabase secrets set MERCURY_API_KEY=sk_...
//   supabase functions deploy ai-assistant --no-verify-jwt=false
//
// Without the secret the function answers 503 and the app falls back to its
// offline engine, which reads the shop's own rows.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const ENDPOINT = 'https://api.inceptionlabs.ai/v1/chat/completions';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** Money the way the shop writes it: TZS 4,250,000. */
function money(n: unknown): string {
  const v = typeof n === 'number' && Number.isFinite(n) ? Math.round(n) : 0;
  return `TZS ${v.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')}`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const key = Deno.env.get('MERCURY_API_KEY') ?? '';
  if (!key) {
    // A clear 503 rather than a 500: the app treats it as "no online model" and
    // answers from the ledger instead of showing an error to the cashier.
    return json({ error: 'model_not_configured' }, 503);
  }

  // Signed-in staff only. The anon key is embedded in the bundle, so an
  // unauthenticated call would be an open door to the shop's spend.
  const auth = req.headers.get('Authorization') ?? '';
  if (!auth.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401);

  const supa = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: auth } } },
  );
  const { data: userData, error: userError } = await supa.auth.getUser();
  if (userError || !userData?.user) return json({ error: 'unauthorized' }, 401);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const prompt = typeof body?.prompt === 'string' ? body.prompt.slice(0, 2000) : '';
  if (!prompt.trim()) return json({ error: 'prompt required' }, 400);

  const facts = body?.facts ?? null;
  const history = Array.isArray(body?.history) ? body.history.slice(-8) : [];

  // The figures are laid out here rather than trusted from the client, so a
  // caller cannot slip instructions in through the context block.
  const context = facts
    ? [
        `Branch: ${String(facts.branch ?? '—')}`,
        `Today: ${Number(facts.salesCount) || 0} transactions, ` +
          `${money(facts.salesTotal)} total, ${money(facts.cashTotal)} cash, ` +
          `${money(facts.creditTotal)} credit, ${money(facts.collectedToday)} collected`,
        `Stock: ${Number(facts.stockUnits) || 0} units across ` +
          `${Number(facts.modelCount) || 0} models`,
        `Loans: ${Number(facts.loansActive) || 0} active, ` +
          `${Number(facts.loansOverdue) || 0} overdue, ` +
          `${money(facts.overdueOutstanding)} outstanding`,
        `Data source: ${String(facts.scope ?? 'unknown')}`,
      ].join('\n')
    : 'No shop data is loaded.';

  const lowStock: Record<string, unknown> = facts?.lowStock ?? {};
  const lowLines = Object.entries(lowStock)
    .slice(0, 10)
    .map(([model, left]) => `- ${model}: ${left} left`)
    .join('\n');

  const system = `You answer questions about one phone shop in Tanzania, from the figures below and nothing else.

${context}
${lowLines ? `\nModels below their buffer:\n${lowLines}` : ''}

Rules:
- Use only the figures above. If a number is not listed, say it is not available. Never estimate, forecast, or fill a gap with an example.
- No sales targets, growth rates, or staff attendance: this system does not record them.
- If the data source is demo, say once that these are demo figures.
- Answer in the language of the question (English or Kiswahili).
- Plain text with short bullets, no markdown symbols.`;

  const messages = [
    { role: 'system', content: system },
    ...history
      .filter((m: any) => m && (m.role === 'user' || m.role === 'assistant'))
      .map((m: any) => ({ role: m.role, content: String(m.content ?? '').slice(0, 2000) })),
    { role: 'user', content: prompt },
  ];

  try {
    const upstream = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'mercury-2.5', reasoning_effort: 'low', messages }),
    });

    if (!upstream.ok) {
      return json({ error: 'upstream', status: upstream.status }, 502);
    }

    const data = await upstream.json();
    const answer = data?.choices?.[0]?.message?.content;
    if (typeof answer !== 'string' || !answer.trim()) {
      return json({ error: 'empty answer' }, 502);
    }
    return json({ answer: answer.trim(), model: data?.model ?? 'mercury-2.5' });
  } catch (_e) {
    return json({ error: 'upstream unreachable' }, 502);
  }
});
