-- ============================================================
-- db/02_tablas_validacion.sql
-- Tablas para el sistema de validación de plantillas
-- Informix 14.10
-- ============================================================

DATABASE banco;

-- ============================================================
-- cfg_plantilla: Configuración de plantillas maestras
-- Una fila por plantilla master (por banco/tipo)
-- ============================================================
CREATE TABLE cfg_plantilla (
    plantilla_id    SERIAL PRIMARY KEY,
    banco_codigo    VARCHAR(20) NOT NULL REFERENCES banco(codigo),
    nombre          VARCHAR(100) NOT NULL,
    descripcion     LVARCHAR(500),
    archivo_master  VARCHAR(300) NOT NULL,      -- master original (sin tags)
    archivo_maestra VARCHAR(300) NOT NULL,      -- generada con tags
    hoja_datos      VARCHAR(50) DEFAULT 'Datos',
    fila_inicio     SMALLINT DEFAULT 2,         -- donde empiezan los tags (fila 2)
    fila_datos      SMALLINT DEFAULT 3,         -- donde empiezan datos usuario
    version         INTEGER DEFAULT 1,
    estado          CHAR(1) DEFAULT 'A' CHECK (estado IN ('A','I','B')),
    fecha_creacion  DATETIME YEAR TO FRACTION(3) DEFAULT CURRENT,
    usuario_creacion VARCHAR(30) DEFAULT USER
);

CREATE INDEX ix_cfg_plantilla_banco ON cfg_plantilla(banco_codigo);
CREATE INDEX ix_cfg_plantilla_estado ON cfg_plantilla(estado);

-- ============================================================
-- cfg_campo: Definición de cada columna de la plantilla
-- Un registro por COLUMNA (campo) de la plantilla
-- ============================================================
CREATE TABLE cfg_campo (
    campo_id        SERIAL PRIMARY KEY,
    plantilla_id    INTEGER NOT NULL REFERENCES cfg_plantilla(plantilla_id),
    columna_excel   VARCHAR(5) NOT NULL,        -- A, B, C... AA, AB
    nombre_campo    VARCHAR(60) NOT NULL,       -- tag interno: cliente.num_doc
    tag_excel       VARCHAR(80) NOT NULL,       -- {{cliente.num_doc}}
    encabezado      VARCHAR(80) NOT NULL,       -- visible en Excel: "Número Documento"
    tabla_bd        VARCHAR(60),                -- banco_cliente, banco_cuenta, etc.
    campo_bd        VARCHAR(60),                -- columna real en BD: num_doc
    validador       VARCHAR(50),                -- val_documento, val_fecha, etc.
    catalogo_tabla  VARCHAR(60),                -- para dropdown: cat_tipo_documento
    catalogo_campo  VARCHAR(60),                -- codigo, descripcion
    obligatorio     CHAR(1) DEFAULT 'N' CHECK (obligatorio IN ('S','N')),
    orden           SMALLINT DEFAULT 0,
    formato_excel   VARCHAR(30),                -- @, 0.00, DD/MM/YYYY, General
    longitud_min    SMALLINT,
    longitud_max    SMALLINT,
    valor_default   VARCHAR(200),
    observaciones   LVARCHAR(500)
);

CREATE INDEX ix_cfg_campo_plantilla ON cfg_campo(plantilla_id);
CREATE INDEX ix_cfg_campo_orden ON cfg_campo(plantilla_id, orden);

-- ============================================================
-- validacion_resultados: Cabecera de cada validación de archivo
-- ============================================================
CREATE TABLE validacion_resultados (
    resultado_id     SERIAL PRIMARY KEY,
    plantilla_id     INTEGER NOT NULL REFERENCES cfg_plantilla(plantilla_id),
    archivo_origen   VARCHAR(300) NOT NULL,      -- archivo que validó el usuario
    archivo_errores  VARCHAR(300),               -- archivo generado con hoja ERRORES
    total_filas      INTEGER DEFAULT 0,
    filas_validas    INTEGER DEFAULT 0,
    filas_error      INTEGER DEFAULT 0,
    filas_duplicadas INTEGER DEFAULT 0,
    estado           VARCHAR(20) DEFAULT 'PENDIENTE', 
    -- PENDIENTE, VALIDANDO, VALIDADO_OK, CON_ERRORES, CARGADO_BD, CANCELADO
    fecha_validacion DATETIME YEAR TO FRACTION(3) DEFAULT CURRENT,
    usuario          VARCHAR(30) DEFAULT USER,
    observaciones    LVARCHAR(1000)
);

CREATE INDEX ix_val_res_plantilla ON validacion_resultados(plantilla_id);
CREATE INDEX ix_val_res_estado ON validacion_resultados(estado);
CREATE INDEX ix_val_res_fecha ON validacion_resultados(fecha_validacion);

-- ============================================================
-- validacion_detalle: Una fila por celda validada (OK/ERROR)
-- ============================================================
CREATE TABLE validacion_detalle (
    detalle_id         SERIAL PRIMARY KEY,
    resultado_id       INTEGER NOT NULL REFERENCES validacion_resultados(resultado_id),
    num_fila           INTEGER NOT NULL,         -- fila en Excel (1-based, cuenta desde header)
    campo_id           INTEGER REFERENCES cfg_campo(campo_id),
    nombre_campo       VARCHAR(60) NOT NULL,     -- redundante para consultas rápidas
    columna_excel      VARCHAR(5),               -- A, B, C...
    valor_original     LVARCHAR(1000),           -- tal cual vino en Excel
    valor_normalizado  LVARCHAR(1000),           -- limpio/tipado para BD
    estado             VARCHAR(10) CHECK (estado IN ('OK','ERROR','WARNING','DUPLICADO','OMITIDO')),
    codigo_error       VARCHAR(30),              -- ERR_TIPO_DOC, ERR_FECHA, ERR_UNIQUE, etc.
    mensaje            LVARCHAR(1000),           -- mensaje legible para usuario
    accion_sugerida    VARCHAR(20) DEFAULT 'REVISAR', 
    -- INSERTAR, ACTUALIZAR, OMITIR, REVISAR, CORREGIR
    fecha_validacion   DATETIME YEAR TO FRACTION(3) DEFAULT CURRENT
);

CREATE INDEX ix_val_det_res ON validacion_detalle(resultado_id);
CREATE INDEX ix_val_det_estado ON validacion_detalle(estado);
CREATE INDEX ix_val_det_fila ON validacion_detalle(resultado_id, num_fila);

-- ============================================================
-- validacion_errores_hoja: Para generar hoja ERRORES en Excel
-- Vista práctica para exportar
-- ============================================================
CREATE VIEW vw_validacion_errores_export AS
SELECT 
    vr.resultado_id,
    vr.archivo_origen,
    vd.num_fila,
    vd.columna_excel,
    vd.nombre_campo,
    vd.valor_original,
    vd.valor_normalizado,
    vd.estado,
    vd.codigo_error,
    vd.mensaje,
    vd.accion_sugerida
FROM validacion_resultados vr
JOIN validacion_detalle vd ON vd.resultado_id = vr.resultado_id
WHERE vd.estado IN ('ERROR','WARNING','DUPLICADO')
ORDER BY vr.resultado_id, vd.num_fila, vd.campo_id;

-- ============================================================
-- DATOS SEMILLA: Ejemplo plantilla cliente
-- ============================================================
-- Se inserta via script Python al crear plantilla master
-- INSERT INTO cfg_plantilla (banco_codigo, nombre, archivo_master, archivo_maestra, hoja_datos)
-- VALUES ('nacion', 'Clientes Banco Nación', 'plantillas_base/master_clientes_nacion.xlsx', 'plantillas_maestras/maestra_clientes_nacion.xlsx', 'Clientes');
--
-- INSERT INTO cfg_campo (plantilla_id, columna_excel, nombre_campo, tag_excel, encabezado, tabla_bd, campo_bd, validador, catalogo_tabla, catalogo_campo, obligatorio, orden, formato_excel)
-- VALUES 
-- (1, 'A', 'cliente.tipo_doc', '{{cliente.tipo_doc}}', 'Tipo Documento', 'banco_cliente', 'tipo_doc', 'val_catalogo', 'cat_tipo_documento', 'codigo', 'S', 1, 'General'),
-- (1, 'B', 'cliente.num_doc', '{{cliente.num_doc}}', 'Número Documento', 'banco_cliente', 'num_doc', 'val_documento', NULL, NULL, 'S', 2, 'General'),
-- (1, 'C', 'cliente.apellidos', '{{cliente.apellidos}}', 'Apellidos', 'banco_cliente', 'apellidos', 'val_nombre', NULL, NULL, 'S', 3, 'General'),
-- (1, 'D', 'cliente.nombres', '{{cliente.nombres}}', 'Nombres', 'banco_cliente', 'nombres', 'val_nombre', NULL, NULL, 'S', 4, 'General'),
-- (1, 'E', 'cliente.genero', '{{cliente.genero}}', 'Género', 'banco_cliente', 'genero', 'val_catalogo', 'cat_genero', 'codigo', 'S', 5, 'General'),
-- (1, 'F', 'cliente.fecha_nac', '{{cliente.fecha_nac}}', 'Fecha Nacimiento', 'banco_cliente', 'fecha_nac', 'val_fecha', NULL, NULL, 'S', 6, 'DD/MM/YYYY'),
-- (1, 'G', 'cliente.email', '{{cliente.email}}', 'Email', 'banco_cliente', 'email', 'val_email', NULL, NULL, 'N', 7, '@');