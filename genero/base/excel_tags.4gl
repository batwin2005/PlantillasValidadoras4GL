-- ============================================================
-- MODULO: excel_tags.4gl
-- Funciones para generar tags automáticos y validar desde 4GL
-- Llama a herramientas Python: auto_tag_master.py, validar_excel.py
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

GLOBALS
    DEFINE gv_python_path VARCHAR(200) = "python"
    DEFINE gv_tools_path VARCHAR(200) = "tools"
END GLOBALS

-- ============================================================
-- 1. GENERAR PLANTILLA MAESTRA CON TAGS (llama auto_tag_master.py)
-- ============================================================
FUNCTION generar_plantilla_maestra(
    p_master_path VARCHAR(300),
    p_maestra_path VARCHAR(300),
    p_banco_codigo VARCHAR(20),
    p_nombre_plantilla VARCHAR(100)
)
    RETURNING INTEGER AS plantilla_id;
    
    DEFINE v_cmd VARCHAR(1000)
    DEFINE v_output VARCHAR(32000)
    DEFINE v_line VARCHAR(255)
    DEFINE v_plantilla_id INTEGER
    DEFINE v_campos_count INTEGER
    DEFINE v_i INTEGER
    
    -- Construir comando Python
    LET v_cmd = gv_python_path, " ", gv_tools_path, "/auto_tag_master.py ",
                '"', p_master_path, '" ',
                '"', p_maestra_path, '" ',
                p_banco_codigo, " ", p_nombre_plantilla
    
    MESSAGE "Ejecutando: ", v_cmd
    
    -- Ejecutar y capturar salida
    RUN v_cmd
    
    -- En Genero 2.x/3.x se puede capturar stdout con base.Channel
    -- En 1.x usar archivo temporal
    -- Por simplicidad, asumimos que el Python imprime PLANTILLA_ID_PENDIENTE
    -- y los campos en formato parseable
    
    -- TODO: Implementar captura real de stdout según versión Genero
    -- Por ahora retornamos 0 (se implementará con base.Channel en bdl_2x/3x)
    
    -- Insertar en BD cfg_plantilla
    INSERT INTO cfg_plantilla (banco_codigo, nombre, archivo_master, archivo_maestra, estado)
    VALUES (p_banco_codigo, p_nombre_plantilla, p_master_path, p_maestra_path, 'A');
    
    SELECT DBINFO('sqlca.sqlerrd1') INTO v_plantilla_id FROM systables WHERE tabid=1;
    
    -- Los campos se insertan desde la salida del Python (ver abajo)
    -- insertar_cfg_campos(v_plantilla_id, v_campos_array)
    
    RETURN v_plantilla_id
END FUNCTION

-- ============================================================
-- 2. INSERTAR CAMPOS EN cfg_campo (desde salida Python)
-- ============================================================
FUNCTION insertar_cfg_campos(p_plantilla_id INTEGER, p_campos_json LVARCHAR(32000))
    -- p_campos_json: JSON array de campos desde Python
    -- En 4GL clásico: parsear con string functions o usar SP
    
    DEFINE v_sql LVARCHAR(32000)
    
    -- Usar SP para insertar masivo (más eficiente)
    -- Por ahora insert individual
    -- En producción: crear SP sp_insertar_campos_plantilla(p_plantilla_id, p_json)
    
    RETURN 1
END FUNCTION

-- ============================================================
-- 3. VALIDAR ARCHIVO EXCEL (llama validar_excel.py)
-- ============================================================
FUNCTION validar_archivo_excel(
    p_archivo_datos VARCHAR(300),
    p_plantilla_id INTEGER,
    p_resultado_id INTEGER
)
    RETURNING SMALLINT AS exito;
    
    DEFINE v_cmd VARCHAR(1000)
    DEFINE v_config_json LVARCHAR(32000)
    DEFINE v_result_json LVARCHAR(32000)
    DEFINE v_exito SMALLINT
    
    -- 1. Obtener config de campos desde BD
    SELECT json_array_agg(json_object(
        'campo_id' VALUE campo_id,
        'columna_excel' VALUE columna_excel,
        'nombre_campo' VALUE nombre_campo,
        'validador' VALUE validador,
        'catalogo_tabla' VALUE catalogo_tabla,
        'catalogo_campo' VALUE catalogo_campo,
        'obligatorio' VALUE obligatorio,
        'formato_excel' VALUE formato_excel,
        'longitud_min' VALUE longitud_min,
        'longitud_max' VALUE longitud_max
    ))
    INTO v_config_json
    FROM cfg_campo
    WHERE plantilla_id = p_plantilla_id;
    
    -- 2. Guardar config en archivo temporal para Python
    -- (en 4GL real: usar base.Channel para pasar JSON directo)
    LET v_cmd = gv_python_path, " ", gv_tools_path, "/validar_excel.py ",
                '"', p_archivo_datos, '" ',
                p_plantilla_id, " ", p_resultado_id, " ",
                "config.json"
    
    -- 3. Ejecutar Python
    RUN v_cmd
    
    -- 4. Leer resultado JSON (archivo temporal o stdout)
    -- Parsear y actualizar validacion_detalle
    
    RETURN 1
END FUNCTION

-- ============================================================
-- 4. VALIDACIONES 4GL (Capa 2 - Reglas de negocio)
-- ============================================================
FUNCTION validar_reglas_4gl(p_resultado_id INTEGER)
    RETURNING INTEGER, INTEGER, INTEGER;  -- total, ok, error
    
    DEFINE v_total INTEGER
    DEFINE v_ok INTEGER
    DEFINE v_err INTEGER
    DEFINE v_fila INTEGER
    DEFINE v_campo_id INTEGER
    DEFINE v_nombre_campo VARCHAR(60)
    DEFINE v_valor VARCHAR(1000)
    DEFINE v_validador VARCHAR(50)
    DEFINE v_tabla_bd VARCHAR(60)
    DEFINE v_campo_bd VARCHAR(60)
    DEFINE v_catalogo_tabla VARCHAR(60)
    DEFINE v_catalogo_campo VARCHAR(60)
    DEFINE v_es_valido SMALLINT
    DEFINE v_mensaje VARCHAR(500)
    DEFINE v_accion VARCHAR(20)
    
    LET v_total = 0
    LET v_ok = 0
    LET v_err = 0
    
    -- Cursor: solo filas que pasaron validación Excel (estado='OK')
    DECLARE cur_validar CURSOR FOR
        SELECT vd.num_fila, vd.campo_id, vd.nombre_campo, vd.valor_normalizado,
               c.validador, c.tabla_bd, c.campo_bd, c.catalogo_tabla, c.catalogo_campo
        FROM validacion_detalle vd
        JOIN cfg_campo c ON c.campo_id = vd.campo_id
        WHERE vd.resultado_id = p_resultado_id
          AND vd.estado = 'OK'
        ORDER BY vd.num_fila, c.orden;
    
    FOREACH cur_validar INTO v_fila, v_campo_id, v_nombre_campo, v_valor,
                              v_validador, v_tabla_bd, v_campo_bd, v_catalogo_tabla, v_catalogo_campo
        
        LET v_total = v_total + 1
        LET v_es_valido = TRUE
        LET v_mensaje = "OK"
        LET v_accion = "INSERTAR"
        
        -- Aplicar validador 4GL correspondiente
        CASE v_validador
            WHEN 'val_documento'     CALL val_documento(v_valor) RETURNING v_es_valido
            WHEN 'val_nombre'        CALL val_nombre(v_valor) RETURNING v_es_valido
            WHEN 'val_fecha'         CALL val_fecha(v_valor) RETURNING v_es_valido
            WHEN 'val_email'         CALL val_email(v_valor) RETURNING v_es_valido
            WHEN 'val_telefono'      CALL val_telefono(v_valor) RETURNING v_es_valido
            WHEN 'val_anio'          CALL val_anio(v_valor) RETURNING v_es_valido
            WHEN 'val_monto'         CALL val_monto(v_valor) RETURNING v_es_valido
            WHEN 'val_catalogo'      CALL val_catalogo(v_catalogo_tabla, v_catalogo_campo, v_valor) RETURNING v_es_valido
            WHEN 'val_unique_bd'     CALL sp_validar_unique_bd(v_tabla_bd, v_campo_bd, v_valor, NULL) RETURNING v_es_valido
            OTHERWISE                LET v_es_valido = TRUE
        END CASE
        
        IF NOT v_es_valido THEN
            LET v_err = v_err + 1
            LET v_mensaje = msg_error_4gl(v_validador, v_valor)
            LET v_accion = 'CORREGIR'
            
            UPDATE validacion_detalle
            SET estado = 'ERROR',
                codigo_error = 'ERR_4GL_' || UPPER(v_validador),
                mensaje = v_mensaje,
                accion_sugerida = v_accion,
                fecha_validacion = CURRENT
            WHERE resultado_id = p_resultado_id
              AND num_fila = v_fila
              AND campo_id = v_campo_id;
        ELSE
            LET v_ok = v_ok + 1
        END IF
        
    END FOREACH
    
    RETURN v_total, v_ok, v_err
END FUNCTION

-- ============================================================
-- 5. GENERAR ARCHIVO CON HOJA ERRORES
-- ============================================================
FUNCTION generar_archivo_con_errores(p_resultado_id INTEGER, p_archivo_original VARCHAR(300))
    RETURNING VARCHAR(300);
    
    DEFINE v_archivo_errores VARCHAR(300)
    DEFINE v_timestamp VARCHAR(20)
    DEFINE v_wb base.Channel  -- En 2.x/3.x usar openpyxl via Python
    DEFINE v_cmd VARCHAR(1000)
    
    -- Generar nombre archivo errores
    LET v_timestamp = EXTEND(CURRENT YEAR TO SECOND, 20)
    LET v_timestamp = REPLACE(v_timestamp, "-", "")
    LET v_timestamp = REPLACE(v_timestamp, ":", "")
    LET v_timestamp = REPLACE(v_timestamp, " ", "_")
    
    LET v_archivo_errores = "plantillas_errores/errores_", v_timestamp, ".xlsx"
    
    -- Llamar Python para generar archivo con hoja ERRORES
    LET v_cmd = gv_python_path, " ", gv_tools_path, "/generar_errores_excel.py ",
                p_resultado_id, " ",
                '"', p_archivo_original, '" ',
                '"', v_archivo_errores, '"'
    
    RUN v_cmd
    
    RETURN v_archivo_errores
END FUNCTION

-- ============================================================
-- 6. OBTENER CONFIG PLANTILLA DESDE BD (XML)
-- ============================================================
FUNCTION obtener_config_plantilla_xml(p_plantilla_id INTEGER)
    RETURNING LVARCHAR;
    
    DEFINE v_xml LVARCHAR(32739)
    
    -- Usar SP existente
    EXECUTE FUNCTION sp_obtener_config_plantilla(p_plantilla_id) INTO v_xml;
    
    RETURN v_xml
END FUNCTION

FUNCTION obtener_campos_plantilla_xml(p_plantilla_id INTEGER)
    RETURNING LVARCHAR;
    
    DEFINE v_xml LVARCHAR(32739)
    
    EXECUTE FUNCTION sp_obtener_campos_plantilla(p_plantilla_id) INTO v_xml;
    
    RETURN v_xml
END FUNCTION

-- ============================================================
-- 7. HELPERS: Mensajes de error 4GL
-- ============================================================
FUNCTION msg_error_4gl(p_validador VARCHAR(50), p_valor VARCHAR(200))
    RETURNING VARCHAR(500);
    
    CASE p_validador
        WHEN 'val_documento'  RETURN "Documento inválido: " || p_valor || " (5-20 alfanuméricos)"
        WHEN 'val_nombre'     RETURN "Nombre inválido: " || p_valor || " (solo letras, 2-60)"
        WHEN 'val_fecha'      RETURN "Fecha inválida: " || p_valor || " (use DD/MM/YYYY)"
        WHEN 'val_email'      RETURN "Email inválido: " || p_valor
        WHEN 'val_telefono'   RETURN "Teléfono inválido: " || p_valor || " (7-20 dígitos)"
        WHEN 'val_anio'       RETURN "Año inválido: " || p_valor || " (1900-" || YEAR(TODAY) || ")"
        WHEN 'val_monto'      RETURN "Monto inválido: " || p_valor || " (>=0, max 2 decimales)"
        WHEN 'val_catalogo'   RETURN "Valor no existe en catálogo: " || p_valor
        WHEN 'val_unique_bd'  RETURN "Valor duplicado en BD: " || p_valor
        OTHERWISE             RETURN "Error validación " || p_validador || ": " || p_valor
    END CASE
END FUNCTION

-- ============================================================
-- 8. FUNCIONES VAL_* EXISTENTES (de validacion.4gl) - REEXPORTAR
-- ============================================================
-- Las funciones val_nombre, val_fecha, val_email, val_documento,
-- val_telefono, val_anio, val_monto, val_catalogo ya están en validacion.4gl
-- Se usan directamente desde validar_reglas_4gl()

-- ============================================================
-- 9. GUARDAR CONFIG PLANTILLA EN BD (desde 4GL)
-- ============================================================
FUNCTION sp_guardar_config_plantilla(
    p_banco_codigo VARCHAR(20),
    p_nombre VARCHAR(100),
    p_archivo_master VARCHAR(300),
    p_archivo_maestra VARCHAR(300)
)
    RETURNING INTEGER AS plantilla_id;
    
    DEFINE v_plantilla_id INTEGER
    
    INSERT INTO cfg_plantilla (banco_codigo, nombre, archivo_master, archivo_maestra, estado)
    VALUES (p_banco_codigo, p_nombre, p_archivo_master, p_archivo_maestra, 'A');
    
    SELECT DBINFO('sqlca.sqlerrd1') INTO v_plantilla_id FROM systables WHERE tabid=1;
    
    RETURN v_plantilla_id
END FUNCTION

-- ============================================================
-- 10. INSERTAR CAMPOS DESDE ARRAY 4GL (para uso interno)
-- ============================================================
FUNCTION insertar_campo_plantilla(
    p_plantilla_id INTEGER,
    p_columna_excel VARCHAR(5),
    p_nombre_campo VARCHAR(60),
    p_tag_excel VARCHAR(80),
    p_encabezado VARCHAR(80),
    p_validador VARCHAR(50),
    p_catalogo_tabla VARCHAR(60),
    p_catalogo_campo VARCHAR(60),
    p_obligatorio CHAR(1),
    p_orden SMALLINT,
    p_formato_excel VARCHAR(30)
)
    RETURNING INTEGER AS campo_id;
    
    DEFINE v_campo_id INTEGER
    
    INSERT INTO cfg_campo (
        plantilla_id, columna_excel, nombre_campo, tag_excel, encabezado,
        validador, catalogo_tabla, catalogo_campo, obligatorio, orden, formato_excel
    ) VALUES (
        p_plantilla_id, p_columna_excel, p_nombre_campo, p_tag_excel, p_encabezado,
        p_validador, p_catalogo_tabla, p_catalogo_campo, p_obligatorio, p_orden, p_formato_excel
    );
    
    SELECT DBINFO('sqlca.sqlerrd1') INTO v_campo_id FROM systables WHERE tabid=1;
    
    RETURN v_campo_id
END FUNCTION