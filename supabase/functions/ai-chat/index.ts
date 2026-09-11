const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });

type ChatMessage = { role: "user" | "assistant"; content: string };

function validHistory(value: unknown): ChatMessage[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is ChatMessage => {
      if (!item || typeof item !== "object") return false;
      const message = item as Record<string, unknown>;
      return (
        (message.role === "user" || message.role === "assistant") &&
        typeof message.content === "string" &&
        message.content.trim().length > 0
      );
    })
    .slice(-6)
    .map((item) => ({ role: item.role, content: item.content.trim().slice(0, 1200) }));
}

function extractReply(payload: Record<string, unknown>): string | null {
  if (typeof payload.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text.trim();
  }
  if (!Array.isArray(payload.output)) return null;
  const parts: string[] = [];
  for (const item of payload.output) {
    if (!item || typeof item !== "object") continue;
    const content = (item as Record<string, unknown>).content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (!part || typeof part !== "object") continue;
      const text = (part as Record<string, unknown>).text;
      if (typeof text === "string") parts.push(text);
    }
  }
  return parts.join("\n").trim() || null;
}

function safeContext(value: unknown, maxLength: number): string | null {
  if (!value || typeof value !== "object") return null;
  try {
    return JSON.stringify(value).slice(0, maxLength);
  } catch {
    return null;
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Metodo no permitido." }, 405);

  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authorization = request.headers.get("Authorization");
  if (!openAiKey) return json({ error: "El asistente aun no ha sido activado." }, 503);
  if (!supabaseUrl || !supabaseAnonKey || !authorization) {
    return json({ error: "Debes iniciar sesion para usar el asistente." }, 401);
  }

  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: supabaseAnonKey },
  });
  if (!userResponse.ok) return json({ error: "Tu sesion vencio. Inicia sesion nuevamente." }, 401);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Solicitud invalida." }, 400);
  }
  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) return json({ error: "Escribe un mensaje." }, 400);
  if (message.length > 1200) return json({ error: "El mensaje es demasiado largo." }, 400);

  const profile = safeContext(body.trainingProfile, 2000);
  const activeWorkout = safeContext(body.activeWorkout, 6000);
  const userContext = [
    profile ? `Evaluacion actual del usuario: ${profile}` : "El usuario aun no tiene una evaluacion guardada.",
    activeWorkout ? `Rutina activa actual: ${activeWorkout}` : "El usuario no tiene una rutina activa guardada.",
  ].join("\n");

  const input = [
    ...validHistory(body.history),
    { role: "user", content: message },
  ];
  const openAiResponse = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openAiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: Deno.env.get("OPENAI_MODEL") || "gpt-5-mini",
      instructions:
        `Eres el asistente de Fit Body Gym. Responde en espanol claro, breve y amable. Comprende literalmente la solicitud actual y usa el historial para mantener el contexto. Distingue una sesion solo para hoy de un plan semanal. Si el usuario pide una rutina, proponla completa, con ejercicios, series, repeticiones y descansos adecuados a su solicitud y evaluacion. No dejes frases, listas ni rutinas a medias. No digas que creaste, guardaste, modificaste o abriste algo: este chat solo puede proponer y explicar. Antes de reemplazar una rutina activa, muestra la propuesta y pide confirmacion. Si faltan datos indispensables, pregunta solo lo necesario. No diagnostiques ni reemplaces a profesionales de salud. Ante dolor fuerte, sintomas preocupantes, lesiones o emergencias, recomienda detener el ejercicio y consultar a un profesional. Limita la respuesta a 500 palabras.\n\n${userContext}`,
      input,
      reasoning: { effort: "low" },
      text: { verbosity: "low" },
      max_output_tokens: 1600,
      store: false,
    }),
  });

  const payload = (await openAiResponse.json()) as Record<string, unknown>;
  if (!openAiResponse.ok) {
    const error = payload.error as Record<string, unknown> | undefined;
    const code = typeof error?.code === "string" ? error.code : "openai_error";
    if (code === "insufficient_quota") {
      return json({ error: "El saldo del asistente esta agotado temporalmente." }, 503);
    }
    console.error("OpenAI error", openAiResponse.status, code);
    return json({ error: "El asistente no pudo responder. Intenta nuevamente." }, 502);
  }

  const reply = extractReply(payload);
  if (!reply) return json({ error: "El asistente devolvio una respuesta vacia." }, 502);
  return json({ reply });
});
