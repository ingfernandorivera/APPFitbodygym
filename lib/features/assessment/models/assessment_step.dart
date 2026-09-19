import 'package:flutter/material.dart';

class AssessmentStep {
  const AssessmentStep(
    this.key,
    this.title,
    this.hint, {
    this.options = const [],
    this.multiple = false,
    this.optional = false,
    this.min,
    this.max,
    this.integer = false,
    this.suffix = '',
    this.category = 'Evaluación',
  });
  final String key;
  final String title;
  final String hint;
  final List<String> options;
  final bool multiple;
  final bool optional;
  final double? min;
  final double? max;
  final bool integer;
  final String suffix;
  final String category;
}

class StepOptionMeta {
  const StepOptionMeta({
    required this.label,
    required this.subtitle,
    required this.icon,
  });
  final String label;
  final String subtitle;
  final IconData icon;
}

const assessmentSteps = [
  AssessmentStep(
    'goal',
    '¿Qué quieres conseguir?',
    'Tu punto de partida es personal. Elige lo que más te importa ahora.',
    options: [
      'Bajar grasa',
      'Ganar masa muscular',
      'Mejorar condición física',
      'Aumentar fuerza',
      'Mantenerme activo',
    ],
  ),
  AssessmentStep(
    'bodyRepresentation',
    '¿Cómo prefieres ver la silueta?',
    'Solo cambia el dibujo. No indica género ni modifica recomendaciones.',
    optional: true,
    options: ['Neutral', 'Hombros amplios', 'Caderas amplias', 'Sin silueta'],
  ),
  AssessmentStep(
    'bodyShape',
    '¿Cómo describirías tu forma actual?',
    'Elige tu propia percepción. Todas las formas son válidas.',
    options: ['Delgada', 'Intermedia', 'Robusta', 'Prefiero no indicarlo'],
  ),
  AssessmentStep(
    'bodyFatEstimate',
    '¿Quieres estimar visualmente tu grasa corporal?',
    'Es opcional y orientativa. El dibujo es esquemático: no permite medir grasa corporal, no es un diagnóstico y no se usa para calcular tu rutina.',
    optional: true,
  ),
  AssessmentStep(
    'experience',
    '¿Qué experiencia tienes?',
    'Elige el nivel que mejor refleja tu práctica actual.',
    options: ['Principiante', 'Intermedio', 'Avanzado'],
  ),
  AssessmentStep(
    'daysPerWeek',
    '¿Cuántos días puedes entrenar?',
    'Elige una frecuencia que puedas sostener.',
    options: ['1', '2', '3', '4', '5', '6', '7'],
  ),
  AssessmentStep(
    'minutesPerSession',
    '¿Cuánto tiempo tienes por sesión?',
    'Incluye el tiempo que dedicarás a prepararte y descansar.',
    options: ['15', '20', '30', '45', '60', '75', '90'],
  ),
  AssessmentStep(
    'schedule',
    '¿En qué momento prefieres entrenar?',
    'Puedes cambiarlo cuando cambie tu semana.',
    options: ['Mañana', 'Mediodía', 'Tarde', 'Noche', 'Flexible'],
  ),
  AssessmentStep(
    'trainingLocation',
    '¿Dónde vas a entrenar?',
    'Nos ayuda a conocer tu contexto.',
    options: ['Gimnasio', 'Casa', 'Al aire libre', 'Varios lugares'],
  ),
  AssessmentStep(
    'equipment',
    '¿Qué equipo tienes disponible?',
    'Elige la opción que más se acerque a tu espacio.',
    options: [
      'Gimnasio completo',
      'Gimnasio básico',
      'Mancuernas y bandas',
      'Solo peso corporal',
      'Sin indicar',
    ],
  ),
  AssessmentStep(
    'priorityMuscles',
    '¿Qué zonas quieres priorizar?',
    'Puedes elegir varias o continuar sin una prioridad específica.',
    optional: true,
    multiple: true,
    options: [
      'Piernas',
      'Glúteos',
      'Espalda',
      'Pecho',
      'Hombros',
      'Brazos',
      'Abdomen',
    ],
  ),
  AssessmentStep(
    'limitations',
    '¿Hay molestias que debamos conocer?',
    'Describe movimientos que te incomodan. Si no hay molestias, puedes dejarlo vacío. Esta evaluación no sustituye una valoración profesional.',
    optional: true,
  ),
  AssessmentStep(
    'motivations',
    '¿Qué te motiva a empezar?',
    'Elige una o varias razones que tengan sentido para ti.',
    multiple: true,
    options: [
      'Sentirme mejor',
      'Tener más energía',
      'Crear un hábito',
      'Superarme',
      'Disfrutar del movimiento',
    ],
  ),
  AssessmentStep(
    'dailyActivity',
    '¿Cómo es tu actividad cotidiana?',
    'Piensa en tu día habitual fuera del entrenamiento.',
    options: [
      'Paso mucho tiempo sentado',
      'Alterno estar sentado y caminar',
      'Camino con frecuencia',
      'Mi actividad es físicamente exigente',
    ],
  ),
  AssessmentStep(
    'sleepHours',
    '¿Cuántas horas sueles dormir?',
    'Anota un promedio aproximado por noche.',
    min: 1,
    max: 16,
    suffix: 'horas',
  ),
  AssessmentStep(
    'hydrationLiters',
    '¿Cuánta agua sueles beber?',
    'Anota un promedio aproximado por día, en litros.',
    min: 0,
    max: 12,
    suffix: 'L',
  ),
  AssessmentStep(
    'age',
    '¿Cuántos años tienes?',
    'Usaremos tu edad como contexto para tu perfil.',
    min: 14,
    max: 100,
    integer: true,
    suffix: 'años',
  ),
  AssessmentStep(
    'heightCm',
    '¿Cuál es tu altura?',
    'Introduce tu altura en centímetros.',
    min: 100,
    max: 250,
    suffix: 'cm',
  ),
  AssessmentStep(
    'weightUnit',
    '¿Qué unidad de peso prefieres?',
    'La misma unidad se usará para el peso actual y tu objetivo.',
    options: ['kg', 'lb'],
  ),
  AssessmentStep(
    'weight',
    '¿Cuál es tu peso actual?',
    'Es un dato de referencia, no una calificación de tu cuerpo.',
    min: 30,
    max: 300,
  ),
  AssessmentStep(
    'targetWeight',
    '¿Tienes un peso objetivo?',
    'Puedes dejarlo vacío si tu objetivo no depende del peso. No se calculan plazos ni se prometen resultados.',
    optional: true,
    min: 30,
    max: 300,
  ),
  AssessmentStep(
    'preferences',
    '¿Algo más que quieras añadir?',
    'Cuéntanos qué actividades disfrutas o qué te gustaría probar.',
    optional: true,
  ),
];

StepOptionMeta? getStepOptionMeta(String stepKey, String option) {
  switch (stepKey) {
    case 'goal':
      switch (option) {
        case 'Bajar grasa':
          return const StepOptionMeta(
            label: 'Bajar grasa',
            subtitle: 'Déficit controlado, tonificación y salud metabólica',
            icon: Icons.local_fire_department,
          );
        case 'Ganar masa muscular':
          return const StepOptionMeta(
            label: 'Ganar masa muscular',
            subtitle: 'Hipertrofia, aumento de volumen y fuerza estructural',
            icon: Icons.fitness_center,
          );
        case 'Mejorar condición física':
          return const StepOptionMeta(
            label: 'Mejorar condición física',
            subtitle: 'Resistencia cardiovascular, agilidad y vitalidad diaria',
            icon: Icons.bolt,
          );
        case 'Aumentar fuerza':
          return const StepOptionMeta(
            label: 'Aumentar fuerza',
            subtitle:
                'Capacidad de carga, potencia y densidad musculoesquelética',
            icon: Icons.military_tech,
          );
        case 'Mantenerme activo':
          return const StepOptionMeta(
            label: 'Mantenerme activo',
            subtitle:
                'Hábito saludable sostenible, salud articular y bienestar',
            icon: Icons.directions_run,
          );
      }
    case 'bodyRepresentation':
      switch (option) {
        case 'Neutral':
          return const StepOptionMeta(
            label: 'Neutral',
            subtitle: 'Proporciones equilibradas y silueta estándar',
            icon: Icons.accessibility_new,
          );
        case 'Hombros amplios':
          return const StepOptionMeta(
            label: 'Hombros amplios',
            subtitle: 'Silueta con hombros y torso superior más ancho',
            icon: Icons.straighten,
          );
        case 'Caderas amplias':
          return const StepOptionMeta(
            label: 'Caderas amplias',
            subtitle: 'Silueta con cadera y base pélvica más acentuada',
            icon: Icons.hourglass_bottom,
          );
        case 'Sin silueta':
          return const StepOptionMeta(
            label: 'Sin silueta',
            subtitle: 'Ocultar la representación esquemática del cuerpo',
            icon: Icons.visibility_off_outlined,
          );
      }
    case 'bodyShape':
      switch (option) {
        case 'Delgada':
          return const StepOptionMeta(
            label: 'Delgada',
            subtitle: 'Estructura ligera con volumen corporal bajo',
            icon: Icons.person_outline,
          );
        case 'Intermedia':
          return const StepOptionMeta(
            label: 'Intermedia',
            subtitle: 'Complexión media equilibrada',
            icon: Icons.person,
          );
        case 'Robusta':
          return const StepOptionMeta(
            label: 'Robusta',
            subtitle: 'Estructura sólida de mayor volumen',
            icon: Icons.shield_outlined,
          );
        case 'Prefiero no indicarlo':
          return const StepOptionMeta(
            label: 'Prefiero no indicarlo',
            subtitle: 'Continuar sin especificar forma física actual',
            icon: Icons.do_not_disturb_on_outlined,
          );
      }
    case 'experience':
      switch (option) {
        case 'Principiante':
          return const StepOptionMeta(
            label: 'Principiante',
            subtitle: 'Menos de 6 meses o retomando tras un descanso',
            icon: Icons.school_outlined,
          );
        case 'Intermedio':
          return const StepOptionMeta(
            label: 'Intermedio',
            subtitle: '6 meses a 2 años con técnica y hábito constante',
            icon: Icons.trending_up,
          );
        case 'Avanzado':
          return const StepOptionMeta(
            label: 'Avanzado',
            subtitle: 'Más de 2 años de entrenamiento sistemático',
            icon: Icons.workspace_premium_outlined,
          );
      }
    case 'schedule':
      switch (option) {
        case 'Mañana':
          return const StepOptionMeta(
            label: 'Mañana',
            subtitle: '6:00 AM – 12:00 PM (energía para arrancar el día)',
            icon: Icons.wb_sunny_outlined,
          );
        case 'Mediodía':
          return const StepOptionMeta(
            label: 'Mediodía',
            subtitle: '12:00 PM – 3:00 PM (pausa activa del mediodía)',
            icon: Icons.wb_sunny,
          );
        case 'Tarde':
          return const StepOptionMeta(
            label: 'Tarde',
            subtitle: '3:00 PM – 7:00 PM (después de la jornada principal)',
            icon: Icons.wb_twilight,
          );
        case 'Noche':
          return const StepOptionMeta(
            label: 'Noche',
            subtitle: '7:00 PM – 11:00 PM (cierre del día con entrenamiento)',
            icon: Icons.nightlight_outlined,
          );
        case 'Flexible':
          return const StepOptionMeta(
            label: 'Flexible',
            subtitle: 'Varía según la agenda de cada semana',
            icon: Icons.schedule,
          );
      }
    case 'trainingLocation':
      switch (option) {
        case 'Gimnasio':
          return const StepOptionMeta(
            label: 'Gimnasio',
            subtitle: 'Acceso a máquinas guiadas, peso libre y poleas',
            icon: Icons.domain,
          );
        case 'Casa':
          return const StepOptionMeta(
            label: 'Casa',
            subtitle:
                'Entrenamiento en casa con equipamiento propio o peso libre',
            icon: Icons.home_outlined,
          );
        case 'Al aire libre':
          return const StepOptionMeta(
            label: 'Al aire libre',
            subtitle: 'Parques, calistenia, barras y espacios abiertos',
            icon: Icons.park_outlined,
          );
        case 'Varios lugares':
          return const StepOptionMeta(
            label: 'Varios lugares',
            subtitle: 'Combinación flexible de gimnasio y hogar',
            icon: Icons.sync_alt,
          );
      }
    case 'equipment':
      switch (option) {
        case 'Gimnasio completo':
          return const StepOptionMeta(
            label: 'Gimnasio completo',
            subtitle: 'Barras olímpicas, mancuernas, poleas y máquinas',
            icon: Icons.fitness_center,
          );
        case 'Gimnasio básico':
          return const StepOptionMeta(
            label: 'Gimnasio básico',
            subtitle: 'Mancuernas, alguna máquina guiada y bancos',
            icon: Icons.home_repair_service_outlined,
          );
        case 'Mancuernas y bandas':
          return const StepOptionMeta(
            label: 'Mancuernas y bandas',
            subtitle: 'Par de mancuernas ajustables, ligas o bandas elásticas',
            icon: Icons.sports_gymnastics,
          );
        case 'Solo peso corporal':
          return const StepOptionMeta(
            label: 'Solo peso corporal',
            subtitle: 'Ejercicios calisténicos sin equipamiento pesado',
            icon: Icons.self_improvement,
          );
        case 'Sin indicar':
          return const StepOptionMeta(
            label: 'Sin indicar',
            subtitle: 'Definir el equipamiento más adelante',
            icon: Icons.help_outline,
          );
      }
    case 'priorityMuscles':
      switch (option) {
        case 'Piernas':
          return const StepOptionMeta(
            label: 'Piernas',
            subtitle: 'Cuádriceps, isquiotibiales y pantorrillas',
            icon: Icons.directions_walk,
          );
        case 'Glúteos':
          return const StepOptionMeta(
            label: 'Glúteos',
            subtitle: 'Fuerza, tono y estabilidad pélvica',
            icon: Icons.airline_seat_recline_extra_outlined,
          );
        case 'Espalda':
          return const StepOptionMeta(
            label: 'Espalda',
            subtitle: 'Dorsales, romboides y postura erguida',
            icon: Icons.shield_outlined,
          );
        case 'Pecho':
          return const StepOptionMeta(
            label: 'Pecho',
            subtitle: 'Pectoral mayor, medio y superior',
            icon: Icons.crop_square_outlined,
          );
        case 'Hombros':
          return const StepOptionMeta(
            label: 'Hombros',
            subtitle: 'Deltoides anterior, lateral y posterior',
            icon: Icons.straighten,
          );
        case 'Brazos':
          return const StepOptionMeta(
            label: 'Brazos',
            subtitle: 'Bíceps, tríceps y antebrazos',
            icon: Icons.sports_handball_outlined,
          );
        case 'Abdomen':
          return const StepOptionMeta(
            label: 'Abdomen',
            subtitle: 'Core funcional, estabilidad lumbar y rectos',
            icon: Icons.grid_view,
          );
      }
    case 'motivations':
      switch (option) {
        case 'Sentirme mejor':
          return const StepOptionMeta(
            label: 'Sentirme mejor',
            subtitle: 'Bienestar mental, salud y menor nivel de estrés',
            icon: Icons.sentiment_very_satisfied_outlined,
          );
        case 'Tener más energía':
          return const StepOptionMeta(
            label: 'Tener más energía',
            subtitle: 'Despertar con vigor y mayor rendimiento cotidiano',
            icon: Icons.electric_bolt_outlined,
          );
        case 'Crear un hábito':
          return const StepOptionMeta(
            label: 'Crear un hábito',
            subtitle: 'Constancia, disciplina y estilo de vida deportivo',
            icon: Icons.calendar_today_outlined,
          );
        case 'Superarme':
          return const StepOptionMeta(
            label: 'Superarme',
            subtitle: 'Progresar en marcas personales y confianza',
            icon: Icons.emoji_events_outlined,
          );
        case 'Disfrutar del movimiento':
          return const StepOptionMeta(
            label: 'Disfrutar del movimiento',
            subtitle: 'Entrenar con agrado y encontrar diversión activa',
            icon: Icons.celebration_outlined,
          );
      }
    case 'dailyActivity':
      switch (option) {
        case 'Paso mucho tiempo sentado':
          return const StepOptionMeta(
            label: 'Paso mucho tiempo sentado',
            subtitle: 'Trabajo sedentario de oficina, estudio o conducción',
            icon: Icons.chair_outlined,
          );
        case 'Alterno estar sentado y caminar':
          return const StepOptionMeta(
            label: 'Alterno estar sentado y caminar',
            subtitle: 'Pausas activas y desplazamientos intermedios',
            icon: Icons.transfer_within_a_station,
          );
        case 'Camino con frecuencia':
          return const StepOptionMeta(
            label: 'Camino con frecuencia',
            subtitle: 'Jornada dinámica de pie o traslados frecuentes a pie',
            icon: Icons.directions_walk,
          );
        case 'Mi actividad es físicamente exigente':
          return const StepOptionMeta(
            label: 'Mi actividad es físicamente exigente',
            subtitle: 'Carga física pesada, deporte o trabajo de alto esfuerzo',
            icon: Icons.handyman_outlined,
          );
      }
    case 'weightUnit':
      switch (option) {
        case 'kg':
          return const StepOptionMeta(
            label: 'kg',
            subtitle: 'Sistema métrico (kilogramos)',
            icon: Icons.scale,
          );
        case 'lb':
          return const StepOptionMeta(
            label: 'lb',
            subtitle: 'Sistema imperial (libras)',
            icon: Icons.scale_outlined,
          );
      }
    case 'daysPerWeek':
      return StepOptionMeta(
        label: '$option días',
        subtitle: int.tryParse(option) != null && int.parse(option) <= 2
            ? 'Ideal para empezar y crear el hábito'
            : int.tryParse(option) != null && int.parse(option) <= 4
            ? 'Equilibrio óptimo de estímulo y descanso'
            : 'Frecuencia avanzada y alto compromiso',
        icon: Icons.event_available,
      );
    case 'minutesPerSession':
      return StepOptionMeta(
        label: '$option minutos',
        subtitle: int.tryParse(option) != null && int.parse(option) <= 30
            ? 'Sesiones ágiles y concentradas'
            : int.tryParse(option) != null && int.parse(option) <= 60
            ? 'Duración estándar recomendada'
            : 'Entrenamientos completos con calentamiento y descanso amplio',
        icon: Icons.timer_outlined,
      );
  }
  return null;
}

String? getStepMilestone(int stepIndex) {
  switch (stepIndex) {
    case 5:
      return '🔥 ¡Gran comienzo! Ya entendemos mejor tu objetivo y ritmo.';
    case 10:
      return '💪 Tu constancia importa más que la perfección. Sigamos con tu entorno.';
    case 15:
      return '🛡️ Conociendo tus hábitos y descansos cuidamos tu salud y energía.';
    case 19:
      return '✨ ¡Último tramo! Tus datos físicos nos ayudan a calibrar el esfuerzo.';
    default:
      return null;
  }
}
