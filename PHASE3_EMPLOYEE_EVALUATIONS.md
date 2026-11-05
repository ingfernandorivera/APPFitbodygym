# Fase 3 · Evaluaciones de empleados · 2026-11-05

## Estado
Implementado en código de desarrollo. NO aplicado a Supabase ni publicado.
No se modificó el sistema administrativo activo, sus bases de datos, caja, cuentas, turnos o biometría.

## Fuente móvil autorizada por Fernando
C:/Users/nancy/Desktop/APPFitbodygym-main/APPFitbodygym-main
No usar otras copias antiguas de appfitbodygym para esta entrega.
Se conservaron los avances existentes de entrenamiento, perfil e IA.
El ZIP original del Escritorio no se modificó.

## Flujo
Inicio → Evaluar atención → seleccionar turno/empleado → tres preguntas → envío confirmado.
Asignaciones confirmadas por Fernando:
- Mañana: Cristabel (cristabel/morning).
- Tarde/noche: Adilene (adilene/evening).
- Domingo: Domingo (domingo/sunday).

Preguntas (escala 1 muy mala, 2 mala, 3 regular, 4 buena, 5 excelente):
1. ¿Cómo calificas la amabilidad y atención que recibes?
2. ¿Qué tan disponible está para ayudarte cuando necesitas apoyo del entrenador?
3. ¿Qué tan proactivo es al ofrecer ayuda a clientes nuevos y antiguos?

Se exige responder las tres. Sin respuestas preseleccionadas.
Regla implementada/propuesta: una evaluación por cliente, empleado y mes.
Mes calculado en servidor con America/El_Salvador; no depende del reloj del teléfono.
No se permite editar una evaluación enviada en esta primera versión.
Vista previa deshabilita los envíos y no inicializa Supabase.

## Dashboard
Clientes (vista retention existente) conserva análisis de retención y agrega
“Evaluaciones de empleados”: filtro mensual, tres fichas por nombre, cantidad,
promedio general y promedio por pregunta, escala 1–5. Estado sin respuestas NO
se presenta como calificación cero. Incluye carga, errores y reintento.

No muestra identidad de los clientes ni clasifica ventas como calidad de atención.
No se rehízo el panel de caja ni los cálculos existentes por empleado.

## Archivos modificados/agregados
Móvil:
- lib/features/home/pages/home_page.dart
- lib/features/membership/pages/membership_page.dart
- lib/features/employee_evaluations/data/employee_evaluation_repository.dart
- lib/features/employee_evaluations/pages/employee_evaluation_page.dart
- test/employee_evaluation_test.dart
- supabase/migrations/20261105_employee_evaluations.sql

Dashboard:
- src/App.tsx (import y render en Clientes)
- src/styles.css (reglas aisladas .employee-evaluations)
- src/EmployeeEvaluations.tsx
- supabase/008_employee_evaluations.sql
- qa/employee-evaluations-contract.cjs

Los dos archivos SQL son LA MISMA migración: ejecutar solo UNO, una vez.
La migración es aditiva, no altera tablas existentes. No es idempotente: si la
tabla ya existe debe revisarse el historial antes de ejecutar.

## Seguridad y conservación
- Miembros autenticados con member_profiles pueden insertar sus respuestas.
- Identidad, mes y fecha se generan en servidor; el cliente no tiene permiso
  para insertar esas columnas.
- Restricciones SQL validan notas, combinación empleado/turno y duplicados.
- Miembros solo pueden leer sus propias respuestas; no pueden editarlas/borrarlas.
- Resumen exclusivamente vía RPC employee_evaluation_summary(p_month).
- RPC verifica is_dashboard_owner(), de acuerdo con el acceso actual del Dashboard.
- Al borrar una cuenta auth se elimina su vínculo, NO sus notas históricas.
- No se promete anonimato absoluto: cada respuesta se vincula a una cuenta para
  evitar duplicados; la interfaz del dueño muestra exclusivamente agregados.

## Verificación realizada
Copia aislada de la fuente móvil del Escritorio en:
C:/Users/PC/Desktop/phase3-evaluations-qa-20261105/mobile
y Dashboard en .../dashboard, sin reutilizar la app móvil antigua como fuente.

- Flutter: 7 pruebas aprobadas (3 nuevas, más pruebas existentes de login/membresía).
- Dart analyze de módulo nuevo y prueba nueva: sin incidencias.
- Análisis completo: advertencia preexistente en ai_chat_page.dart:2230
  (unnecessary_non_null_assertion); no se modificó ese archivo de Fernando.
- Dashboard: npm run build aprobado (TypeScript + Vite).
- SQL: 15 comprobaciones aprobadas en PostgreSQL aislado PGlite con usuarios ficticios:
  inserción válida, duplicados, notas fuera de escala, turno incorrecto, suplantación,
  mes manipulado, no-miembro, lectura ajena, resumen no autorizado, borrado bloqueado,
  resumen correcto, mes inválido, acceso anónimo y conservación al borrar una cuenta.
- No se ejecutó SQL contra Supabase real.
- No hay prueba extremo a extremo con sesiones reales ni inspección visual del
  Dashboard publicado; ambas requieren activación.
- Compilación web completa de Flutter intentada en QA, excedió límite de ejecución;
  se detuvieron únicamente sus compiladores QA. No se entrega ese build parcial
  como una versión publicable.
- QA resolvió dependencias de móvil desde lock del Escritorio; SDK Flutter 3.44.8 /
  Dart 3.12.2 ajustó 4 dependencias de herramientas de prueba solo en QA.
  Dashboard QA resolvió dependencias de package.json sin alterar lock del proyecto.

## Activación pendiente (requiere autorización para afectar Supabase/publicación)
1. Confirmar que la configuración real de ambas apps apunta al MISMO proyecto Supabase
   y que allí existen member_profiles, dashboard_owners e is_dashboard_owner().
2. Revisar regla mensual y asignaciones antes de activar; los nombres ya confirmados
   están validados por SQL y no son inferidos de los registros de caja.
3. Aplicar UNA migración SQL en ese proyecto.
4. Probar con miembro y dueño reales: envío, resumen, otro cliente sin lectura ajena,
   duplicado rechazado. No generar votos de prueba mezclados con resultados reales.
5. Compilar la app móvil en la PC principal con sus assets y configuración actual;
   validar visualmente Inicio → turno → notas → confirmación.
6. Empaquetar/publicar Dashboard manteniendo su URL y caché del service worker,
   y publicar/distribuir móvil por su canal actual, previa autorización.
7. Guardar en Git las versiones exactas y documentar commits/artefactos si Fernando lo solicita.

## Reversión
Antes de activar basta revertir los imports/render y los archivos nuevos.
Después de recibir votos, no borrar la tabla para “deshacer”: retirar los puntos
de entrada y conservar/exportar las respuestas. Cualquier borrado requiere revisión.

## Verificación local adicional 2026-11-05 (PC principal)
- Dashboard: `npm run build` aprobado.
- SQL aislado PGlite: 15/15 comprobaciones aprobadas; no ejecutado contra Supabase real.
- Flutter: 7/7 pruebas aprobadas (encuesta, acceso y membresía).
- Flutter analyze del módulo de evaluaciones y su prueba: sin incidencias.
- Flutter web release: compilación completa aprobada. Este artefacto QA no incluye configuración real de Supabase y no se publicó.
- Ambas migraciones SQL son idénticas (SHA256 EC6966BAC7B5C63D7EB8B6649673641204AE84753F43DFE592B728CCB5000CD5).
- Entrega Git preparada en rama `phase3-employee-evaluations` de cada repositorio, sin modificar `main` ni activar el despliegue automático de GitHub Pages.
- La validación extremo a extremo con cuentas reales y la activación de Supabase siguen pendientes.
