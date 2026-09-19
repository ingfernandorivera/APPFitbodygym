type ObjectValue = Record<string, unknown>;
const object = (value: unknown): value is ObjectValue => !!value && typeof value === "object" && !Array.isArray(value);
const integer = (value: unknown, min: number, max: number): value is number => typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;
const text = (value: unknown, max = 500): string => typeof value === "string" ? value.trim().slice(0, max) : "";
const normalize = (value: unknown): string => text(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
export function sanitizeResponse(raw: string, catalog: unknown, current: unknown, profile: unknown): ObjectValue {
  const fallback = { type: "answer", reply: "No pude validar una propuesta segura. Intenta de nuevo o crea una rutina local desde tu evaluación." };
  let value: unknown;
  try { value = JSON.parse(raw); } catch { return raw.trim().startsWith("{") || raw.trim().startsWith("[") ? fallback : {type:"answer",reply:text(raw,6000) || fallback.reply}; }
  if (!object(value) || !text(value.reply,6000)) return fallback;
  const reply = text(value.reply,6000);
  if (value.type === "answer" || value.type === "request_more_information") return {type:value.type,reply};
  if (!["propose_workout","modify_workout","replace_exercise"].includes(String(value.type)) || !object(value.payload)) return fallback;
  const payload=value.payload;
  const expected=object(current) && integer(current.version,1,1000000) ? current.version : 0;
  if(payload.expectedVersion!==expected || expected>0 && (!object(current) || payload.expectedPlanId!==current.id)) return fallback;
  if(!object(payload.plan))return fallback;
  const p=payload.plan;
  if(!text(p.name) || !text(p.goal) || !text(p.id) || p.version!==expected+1 || !integer(p.plannedMinutes,15,240) || !integer(p.block,1,1000) || !integer(p.week,1,1000) || !text(p.changeReason) || !Number.isFinite(Date.parse(String(p.createdAt))) || !Array.isArray(p.days) || p.days.length<1 || p.days.length>7)return fallback;
  if(expected>0 && object(current) && p.id!==current.id)return fallback;
  if(object(profile) && (typeof profile.daysPerWeek!=="number" || p.days.length>profile.daysPerWeek || typeof profile.minutesPerSession!=="number" || p.plannedMinutes>profile.minutesPerSession))return fallback;
  const known=new Map<string,ObjectValue>();
  if(Array.isArray(catalog))for(const e of catalog.slice(0,100)){if(object(e) && typeof e.id==="string")known.set(String(e.catalogId??e.id),e);}
  const dayIds=new Set<number>();
  const days: ObjectValue[]=[];
  for(const day of p.days){
    if(!object(day) || !integer(day.dayNumber,1,7) || dayIds.has(day.dayNumber) || !Array.isArray(day.exercises) || day.exercises.length<1 || day.exercises.length>12)return fallback;
    dayIds.add(day.dayNumber);
    const ids=new Set<string>();const exercises:ObjectValue[]=[];let seconds=300;let totalSets=0;
    for(const e of day.exercises){
      if(!object(e))return fallback;
      const id=String(e.catalogId??e.id);const canonical=known.get(id);
      if(!canonical || ids.has(id) || !integer(e.sets,1,6) || !integer(e.restSeconds,canonical.type==="cardio"?0:15,300) || !integer(e.targetMin,1,50) || !integer(e.targetMax,e.targetMin,50) || !integer(e.targetRir,0,4))return fallback;
      const limitations = object(profile) ? normalize(profile.limitations) : "";
      const pattern = String(canonical.movementPattern);
      if (
        (limitations.includes("rodilla") && ["squat", "lunge", "knee_flexion", "cardio"].includes(pattern)) ||
        (limitations.includes("hombro") && ["vertical_push", "shoulder_abduction"].includes(pattern)) ||
        ((limitations.includes("lumbar") || limitations.includes("espalda")) && pattern === "hinge")
      ) return fallback;
      if (object(profile)) {
        const equipment = normalize(profile.equipment);
        const place = normalize(profile.trainingLocation);
        const home = place.includes("casa") || place.includes("aire libre");
        const preferences = normalize(profile.preferences);
        if (preferences.includes("sin mancuernas") && canonical.equipment === "dumbbell") return fallback;
        if (preferences.includes("sin maquinas") && canonical.equipment === "machine") return fallback;
        if (canonical.equipment !== "bodyweight") {
          if (equipment.includes("sin equipo") || equipment.includes("peso corporal")) return fallback;
          if (equipment.includes("mancuerna") && !equipment.includes("maquina") && !equipment.includes("completo") && canonical.equipment !== "dumbbell") return fallback;
          if (home && !(equipment.includes("mancuerna") && canonical.equipment === "dumbbell")) return fallback;
        }
      }
      ids.add(id);totalSets+=e.sets;
      seconds+=45+(canonical.type==="cardio"?e.targetMin*60:e.sets*(e.targetMax*4+10)+(e.sets-1)*e.restSeconds);
      exercises.push({...canonical,id:canonical.id,catalogId:id,sets:e.sets,restSeconds:e.restSeconds,targetMin:e.targetMin,targetMax:e.targetMax,targetRir:e.targetRir,repetitions:String(e.targetMin)+"-"+String(e.targetMax)});
    }
    if(Math.ceil(seconds/60)>p.plannedMinutes || object(profile) && normalize(profile.experience).includes("princip") && totalSets>12)return fallback;
    days.push({dayNumber:day.dayNumber,title:text(day.title),focus:text(day.focus),exercises});
  }
  if(value.type==="replace_exercise" && (!integer(payload.dayNumber,1,7) || !text(payload.exerciseId)))return fallback;
  return {type:value.type,reply,payload:{expectedVersion:expected,expectedPlanId:expected>0 && object(current)?current.id:null, ...(value.type==="replace_exercise"?{dayNumber:payload.dayNumber,exerciseId:text(payload.exerciseId)}:{}),plan:{id:text(p.id),name:text(p.name),goal:text(p.goal),version:p.version,createdAt:p.createdAt,startDate:typeof p.startDate==="string" && Number.isFinite(Date.parse(p.startDate))?p.startDate:p.createdAt,block:p.block,week:p.week,plannedMinutes:p.plannedMinutes,source:"ai",changeReason:text(p.changeReason),isDemo:false,days}}};
}
