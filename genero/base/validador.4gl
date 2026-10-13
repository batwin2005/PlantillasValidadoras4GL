-- ============================================================
-- MODULO: validador.4gl
-- Flujo principal: leer SpreadsheetML → validar → mostrar resultado
-- 100% 4GL (sin Python)
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_fila_tags INTEGER
    DEFINE gv_fila_datos INTEGER
    DEFINE gv_total_filas INTEGER
    DEFINE gv_archivo VARCHAR(300)
END GLOBALS

-- ============================================================
-- FUNCIÓN PRINCIPAL: Validar archivo SpreadsheetML
-- ============================================================
FUNCTION validar_archivo_spm(p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_total_filas INTEGER
    DEFINE v_fila INTEGER
    DEFINE v_col INTEGER
    DEFINE v_valor VARCHAR(255)
    DEFINE v_tag VARCHAR(50)
    DEFINE v_es_valido SMALLINT
    DEFINE v_mensaje VARCHAR(500)
    DEFINE v_total_ok INTEGER
    DEFINE v_total_error INTEGER
    DEFINE v_plantilla VARCHAR(100)
    
    LET gv_archivo = p_ruta
    
    -- Leer archivo
    LET v_xml = spm_leer_archivo(p_ruta)
    IF v_xml = "" THEN
        ERROR "No se pudo leer el archivo"
        RETURN FALSE
    END IF
    
    -- Detectar estructura
    LET v_total_filas = spm_contar_filas(v_xml)
    LET gv_total_filas = v_total_filas
    
    MESSAGE "Archivo: ", p_ruta
    MESSAGE "Filas totales: ", v_total_filas
    
    -- Buscar fila de tags (fila con {{...}})
    LET gv_fila_tags = 0
    FOR v_fila = 1 TO v_total_filas
        LET v_valor = spm_get_celda(v_xml, v_fila, 1)
        IF v_valor MATCHES "{{*}}" THEN
            LET gv_fila_tags = v_fila
            EXIT FOR
        END IF
    END FOR
    
    IF gv_fila_tags = 0 THEN
        ERROR "No se encontraron tags {{campo}} en el archivo"
        RETURN FALSE
    END IF
    
    LET gv_fila_datos = gv_fila_tags + 1
    MESSAGE "Fila tags: ", gv_fila_tags
    MESSAGE "Fila datos: ", gv_fila_datos
    
    -- Validar cada fila de datos
    LET v_total_ok = 0
    LET v_total_error = 0
    
    FOR v_fila = gv_fila_datos TO v_total_filas
        LET v_es_valido = TRUE
        LET v_mensaje = ""
        
        -- Obtener valores de cada campo por tag
        -- (Aquí se leen los tags y se validan con val_*)
        
        -- Ejemplo: validar tipo_doc
        LET v_valor = spm_get_valor_by_tag(v_xml, gv_fila_tags, v_fila, "tipo_doc")
        IF v_valor IS NOT NULL AND v_valor != "" THEN
            IF NOT val_catalogo("cat_tipo_documento", "codigo", v_valor) THEN
                LET v_es_valido = FALSE
                LET v_mensaje = "Tipo documento inválido: " || v_valor
            END IF
        END IF
        
        -- Ejemplo: validar num_doc
        LET v_valor = spm_get_valor_by_tag(v_xml, gv_fila_tags, v_fila, "num_doc")
        IF v_valor IS NOT NULL AND v_valor != "" THEN
            IF NOT val_documento(v_valor) THEN
                LET v_es_valido = FALSE
                LET v_mensaje = "Documento inválido: " || v_valor
            END IF
        END IF
        
        -- Ejemplo: validar apellidos
        LET v_valor = spm_get_valor_by_tag(v_xml, gv_fila_tags, v_fila, "apellidos")
        IF v_valor IS NOT NULL AND v_valor != "" THEN
            IF NOT val_nombre(v_valor) THEN
                LET v_es_valido = FALSE
                LET v_mensaje = "Apellidos inválidos: " || v_valor
            END IF
        END IF
        
        -- Ejemplo: validar nombres
        LET v_valor = spm_get_valor_by_tag(v_xml, gv_fila_tags, v_fila, "nombres")
        IF v_valor IS NOT NULL AND v_valor != "" THEN
            IF NOT val_nombre(v_valor) THEN
                LET v_es_valido = FALSE
                LET v_mensaje = "Nombres inválidos: " || v_valor
            END IF
        END IF
        
        -- Ejemplo: validar fecha_nac
        LET v_valor = spm_get_valor_by_tag(v_xml, gv_fila_tags, v_fila, "fecha_nac")
        IF v_valor IS NOT NULL AND v_valor != "" THEN
            IF NOT val_fecha(v_valor) THEN
                LET v_es_valido = FALSE
                LET v_mensaje = "Fecha inválida: " || v_valor
            END IF
        END IF
        
        -- Ejemplo: validar email
        LET v_valor = spm_get_valor_by_tag(v_xml, gv_fila_tags, v_fila, "email")
        IF v_valor IS NOT NULL AND v_valor != "" THEN
            IF NOT val_email(v_valor) THEN
                LET v_es_valido = FALSE
                LET v_mensaje = "Email inválido: " || v_valor
            END IF
        END IF
        
        -- Contar resultado
        IF v_es_valido THEN
            LET v_total_ok = v_total_ok + 1
        ELSE
            LET v_total_error = v_total_error + 1
            MESSAGE "Fila ", v_fila, ": ", v_mensaje
        END IF
    END FOR
    
    -- Mostrar resumen
    MESSAGE "========================================"
    MESSAGE "Validación completa"
    MESSAGE "  Filas OK: ", v_total_ok
    MESSAGE "  Filas con error: ", v_total_error
    MESSAGE "========================================"
    
    IF v_total_error > 0 THEN
        RETURN FALSE
    ELSE
        RETURN TRUE
    END IF
END FUNCTION

-- ============================================================
-- EXPORTAR DATOS VALIDADOS A SPREADSHEETML
-- ============================================================
FUNCTION exportar_validados_spm(p_ruta_origen VARCHAR(300), p_ruta_salida VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_xml_salida LVARCHAR(32000)
    
    -- Leer archivo original
    LET v_xml = spm_leer_archivo(p_ruta_origen)
    
    -- Generar nuevo SpreadsheetML con datos validados
    -- (Aquí se construye el XML de salida)
    
    LET v_xml_salida = v_xml
    
    -- Escribir archivo
    CALL spm_escribir_archivo(p_ruta_salida, v_xml_salida)
    
    MESSAGE "✅ Exportado: ", p_ruta_salida
    RETURN TRUE
END FUNCTION

-- ============================================================
-- MOSTRAR DATOS EN PANTALLA (DISPLAY ARRAY)
-- ============================================================
FUNCTION mostrar_datos_spm(p_ruta VARCHAR(300))
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_total_filas INTEGER
    DEFINE v_fila INTEGER
    DEFINE v_col INTEGER
    DEFINE v_valor VARCHAR(255)
    DEFINE v_total_cols INTEGER
    
    LET v_xml = spm_leer_archivo(p_ruta)
    LET v_total_filas = spm_contar_filas(v_xml)
    
    -- Mostrar primeras 10 filas
    FOR v_fila = 1 TO v_total_filas
        LET v_total_cols = spm_contar_celdas_fila(v_xml, v_fila)
        FOR v_col = 1 TO v_total_cols
            LET v_valor = spm_get_celda(v_xml, v_fila, v_col)
            IF v_valor IS NOT NULL AND v_valor != "" THEN
                DISPLAY "Fila ", v_fila, " Col ", v_col, ": ", v_valor
            END IF
        END FOR
    END FOR
END FUNCTION