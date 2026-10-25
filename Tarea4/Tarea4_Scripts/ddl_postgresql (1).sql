-- =====================================================================
-- Tarea 4 - Bases de Datos I
-- Red Social Estudiantil Pascualina - Modelo físico (DDL)
-- SGBD 1: PostgreSQL 17
-- Base de datos: red_social_pascualina | Esquema: red_social
--
-- Cambio frente a la Tarea 3: la tabla EVENTOS incluye la columna
-- detalles_json (JSONB) para datos semiestructurados (coordenadas del
-- lugar, aforo y lecturas de sensores de asistencia: caso IoT/Big Data).
--
-- Convenciones: minúscula y snake_case; tablas en plural; PK = id_<entidad>;
-- prefijos pk_, fk_, uq_, ck_ para restricciones e ix_ para índices.
-- Orden: tablas padre primero, tablas hijas después.
-- =====================================================================

DROP SCHEMA IF EXISTS red_social CASCADE;
CREATE SCHEMA red_social;
SET search_path TO red_social;

-- 1. USUARIOS
CREATE TABLE usuarios (
    id_usuario  INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre      VARCHAR(100) NOT NULL,
    correo      VARCHAR(150) NOT NULL,
    carrera     VARCHAR(80)  NOT NULL,
    CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuarios_correo UNIQUE (correo)
);

-- 2. INTERESES_HABILIDADES (catálogo)
CREATE TABLE intereses_habilidades (
    id_interes  INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre      VARCHAR(60) NOT NULL,
    CONSTRAINT pk_intereses_habilidades PRIMARY KEY (id_interes),
    CONSTRAINT uq_intereses_habilidades_nombre UNIQUE (nombre)
);

-- 3. PUBLICACIONES (publica 1:N con usuarios)
CREATE TABLE publicaciones (
    id_publicacion     INTEGER GENERATED ALWAYS AS IDENTITY,
    contenido          TEXT      NOT NULL,
    fecha_publicacion  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor   INTEGER   NOT NULL,
    CONSTRAINT pk_publicaciones PRIMARY KEY (id_publicacion),
    CONSTRAINT fk_publicaciones_usuarios FOREIGN KEY (id_usuario_autor)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 4. COMENTARIOS (escribe 1:N con usuarios, comenta_en 1:N con publicaciones)
CREATE TABLE comentarios (
    id_comentario     INTEGER GENERATED ALWAYS AS IDENTITY,
    contenido         VARCHAR(500) NOT NULL,
    id_usuario_autor  INTEGER      NOT NULL,
    id_publicacion    INTEGER      NOT NULL,
    CONSTRAINT pk_comentarios PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentarios_usuarios FOREIGN KEY (id_usuario_autor)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_comentarios_publicaciones FOREIGN KEY (id_publicacion)
        REFERENCES publicaciones (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 5. GRUPOS (crea 1:N con usuarios). Si se elimina el creador, el grupo se conserva.
CREATE TABLE grupos (
    id_grupo            INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre              VARCHAR(100) NOT NULL,
    descripcion         VARCHAR(300),
    id_usuario_creador  INTEGER,
    CONSTRAINT pk_grupos PRIMARY KEY (id_grupo),
    CONSTRAINT fk_grupos_usuarios FOREIGN KEY (id_usuario_creador)
        REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 6. EVENTOS (organiza 1:N con usuarios, programa 1:N opcional con grupos)
-- detalles_json: dato SEMIESTRUCTURADO (NoSQL dentro de SQL). Ejemplo:
-- {"ubicacion":{"lat":6.2776,"lng":-75.5686,"bloque":"Aula 204"},
--  "aforo_max":40,"sensor_asistencia":{"tipo":"QR","lecturas":32}}
-- JSONB: almacenamiento binario, permite índice GIN y consultas rápidas.
CREATE TABLE eventos (
    id_evento               INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre                  VARCHAR(100) NOT NULL,
    fecha_evento            TIMESTAMP    NOT NULL,
    lugar                   VARCHAR(150) NOT NULL,
    id_usuario_organizador  INTEGER,
    id_grupo                INTEGER,
    detalles_json           JSONB,
    CONSTRAINT pk_eventos PRIMARY KEY (id_evento),
    CONSTRAINT fk_eventos_usuarios FOREIGN KEY (id_usuario_organizador)
        REFERENCES usuarios (id_usuario)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_eventos_grupos FOREIGN KEY (id_grupo)
        REFERENCES grupos (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_eventos_detalles_objeto
        CHECK (detalles_json IS NULL OR jsonb_typeof(detalles_json) = 'object')
);

-- 7. USUARIOS_INTERESES (posee N:M)
CREATE TABLE usuarios_intereses (
    id_usuario  INTEGER NOT NULL,
    id_interes  INTEGER NOT NULL,
    CONSTRAINT pk_usuarios_intereses PRIMARY KEY (id_usuario, id_interes),
    CONSTRAINT fk_usuarios_intereses_usuarios FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_usuarios_intereses_intereses FOREIGN KEY (id_interes)
        REFERENCES intereses_habilidades (id_interes)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 8. SEGUIMIENTOS (sigue N:M reflexiva)
CREATE TABLE seguimientos (
    id_seguidor  INTEGER NOT NULL,
    id_seguido   INTEGER NOT NULL,
    CONSTRAINT pk_seguimientos PRIMARY KEY (id_seguidor, id_seguido),
    CONSTRAINT fk_seguimientos_seguidor FOREIGN KEY (id_seguidor)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_seguimientos_seguido FOREIGN KEY (id_seguido)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_seguimientos_no_autoseguir CHECK (id_seguidor <> id_seguido)
);

-- 9. MIEMBROS_GRUPO (pertenece_a N:M)
CREATE TABLE miembros_grupo (
    id_usuario  INTEGER NOT NULL,
    id_grupo    INTEGER NOT NULL,
    CONSTRAINT pk_miembros_grupo PRIMARY KEY (id_usuario, id_grupo),
    CONSTRAINT fk_miembros_grupo_usuarios FOREIGN KEY (id_usuario)
        REFERENCES usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_miembros_grupo_grupos FOREIGN KEY (id_grupo)
        REFERENCES grupos (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 10. ASISTENCIAS (asiste_a N:M)
CREATE TABLE asistencias (
    id_usuario  INTEGER NOT NULL,
    id_evento   INTEGER NOT NULL,
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

-- Índice GIN para consultas dentro del JSON (operadores @>, ?, etc.)
CREATE INDEX ix_eventos_detalles_json ON eventos USING GIN (detalles_json);

-- ---------------------------------------------------------------------
-- PRUEBA DEL CAMPO JSON (evidencia para el informe)
-- ---------------------------------------------------------------------
INSERT INTO usuarios (nombre, correo, carrera)
VALUES ('Julián Quintero', 'julian@correo.com', 'Ingeniería de Software');

INSERT INTO eventos (nombre, fecha_evento, lugar, id_usuario_organizador, detalles_json)
VALUES ('Taller de SQL', '2026-11-05 14:00', 'Pascual Bravo', 1,
 '{"ubicacion":{"lat":6.2776,"lng":-75.5686,"bloque":"Aula 204"},"aforo_max":40,"sensor_asistencia":{"tipo":"QR","lecturas":32}}');

SELECT nombre,
       detalles_json->'ubicacion'->>'bloque' AS bloque,
       (detalles_json->>'aforo_max')::INT    AS aforo_max
FROM eventos
WHERE detalles_json @> '{"sensor_asistencia":{"tipo":"QR"}}';
