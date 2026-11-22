-- =====================================================================
-- TAREA 6 - ARQUITECTURA HÍBRIDA (RELACIONAL + JSONB + IoT)
-- Script 04: DML (carga de datos de prueba y consultas sobre JSONB / IoT)
-- Base de datos: red_social_pascualina | Esquema: red_social
-- Requiere haber ejecutado antes 03_ddl_hibrido.sql
-- Todos los datos son ficticios y generados para pruebas.
-- =====================================================================

SET search_path TO red_social;

-- =====================================================================
-- PARTE 1. CARGA DE DATOS DE PRUEBA
-- =====================================================================

-- 1.1 Multimedia de las publicaciones (JSONB con objeto, arreglo de archivos y hashtags)
UPDATE publicaciones p
SET multimedia = v.m::jsonb
FROM (VALUES
 (1, '{"tipo":"imagen","archivos":[{"url":"img/diagrama_join.png","formato":"png","tamano_kb":310}],"hashtags":["bd","sql"],"visibilidad":"publica"}'),
 (2, '{"tipo":"documento","archivos":[{"url":"docs/practica_programacion.pdf","formato":"pdf","tamano_kb":1250}],"hashtags":["programacion","recursos"],"visibilidad":"publica"}'),
 (3, '{"tipo":"enlace","archivos":[],"hashtags":["ia","noticias"],"visibilidad":"publica"}'),
 (4, '{"tipo":"imagen","archivos":[{"url":"img/meme_compilar.png","formato":"png","tamano_kb":180}],"hashtags":["meme","programacion"],"visibilidad":"publica"}'),
 (5, '{"tipo":"imagen","archivos":[{"url":"img/afiche_hackaton.jpg","formato":"jpg","tamano_kb":420}],"hashtags":["hackaton","equipo","programacion"],"visibilidad":"publica"}'),
 (6, '{"tipo":"video","archivos":[{"url":"vid/tutorial_sql.mp4","formato":"mp4","tamano_kb":5200}],"hashtags":["bd","tutorial"],"visibilidad":"grupo"}'),
 (7, '{"tipo":"imagen","archivos":[{"url":"img/campus_1.jpg","formato":"jpg","tamano_kb":640},{"url":"img/campus_2.jpg","formato":"jpg","tamano_kb":580}],"hashtags":["campus","fotos"],"visibilidad":"publica"}'),
 (8, '{"tipo":"video","archivos":[{"url":"vid/torneo.mp4","formato":"mp4","tamano_kb":8300}],"hashtags":["videojuegos","torneo"],"visibilidad":"publica"}'),
 (9, '{"tipo":"ninguno","archivos":[],"hashtags":["hackaton","campus"],"visibilidad":"publica"}')
) AS v(id, m)
WHERE p.id_publicacion = v.id;

-- 1.2 Preferencias de usuario (objeto JSON anidado)
UPDATE usuarios
SET preferencias = jsonb_build_object(
        'tema',    CASE WHEN id_usuario % 2 = 0 THEN 'oscuro' ELSE 'claro' END,
        'idioma',  'es',
        'notificaciones', jsonb_build_object(
                'correo', (id_usuario % 3 <> 0),
                'push',   true));

-- 1.3 Sensores: uno de ocupación por cada lugar donde hay eventos y dos de
--     temperatura. La ubicación se toma de eventos.lugar para poder hacer JOIN.
INSERT INTO sensores (codigo, tipo, ubicacion)
SELECT 'OCU-EV' || LPAD(e.id_evento::text, 2, '0'), 'ocupacion', e.lugar
FROM eventos e
WHERE e.lugar IS NOT NULL
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO sensores (codigo, tipo, ubicacion)
SELECT 'TEMP-EV' || LPAD(e.id_evento::text, 2, '0'), 'temperatura', e.lugar
FROM eventos e
WHERE e.id_evento IN (2, 3) AND e.lugar IS NOT NULL
ON CONFLICT (codigo) DO NOTHING;

-- 1.4 Lecturas IoT masivas: una lectura cada 5 minutos por sensor durante
--     casi todo noviembre (~55.000 filas). Simula el volumen típico de IoT.
--     Se vacían solo las tablas nuevas para poder repetir el script sin duplicar.
TRUNCATE TABLE lecturas_sensores, logs_actividad RESTART IDENTITY;

INSERT INTO lecturas_sensores (id_sensor, fecha_hora, datos)
SELECT s.id_sensor,
       t.ts,
       CASE s.tipo
         WHEN 'ocupacion' THEN jsonb_build_object(
              -- De día (8-17h) hay más personas que de noche
              'personas',  floor(random() * CASE WHEN EXTRACT(HOUR FROM t.ts) BETWEEN 8 AND 17
                                                 THEN 40 ELSE 8 END)::int,
              'capacidad', 40,
              'bateria',   round((60 + random() * 40)::numeric, 1))
         ELSE jsonb_build_object(
              'temp_c',  round((20 + random() * 8)::numeric, 1),
              'humedad', round((45 + random() * 30)::numeric, 1),
              'bateria', round((60 + random() * 40)::numeric, 1))
       END
FROM sensores s
CROSS JOIN generate_series(timestamp '2026-11-01 06:00',
                           timestamp '2026-11-28 22:00',
                           interval '5 minutes') AS t(ts);

-- 1.5 Logs de actividad: 20.000 acciones de usuarios reales de la tabla usuarios.
--     Cerca del 0,5 % incluye la clave "error" (permite una búsqueda muy selectiva).
WITH ids AS (SELECT array_agg(id_usuario) AS arr FROM usuarios)
INSERT INTO logs_actividad (id_usuario, tipo_accion, fecha_hora, detalle)
SELECT ids.arr[1 + floor(random() * array_length(ids.arr, 1))::int],
       (ARRAY['login','like','comentario','busqueda','ver_evento'])[1 + floor(random() * 5)::int],
       timestamp '2026-11-01 00:00' + random() * interval '27 days',
       jsonb_build_object(
            'dispositivo',  (ARRAY['movil','web','tablet'])[1 + floor(random() * 3)::int],
            'duracion_seg', floor(random() * 600)::int,
            'red',          'campus-wifi')
       || CASE WHEN random() < 0.005 THEN jsonb_build_object('error', 'timeout')
               ELSE '{}'::jsonb END
FROM ids, generate_series(1, 20000);

-- Actualiza estadísticas para que el optimizador use bien los índices
ANALYZE publicaciones;
ANALYZE logs_actividad;
ANALYZE lecturas_sensores;

-- Captura 1: volumen de datos cargado
SELECT 'sensores' AS tabla, COUNT(*) AS total_filas FROM sensores
UNION ALL SELECT 'lecturas_sensores', COUNT(*) FROM lecturas_sensores
UNION ALL SELECT 'logs_actividad',    COUNT(*) FROM logs_actividad;

-- Captura 2: filas por partición mensual (tableoid indica la partición física)
SELECT tableoid::regclass AS particion, COUNT(*) AS total_filas
FROM lecturas_sensores
GROUP BY tableoid
ORDER BY 1;

-- =====================================================================
-- PARTE 2. CONSULTAS SOBRE DATOS SEMIESTRUCTURADOS (JSONB) E IoT
-- Operadores usados:
--   ->   obtiene un elemento JSON (resultado: jsonb)
--   ->>  obtiene un elemento como texto
--   @>   contención: ¿el JSON de la izquierda contiene al de la derecha? (usa GIN)
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONSULTA 1: Hashtags más usados
-- Pregunta de negocio: ¿qué temas están de moda entre los estudiantes?
-- Técnica: desanidar el arreglo JSON de hashtags con jsonb_array_elements_text.
-- ---------------------------------------------------------------------
SELECT
    h.hashtag AS hashtag,
    COUNT(*)  AS total_publicaciones
FROM publicaciones p
CROSS JOIN LATERAL jsonb_array_elements_text(p.multimedia -> 'hashtags') AS h(hashtag)
GROUP BY h.hashtag
ORDER BY total_publicaciones DESC, hashtag;

-- ---------------------------------------------------------------------
-- CONSULTA 2: Peso del contenido multimedia por carrera
-- Pregunta de negocio: ¿cuánto almacenamiento consume cada carrera?
-- Técnica: JOIN con usuarios + desanidar archivos + SUM/COUNT/GROUP BY.
-- ---------------------------------------------------------------------
SELECT
    u.carrera                                              AS carrera,
    COUNT(DISTINCT p.id_publicacion)                       AS total_publicaciones,
    COUNT(a.archivo)                                       AS total_archivos,
    COALESCE(SUM((a.archivo ->> 'tamano_kb')::int), 0)     AS total_kb
FROM publicaciones p
JOIN usuarios u ON u.id_usuario = p.id_usuario_autor
LEFT JOIN LATERAL jsonb_array_elements(p.multimedia -> 'archivos') AS a(archivo) ON true
GROUP BY u.carrera
ORDER BY total_kb DESC, carrera;

-- ---------------------------------------------------------------------
-- CONSULTA 3: Publicaciones del hashtag #hackaton y su conversación
-- Pregunta de negocio: ¿qué tanto comentan las publicaciones de hackatón?
-- Técnica: filtro por contención @> (apoyado por el índice GIN
--          idx_publicaciones_multimedia_gin) + JOIN + COUNT.
-- ---------------------------------------------------------------------
SELECT
    p.id_publicacion                 AS id_publicacion,
    p.multimedia ->> 'tipo'          AS tipo_contenido,
    u.nombre                         AS autor,
    COUNT(c.id_comentario)           AS total_comentarios
FROM publicaciones p
JOIN usuarios u ON u.id_usuario = p.id_usuario_autor
LEFT JOIN comentarios c ON c.id_publicacion = p.id_publicacion
WHERE p.multimedia @> '{"hashtags": ["hackaton"]}'
GROUP BY p.id_publicacion, p.multimedia ->> 'tipo', u.nombre
ORDER BY total_comentarios DESC, p.id_publicacion;

-- ---------------------------------------------------------------------
-- CONSULTA 4: Uso de dispositivos por estudiante (logs de actividad)
-- Pregunta de negocio: ¿desde qué dispositivo interactúa cada estudiante y
--                      cuánto dura en promedio cada sesión de acción?
-- Técnica: campos del JSON del log + JOIN + COUNT/AVG/GROUP BY.
-- ---------------------------------------------------------------------
SELECT
    u.nombre                                                   AS estudiante,
    l.detalle ->> 'dispositivo'                                AS dispositivo,
    COUNT(*)                                                   AS total_acciones,
    ROUND(AVG((l.detalle ->> 'duracion_seg')::numeric), 1)     AS promedio_duracion_seg
FROM logs_actividad l
JOIN usuarios u ON u.id_usuario = l.id_usuario
GROUP BY u.id_usuario, u.nombre, l.detalle ->> 'dispositivo'
ORDER BY total_acciones DESC, estudiante, dispositivo
LIMIT 10;

-- ---------------------------------------------------------------------
-- CONSULTA 5: Estudiantes que sufren más errores de la plataforma
-- Pregunta de negocio: ¿a quiénes les fallan más las acciones (timeout)?
-- Técnica: búsqueda selectiva con @> sobre 20.000 logs (índice GIN
--          idx_logs_detalle_gin) + JOIN + COUNT.
-- ---------------------------------------------------------------------
SELECT
    u.nombre   AS estudiante,
    COUNT(*)   AS total_errores
FROM logs_actividad l
JOIN usuarios u ON u.id_usuario = l.id_usuario
WHERE l.detalle @> '{"error": "timeout"}'
GROUP BY u.id_usuario, u.nombre
ORDER BY total_errores DESC, estudiante;

-- ---------------------------------------------------------------------
-- CONSULTA 6: Ocupación del lugar durante cada evento (IoT + relacional)
-- Pregunta de negocio: ¿los sensores del campus confirman la asistencia
--                      registrada de cada evento?
-- Técnica: cruza eventos, sensores y lecturas_sensores (JSONB) usando la
--          ubicación; la CTE calcula por separado asistentes y ocupación
--          para evitar el doble conteo. Ventana: las 2 horas del evento.
-- ---------------------------------------------------------------------
WITH ocupacion_evento AS (
    SELECT
        e.id_evento,
        ROUND(AVG((l.datos ->> 'personas')::numeric), 1) AS promedio_personas,
        MAX((l.datos ->> 'personas')::int)               AS maximo_personas,
        COUNT(*)                                         AS total_lecturas
    FROM eventos e
    JOIN sensores s ON s.ubicacion = e.lugar AND s.tipo = 'ocupacion'
    JOIN lecturas_sensores l
         ON l.id_sensor = s.id_sensor
        AND l.fecha_hora >= e.fecha_evento
        AND l.fecha_hora <  e.fecha_evento + interval '2 hours'
    GROUP BY e.id_evento
),
asistentes AS (
    SELECT id_evento, COUNT(*) AS total_asistentes
    FROM asistencias
    GROUP BY id_evento
)
SELECT
    e.nombre                              AS evento,
    e.lugar                               AS lugar,
    COALESCE(a.total_asistentes, 0)       AS total_asistentes,
    o.promedio_personas                   AS promedio_personas,
    o.maximo_personas                     AS maximo_personas,
    o.total_lecturas                      AS total_lecturas
FROM eventos e
LEFT JOIN asistentes a        ON a.id_evento = e.id_evento
LEFT JOIN ocupacion_evento o  ON o.id_evento = e.id_evento
ORDER BY e.fecha_evento;

-- =====================================================================
-- PARTE 3. EVIDENCIA DE OPTIMIZACIÓN (tomar captura de cada EXPLAIN)
-- =====================================================================

-- EXPLAIN A: el índice GIN se usa en la búsqueda dentro del JSONB.
-- Se espera ver "Bitmap Index Scan on idx_logs_detalle_gin".
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM logs_actividad
WHERE detalle @> '{"error": "timeout"}';

-- EXPLAIN B: partition pruning. Al filtrar un solo día de noviembre,
-- PostgreSQL solo recorre la partición lecturas_2026_11 y descarta las demás.
EXPLAIN (ANALYZE)
SELECT COUNT(*) FROM lecturas_sensores
WHERE fecha_hora >= '2026-11-10' AND fecha_hora < '2026-11-11';
