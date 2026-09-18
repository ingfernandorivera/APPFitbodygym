-- FitBodyGym App - SQL Generado para los Videos de tu Bucket 'exercise-videos'
-- Proyecto Supabase ID: iqlxotcjmvixnisetpiy
-- Ejecutar en: https://supabase.com/dashboard/project/iqlxotcjmvixnisetpiy/sql/new

INSERT INTO public.exercise_catalog (name, muscle_group, equipment, instructions, media_url, media_type, is_active)
VALUES 
  (
    'Press de pecho en polea', 
    'Pecho y tríceps', 
    'Poleas', 
    'Mantén los pies estables, lleva las asas al frente juntando el pecho sin bloquear codos.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/013_press_pecho_pie_polea.mp4', 
    'video', 
    true
  ),
  (
    'Jalón al pecho (agarre neutro)', 
    'Espalda y bíceps', 
    'Polea Alta', 
    'Sujeta el agarre neutro, tracciona hacia la parte superior del pecho con el torso erguido.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/015_jalon_pecho_neutro.mp4', 
    'video', 
    true
  ),
  (
    'Remo sentado en polea', 
    'Espalda', 
    'Polea Baja', 
    'Lleva el agarre al abdomen, junta escápulas y evita usar el balanceo del cuerpo.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/016_remo_sentado_polea.mp4', 
    'video', 
    true
  ),
  (
    'Jalón al pecho', 
    'Espalda y bíceps', 
    'Polea Alta', 
    'Lleva la barra ancha al pecho controlando el movimiento en la bajada y subida.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/017_jalon_pecho_agarre_ancho.mp4', 
    'video', 
    true
  ),
  (
    'Remo unilateral en polea', 
    'Espalda', 
    'Polea Baja', 
    'Realiza el jalón con un solo brazo enfocado en la contracción de la dorsal.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/019_remo_unilateral_polea.mp4', 
    'video', 
    true
  ),
  (
    'Pullover en polea', 
    'Espalda y serratos', 
    'Polea Alta', 
    'Mantén los brazos semi-extendidos y empuja la barra o cuerda hacia los muslos.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/020_pullover_polea_brazo.mp4', 
    'video', 
    true
  ),
  (
    'Face pull con cuerda', 
    'Hombro posterior y espalda alta', 
    'Polea Alta', 
    'Jala la cuerda hacia el rostro separando las manos y contrayendo los deltoides posteriores.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/021_face_pull_cuerda.mp4', 
    'video', 
    true
  ),
  (
    'Apertura inversa (Peck Deck)', 
    'Hombro posterior', 
    'Máquina Peck Deck', 
    'Mantén codos alineados y abre los brazos hacia los lados sin encorvar los hombros.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/022_apertura_inversa_peck_deck.mp4', 
    'video', 
    true
  ),
  (
    'Dominada asistida', 
    'Espalda y bíceps', 
    'Máquina asistida', 
    'Apoya las rodillas/pies en la plataforma y realiza la flexión de brazos completa.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/024_dominada_asistida_pronada.mp4', 
    'video', 
    true
  ),
  (
    'Dominada asistida supina', 
    'Bíceps y espalda', 
    'Máquina asistida', 
    'Con palmas hacia ti, sube hasta que la barbilla supere el agarre.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/025_dominada_asistida_supina.mp4', 
    'video', 
    true
  ),
  (
    'Remo invertido en Smith', 
    'Espalda', 
    'Máquina Smith', 
    'Sujétate de la barra fija con cuerpo alineado y eleva el pecho hacia la barra.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/027_remo_invertido_smith.mp4', 
    'video', 
    true
  ),
  (
    'Press militar con barra', 
    'Hombros y tríceps', 
    'Barra', 
    'Empuja la barra hacia arriba desde la parte superior del pecho con abdomen firme.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/029_press_militar_barra.mp4', 
    'video', 
    true
  ),
  (
    'Press militar en Smith', 
    'Hombros y tríceps', 
    'Máquina Smith', 
    'Usa la guía de la máquina Smith para realizar un empuje vertical controlado.', 
    'https://iqlxotcjmvixnisetpiy.supabase.co/storage/v1/object/public/exercise-videos/030_press_militar_smith.mp4', 
    'video', 
    true
  )
ON CONFLICT (name, equipment) DO UPDATE 
SET 
  media_url = EXCLUDED.media_url,
  instructions = EXCLUDED.instructions,
  media_type = EXCLUDED.media_type,
  is_active = EXCLUDED.is_active;
