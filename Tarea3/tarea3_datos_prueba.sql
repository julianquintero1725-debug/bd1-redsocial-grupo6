-- =====================================================================
-- Tarea 3 - Datos de prueba y consultas de verificación
-- Ejecutar DESPUÉS de tarea3_red_social_pascualina.sql
-- =====================================================================
SET search_path TO red_social;

-- ---------------------------------------------------------------------
-- 1. Datos de prueba
-- Primero se vacían las tablas y se reinician los contadores de identidad,
-- porque los ids de los datos de prueba asumen que empiezan en 1.
-- ---------------------------------------------------------------------
TRUNCATE usuarios, intereses_habilidades RESTART IDENTITY CASCADE;

INSERT INTO usuarios (nombre, correo, carrera) VALUES
    ('Ana Gómez',     'ana.gomez@pascualbravo.edu.co',     'Ingeniería de Software'),
    ('Carlos Ruiz',   'carlos.ruiz@pascualbravo.edu.co',   'Ingeniería de Software'),
    ('Laura Pérez',   'laura.perez@pascualbravo.edu.co',   'Ingeniería Eléctrica'),
    ('Mateo Londoño', 'mateo.londono@pascualbravo.edu.co', 'Ingeniería Mecánica');

INSERT INTO intereses_habilidades (nombre) VALUES
    ('Programación'), ('Fútbol'), ('Videojuegos'), ('Cálculo');

INSERT INTO usuarios_intereses (id_usuario, id_interes) VALUES
    (1, 1), (1, 3), (2, 1), (2, 2), (3, 4), (4, 2);

INSERT INTO seguimientos (id_seguidor, id_seguido) VALUES
    (1, 2), (2, 1), (3, 1), (4, 2);

INSERT INTO publicaciones (contenido, id_usuario_autor) VALUES
    ('¿Alguien tiene apuntes de Bases de Datos I?', 1),
    ('Comparto una guía de PostgreSQL para el curso', 2),
    ('Meme del parcial de cálculo', 3);

INSERT INTO comentarios (contenido, id_usuario_autor, id_publicacion) VALUES
    ('Yo tengo, te los paso', 2, 1),
    ('Gracias por la guía', 1, 2),
    ('Jajaja muy bueno', 4, 3);

INSERT INTO grupos (nombre, descripcion, id_usuario_creador) VALUES
    ('Estudio Bases de Datos', 'Grupo para preparar parciales de BD', 1),
    ('Club de Videojuegos', 'Torneos y reuniones casuales', 2);

INSERT INTO miembros_grupo (id_usuario, id_grupo) VALUES
    (1, 1), (2, 1), (3, 1), (2, 2), (4, 2);

INSERT INTO eventos (nombre, fecha_evento, lugar, id_usuario_organizador, id_grupo) VALUES
    ('Sesión de estudio SQL', '2026-10-25 15:00', 'Biblioteca', 1, 1),
    ('Torneo de FIFA',        '2026-11-02 17:00', 'Sala de cómputo', 2, 2),
    ('Charla abierta de carreras', '2026-11-10 10:00', 'Auditorio', 3, NULL);

INSERT INTO asistencias (id_usuario, id_evento) VALUES
    (1, 1), (2, 1), (3, 1), (2, 2), (4, 2), (1, 3);

-- ---------------------------------------------------------------------
-- 2. Consultas de verificación (muestran que las relaciones funcionan)
-- ---------------------------------------------------------------------

-- 2.1 Publicaciones con su autor (relación publica 1:N)
SELECT p.id_publicacion, u.nombre AS autor, p.contenido
FROM publicaciones p
JOIN usuarios u ON u.id_usuario = p.id_usuario_autor;

-- 2.2 Comentarios con autor y publicación (escribe y comenta_en)
SELECT c.contenido AS comentario, u.nombre AS autor_comentario, p.contenido AS publicacion
FROM comentarios c
JOIN usuarios u ON u.id_usuario = c.id_usuario_autor
JOIN publicaciones p ON p.id_publicacion = c.id_publicacion;

-- 2.3 Intereses de cada usuario (relación posee N:M)
SELECT u.nombre, i.nombre AS interes
FROM usuarios_intereses ui
JOIN usuarios u ON u.id_usuario = ui.id_usuario
JOIN intereses_habilidades i ON i.id_interes = ui.id_interes
ORDER BY u.nombre;

-- 2.4 Quién sigue a quién (relación reflexiva)
SELECT seguidor.nombre AS seguidor, seguido.nombre AS seguido
FROM seguimientos s
JOIN usuarios seguidor ON seguidor.id_usuario = s.id_seguidor
JOIN usuarios seguido  ON seguido.id_usuario  = s.id_seguido;

-- 2.5 Miembros de cada grupo (relación pertenece_a N:M)
SELECT g.nombre AS grupo, u.nombre AS miembro
FROM miembros_grupo m
JOIN grupos g ON g.id_grupo = m.id_grupo
JOIN usuarios u ON u.id_usuario = m.id_usuario
ORDER BY g.nombre;

-- 2.6 Eventos con organizador y grupo (LEFT JOIN: el grupo es opcional)
SELECT e.nombre AS evento, u.nombre AS organizador, g.nombre AS grupo
FROM eventos e
LEFT JOIN usuarios u ON u.id_usuario = e.id_usuario_organizador
LEFT JOIN grupos g ON g.id_grupo = e.id_grupo;

-- 2.7 Asistentes por evento (relación asiste_a N:M)
SELECT e.nombre AS evento, COUNT(a.id_usuario) AS asistentes
FROM eventos e
LEFT JOIN asistencias a ON a.id_evento = e.id_evento
GROUP BY e.nombre;

-- ---------------------------------------------------------------------
-- 3. Prueba de ON DELETE (dentro de una transacción que se deshace)
-- Ejecutar este bloque completo, de BEGIN a ROLLBACK.
-- ---------------------------------------------------------------------
BEGIN;

-- Antes: publicaciones del usuario 1
SELECT 'publicaciones de Ana (antes)' AS prueba, COUNT(*) FROM publicaciones WHERE id_usuario_autor = 1;

DELETE FROM usuarios WHERE id_usuario = 1;

-- CASCADE: sus publicaciones desaparecen
SELECT 'publicaciones de Ana (despues)' AS prueba, COUNT(*) FROM publicaciones WHERE id_usuario_autor = 1;

-- SET NULL: el grupo que creó se conserva, con creador NULL
SELECT id_grupo, nombre, id_usuario_creador FROM grupos WHERE id_grupo = 1;

ROLLBACK;  -- deshace el borrado, los datos quedan intactos

-- ---------------------------------------------------------------------
-- 4. Pruebas de restricciones (cada una DEBE dar error; ejecutar de una en una)
-- ---------------------------------------------------------------------
-- 4.1 Correo duplicado (viola uq_usuarios_correo):
-- INSERT INTO usuarios (nombre, correo, carrera)
-- VALUES ('Otro', 'ana.gomez@pascualbravo.edu.co', 'Ingeniería Civil');

-- 4.2 FK inexistente (viola fk_publicaciones_usuarios):
-- INSERT INTO publicaciones (contenido, id_usuario_autor) VALUES ('Hola', 999);

-- 4.3 Autoseguimiento (viola ck_seguimientos_no_autoseguir):
-- INSERT INTO seguimientos (id_seguidor, id_seguido) VALUES (1, 1);
