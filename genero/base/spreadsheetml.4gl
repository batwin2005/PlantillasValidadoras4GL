-- ============================================================
-- MODULO: spreadsheetml.4gl
-- Leer y escribir SpreadsheetML 2003 en 4GL puro (sin Python)
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

GLOBALS
    DEFINE gv_ns_ss VARCHAR(80) = "urn:schemas-microsoft-com:office:spreadsheet"
END GLOBALS

-- ============================================================
-- LEER ARCHIVO SPREADSHEETML (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION spm_leer_archivo(p_ruta VARCHAR(300))
    RETURNING LVARCHAR;
    
    RETURN fc_leer_archivo(p_ruta)
END FUNCTION

-- ============================================================
-- PARSEAR FILAS DEL XML
-- ============================================================
FUNCTION spm_contar_filas(p_xml LVARCHAR(32000))
    RETURNING INTEGER;
    
    DEFINE v_count INTEGER
    DEFINE v_pos INTEGER
    
    LET v_count = 0
    LET v_pos = 1
    WHILE TRUE
        LET v_pos = INSTR(p_xml, "<Row", v_pos)
        IF v_pos = 0 THEN EXIT WHILE END IF
        LET v_count = v_count + 1
        LET v_pos = v_pos + 4
    END WHILE
    RETURN v_count
END FUNCTION

-- ============================================================
-- PARSEAR CELDAS DE UNA FILA
-- ============================================================
FUNCTION spm_contar_celdas_fila(p_xml LVARCHAR(32000), p_fila INTEGER)
    RETURNING INTEGER;
    
    DEFINE v_row_start INTEGER
    DEFINE v_row_end INTEGER
    DEFINE v_count INTEGER
    DEFINE v_pos INTEGER
    DEFINE v_i INTEGER
    DEFINE v_row_count INTEGER
    
    LET v_row_count = 0
    LET v_pos = 1
    
    FOR v_i = 1 TO p_fila
        LET v_row_start = INSTR(p_xml, "<Row", v_pos)
        IF v_row_start = 0 THEN RETURN 0 END IF
        LET v_row_count = v_row_count + 1
        LET v_row_end = INSTR(p_xml, "</Row>", v_row_start)
        IF v_row_end = 0 THEN RETURN 0 END IF
        LET v_pos = v_row_end + 6
    END FOR
    
    LET v_row_start = INSTR(p_xml, "<Row", v_pos - 6)
    LET v_row_end = INSTR(p_xml, "</Row>", v_row_start)
    
    LET v_count = 0
    LET v_pos = v_row_start
    WHILE v_pos < v_row_end
        LET v_pos = INSTR(p_xml, "<Cell", v_pos)
        IF v_pos = 0 OR v_pos > v_row_end THEN EXIT WHILE END IF
        LET v_count = v_count + 1
        LET v_pos = v_pos + 5
    END WHILE
    
    RETURN v_count
END FUNCTION

-- ============================================================
-- OBTENER VALOR DE UNA CELDA ESPECIFICA
-- ============================================================
FUNCTION spm_get_celda(p_xml LVARCHAR(32000), p_fila INTEGER, p_col INTEGER)
    RETURNING VARCHAR(255);
    
    DEFINE v_row_start INTEGER
    DEFINE v_row_end INTEGER
    DEFINE v_cell_start INTEGER
    DEFINE v_cell_end INTEGER
    DEFINE v_data_start INTEGER
    DEFINE v_data_end INTEGER
    DEFINE v_valor VARCHAR(255)
    DEFINE v_i INTEGER
    DEFINE v_row_count INTEGER
    DEFINE v_pos INTEGER
    
    LET v_row_count = 0
    LET v_pos = 1
    
    -- Buscar la fila especificada
    FOR v_i = 1 TO p_fila
        LET v_row_start = INSTR(p_xml, "<Row", v_pos)
        IF v_row_start = 0 THEN RETURN "" END IF
        LET v_row_end = INSTR(p_xml, "</Row>", v_row_start)
        IF v_row_end = 0 THEN RETURN "" END IF
        LET v_pos = v_row_end + 6
    END FOR
    
    -- Buscar la celda especificada dentro de la fila
    LET v_cell_start = v_row_start
    FOR v_i = 1 TO p_col
        LET v_cell_start = INSTR(p_xml, "<Cell", v_cell_start)
        IF v_cell_start = 0 OR v_cell_start > v_row_end THEN RETURN "" END IF
        LET v_cell_start = v_cell_start + 5
    END FOR
    
    -- Extraer valor de <Data>...</Data>
    LET v_data_start = INSTR(p_xml, "<Data", v_cell_start)
    IF v_data_start = 0 OR v_data_start > v_row_end THEN RETURN "" END IF
    LET v_data_start = INSTR(p_xml, ">", v_data_start) + 1
    LET v_data_end = INSTR(p_xml, "</Data>", v_data_start)
    IF v_data_end = 0 THEN RETURN "" END IF
    
    LET v_valor = SUBSTR(p_xml, v_data_start, v_data_end - v_data_start)
    RETURN TRIM(v_valor)
END FUNCTION

-- ============================================================
-- BUSCAR TAG EN FILA Y RETORNAR COLUMNA
-- ============================================================
FUNCTION spm_buscar_tag(p_xml LVARCHAR(32000), p_fila INTEGER, p_tag VARCHAR(50))
    RETURNING INTEGER;
    
    DEFINE v_col INTEGER
    DEFINE v_total_cols INTEGER
    DEFINE v_valor VARCHAR(255)
    
    LET v_total_cols = spm_contar_celdas_fila(p_xml, p_fila)
    
    FOR v_col = 1 TO v_total_cols
        LET v_valor = spm_get_celda(p_xml, p_fila, v_col)
        IF v_valor = "{{" || p_tag || "}}" THEN
            RETURN v_col
        END IF
    END FOR
    
    RETURN 0
END FUNCTION

-- ============================================================
-- OBTENER VALOR POR TAG
-- ============================================================
FUNCTION spm_get_valor_by_tag(p_xml LVARCHAR(32000), p_fila_tag INTEGER, p_fila_datos INTEGER, p_tag VARCHAR(50))
    RETURNING VARCHAR(255);
    
    DEFINE v_col INTEGER
    
    LET v_col = spm_buscar_tag(p_xml, p_fila_tag, p_tag)
    IF v_col = 0 THEN RETURN "" END IF
    
    RETURN spm_get_celda(p_xml, p_fila_datos, v_col)
END FUNCTION

-- ============================================================
-- PARSEAR TODOS LOS TAGS DE UNA FILA
-- Retorna: array de tags y array de valores
-- ============================================================
FUNCTION spm_parse_tags(p_xml LVARCHAR(32000), p_fila INTEGER)
    RETURNING INTEGER;
    
    DEFINE v_col INTEGER
    DEFINE v_total_cols INTEGER
    DEFINE v_valor VARCHAR(255)
    DEFINE v_count INTEGER
    
    LET v_total_cols = spm_contar_celdas_fila(p_xml, p_fila)
    LET v_count = 0
    
    FOR v_col = 1 TO v_total_cols
        LET v_valor = spm_get_celda(p_xml, p_fila, v_col)
        IF v_valor MATCHES "{{*}}" THEN
            LET v_count = v_count + 1
        END IF
    END FOR
    
    RETURN v_count
END FUNCTION

-- ============================================================
-- GENERAR SPREADSHEETML (exportar datos)
-- ============================================================
FUNCTION spm_generar_xml(p_titulo VARCHAR(100), p_headers ARRAY[1:50] OF VARCHAR(80), p_datos ARRAY[1:500] OF ARRAY[1:50] OF VARCHAR(255), p_num_rows INTEGER, p_num_cols SMALLINT)
    RETURNING LVARCHAR(32000);
    
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_i INTEGER
    DEFINE j SMALLINT
    DEFINE v_valor VARCHAR(255)
    DEFINE v_tipo VARCHAR(20)
    
    -- Cabecera
    LET v_xml = '<?xml version="1.0"?>'
    LET v_xml = v_xml || '<?mso-application progid="Excel.Sheet"?>'
    LET v_xml = v_xml || '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"'
    LET v_xml = v_xml || ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">'
    
    -- Estilos
    LET v_xml = v_xml || '<Styles>'
    LET v_xml = v_xml || '<Style ss:ID="Default" ss:Name="Normal"><Font ss:FontName="Calibri" ss:Size="11"/></Style>'
    LET v_xml = v_xml || '<Style ss:ID="Title"><Font ss:Bold="1" ss:Size="14" ss:Color="#FFFFFF"/><Interior ss:Color="#003366" ss:Pattern="Solid"/></Style>'
    LET v_xml = v_xml || '<Style ss:ID="Header"><Font ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#003366" ss:Pattern="Solid"/></Style>'
    LET v_xml = v_xml || '</Styles>'
    
    -- Hoja
    LET v_xml = v_xml || '<Worksheet ss:Name="Datos"><Table>'
    
    -- Fila título
    LET v_xml = v_xml || '<Row><Cell ss:StyleID="Title"><Data ss:Type="String">' || p_titulo || '</Data></Cell></Row>'
    
    -- Fila encabezados
    LET v_xml = v_xml || '<Row>'
    FOR j = 1 TO p_num_cols
        LET v_xml = v_xml || '<Cell ss:StyleID="Header"><Data ss:Type="String">' || p_headers[j] || '</Data></Cell>'
    END FOR
    LET v_xml = v_xml || '</Row>'
    
    -- Filas datos
    FOR i = 1 TO p_num_rows
        LET v_xml = v_xml || '<Row>'
        FOR j = 1 TO p_num_cols
            LET v_valor = p_datos[i, j]
            IF v_valor IS NULL THEN LET v_valor = "" END IF
            
            -- Determinar tipo
            IF v_valor MATCHES "^[-+]?[0-9]*\.?[0-9]+$" THEN
                LET v_tipo = "Number"
            ELSE
                LET v_tipo = "String"
            END IF
            
            -- Escapar XML
            LET v_valor = REPLACE(v_valor, "&", "&amp;")
            LET v_valor = REPLACE(v_valor, "<", "&lt;")
            LET v_valor = REPLACE(v_valor, ">", "&gt;")
            
            LET v_xml = v_xml || '<Cell><Data ss:Type="' || v_tipo || '">' || v_valor || '</Data></Cell>'
        END FOR
        LET v_xml = v_xml || '</Row>'
    END FOR
    
    LET v_xml = v_xml || '</Table></Worksheet></Workbook>'
    
    RETURN v_xml
END FUNCTION

-- ============================================================
-- ESCRIBIR ARCHIVO SPREADSHEETML (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION spm_escribir_archivo(p_ruta VARCHAR(300), p_xml LVARCHAR(32000))
    RETURNING SMALLINT;
    
    RETURN fc_escribir_archivo(p_ruta, p_xml)
END FUNCTION

-- ============================================================
-- REEMPLAZAR TAG EN SPREADSHEETML
-- ============================================================
FUNCTION spm_reemplazar_tag(p_xml LVARCHAR(32000), p_tag VARCHAR(50), p_valor VARCHAR(255))
    RETURNING LVARCHAR(32000);
    
    DEFINE v_pattern VARCHAR(100)
    LET v_pattern = "{{" || p_tag || "}}"
    RETURN REPLACE(p_xml, v_pattern, p_valor)
END FUNCTION

-- ============================================================
-- VALIDAR CARACTERES XML
-- ============================================================
FUNCTION spm_escape_xml(p_texto VARCHAR(255))
    RETURNING VARCHAR(255);
    
    LET p_texto = REPLACE(p_texto, "&", "&amp;")
    LET p_texto = REPLACE(p_texto, "<", "&lt;")
    LET p_texto = REPLACE(p_texto, ">", "&gt;")
    LET p_texto = REPLACE(p_texto, '"', "&quot;")
    LET p_texto = REPLACE(p_texto, "'", "&apos;")
    
    RETURN p_texto
END FUNCTION