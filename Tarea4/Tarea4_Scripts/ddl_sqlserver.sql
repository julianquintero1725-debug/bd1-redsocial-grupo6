-- =====================================================================
-- Tarea 4 - Bases de Datos I
-- Red Social Estudiantil Pascualina - Modelo físico (DDL)
-- SGBD 3: Microsoft SQL Server (T-SQL)
--
-- Diferencias frente a PostgreSQL:
--   * IDENTITY(1,1) para autonumérico; VARCHAR -> NVARCHAR (Unicode);
--     TIMESTAMP -> DATETIME2; TEXT -> NVARCHAR(MAX).
--   * NO existe tipo JSON nativo: se usa NVARCHAR(MAX) + CHECK (ISJSON() = 1).
--   * SQL Server rechaza "múltiples rutas de cascada" (error 1785):
--     por eso 4 claves foráneas usan NO ACTION en lugar de CASCADE/SET NULL.
--     Están marcadas con "NO ACTION" en los comentarios.
-- =====================================================================

IF DB_ID('red_social_pascualina') IS NOT NULL
BEGIN
    ALTER DATABASE red_social_pascualina SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE red_social_pascualina;
END
GO
CREATE DATABASE red_social_pascualina;
GO
USE red_social_pascualina;
GO
CREATE SCHEMA red_social;
GO

-- 1. USUARIOS
CREATE TABLE red_social.usuarios (
    id_usuario  INT IDENTITY(1,1),
    nombre      NVARCHAR(100) NOT NULL,
    correo      NVARCHAR(150) NOT NULL,
    carrera     NVARCHAR(80)  NOT NULL,
    CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuarios_correo UNIQUE (correo)
);

-- 2. INTERESES_HABILIDADES (catálogo)
CREATE TABLE red_social.intereses_habilidades (
    id_interes  INT IDENTITY(1,1),
    nombre      NVARCHAR(60) NOT NULL,
    CONSTRAINT pk_intereses_habilidades PRIMARY KEY (id_interes),
    CONSTRAINT uq_intereses_habilidades_nombre UNIQUE (nombre)
);

-- 3. PUBLICACIONES
CREATE TABLE red_social.publicaciones (
    id_publicacion     INT IDENTITY(1,1),
    contenido          NVARCHAR(MAX) NOT NULL,
    fecha_publicacion  DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
    id_usuario_autor   INT           NOT NULL,
    CONSTRAINT pk_publicaciones PRIMARY KEY (id_publicacion),
    CONSTRAINT fk_publicaciones_usuarios FOREIGN KEY (id_usuario_autor)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 4. COMENTARIOS
-- fk_comentarios_usuarios usa NO ACTION: usuarios llega a comentarios por dos
-- rutas (directa y vía publicaciones) y SQL Server no permite ambas en cascada.
CREATE TABLE red_social.comentarios (
    id_comentario     INT IDENTITY(1,1),
    contenido         NVARCHAR(500) NOT NULL,
    id_usuario_autor  INT           NOT NULL,
    id_publicacion    INT           NOT NULL,
    CONSTRAINT pk_comentarios PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentarios_usuarios FOREIGN KEY (id_usuario_autor)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_comentarios_publicaciones FOREIGN KEY (id_publicacion)
        REFERENCES red_social.publicaciones (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 5. GRUPOS
-- fk_grupos_usuarios usa NO ACTION (en PostgreSQL era SET NULL) para evitar
-- rutas de cascada múltiples hacia eventos, miembros_grupo y asistencias.
CREATE TABLE red_social.grupos (
    id_grupo            INT IDENTITY(1,1),
    nombre              NVARCHAR(100) NOT NULL,
    descripcion         NVARCHAR(300) NULL,
    id_usuario_creador  INT NULL,
    CONSTRAINT pk_grupos PRIMARY KEY (id_grupo),
    CONSTRAINT fk_grupos_usuarios FOREIGN KEY (id_usuario_creador)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- 6. EVENTOS
-- detalles_json: dato SEMIESTRUCTURADO. SQL Server lo guarda como texto y
-- CHECK (ISJSON = 1) garantiza que sea un JSON válido (NULL se permite).
-- fk_eventos_usuarios usa NO ACTION (en PostgreSQL era SET NULL), por rutas múltiples.
CREATE TABLE red_social.eventos (
    id_evento               INT IDENTITY(1,1),
    nombre                  NVARCHAR(100) NOT NULL,
    fecha_evento            DATETIME2(0)  NOT NULL,
    lugar                   NVARCHAR(150) NOT NULL,
    id_usuario_organizador  INT NULL,
    id_grupo                INT NULL,
    detalles_json           NVARCHAR(MAX) NULL,
    CONSTRAINT pk_eventos PRIMARY KEY (id_evento),
    CONSTRAINT fk_eventos_usuarios FOREIGN KEY (id_usuario_organizador)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_eventos_grupos FOREIGN KEY (id_grupo)
        REFERENCES red_social.grupos (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_eventos_detalles_json CHECK (ISJSON(detalles_json) = 1)
);

-- 7. USUARIOS_INTERESES
CREATE TABLE red_social.usuarios_intereses (
    id_usuario  INT NOT NULL,
    id_interes  INT NOT NULL,
    CONSTRAINT pk_usuarios_intereses PRIMARY KEY (id_usuario, id_interes),
    CONSTRAINT fk_usuarios_intereses_usuarios FOREIGN KEY (id_usuario)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_usuarios_intereses_intereses FOREIGN KEY (id_interes)
        REFERENCES red_social.intereses_habilidades (id_interes)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 8. SEGUIMIENTOS
-- fk_seguimientos_seguido usa NO ACTION: dos claves hacia usuarios no pueden
-- ser ambas en cascada.
CREATE TABLE red_social.seguimientos (
    id_seguidor  INT NOT NULL,
    id_seguido   INT NOT NULL,
    CONSTRAINT pk_seguimientos PRIMARY KEY (id_seguidor, id_seguido),
    CONSTRAINT fk_seguimientos_seguidor FOREIGN KEY (id_seguidor)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_seguimientos_seguido FOREIGN KEY (id_seguido)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT ck_seguimientos_no_autoseguir CHECK (id_seguidor <> id_seguido)
);

-- 9. MIEMBROS_GRUPO
CREATE TABLE red_social.miembros_grupo (
    id_usuario  INT NOT NULL,
    id_grupo    INT NOT NULL,
    CONSTRAINT pk_miembros_grupo PRIMARY KEY (id_usuario, id_grupo),
    CONSTRAINT fk_miembros_grupo_usuarios FOREIGN KEY (id_usuario)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_miembros_grupo_grupos FOREIGN KEY (id_grupo)
        REFERENCES red_social.grupos (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 10. ASISTENCIAS
CREATE TABLE red_social.asistencias (
    id_usuario  INT NOT NULL,
    id_evento   INT NOT NULL,
    CONSTRAINT pk_asistencias PRIMARY KEY (id_usuario, id_evento),
    CONSTRAINT fk_asistencias_usuarios FOREIGN KEY (id_usuario)
        REFERENCES red_social.usuarios (id_usuario)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_asistencias_eventos FOREIGN KEY (id_evento)
        REFERENCES red_social.eventos (id_evento)
        ON DELETE CASCADE ON UPDATE CASCADE
);
GO

-- Índices sobre claves foráneas de uso frecuente
CREATE INDEX ix_publicaciones_id_usuario_autor ON red_social.publicaciones (id_usuario_autor);
CREATE INDEX ix_comentarios_id_publicacion ON red_social.comentarios (id_publicacion);
CREATE INDEX ix_comentarios_id_usuario_autor ON red_social.comentarios (id_usuario_autor);
CREATE INDEX ix_eventos_id_grupo ON red_social.eventos (id_grupo);
CREATE INDEX ix_seguimientos_id_seguido ON red_social.seguimientos (id_seguido);
GO

-- ---------------------------------------------------------------------
-- PRUEBA DEL CAMPO JSON
-- ---------------------------------------------------------------------
INSERT INTO red_social.usuarios (nombre, correo, carrera)
VALUES (N'Julián Quintero', N'julian@correo.com', N'Ingeniería de Software');

INSERT INTO red_social.eventos (nombre, fecha_evento, lugar, id_usuario_organizador, detalles_json)
VALUES (N'Taller de SQL', '2026-11-05 14:00:00', N'Pascual Bravo', 1,
 N'{"ubicacion":{"lat":6.2776,"lng":-75.5686,"bloque":"Aula 204"},"aforo_max":40,"sensor_asistencia":{"tipo":"QR","lecturas":32}}');

SELECT nombre,
       JSON_VALUE(detalles_json, '$.ubicacion.bloque') AS bloque,
       JSON_VALUE(detalles_json, '$.aforo_max')        AS aforo_max
FROM red_social.eventos
WHERE JSON_VALUE(detalles_json, '$.sensor_asistencia.tipo') = 'QR';
GO
