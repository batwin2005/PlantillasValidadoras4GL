-- ============================================================
-- db/reglas_validacion.sql
-- Sistema de Reglas de Validación Dinámicas
-- ============================================================
-- NOTAS DE SINTAXIS INFORMIX 14.10 (SPL):
--  * No acepta VALUES multilínea: un INSERT por fila.
--  * VARCHAR máximo 255 bytes: usar LVARCHAR por encima.
--  * RETURNING de rutina requiere "AS nombre".
--  * IF encadenado usa ELIF (no ELSEIF).
--  * Concatenar strings con || (una LET con comas es multi-asignación).
--  * Las rutinas no admiten SELECT sin INTO: usar cursores dinámicos
--    (PREPARE + DECLARE + OPEN USING + FETCH) o funciones nativas.

-- Tabla de reglas por campo
CREATE TABLE reglas_validacion (
    tabla VARCHAR(64) NOT NULL,
    campo VARCHAR(64) NOT NULL,
    tipo_validacion VARCHAR(50) NOT NULL,
    parametro VARCHAR(200),
    mensaje_error VARCHAR(200),
    es_obligatorio CHAR(1) DEFAULT 'N',
    PRIMARY KEY (tabla, campo, tipo_validacion)
);

-- Índices
CREATE INDEX ix_reglas_tabla ON reglas_validacion(tabla);

-- Tipos de validación soportados:
-- FORMATO_DOCUMENTO: Valida DNI, LE, LC, PAS, CI, RUT, CIU
-- EMAIL: Formato email válido
-- SOLO_LETRAS: Solo letras y espacios
-- SOLO_DIGITOS: Solo números
-- ALFANUMERICO: Letras y números
-- NUMERO_POSITIVO: Número mayor o igual a 0
-- NUMERO_ENTERO: Solo números enteros
-- FECHA: Fecha válida
-- RANGO_FECHAS: Fecha en rango (parametro: desde,hasta)
-- LONGITUD: Longitud mínima-máxima (parametro: min,max)
-- REGEX: Expresión regular (parametro: patron)
-- EXISTE_BD: Valor debe existir en otra tabla
-- NO_EXISTE_BD: Valor no debe existir en otra tabla
-- UNIQUE: Valor único en la tabla

-- ============================================================
-- REGLAS PARA TABLA: banco_cliente
-- ============================================================
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'cliente_id', 'NUMERO_ENTERO', NULL, 'ID inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'tipo_doc', 'EXISTE_BD', 'cat_tipo_documento,codigo', 'Tipo documento inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'num_doc', 'FORMATO_DOCUMENTO', NULL, 'Documento inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'num_doc', 'UNIQUE', NULL, 'Cliente ya existe con este documento', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'apellidos', 'SOLO_LETRAS', '2-60', 'Apellidos solo letras (2-60)', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'nombres', 'SOLO_LETRAS', '2-60', 'Nombres solo letras (2-60)', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'genero', 'EXISTE_BD', 'cat_genero,codigo', 'Género inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'fecha_nac', 'RANGO_FECHAS', '1900-01-01,2026-12-31', 'Fecha nacimiento fuera de rango', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'anio_emision', 'RANGO_FECHAS', '1900-01-01,2026-12-31', 'Año emisión inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'telefono', 'LONGITUD', '7-20', 'Teléfono inválido (7-20)', 'N');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'celular', 'LONGITUD', '7-20', 'Celular inválido (7-20)', 'N');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'email', 'EMAIL', NULL, 'Email inválido', 'N');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'estado_civil', 'EXISTE_BD', 'cat_estado_civil,codigo', 'Estado civil inválido', 'N');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'direccion', 'LONGITUD', '5-100', 'Dirección inválida (5-100)', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'ciudad', 'EXISTE_BD', 'cat_ciudad,codigo', 'Ciudad inválida', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cliente', 'ocupacion', 'LONGITUD', '2-50', 'Ocupación inválida (2-50)', 'N');

-- ============================================================
-- REGLAS PARA TABLA: banco_cuenta
-- ============================================================
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'cuenta_id', 'NUMERO_ENTERO', NULL, 'ID inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'cliente_id', 'EXISTE_BD', 'banco_cliente,cliente_id', 'Cliente no existe', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'num_cuenta', 'ALFANUMERICO', '10-20', 'Número cuenta inválido (10-20)', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'num_cuenta', 'UNIQUE', NULL, 'Cuenta ya existe', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'tipo_cuenta', 'EXISTE_BD', 'cat_tipo_cuenta,codigo', 'Tipo cuenta inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'moneda', 'EXISTE_BD', 'cat_moneda,codigo', 'Moneda inválida', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'saldo', 'NUMERO_POSITIVO', NULL, 'Saldo debe ser positivo', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'fecha_apertura', 'FECHA', NULL, 'Fecha apertura inválida', 'S');
INSERT INTO reglas_validacion VALUES ('banco_cuenta', 'estado', 'ALFANUMERICO', '1-1', 'Estado inválido (A/C/B)', 'S');

-- ============================================================
-- REGLAS PARA TABLA: banco_movimiento
-- (nombres de columna reales: fecha, concepto, monto, saldo_post)
-- ============================================================
INSERT INTO reglas_validacion VALUES ('banco_movimiento', 'mov_id', 'NUMERO_ENTERO', NULL, 'ID inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_movimiento', 'cuenta_id', 'EXISTE_BD', 'banco_cuenta,cuenta_id', 'Cuenta no existe', 'S');
INSERT INTO reglas_validacion VALUES ('banco_movimiento', 'fecha', 'FECHA', NULL, 'Fecha movimiento inválida', 'S');
INSERT INTO reglas_validacion VALUES ('banco_movimiento', 'concepto', 'LONGITUD', '5-80', 'Concepto inválido (5-80)', 'S');
INSERT INTO reglas_validacion VALUES ('banco_movimiento', 'monto', 'NUMERO_POSITIVO', NULL, 'Importe inválido', 'S');
INSERT INTO reglas_validacion VALUES ('banco_movimiento', 'saldo_post', 'NUMERO_POSITIVO', NULL, 'Saldo resultante inválido', 'S');

-- ============================================================
-- TABLA DE RESULTADOS DE VALIDACIÓN
-- ============================================================
CREATE TABLE validacion_resultados (
    resultado_id SERIAL PRIMARY KEY,
    archivo_nombre VARCHAR(200),
    fecha_validacion DATETIME YEAR TO FRACTION(3) DEFAULT CURRENT,
    query_original LVARCHAR(32000),
    total_registros INTEGER,
    total_validos INTEGER,
    total_errores INTEGER,
    total_duplicados INTEGER,
    estado VARCHAR(20)  -- PENDIENTE, PROCESADO, CANCELADO
);

CREATE TABLE validacion_detalle (
    detalle_id SERIAL PRIMARY KEY,
    resultado_id INTEGER REFERENCES validacion_resultados(resultado_id),
    num_fila INTEGER,
    campo VARCHAR(64),
    valor_original VARCHAR(200),
    estado VARCHAR(20),  -- OK, ERROR, WARNING
    mensaje LVARCHAR(500),
    accion_sugerida VARCHAR(50)  -- INSERTAR, ACTUALIZAR, OMITIR
);

-- NOTA: no hace falta indexar validacion_detalle(resultado_id):
-- Informix crea un índice implícito para la columna referenciada por
-- la clave foránea (crear otro equivalente da error -350).

-- ============================================================
-- SP PARA OBTENER REGLAS DE UNA TABLA
-- Devuelve todas las reglas de la tabla como XML con cabecera,
-- usando la función nativa genxmlqueryhdr() (la misma que usan
-- f_query_to_xml_hdr y sp_cache_estadisticas).
-- Un SELECT sin INTO no está permitido dentro de una rutina
-- Informix y no se pueden concatenar varias filas sin LIST(),
-- por eso se genera el XML dinámicamente.
-- Uso: SELECT sp_obtener_reglas_tabla('banco_cliente') FROM systables WHERE tabid=1;
-- ============================================================
CREATE FUNCTION sp_obtener_reglas_tabla(p_tabla VARCHAR(64))
    RETURNING LVARCHAR AS reglas;
    
    DEFINE v_query LVARCHAR(32000);
    DEFINE v_xml LVARCHAR(32739);
    
    LET v_query = 'SELECT campo, tipo_validacion, parametro, mensaje_error, es_obligatorio FROM reglas_validacion WHERE tabla = '''
                  || p_tabla || ''' ORDER BY campo';
    
    EXECUTE FUNCTION genxmlqueryhdr('reglas', v_query) INTO v_xml;
    
    RETURN v_xml;
END FUNCTION;

-- ============================================================
-- SP PARA VALIDAR SI EXISTE EN OTRA TABLA
-- ============================================================
CREATE FUNCTION sp_validar_existencia(
    p_tabla VARCHAR(64),
    p_campo VARCHAR(64),
    p_valor VARCHAR(200)
)
    RETURNING SMALLINT AS existe;
    
    DEFINE v_sql LVARCHAR(32000);
    DEFINE v_count INTEGER;
    
    LET v_sql = 'SELECT COUNT(*) FROM ' || p_tabla || 
                ' WHERE ' || p_campo || ' = ?';
    
    PREPARE stmt_ex FROM v_sql;
    DECLARE cur_ex CURSOR FOR stmt_ex;
    OPEN cur_ex USING p_valor;
    FETCH cur_ex INTO v_count;
    CLOSE cur_ex;
    
    IF v_count > 0 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
    
END FUNCTION;

-- ============================================================
-- SP PARA VALIDAR UNIQUE
-- ============================================================
CREATE FUNCTION sp_validar_unique(
    p_tabla VARCHAR(64),
    p_campo VARCHAR(64),
    p_valor VARCHAR(200),
    p_excluir_id INTEGER
)
    RETURNING SMALLINT AS es_unico;
    
    DEFINE v_sql LVARCHAR(32000);
    DEFINE v_count INTEGER;
    DEFINE v_id_col VARCHAR(64);
    
    -- Columna de id según la tabla (las tablas del proyecto no usan "id")
    IF p_tabla = 'banco_cliente' THEN
        LET v_id_col = 'cliente_id';
    ELIF p_tabla = 'banco_cuenta' THEN
        LET v_id_col = 'cuenta_id';
    ELIF p_tabla = 'banco_movimiento' THEN
        LET v_id_col = 'mov_id';
    ELSE
        LET v_id_col = 'cliente_id';
    END IF;
    
    LET v_sql = 'SELECT COUNT(*) FROM ' || p_tabla || 
                ' WHERE ' || p_campo || ' = ?';
    
    IF p_excluir_id IS NOT NULL THEN
        LET v_sql = v_sql || ' AND ' || v_id_col || ' != ' || p_excluir_id;
    END IF;
    
    PREPARE stmt_uq FROM v_sql;
    DECLARE cur_uq CURSOR FOR stmt_uq;
    OPEN cur_uq USING p_valor;
    FETCH cur_uq INTO v_count;
    CLOSE cur_uq;
    
    IF v_count = 0 THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
    
END FUNCTION;
