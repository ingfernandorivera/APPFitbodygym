-- FitBodyGym App - SQL COMPLETO para TODOS los 35 Videos de tu carpeta 'Videos de ejercicios'
-- Proyecto Supabase ID: iqlxotcjmvixnisetpiy
-- Bucket: exercise-videos (Public)
-- Copiar y Ejecutar en: https://supabase.com/dashboard/project/iqlxotcjmvixnisetpiy/sql/new

INSERT INTO public.exercise_catalog (name, muscle_group, equipment, instructions, media_url, media_type, is_active)
VALUES 
  (
    'Press de pecho de pie en polea', 
    'Pecho y tríceps', 
    'Poleas', 
    'Mantén los pies estables y lleva las asas hacia al frente a la altura del pecho.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/013_press_pecho_pie_polea.mp4', 
    'video', 
    true
  ),
  (
    'Jalón al pecho agarre neutro estrecho', 
    'Espalda y bíceps', 
    'Polea Alta', 
    'Sujeta el agarre estrecho neutro y tracciona hacia la parte superior del pecho.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/015_jalon_pecho_neutro_estrecho.mp4', 
    'video', 
    true
  ),
  (
    'Remo sentado en polea', 
    'Espalda', 
    'Polea Baja', 
    'Sujeta el agarre, mantén la espalda recta y jala hacia el abdomen sin usar impulso.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/016_remo_sentado_polea.mp4', 
    'video', 
    true
  ),
  (
    'Jalón al pecho agarre supino', 
    'Espalda y bíceps', 
    'Polea Alta', 
    'Con palmas mirando hacia ti, jala la barra hacia la parte superior del pecho.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/017_jalon_pecho_agarre_supino.mp4', 
    'video', 
    true
  ),
  (
    'Remo unilateral en polea', 
    'Espalda', 
    'Polea Baja', 
    'Realiza el jalón con un solo brazo enfocando la contracción en el dorsal.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/019_remo_unilateral_polea_2_imagenes.mp4', 
    'video', 
    true
  ),
  (
    'Pullover en polea brazos extendidos', 
    'Espalda y serratos', 
    'Polea Alta', 
    'Mantén los codos ligeramente flexionados y lleva la barra hacia la cadera.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/020_pullover_polea_brazos_extendidos.mp4', 
    'video', 
    true
  ),
  (
    'Face pull con cuerda', 
    'Hombro posterior y espalda alta', 
    'Polea Alta', 
    'Jala la cuerda hacia tu cara separando las manos y contrayendo los deltoides posteriores.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/021_face_pull_cuerda.mp4', 
    'video', 
    true
  ),
  (
    'Apertura inversa en Pec Deck', 
    'Hombro posterior', 
    'Máquina Peck Deck', 
    'Abre las palancas hacia los lados contrayendo la zona posterior de los hombros.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/022_apertura_inversa_pec_deck.mp4', 
    'video', 
    true
  ),
  (
    'Dominada asistida pronada', 
    'Espalda y bíceps', 
    'Máquina Asistida', 
    'Apoya rodillas o pies y sube hasta que tu barbilla supere la barra.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/024_dominada_asistida_pronada.mp4', 
    'video', 
    true
  ),
  (
    'Dominada asistida supina', 
    'Bíceps y espalda', 
    'Máquina Asistida', 
    'Sostén la barra con palmas hacia ti y eleva el cuerpo con asistencia.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/025_dominada_asistida_supina_2_imagenes.mp4', 
    'video', 
    true
  ),
  (
    'Remo invertido en Smith', 
    'Espalda', 
    'Máquina Smith', 
    'Sujétate de la barra fija con cuerpo tenso y eleva el pecho hacia la barra.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/027_remo_invertido_smith.mp4', 
    'video', 
    true
  ),
  (
    'Press militar con barra', 
    'Hombros y tríceps', 
    'Barra', 
    'Empuja la barra sobre la cabeza desde los hombros manteniendo el core firme.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/029_press_militar_barra.mp4', 
    'video', 
    true
  ),
  (
    'Press militar en Smith', 
    'Hombros y tríceps', 
    'Máquina Smith', 
    'Realiza el empuje de hombros utilizando la guía guiada de la Smith.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/030_press_militar_smith.mp4', 
    'video', 
    true
  ),
  (
    'Press de hombros con mancuernas', 
    'Hombros y tríceps', 
    'Mancuernas', 
    'Sentado o de pie, empuja las mancuernas verticalmente hacia arriba.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/031_press_hombros_mancuernas.mp4', 
    'video', 
    true
  ),
  (
    'Elevación lateral con mancuernas', 
    'Hombros', 
    'Mancuernas', 
    'Eleva los brazos hacia los lados hasta la altura de los hombros.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/032_elevacion_lateral_mancuernas.mp4', 
    'video', 
    true
  ),
  (
    'Elevación lateral unilateral en polea', 
    'Hombros', 
    'Polea Baja', 
    'Jala el cable lateralmente con un solo brazo controlando la bajada.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/033_elevacion_lateral_unilateral_polea.mp4', 
    'video', 
    true
  ),
  (
    'Elevación frontal en polea', 
    'Hombros', 
    'Polea Baja', 
    'Lleva la barra o cuerda hacia al frente hasta la altura de los ojos.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/034_elevacion_frontal_polea.mp4', 
    'video', 
    true
  ),
  (
    'Encogimiento de hombros con mancuernas', 
    'Trapecios', 
    'Mancuernas', 
    'Eleva los hombros hacia las orejas contrayendo el trapecio arriba.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/035_encogimiento_hombros_mancuernas.mp4', 
    'video', 
    true
  ),
  (
    'Encogimiento de hombros en polea', 
    'Trapecios', 
    'Polea Baja', 
    'Sujeta el agarre y realiza la elevación vertical de hombros.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/036_encogimiento_hombros_polea.mp4', 
    'video', 
    true
  ),
  (
    'Curl predicador en máquina', 
    'Bíceps', 
    'Máquina Predicador', 
    'Apoya los tríceps en la almohadilla y flexiona los brazos con ambas manos.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/037_curl_predicador_bilateral_maquina.mp4', 
    'video', 
    true
  ),
  (
    'Curl predicador unilateral en máquina', 
    'Bíceps', 
    'Máquina Predicador', 
    'Realiza el curl de bíceps concentrado brazo por brazo.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/038_curl_predicador_unilateral_maquina.mp4', 
    'video', 
    true
  ),
  (
    'Curl de bíceps con barra corta', 
    'Bíceps', 
    'Barra / Polea', 
    'Flexiona los codos manteniendo los brazos pegados al costado del cuerpo.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/039_curl_biceps_barra_corta.mp4', 
    'video', 
    true
  ),
  (
    'Curl alterno con mancuernas', 
    'Bíceps', 
    'Mancuernas', 
    'Alterna el brazo derecho e izquierdo girando la muñeca en la subida.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/040_curl_alterno_mancuernas_corregido.mp4', 
    'video', 
    true
  ),
  (
    'Jalón de tríceps con cuerda', 
    'Tríceps', 
    'Polea Alta', 
    'Extiende los codos hacia abajo separando los extremos de la cuerda abajo.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/045_jalon_triceps_cuerda.mp4', 
    'video', 
    true
  ),
  (
    'Aperturas planas con mancuernas', 
    'Pecho', 
    'Banco Plano y Mancuernas', 
    'Abre los brazos en forma de arco sintiendo el estiramiento del pectoral.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/Aperturas%20planas%20con%20mancuernas.mp4', 
    'video', 
    true
  ),
  (
    'Jalón al pecho con agarre ancho', 
    'Espalda', 
    'Polea Alta', 
    'Tira de la barra ancha directamente al pecho con espalda erguida.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/Jal%C3%B3n%20al%20pecho%20con%20agarre%20ancho.mp4', 
    'video', 
    true
  ),
  (
    'Press de banca plano con barra', 
    'Pecho y tríceps', 
    'Banco Plano y Barra', 
    'Baja la barra al centro del pecho y empuja con potencia.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/Press%20de%20banca%20plano%20con%20barra.mp4', 
    'video', 
    true
  ),
  (
    'Press de banca plano con mancuernas', 
    'Pecho', 
    'Banco Plano y Mancuernas', 
    'Empuja las mancuernas desde los costados del pecho hacia arriba.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/Press%20de%20banca%20plano%20con%20mancuernas.mp4', 
    'video', 
    true
  ),
  (
    'Apertura de pecho en Pec Deck', 
    'Pecho', 
    'Máquina Peck Deck', 
    'Junta las almohadillas al centro del pecho aislando los pectorales.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/apertura_pecho_pec_deck_loop.mp4', 
    'video', 
    true
  ),
  (
    'Cruce de poleas alto a bajo', 
    'Pecho inferior', 
    'Poleas', 
    'Jala los cables de arriba hacia abajo cruzando ligeramente las manos.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/cruce_de_poleas_alto_a_bajo_loop.mp4', 
    'video', 
    true
  ),
  (
    'Cruce de poleas bajo a alto', 
    'Pecho superior', 
    'Poleas', 
    'Jala los cables desde la posición baja hacia arriba y al centro.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/cruce_de_poleas_bajo_a_alto_loop.mp4', 
    'video', 
    true
  ),
  (
    'Press de banca agarre cerrado', 
    'Tríceps y pecho', 
    'Banco Plano y Barra', 
    'Agarra la barra a la anchura de tus hombros enfocado en los tríceps.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/press_banca_agarre_cerrado_loop.mp4', 
    'video', 
    true
  ),
  (
    'Press inclinado con barra', 
    'Pecho superior', 
    'Banco Inclinado y Barra', 
    'Baja la barra a la parte superior del pecho y empuja verticalmente.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/press_inclinado_con_barra_loop.mp4', 
    'video', 
    true
  ),
  (
    'Press inclinado con mancuernas', 
    'Pecho superior', 
    'Banco Inclinado y Mancuernas', 
    'Empuja las mancuernas en banco inclinado manteniendo el control.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/press_inclinado_con_mancuernas_loop.mp4', 
    'video', 
    true
  ),
  (
    'Press inclinado en máquina', 
    'Pecho superior', 
    'Máquina Guiada', 
    'Empuja los agarres de la máquina guiada inclinada de forma segura.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/press_inclinado_en_maquina_loop.mp4', 
    'video', 
    true
  )
ON CONFLICT (name, equipment) DO UPDATE 
SET 
  media_url = EXCLUDED.media_url,
  instructions = EXCLUDED.instructions,
  media_type = EXCLUDED.media_type,
  is_active = EXCLUDED.is_active;
