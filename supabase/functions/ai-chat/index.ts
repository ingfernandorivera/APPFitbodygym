const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });

type ChatMessage = {
  role: "user" | "assistant" | "system";
  content: string;
};

type MemberProfile = {
  membership_active?: boolean | null;
  membership_end?: string | null;
};

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
    .slice(-8)
    .map((item) => ({
      role: item.role,
      content: item.content.trim().slice(0, 1200),
    }));
}

function extractReply(payload: Record<string, unknown>): string | null {
  // 1. output_text directo (OpenAI Responses API)
  if (typeof payload.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text.trim();
  }

  // 2. choices[0].message.content (OpenAI Chat Completions API estándar)
  if (Array.isArray(payload.choices) && payload.choices.length > 0) {
    const choice = payload.choices[0] as Record<string, unknown>;
    const msg = choice?.message as Record<string, unknown> | undefined;
    if (typeof msg?.content === "string" && msg.content.trim()) {
      return msg.content.trim();
    }
  }

  // 3. output array (OpenAI Responses API estructurado)
  if (Array.isArray(payload.output)) {
    const parts: string[] = [];
    for (const item of payload.output) {
      if (!item || typeof item !== "object") continue;
      const content = (item as Record<string, unknown>).content;
      if (!Array.isArray(content)) continue;

      for (const part of content) {
        if (!part || typeof part !== "object") continue;
        const text = (part as Record<string, unknown>).text;
        if (typeof text === "string" && text.trim()) {
          parts.push(text.trim());
        }
      }
    }
    if (parts.length > 0) {
      return parts.join("\n").trim();
    }
  }

  // 4. Campo reply o text directo
  if (typeof payload.reply === "string" && payload.reply.trim()) {
    return payload.reply.trim();
  }

  return null;
}

function todayInElSalvador(): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/El_Salvador",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());

  const year = parts.find((p) => p.type === "year")?.value;
  const month = parts.find((p) => p.type === "month")?.value;
  const day = parts.find((p) => p.type === "day")?.value;

  return `${year}-${month}-${day}`;
}

function hasActiveMembership(profile: MemberProfile): boolean {
  if (profile.membership_active !== true) {
    return false;
  }

  if (!profile.membership_end) {
    return false;
  }

  const membershipEnd = profile.membership_end.slice(0, 10);
  const today = todayInElSalvador();

  return membershipEnd >= today;
}

function formatWorkoutSummary(workout: unknown): string {
  if (!workout || typeof workout !== "object") {
    return "El usuario no tiene una rutina activa guardada actualmente.";
  }

  const w = workout as Record<string, unknown>;
  const name = w.name || "Rutina activa";
  const goal = w.goal || "General";
  const days = Array.isArray(w.days) ? w.days : [];

  let summary = `Nombre: ${name} | Objetivo: ${goal} | Total días: ${days.length}\n`;

  for (const day of days) {
    if (!day || typeof day !== "object") continue;
    const d = day as Record<string, unknown>;
    const dayNum = d.dayNumber ?? "";
    const title = d.title || `Día ${dayNum}`;
    const focus = d.focus ? `(${d.focus})` : "";
    const exercises = Array.isArray(d.exercises) ? d.exercises : [];
    const exerciseNames = exercises
      .map((e) => (typeof e === "object" && e ? (e as Record<string, unknown>).name || (e as Record<string, unknown>).id : null))
      .filter(Boolean)
      .slice(0, 6)
      .join(", ");

    summary += `- Día ${dayNum}: ${title} ${focus} -> Ejercicios: ${exerciseNames || "Sin ejercicios"}\n`;
  }

  return summary.trim();
}

Deno.serve(async (request) => {
  /*
   * CORS
   */
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (request.method !== "POST") {
    return json({ error: "Método no permitido." }, 405);
  }

  /*
   * VARIABLES SEGURAS
   */
  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authorization = request.headers.get("Authorization");

  if (!openAiKey) {
    return json(
      { error: "El asistente aún no ha sido activado." },
      503,
    );
  }

  if (!supabaseUrl || !supabaseAnonKey || !authorization) {
    return json(
      { error: "Debes iniciar sesión para usar el asistente." },
      401,
    );
  }

  /*
   * 1. VERIFICAR USUARIO AUTENTICADO
   */
  const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: supabaseAnonKey,
    },
  });

  if (!userResponse.ok) {
    return json(
      { error: "Tu sesión venció. Inicia sesión nuevamente." },
      401,
    );
  }

  const userData = (await userResponse.json()) as Record<string, unknown>;
  const userId = typeof userData.id === "string" ? userData.id : null;

  if (!userId) {
    return json(
      { error: "No fue posible identificar tu cuenta." },
      401,
    );
  }

  /*
   * 2. VERIFICAR MEMBRESÍA
   */
  const profileUrl = new URL(`${supabaseUrl}/rest/v1/member_profiles`);
  profileUrl.searchParams.set("select", "membership_active,membership_end");
  profileUrl.searchParams.set("auth_user_id", `eq.${userId}`);
  profileUrl.searchParams.set("limit", "1");

  const profileResponse = await fetch(profileUrl.toString(), {
    headers: {
      Authorization: authorization,
      apikey: supabaseAnonKey,
      Accept: "application/json",
    },
  });

  if (!profileResponse.ok) {
    console.error("Error verificando member_profiles:", profileResponse.status);
    return json(
      { error: "No fue posible verificar tu membresía. Intenta nuevamente." },
      503,
    );
  }

  const profiles = (await profileResponse.json()) as MemberProfile[];

  if (!Array.isArray(profiles) || profiles.length === 0) {
    return json(
      { error: "Tu cuenta todavía no está vinculada a un cliente de Fit Body Gym." },
      403,
    );
  }

  const memberProfile = profiles[0];

  if (!hasActiveMembership(memberProfile)) {
    return json(
      { error: "Necesitas una membresía activa para usar el asistente de Fit Body Gym." },
      403,
    );
  }

  /*
   * 3. LEER CUERPO DE LA SOLICITUD
   */
  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return json({ error: "Solicitud inválida." }, 400);
  }

  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) {
    return json({ error: "Escribe un mensaje." }, 400);
  }

  if (message.length > 1200) {
    return json({ error: "El mensaje es demasiado largo." }, 400);
  }

  // 4. Extraer perfil de entrenamiento y rutina activa enviados por la app
  const tp = (body.trainingProfile && typeof body.trainingProfile === "object")
    ? (body.trainingProfile as Record<string, unknown>)
    : null;

  const profileFacts = tp
    ? [
        `- Nombre: ${tp.fullName || tp.name || "Miembro FitBody"}`,
        `- Edad: ${tp.age || "No indicada"} años`,
        `- Peso: ${tp.weightKg || tp.weight || "No indicado"} kg`,
        `- Estatura: ${tp.heightCm || tp.height || "No indicada"} cm`,
        `- Género: ${tp.gender || "No indicado"}`,
        `- Objetivo principal: ${tp.goal || "Entrenamiento general"}`,
        `- Días disponibles por semana: ${tp.daysPerWeek || 4} días`,
        `- Tiempo disponible por sesión: ${tp.minutesPerSession || 60} minutos`,
        `- Nivel de experiencia: ${tp.experience || "Intermedio"}`,
        `- Lugar y equipo: ${tp.trainingLocation || "Gimnasio"} (${tp.equipment || "Gimnasio completo"})`,
        `- Limitaciones o lesiones: ${tp.limitations || "Ninguna registrada"}`,
        `- Músculos prioritarios: ${Array.isArray(tp.priorityMuscles) ? tp.priorityMuscles.join(", ") : (tp.priorityMuscles || "Equilibrado")}`,
      ].join("\n")
    : "Sin perfil previo guardado.";

  const activeWorkoutSummary = formatWorkoutSummary(body.activeWorkout);

  // 5. Historial de conversación
  const historyMessages = validHistory(body.history);

  // 6. Instrucciones maestras de Fit Body Gym
  const systemPrompt = `Eres el entrenador y coach principal de inteligencia artificial de Fit Body Gym.
Tu objetivo es guiar, asesorar y estructurar entrenamientos de la más alta calidad, con un tono motivador, profesional, técnico pero accesible, y 100% empático.

CONOCES PERFECTAMENTE EL PERFIL DEL USUARIO Y SU RUTINA ACTUAL:
[DATOS DEL PERFIL DEL USUARIO]
${profileFacts}

[RUTINA ACTIVA ACTUAL DEL USUARIO]
${activeWorkoutSummary}

REGLAS OBLIGATORIAS:
1. NUNCA PREGUNTES COSAS QUE YA SABES:
   - Ya conoces cuántos días entrena (${tp?.daysPerWeek ?? 4} días), su objetivo (${tp?.goal ?? "General"}), su equipo, su peso, su edad y sus lesiones.
   - NUNCA le preguntes "¿cuántos días entrenas?", "¿qué equipo tienes?", "¿cuál es tu meta?" o "¿cuál es tu rutina?". ¡YA TIENES ESOS DATOS!
2. SI EL USUARIO PREGUNTA POR SUS DATOS PERSONALES:
   - Si pregunta por su edad, peso, estatura, objetivo, limitaciones o cualquier dato de su perfil, respóndele detalladamente y con precisión usando los datos listados arriba.
3. LÓGICA BIOMECÁNICA DE DIVISIONES (MÚSCULO GRANDE + PEQUEÑO / SINERGIAS):
   - Si el usuario te pide trabajar "un músculo grande y uno pequeño" o dividir sus días:
     * EMPUJE (Push): Pecho (grande) + Tríceps (pequeño) o Hombro/Deltoides lateral (pequeño/mediano).
     * TIRÓN (Pull): Espalda (grande) + Bíceps (pequeño) y Deltoides posterior / Trapecio.
     * PIERNA / INFERIOR:
       - Opción A: Cuádriceps (grande) + Pantorrilla / Gemelos (pequeño) o Abdomen.
       - Opción B: Femorales/Isquiotibiales y Glúteos (grande) + Pantorrillas.
       - Opción C (Pierna completa): Cuádriceps + Femorales/Glúteo + Pantorrilla.
     * BRAZOS / CORE: Bíceps + Tríceps (antagonistas) o Hombros + Core.
     * PROHIBICIÓN ABSOLUTA: NUNCA sugieras combinaciones absurdas e inconexas como "Cuádriceps + Tríceps" o "Espalda + Cuádriceps". Respeta siempre la coherencia funcional del cuerpo humano.
4. CUANDO EL USUARIO SOLICITE CAMBIAR O ENFOCAR SU RUTINA:
   - Diseña de inmediato la distribución de los días (Día 1, Día 2, etc.) con sus ejercicios, series y repeticiones coherentes.
   - Respeta estrictamente sus días por semana (${tp?.daysPerWeek ?? 4} días) y duración por sesión (${tp?.minutesPerSession ?? 60} min).
   - Recuérdale al final: "He organizado esta estructura para ti; puedes pulsar el botón 'Aplicar' en la tarjeta de tu pantalla para guardar estos cambios directamente en tu plan de entrenamiento."
   - NUNCA digas que no puedes modificar su rutina o que no tienes autorización técnica.
   - Si el usuario dice que no tiene tiempo para anotarla, que la dejes en Entrenar, o que no ve el botón Aplicar:
     Confírmale con entusiasmo: "¡Listo! Ya he dejado configurada la tarjeta interactiva con tu rutina. Solo presiona el botón 'Aplicar' que aparece abajo para que quede guardada automáticamente en tu pestaña Entrenar sin tener que anotar nada."
5. SEGURIDAD ANTE DOLOR O LESIONES:
   - Si el usuario reporta dolor agudo o molestias articulares, recomiéndale pausar ese ejercicio y consultar con un profesional o el entrenador de turno de Fit Body Gym.
6. IDIOMA: Responde siempre en español.`;

  /*
   * 7. LLAMAR A OPENAI (con fallback inteligente y tokens suficientes)
   */
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini";
  let replyText: string | null = null;

  // Intento 1: API /v1/chat/completions estándar (máxima compatibilidad y estabilidad)
  try {
    const chatCompletionsResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          ...historyMessages,
          { role: "user", content: message },
        ],
        temperature: 0.7,
        max_tokens: 1500,
      }),
    });

    if (chatCompletionsResponse.ok) {
      const data = (await chatCompletionsResponse.json()) as Record<string, unknown>;
      replyText = extractReply(data);
    } else {
      console.warn("chat/completions failed, status:", chatCompletionsResponse.status);
    }
  } catch (err) {
    console.warn("chat/completions error:", err);
  }

  // Intento 2: Fallback a /v1/responses si chat/completions no devolvió texto
  if (!replyText) {
    try {
      const responsesApiResponse = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openAiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          instructions: systemPrompt,
          input: [
            ...historyMessages,
            { role: "user", content: message },
          ],
          reasoning: { effort: "low" },
          max_output_tokens: 1500,
          store: false,
        }),
      });

      if (responsesApiResponse.ok) {
        const data = (await responsesApiResponse.json()) as Record<string, unknown>;
        replyText = extractReply(data);
      } else {
        const errorData = (await responsesApiResponse.json().catch(() => ({}))) as Record<string, unknown>;
        console.error("OpenAI responses API failed:", responsesApiResponse.status, errorData);
      }
    } catch (err) {
      console.error("responses API fallback error:", err);
    }
  }

  // Si ninguno de los dos devolvió respuesta
  if (!replyText) {
    return json(
      {
        error: "El asistente no pudo procesar tu solicitud en este momento. Por favor intenta de nuevo.",
      },
      502,
    );
  }

  /*
   * 8. RESPUESTA EXITOSA AL CLIENTE
   */
  return json({
    type: "answer",
    reply: replyText,
  });
});
