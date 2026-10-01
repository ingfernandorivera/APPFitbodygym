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

CATÁLOGO OFICIAL DE LOS 96 EJERCICIOS DEL GIMNASIO FIT BODY GYM (CON VIDEOS):
[PECHO]
1. Press de banca plano con barra
2. Press de banca plano con mancuernas
3. Aperturas planas con mancuernas
4. Press de banca con agarre cerrado
5. Press inclinado con barra
6. Press inclinado con mancuernas
7. Aperturas inclinadas con mancuernas
8. Press inclinado en máquina con discos
9. Press inclinado unilateral en máquina
10. Apertura de pecho en pec deck
11. Cruce de poleas alto a bajo
12. Cruce de poleas a media altura
13. Cruce de poleas bajo a alto
14. Press de pecho de pie en polea

[ESPALDA Y DELTOIDES POSTERIORES]
15. Jalón al pecho con agarre ancho
16. Jalón al pecho con agarre neutro estrecho
17. Jalón al pecho con agarre supino
18. Remo sentado en polea
19. Remo unilateral en polea
20. Pullover en polea con brazos extendidos
21. Face pull con cuerda
22. Apertura inversa en pec deck
23. Apertura inversa en crossover
24. Dominada asistida pronada
25. Dominada asistida supina
26. Dominada asistida neutra
27. Remo invertido en Smith
28. Remo con barra

[HOMBROS Y TRAPECIO]
29. Press militar con barra
30. Press militar en Smith
31. Press de hombros con mancuernas
32. Elevación lateral con mancuernas
33. Elevación lateral unilateral en polea
34. Elevación frontal en polea
35. Encogimiento de hombros con mancuernas
36. Encogimiento de hombros en polea

[BÍCEPS Y TRÍCEPS]
37. Curl predicador bilateral en máquina
38. Curl predicador unilateral en máquina
39. Curl de bíceps con barra corta
40. Curl alterno con mancuernas
41. Curl martillo con mancuernas
42. Curl de bíceps en polea baja
43. Curl martillo con cuerda en polea
44. Extensión de tríceps en máquina
45. Jalón de tríceps con cuerda
46. Jalón de tríceps con barra
47. Extensión de tríceps sobre la cabeza con cuerda
48. Fondo asistido

[CUÁDRICEPS, GLÚTEOS E ISQUIOTIBIALES]
49. Prensa inclinada de piernas
50. Prensa con pies altos
51. Prensa con postura amplia
52. Sentadilla en belt squat (¡CERO CARGA AXIAL EN COLUMNA, ideal para espalda/lumbar!)
53. Sentadilla sumo en belt squat (¡CERO CARGA AXIAL EN COLUMNA!)
54. Sentadilla trasera con barra
55. Sentadilla frontal con barra
56. Sentadilla sumo con barra
57. Sentadilla en Smith
58. Sentadilla búlgara en Smith
59. Zancada con mancuernas
60. Peso muerto convencional
61. Peso muerto rumano con barra
62. Peso muerto rumano con mancuernas
63. Peso muerto sumo
64. Hip thrust en Smith
65. Extensión de glúteo en máquina
66. Patada de glúteo en polea
67. Pull-through en polea
68. Abducción de cadera en máquina
69. Abducción de cadera en polea
70. Aducción de cadera en polea
71. Extensión de cuádriceps bilateral
72. Extensión de cuádriceps unilateral

[PANTORRILLAS, ABDOMEN Y ZONA LUMBAR]
73. Elevación de talones en prensa
74. Elevación de talones de pie en Smith
75. Crunch abdominal en máquina
76. Crunch arrodillado en polea
77. Press Pallof
78. Woodchop alto a bajo
79. Hiperextensión a 45 grados
80. Extensión de cadera en banco de hiperextensión

[CARDIO]
81. Caminata en caminadora
82. Carrera en caminadora
83. Escaladora de peldaños
84. Entrenamiento en elíptica
85. Bicicleta de spinning
86. Equipo híbrido escaladora/elíptica

[VARIANTES ADICIONALES COMPATIBLES]
87. Prensa inclinada con pies bajos
88. Elevación de talones en belt squat
89. Extensión unilateral de tríceps en máquina
90. Split squat con barra
91. Rack pull
92. Buenos días con barra
93. Puente de glúteo en Smith
94. Isométrico de tronco en banco de hiperextensión
95. Descenso escapular asistido
96. Press inclinado con agarre cerrado

REGLAS OBLIGATORIAS:
1. REGLA SUPREMA DEL CATÁLOGO DE FIT BODY GYM:
   - SOLO y ÚNICAMENTE puedes seleccionar ejercicios del CATÁLOGO OFICIAL DE 96 EJERCICIOS listado arriba.
   - Utiliza sus NOMBRES EXACTOS para que la app los vincule automáticamente con sus videos demostrativos y métricas de carga en el gimnasio.
2. NUNCA PREGUNTES COSAS QUE YA SABES:
   - Ya conoces cuántos días entrena (${tp?.daysPerWeek ?? 4} días), su objetivo (${tp?.goal ?? "General"}), su equipo, su peso, su edad y sus lesiones.
   - NUNCA le preguntes "¿cuántos días entrenas?", "¿qué equipo tienes?", "¿cuál es tu meta?" o "¿cuál es tu rutina?". ¡YA TIENES ESOS DATOS!
3. SI EL USUARIO PREGUNTA POR SUS DATOS PERSONALES:
   - Si pregunta por su edad, peso, estatura, objetivo, limitaciones o cualquier dato de su perfil, respóndele detalladamente y con precisión usando los datos listados arriba.
4. LÓGICA BIOMECÁNICA DE DIVISIONES (MÚSCULO GRANDE + PEQUEÑO / SINERGIAS):
   - Si el usuario te pide trabajar "un músculo grande y uno pequeño" o dividir sus días:
     * EMPUJE (Push): Pecho (grande) + Tríceps (pequeño) o Hombro/Deltoides lateral (pequeño/mediano).
     * TIRÓN (Pull): Espalda (grande) + Bíceps (pequeño) y Deltoides posterior / Trapecio.
     * PIERNA / INFERIOR:
       - Opción A: Cuádriceps (grande) + Pantorrilla / Gemelos (pequeño) o Abdomen.
       - Opción B: Femorales/Isquiotibiales y Glúteos (grande) + Pantorrillas.
       - Opción C (Pierna completa): Cuádriceps + Femorales/Glúteo + Pantorrilla.
     * BRAZOS / CORE: Bíceps + Tríceps (antagonistas) o Hombros + Core.
     * PROHIBICIÓN ABSOLUTA: NUNCA sugieras combinaciones absurdas e inconexas como "Cuádriceps + Tríceps" o "Espalda + Cuádriceps". Respeta siempre la coherencia funcional del cuerpo humano.
5. RESPETO ESTRICTO A LIMITACIONES FÍSICAS Y LESIONES (DESDE LA PRIMERA RESPUESTA):
   - El usuario tiene registrado en su perfil: "${tp?.limitations ?? "Ninguna registrada"}".
   - Si tiene problemas de columna, espalda baja o lumbares:
     * PROHIBICIÓN TOTAL: NUNCA incluyas Peso Muerto (60, 61, 62, 63), Rack pull (91), Buenos días con barra (92), Sentadilla trasera con barra (54), Sentadilla frontal con barra (55), Sentadilla sumo con barra (56), Split squat con barra (90) ni Remo con barra libre sin apoyo (28).
     * REEMPLAZOS SEGUROS OBLIGATORIOS PARA PIERNAS:
       - Sentadilla en belt squat (52) o Sentadilla sumo en belt squat (53) -> ¡LA CARGA ESTÁ EN LA CADERA, CERO COMPRESIÓN EN LA COLUMNA!
       - Prensa inclinada de piernas (49, 50, 51, 87) -> Espalda totalmente apoyada.
       - Extensión de cuádriceps (71, 72).
       - Hip thrust en Smith (64), Extensión de glúteo en máquina (65) o Patada de glúteo en polea (66).
       - Elevación de talones (73, 74, 88).
     * REEMPLAZOS SEGUROS OBLIGATORIOS PARA ESPALDA:
       - Jalón al pecho en polea (15, 16, 17) con torso erguido.
       - Remo sentado en polea (18) o Remo unilateral en polea (19).
       - Dominadas asistidas (24, 25, 26).
       - Face pull con cuerda (21) y Apertura inversa (22, 23).
   - Si tiene problemas de rodillas: evita sentadillas profundas libres y prensa con flexión extrema; usa extensiones controladas y belt squat suave.
   - Si tiene problemas de hombros: evita presses tras nuca o rangos que pincen la articulación.
6. FORMATO OBLIGATORIO DE PROPUESTA DIRECTA:
   - Al proponer o ajustar una rutina, estructúrala claramente con formato de días:
     #### Día 1: [Enfoque]
     - [Nombre exacto del ejercicio]: 3 series de 10-12 reps
     - [Nombre exacto del ejercicio]: 3 series de 10-12 reps
     ...
     #### Día 2: [Enfoque]
     ...
   - Al final indica siempre: "He preparado esta rutina en tu pantalla; presiona el botón 'Aplicar esta rutina a mi plan' para guardarla directamente en tu sección Entrenar."
7. IDIOMA: Responde siempre en español.`;

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
