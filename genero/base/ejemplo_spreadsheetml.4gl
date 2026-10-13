-- ============================================================
-- MODULO: ejemplo_spreadsheetml.4gl
-- Ejemplo: Generar y leer SpreadsheetML 2003 en 4GL puro
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_output_dir VARCHAR(200) = "ejemplo"
END GLOBALS

-- ============================================================
-- EJEMPLO 1: Generar SpreadsheetML con datos de BD
-- ============================================================
FUNCTION generar_spreadsheetml_ejemplo()
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_total INTEGER

    LET v_ruta = gv_output_dir, "/clientes_generado.xml"

    -- Crear directorio
    RUN "if not exist ", gv_output_dir, " mkdir ", gv_output_dir

    -- Abrir archivo
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")

    -- Cabecera XML
    CALL v_file.write('<?xml version="1.0" encoding="UTF-8"?>')
    CALL v_file.write('<?mso-application progid="Excel.Sheet"?>')
    CALL v_file.write('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"')
    CALL v_file.write(' xmlns:o="urn:schemas-microsoft-com:office:office"')
    CALL v_file.write(' xmlns:x="urn:schemas-microsoft-com:office:excel"')
    CALL v_file.write(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">')

    -- Estilos
    CALL v_file.write('<Styles>')
    CALL v_file.write('<Style ss:ID="Default" ss:Name="Normal"><Font ss:FontName="Calibri" ss:Size="11" ss:Color="#000000"/></Style>')
    CALL v_file.write('<Style ss:ID="Header"><Font ss:Bold="1" ss:Color="#FFFFFF" ss:Size="11"/><Interior ss:Color="#003366" ss:Pattern="Solid"/></Style>')
    CALL v_file.write('<Style ss:ID="Tag"><Font ss:Bold="1" ss:Color="#003366" ss:Size="9" ss:Italic="1"/><Interior ss:Color="#E8F0FE" ss:Pattern="Solid"/></Style>')
    CALL v_file.write('<Style ss:ID="Money"><NumberFormat ss:Format="#,##0.00"/></Style>')
    CALL v_file.write('<Style ss:ID="Date"><NumberFormat ss:Format="DD/MM/YYYY"/></Style>')
    CALL v_file.write('</Styles>')

    -- Hoja Datos
    CALL v_file.write('<Worksheet ss:Name="Datos"><Table>')
    CALL v_file.write('<Column ss:Width="100"/><Column ss:Width="120"/><Column ss:Width="80"/><Column ss:Width="100"/>')

    -- Fila 1: Encabezados
    CALL v_file.write('<Row ss:Height="25">')
    CALL v_file.write('<Cell ss:StyleID="Header"><Data ss:Type="String">Tipo Documento</Data></Cell>')
    CALL v_file.write('<Cell ss:StyleID="Header"><Data ss:Type="String">Número Documento</Data></Cell>')
    CALL v_file.write('<Cell ss:StyleID="Header"><Data ss:Type="String">Apellidos</Data></Cell>')
    CALL v_file.write('<Cell ss:StyleID="Header"><Data ss:Type="String">Nombres</Data></Cell>')
    CALL v_file.write('</Row>')

    -- Fila 2: Tags
    CALL v_file.write('<Row ss:Height="18">')
    CALL v_file.write('<Cell ss:StyleID="Tag"><Data ss:Type="String">{{tipo_doc}}</Data></Cell>')
    CALL v_file.write('<Cell ss:StyleID="Tag"><Data ss:Type="String">{{num_doc}}</Data></Cell>')
    CALL v_file.write('<Cell ss:StyleID="Tag"><Data ss:Type="String">{{apellidos}}</Data></Cell>')
    CALL v_file.write('<Cell ss:StyleID="Tag"><Data ss:Type="String">{{nombres}}</Data></Cell>')
    CALL v_file.write('</Row>')

    -- Datos desde BD
    DECLARE cur_datos CURSOR FOR
        SELECT tipo_doc, num_doc, apellidos, nombres
        FROM banco_cliente
        ORDER BY apellidos
        LIMIT 100

    LET v_total = 0
    FOREACH cur_datos INTO v_tipo_doc, v_num_doc, v_apellidos, v_nombres
        CALL v_file.write('<Row>')
        CALL v_file.write('<Cell><Data ss:Type="String">', v_tipo_doc, '</Data></Cell>')
        CALL v_file.write('<Cell><Data ss:Type="String">', v_num_doc, '</Data></Cell>')
        CALL v_file.write('<Cell><Data ss:Type="String">', v_apellidos, '</Data></Cell>')
        CALL v_file.write('<Cell><Data ss:Type="String">', v_nombres, '</Data></Cell>')
        CALL v_file.write('</Row>')
        LET v_total = v_total + 1
    END FOREACH

    CALL v_file.write('</Table></Worksheet>')
    CALL v_file.write('</Workbook>')
    CALL v_file.close()

    MESSAGE "✅ Archivo generado: ", v_ruta
    MESSAGE "   Registros: ", v_total
    MESSAGE "   Abrir en Excel: doble clic → se abre con diseño intacto"
END FUNCTION

-- ============================================================
-- EJEMPLO 2: Leer SpreadsheetML y extraer datos
-- ============================================================
FUNCTION leer_spreadsheetml(p_ruta VARCHAR(300))
    DEFINE v_file base.Channel
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_pos INTEGER
    DEFINE v_row_start INTEGER
    DEFINE v_row_end INTEGER
    DEFINE v_cell_start INTEGER
    DEFINE v_cell_end INTEGER
    DEFINE v_data_start INTEGER
    DEFINE v_data_end INTEGER
    DEFINE v_valor VARCHAR(255)
    DEFINE v_fila INTEGER
    DEFINE v_col INTEGER

    -- Leer archivo completo
    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_ruta, "r")

    LET v_xml = ""
    WHILE v_file.read(v_linea)
        LET v_xml = v_xml, v_linea
    END WHILE
    CALL v_file.close()

    -- Parsear filas
    LET v_fila = 0
    LET v_pos = 1

    WHILE v_pos < LENGTH(v_xml)
        LET v_row_start = INSTR(v_xml, "<Row", v_pos)
        IF v_row_start = 0 THEN EXIT WHILE END IF

        LET v_row_end = INSTR(v_xml, "</Row>", v_row_start)
        IF v_row_end = 0 THEN EXIT WHILE END IF

        LET v_fila = v_fila + 1
        LET v_col = 0

        -- Parsear celdas dentro de la fila
        LET v_cell_start = v_row_start
        WHILE v_cell_start < v_row_end
            LET v_cell_start = INSTR(v_xml, "<Cell", v_cell_start)
            IF v_cell_start = 0 OR v_cell_start > v_row_end THEN EXIT WHILE END IF

            LET v_data_start = INSTR(v_xml, "<Data", v_cell_start)
            IF v_data_start = 0 OR v_data_start > v_row_end THEN
                LET v_cell_start = v_cell_start + 6
                CONTINUE WHILE
            END IF

            LET v_data_start = INSTR(v_xml, ">", v_data_start) + 1
            LET v_data_end = INSTR(v_xml, "</Data>", v_data_start)
            IF v_data_end = 0 THEN EXIT WHILE END IF

            LET v_valor = SUBSTR(v_xml, v_data_start, v_data_end - v_data_start)
            LET v_col = v_col + 1

            -- Mostrar solo filas de datos (después de tags)
            IF v_fila > 2 AND v_valor IS NOT NULL AND v_valor != "" THEN
                DISPLAY "Fila ", v_fila, " Col ", v_col, ": ", v_valor
            END IF

            LET v_cell_start = v_data_end + 7
        END WHILE

        LET v_pos = v_row_end + 6
    END WHILE

    MESSAGE "✅ Archivo leído: ", p_ruta
    MESSAGE "   Filas procesadas: ", v_fila
END FUNCTION

-- ============================================================
-- EJEMPLO 3: Validar datos leídos desde SpreadsheetML
-- ============================================================
FUNCTION validar_desde_spreadsheetml(p_ruta VARCHAR(300))
    -- 1. Leer archivo
    -- 2. Extraer valores por tag
    -- 3. Aplicar val_* a cada campo
    -- 4. Mostrar resultado

    MESSAGE "Validando datos desde SpreadsheetML..."
    CALL leer_spreadsheetml(p_ruta)
    -- Aquí se aplicarían las validaciones val_*
END FUNCTION

-- ============================================================
-- MAIN - Ejecutar ejemplos
-- ============================================================
MAIN
    DEFINE opcion SMALLINT

    DATABASE banco

    MENU "EJEMPLO SPREADSHEETML"
        COMMAND "1. Generar SpreadsheetML desde BD"  CALL generar_spreadsheetml_ejemplo()
        COMMAND "2. Leer SpreadsheetML"              CALL leer_spreadsheetml("ejemplo/plantilla_ejemplo.xml")
        COMMAND "3. Validar desde SpreadsheetML"      CALL validar_desde_spreadsheetml("ejemplo/plantilla_ejemplo.xml")
        COMMAND "0. Salir"                            EXIT MENU
    END MENU
END MAIN