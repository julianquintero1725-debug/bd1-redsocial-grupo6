-- =====================================================================
-- Tarea 4 - Bases de Datos I
-- Red Social Estudiantil Pascualina - Modelo físico (DDL)
-- SGBD 2: MySQL 8.0 (requiere 8.0.16+ para que CHECK se aplique)
--
-- Diferencias frente a PostgreSQL:
--   * En MySQL "esquema" y "base de datos" son lo mismo (no hay SET search_path).
--   * IDENTITY -> AUTO_INCREMENT; TIMESTAMP -> DATETIME; JSONB -> JSON.
--   * MySQL no permite un CHECK sobre columnas con ON UPDATE CASCADE
--     (error 3823), por eso seguimientos usa ON UPDATE RESTRICT.
--   * El tipo JSON valida el formato automáticamente.
-- =====================================================================

DROP DATABASE IF EXISTS red_social_pascualina;
CREATE DATABASE red_social_pascualina CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE red_social_pascualina;

-- 1. USUARIOS
CREATE TABLE usuarios (
    id_usuario  INT AUTO_INCREMENT,
    nombre      VARCHAR(100) NOT NULL,
    correo      VARCHAR(150) NOT NULL,
    carrera     VARCHAR(80)  NOT NULL,
    CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuarios_correo UNIQUE (correo)
);

-- 2. INTERESES_HABILIDADES (catálogo)
CREATE TABLE intereses_habilidades (
    id_interes  INT AUTO_INCREMENT,
    nombre      VARCHAR(60) NOT NULL,
    CONSTRAINT pk_intereses_habilidades PRIMARY KEY (id_interes),
    CONSTRAINT uq_intereses_habilidades_nombre UNIQUE (nombre)
);

-- 3. PUBLICACIONES
CREATE TABLE publicaciones (
    id_publicacion     INT AUTO_INCREMENT,
    contenido          TEXT     NOT NULL,
    fecha_publicacion  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor   INT      NOT NULL,
    CONSTRAINT pk_publicaciones PRIMARY KEY (id_publicacion),
    CONSTRAINT fk_publicaciones_usuarios FOREIGN KEY (id_usuario_autor)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 4. COMENTARIOS
CREATE TABLE comentarios (
    id_comentario     INT AUTO_INCREMENT,
    contenido         VARCHAR(500) NOT NULL,
    id_usuario_autor  INT          NOT NULL,
    id_publicacion    INT          NOT NULL,
    CONSTRAINT pk_comentarios PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentarios_usuarios FOREIGN KEY (id_usuario_autor)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_comentarios_publicaciones FOREIGN KEY (id_publicacion)
        REFERENCES publicaciones (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 5. GRUPOS
CREATE TABLE grupos (
    id_grupo            INT AUTO_INCREMENT,
    nombre              VARCHAR(100) NOT NULL,
    descripcion         VARCHAR(300),
    id_usuario_creador  INT,
    CONSTRAINT pk_grupos PRIMARY KEY (id_grupo),
    CONSTRAINT fk_grupos_usuarios FOREIGN KEY (id_usuario_creador)
        REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 6. EVENTOS
-- detalles_json: dato SEMIESTRUCTURADO (coordenadas, aforo, sensores IoT).
-- El tipo JSON de MySQL valida el formato y lo guarda en binario optimizado.
CREATE TABLE eventos (
    id_evento               INT AUTO_INCREMENT,
    nombre                  VARCHAR(100) NOT NULL,
    fecha_evento            DATETIME     NOT NULL,
    lugar                   VARCHAR(150) NOT NULL,
    id_usuario_organizador  INT,
    id_grupo                INT,
    detalles_json           JSON,
    CONSTRAINT pk_eventos PRIMARY KEY (id_evento),
    CONSTRAINT fk_eventos_usuarios FOREIGN KEY (id_usuario_organizador)
        REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_eventos_grupos FOREIGN KEY (id_grupo)
        REFERENCES grupos (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 7. USUARIOS_INTERESES
CREATE TABLE usuarios_intereses (
    id_usuario  INT NOT NULL,
    id_interes  INT NOT NULL,
    CONSTRAINT pk_usuarios_intereses PRIMARY KEY (id_usuario, id_interes),
    CONSTRAINT fk_usuarios_intereses_usuarios FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_usuarios_intereses_intereses FOREIGN KEY (id_interes)
        REFERENCES intereses_habilidades (id_interes)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 8. SEGUIMIENTOS
-- ON UPDATE RESTRICT: MySQL prohíbe CHECK sobre columnas con ON UPDATE CASCADE.
-- Como id_usuario es AUTO_INCREMENT y no cambia, no se pierde funcionalidad.
CREATE TABLE seguimientos (
    id_seguidor  INT NOT NULL,
    id_seguido   INT NOT NULL,
    CONSTRAINT pk_seguimientos PRIMARY KEY (id_seguidor, id_seguido),
    CONSTRAINT fk_seguimientos_seguidor FOREIGN KEY (id_seguidor)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_seguimientos_seguido FOREIGN KEY (id_seguido)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT ck_seguimientos_no_autoseguir CHECK (id_seguidor <> id_seguido)
);

-- 9. MIEMBROS_GRUPO
CREATE TABLE miembros_grupo (
    id_usuario  INT NOT NULL,
    id_grupo    INT NOT NULL,
    CONSTRAINT pk_miembros_grupo PRIMARY KEY (id_usuario, id_grupo),
    CONSTRAINT fk_miembros_grupo_usuarios FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_miembros_grupo_grupos FOREIGN KEY (id_grupo)
        REFERENCES grupos (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 10. ASISTENCIAS
CREATE TABLE asistencias (
    id_usuario  INT NOT NULL,
    id_evento   INT NOT NULL,
    CONSTRAINT pk_asistencias PRIMARY KEY (id_usuario, id_evento),
    CONSTRAINT fk_asistencias_usuarios FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_asistencias_eventos FOREIGN KEY (id_evento)
        REFERENCES eventos (id_evento)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Índices sobre claves foráneas de uso frecuente
CREATE INDEX ix_publicaciones_id_usuario_autor ON publicaciones (id_usuario_autor);
CREATE INDEX ix_comentarios_id_publicacion ON comentarios (id_publicacion);
CREATE INDEX ix_comentarios_id_usuario_autor ON comentarios (id_usuario_autor);
CREATE INDEX ix_eventos_id_grupo ON eventos (id_grupo);
CREATE INDEX ix_seguimientos_id_seguido ON seguimientos (id_seguido);

-- ---------------------------------------------------------------------
-- PRUEBA DEL CAMPO JSON
-- ---------------------------------------------------------------------
INSERT INTO usuarios (nombre, correo, carrera)
VALUES ('Julián Quintero', 'julian@correo.com', 'Ingeniería de Software');

INSERT INTO eventos (nombre, fecha_evento, lugar, id_usuario_organizador, detalles_json)
VALUES ('Taller de SQL', '2026-11-05 14:00:00', 'Pascual Bravo', 1,
 '{"ubicacion":{"lat":6.2776,"lng":-75.5686,"bloque":"Aula 204"},"aforo_max":40,"sensor_asistencia":{"tipo":"QR","lecturas":32}}');

SELECT nombre,
       JSON_UNQUOTE(JSON_EXTRACT(detalles_json, '$.ubicacion.bloque')) AS bloque,
       JSON_EXTRACT(detalles_json, '$.aforo_max') AS aforo_max
FROM eventos
WHERE JSON_UNQUOTE(JSON_EXTRACT(detalles_json, '$.sensor_asistencia.tipo')) = 'QR';
