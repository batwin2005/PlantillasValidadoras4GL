-- ============================================================
-- MODULO: xml_plantilla.4gl
-- Parseo y generación de SpreadsheetML 2003 (XML de Excel)
-- Parsing clásico con SEARCH/SUBSTR (sin clases XmlReader)
-- ============================================================

GLOBALS
    DEFINE gc_ns_ss VARCHAR(80) = "urn:schemas-microsoft-com:office:spreadsheet"
    DEFINE gc_ns_x VARCHAR(80) = "urn:schemas-microsoft-com:office:excel"
END GLOBALS

-- ============================================================
-- Extraer valor de celda SpreadsheetML: <Cell><Data ss:Type="...">valor</Data></Cell>
-- ============================================================
FUNCTION xml_get_cell_value(p_xml VARCHAR(32000), p_row_idx INT, p_col_idx INT)
    DEFINE row_start INT
    DEFINE row_end INT
    DEFINE cell_start INT
    DEFINE cell_end INT
    DEFINE data_start INT
    DEFINE data_end INT
    DEFINE valor VARCHAR(255)
    DEFINE tag_open VARCHAR(50)
    DEFINE tag_close VARCHAR(50)
    DEFINE i INT
    DEFINE row_count INT
    
    LET row_count = 0
    LET i = 1
    
    -- Buscar filas <Row>...</Row>
    WHILE i <= LENGTH(p_xml)
        LET row_start = INSTR(p_xml, "<Row", i)
        IF row_start = 0 THEN
            EXIT WHILE
        END IF
        LET row_end = INSTR(p_xml, "</Row>", row_start)
        IF row_end = 0 THEN
            EXIT WHILE
        END IF
        
        LET row_count = row_count + 1
        IF row_count = p_row_idx THEN
            -- Encontrar la celda p_col_idx dentro de esta fila
            LET cell_start = 1
            FOR i = 1 TO p_col_idx
                LET cell_start = INSTR(p_xml, "<Cell", cell_start)
                IF cell_start = 0 OR cell_start > row_end THEN
                    RETURN ""
                END IF
                LET cell_start = cell_start + 5
            END FOR
            
            -- Extraer <Data>...</Data> dentro de la celda
            LET data_start = INSTR(p_xml, "<Data", cell_start)
            IF data_start = 0 OR data_start > row_end THEN
                RETURN ""
            END IF
            LET data_start = INSTR(p_xml, ">", data_start) + 1
            LET data_end = INSTR(p_xml, "</Data>", data_start)
            IF data_end = 0 THEN
                RETURN ""
            END IF
            LET valor = SUBSTR(p_xml, data_start, data_end - data_start)
            RETURN TRIM(valor)
        END IF
        
        LET i = row_end + 6
    END WHILE
    
    RETURN ""
END FUNCTION

-- ============================================================
-- Contar filas <Row> en el XML
-- ============================================================
FUNCTION xml_count_rows(p_xml VARCHAR(32000))
    DEFINE count INT
    DEFINE pos INT
    
    LET count = 0
    LET pos = 1
    WHILE TRUE
        LET pos = INSTR(p_xml, "<Row", pos)
        IF pos = 0 THEN EXIT WHILE END IF
        LET count = count + 1
        LET pos = pos + 4
    END WHILE
    RETURN count
END FUNCTION

-- ============================================================
-- Generar fila SpreadsheetML a partir de array de valores
-- ============================================================
FUNCTION xml_build_row(p_valores ARRAY[1:50] OF VARCHAR(255), p_num_cols SMALLINT)
    DEFINE xml VARCHAR(8000)
    DEFINE i SMALLINT
    DEFINE val VARCHAR(255)
    DEFINE tipo VARCHAR(20)
    
    LET xml = "<Row>"
    FOR i = 1 TO p_num_cols
        LET val = p_valores[i]
        IF val IS NULL THEN
            LET val = ""
        END IF
        -- Determinar tipo: String por defecto, Number si es numérico
        IF val MATCHES "^[-+]?[0-9]*\.?[0-9]+$" THEN
            LET tipo = 'Number'
        ELSE
            LET tipo = 'String'
        END IF
        -- Escapar caracteres XML
        LET val = xml_escape(val)
        LET xml = xml || "<Cell><Data ss:Type=\"" || tipo || "\">" || val || "</Data></Cell>"
    END FOR
    LET xml = xml || "</Row>"
    RETURN xml
END FUNCTION

-- ============================================================
-- Escapar caracteres especiales XML
-- ============================================================
FUNCTION xml_escape(p_texto VARCHAR(255))
    DEFINE resultado VARCHAR(500)
    DEFINE i INT
    DEFINE c CHAR(1)
    
    LET resultado = ""
    FOR i = 1 TO LENGTH(p_texto)
        LET c = SUBSTR(p_texto, i, 1)
        CASE c
            WHEN "&"  LET resultado = resultado || "&"
            WHEN "<"  LET resultado = resultado || "<"
            WHEN ">"  LET resultado = resultado || ">"
            WHEN '"'  LET resultado = resultado || """
            WHEN "'"  LET resultado = resultado || "&apos;"
            OTHERWISE LET resultado = resultado || c
        END CASE
    END FOR
    RETURN resultado
END FUNCTION

-- ============================================================
-- Construir archivo SpreadsheetML completo (hoja Lote)
-- p_headers: array de encabezados
-- p_rows: array bidimensional de datos [filas][cols]
-- ============================================================
FUNCTION xml_build_spreadsheetml(p_headers ARRAY[1:50] OF VARCHAR(60),
                                  p_rows ARRAY[1:500] OF ARRAY[1:50] OF VARCHAR(255),
                                  p_num_rows INT, p_num_cols SMALLINT)
    DEFINE xml VARCHAR(32000)
    DEFINE i INT
    DEFINE j SMALLINT
    DEFINE row_xml VARCHAR(2000)
    
    -- Cabecera XML + Workbook + Styles
    LET xml = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>'
    LET xml = xml || '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"'
    LET xml = xml || ' xmlns:o="urn:schemas-microsoft-com:office:office"'
    LET xml = xml || ' xmlns:x="urn:schemas-microsoft-com:office:excel"'
    LET xml = xml || ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">'
    
    -- Styles básicos
    LET xml = xml || '<Styles>'
    LET xml = xml || '<Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Bottom"/><Borders/><Font ss:FontName="Calibri" x:Family="Swiss" ss:Size="11" ss:Color="#000000"/><Interior/><NumberFormat/><Protection/></Style>'
    LET xml = xml || '<Style ss:ID="Header"><Font ss:Bold="1"/><Interior ss:Color="#003366" ss:Pattern="Solid"/><Font ss:Color="#FFFFFF"/></Style>'
    LET xml = xml || '</Styles>'
    
    -- Worksheet Lote
    LET xml = xml || '<Worksheet ss:Name="Lote"><Table>'
    
    -- Fila de encabezados
    LET xml = xml || xml_build_row(p_headers, p_num_cols)
    
    -- Filas de datos
    -- NOTA: p_rows es array 2D simulado con índice compuesto
    -- En 4GL clásico se usa array unidimensional con índice compuesto
    
    LET xml = xml || '</Table></Worksheet>'
    
    -- Hoja Listas (para validaciones dropdown)
    LET xml = xml || '<Worksheet ss:Name="Listas"><Table>'
    LET xml = xml || '<Row><Cell><Data ss:Type="String">tipo_doc</Data></Cell><Cell><Data ss:Type="String">DNI</Data></Cell></Row>'
    LET xml = xml || '<Row><Cell><Data ss:Type="String"></Data></Cell><Cell><Data ss:Type="String">LE</Data></Cell></Row>'
    LET xml = xml || '<Row><Cell><Data ss:Type="String"></Data></Cell><Cell><Data ss:Type="String">PAS</Data></Cell></Row>'
    LET xml = xml || '</Table></Worksheet>'
    
    LET xml = xml || '</Workbook>'
    RETURN xml
END FUNCTION

-- ============================================================
-- Leer archivo XML completo a variable
-- ============================================================
FUNCTION xml_read_file(p_ruta VARCHAR(255))
    DEFINE archivo INT
    DEFINE linea VARCHAR(255)
    DEFINE contenido VARCHAR(32000)
    
    LET archivo = OPEN p_ruta FOR INPUT
    IF archivo < 0 THEN
        RETURN ""
    END IF
    
    LET contenido = ""
    WHILE TRUE
        READ archivo INTO linea
        IF STATUS <> 0 THEN EXIT WHILE END IF
        LET contenido = contenido || linea
    END WHILE
    
    CLOSE archivo
    RETURN contenido
END FUNCTION

-- ============================================================
-- Escribir archivo XML
-- ============================================================
FUNCTION xml_write_file(p_ruta VARCHAR(255), p_contenido VARCHAR(32000))
    DEFINE archivo INT
    
    LET archivo = OPEN p_ruta FOR OUTPUT
    IF archivo < 0 THEN
        RETURN FALSE
    END IF
    
    PUT archivo, p_contenido
    IF STATUS <> 0 THEN
        CLOSE archivo
        RETURN FALSE
    END IF
    
    CLOSE archivo
    RETURN TRUE
END FUNCTION