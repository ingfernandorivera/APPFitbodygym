import '../models/workout_plan.dart';

abstract final class ExerciseCatalog {
  static const exercises = <WorkoutExercise>[
    WorkoutExercise(
      id: 'chest_press_machine',
      name: 'Press de pecho en máquina',
      muscleGroup: 'Pecho y tríceps',
      sets: 3,
      repetitions: '10-12',
      restSeconds: 75,
      instructions:
          'Ajusta el asiento, apoya la espalda y empuja sin bloquear los codos.',
      commonMistakes:
          'Separar la espalda del respaldo o bajar los codos en exceso.',
      alternative: 'Press con mancuernas en banco plano.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'lat_pulldown',
      name: 'Jalón al pecho',
      muscleGroup: 'Espalda y bíceps',
      sets: 3,
      repetitions: '10-12',
      restSeconds: 75,
      instructions:
          'Lleva la barra a la parte alta del pecho con el torso estable.',
      commonMistakes: 'Balancear el cuerpo o tirar detrás de la nuca.',
      alternative: 'Remo sentado con agarre neutro.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'seated_row',
      name: 'Remo sentado',
      muscleGroup: 'Espalda',
      sets: 3,
      repetitions: '12',
      restSeconds: 60,
      instructions:
          'Lleva el agarre al abdomen y junta los omóplatos sin encorvarte.',
      commonMistakes: 'Usar impulso o elevar los hombros.',
      alternative: 'Remo con mancuerna apoyado.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'leg_press',
      name: 'Prensa de piernas',
      muscleGroup: 'Cuádriceps y glúteos',
      sets: 4,
      repetitions: '10-12',
      restSeconds: 90,
      instructions:
          'Apoya toda la planta del pie y baja solo mientras la pelvis siga estable.',
      commonMistakes: 'Bloquear las rodillas o despegar la cadera.',
      alternative: 'Sentadilla goblet.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'leg_curl',
      name: 'Curl femoral',
      muscleGroup: 'Isquiotibiales',
      sets: 3,
      repetitions: '12-15',
      restSeconds: 60,
      instructions:
          'Flexiona las rodillas lentamente y mantén la cadera apoyada.',
      commonMistakes: 'Levantar la cadera o soltar el peso de golpe.',
      alternative: 'Peso muerto rumano con mancuernas ligeras.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'calf_raise',
      name: 'Elevación de pantorrillas',
      muscleGroup: 'Pantorrillas',
      sets: 3,
      repetitions: '15-20',
      restSeconds: 45,
      instructions: 'Completa el recorrido y mantén una pausa breve arriba.',
      commonMistakes: 'Rebotar o hacer un recorrido corto.',
      alternative: 'Elevación de pantorrillas de pie.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'goblet_squat',
      name: 'Sentadilla goblet',
      muscleGroup: 'Piernas y glúteos',
      sets: 3,
      repetitions: '10',
      restSeconds: 75,
      instructions:
          'Sostén el peso junto al pecho y mantén rodillas y pies alineados.',
      commonMistakes:
          'Colapsar las rodillas hacia dentro o redondear la espalda.',
      alternative: 'Prensa de piernas.',
      difficulty: 'Intermedio',
    ),
    WorkoutExercise(
      id: 'shoulder_press_machine',
      name: 'Press de hombros en máquina',
      muscleGroup: 'Hombros y tríceps',
      sets: 3,
      repetitions: '10-12',
      restSeconds: 60,
      instructions: 'Mantén la espalda apoyada y controla todo el recorrido.',
      commonMistakes: 'Arquear la zona lumbar o bajar demasiado los codos.',
      alternative: 'Press de hombros con mancuernas ligeras.',
      difficulty: 'Principiante',
    ),
    WorkoutExercise(
      id: 'treadmill_walk',
      name: 'Caminata en banda',
      muscleGroup: 'Cardiovascular',
      sets: 1,
      repetitions: '12 minutos',
      restSeconds: 0,
      instructions: 'Usa un ritmo sostenible y conserva una postura erguida.',
      commonMistakes:
          'Sujetarse con fuerza o aumentar la velocidad sin control.',
      alternative: 'Bicicleta estacionaria.',
      difficulty: 'Principiante',
    ),
  ];

  static WorkoutExercise byId(String id) =>
      exercises.firstWhere((exercise) => exercise.id == id);
}
