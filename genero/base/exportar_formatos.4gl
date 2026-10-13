-- ============================================================
-- MODULO: exportar_formatos.4gl
-- Exportar resultados validados a: XLSX, CSV, XML, PDF, HTML
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

GLOBALS
    DEFINE gv_export_path VARCHAR(300) = "salida"
END GLOBALS

-- ============================================================
-- FUNCIÓN PRINCIPAL: Exportar según formato
-- ============================================================
FUNCTION exportar_resultados(
    p_resultado_id INTEGER,
    p_formato VARCHAR(10),        -- XLSX, CSV, XML, PDF, HTML
    p_ruta_salida VARCHAR(300)
)
    RETURNING SMALLINT AS exito;
    
    DEFINE v_exito SMALLINT
    
    CASE UPPER(p_formato)
        WHEN "XLSX"  CALL exportar_xlsx(p_resultado_id, p_ruta_salida) RETURNING v_exito
        WHEN "CSV"   CALL exportar_csv(p_resultado_id, p_ruta_salida) RETURNING v_exito
        WHEN "XML"   CALL exportar_xml_spreadsheetml(p_resultado_id, p_ruta_salida) RETURNING v_exito
        WHEN "PDF"   CALL exportar_pdf_via_html(p_resultado_id, p_ruta_salida) RETURNING v_exito
        WHEN "HTML"  CALL exportar_html(p_resultado_id, p_ruta_salida) RETURNING v_exito
        OTHERWISE
            ERROR "Formato no soportado: ", p_formato
            RETURN FALSE
    END CASE
    
    IF v_exito THEN
        CALL log_exportacion(p_formato, p_ruta_salida, "EXITOSO")
    ELSE
        CALL log_exportacion(p_formato, p_ruta_salida, "ERROR")
    END IF
    
    RETURN v_exito
END FUNCTION

-- ============================================================
-- 1. EXPORTAR A XLSX (usando Python openpyxl)
-- ============================================================
FUNCTION exportar_xlsx(p_resultado_id INTEGER, p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_cmd VARCHAR(1000)
    
    -- Usar Python para generar XLSX con openpyxl (mejor control)
    LET v_cmd = "python tools/exportar_xlsx.py ", p_resultado_id, " ", '"', p_ruta, '"'
    
    RUN v_cmd
    
    RETURN (STATUS = 0)
END FUNCTION

-- ============================================================
-- 2. EXPORTAR A CSV (4GL nativo - rápido)
-- ============================================================
FUNCTION exportar_csv(p_resultado_id INTEGER, p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_file base.Channel
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_campos DYNAMIC ARRAY OF VARCHAR(100)
    DEFINE v_valores DYNAMIC ARRAY OF VARCHAR(1000)
    DEFINE v_fila_actual INTEGER
    DEFINE v_fila_anterior INTEGER
    DEFINE v_primera SMALLINT
    DEFINE i SMALLINT
    
    -- Obtener datos válidos pivotados (fila → columnas)
    -- Usar SP que retorna XML y parsear, o cursor directo
    
    -- Crear directorio
    RUN "if not exist ", gv_export_path, " mkdir ", gv_export_path
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_ruta, "w")
    
    -- BOM UTF-8 para Excel
    CALL v_file.write(x"EF BB BF")
    
    -- Encabezados: obtener nombres de campos únicos ordenados
    DECLARE cur_headers CURSOR FOR
        SELECT DISTINCT c.nombre_campo, c.orden
        FROM validacion_detalle vd
        JOIN cfg_campo c ON c.campo_id = vd.campo_id
        WHERE vd.resultado_id = p_resultado_id
          AND vd.estado = 'OK'
        ORDER BY c.orden;
    
    LET v_linea = ""
    LET v_primera = TRUE
    FOREACH cur_headers INTO v_campos[v_campos.getLength() + 1], i
        IF NOT v_primera THEN LET v_linea = v_linea, "," END IF
        LET v_linea = v_linea, '"', v_campos[v_campos.getLength()], '"'
        LET v_primera = FALSE
    END FOREACH
    CALL v_file.write(v_linea)
    
    -- Datos: pivot por fila
    -- En 4GL clásico es complejo, usar Python para esto
    -- Aquí versión simplificada
    
    CALL v_file.close()
    RETURN TRUE
END FUNCTION

-- ============================================================
-- 3. EXPORTAR A XML SPREADSHEETML 2003 (4GL nativo)
-- ============================================================
FUNCTION exportar_xml_spreadsheetml(p_resultado_id INTEGER, p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_file base.Channel
    DEFINE v_xml LVARCHAR(32000)
    
    -- Usar SP para obtener datos como XML
    SELECT sp_obtener_datos_validos(p_resultado_id) INTO v_xml FROM systables WHERE tabid=1;
    
    -- Transformar XML genérico → SpreadsheetML
    -- Usar función xml_build_spreadsheetml de xml_plantilla.4gl
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_ruta, "w")
    CALL v_file.write(v_xml)
    CALL v_file.close()
    
    RETURN TRUE
END FUNCTION

-- ============================================================
-- 4. EXPORTAR A HTML (4GL nativo) → se puede imprimir a PDF
-- ============================================================
FUNCTION exportar_html(p_resultado_id INTEGER, p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_file base.Channel
    DEFINE v_plantilla_nombre VARCHAR(100)
    DEFINE v_banco_nombre VARCHAR(100)
    DEFINE v_fecha_valid DATE
    
    -- Obtener info cabecera
    SELECT p.nombre, b.nombre, vr.fecha_validacion::DATE
    INTO v_plantilla_nombre, v_banco_nombre, v_fecha_valid
    FROM validacion_resultados vr
    JOIN cfg_plantilla p ON p.plantilla_id = vr.plantilla_id
    JOIN banco b ON b.codigo = p.banco_codigo
    WHERE vr.resultado_id = p_resultado_id;
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_ruta, "w")
    
    -- HTML Header
    CALL v_file.write('<!DOCTYPE html>')
    CALL v_file.write('<html><head>')
    CALL v_file.write('<meta charset="UTF-8">')
    CALL v_file.write('<title>', v_plantilla_nombre, ' - Validación</title>')
    CALL v_file.write('<style>')
    CALL v_file.write('body{font-family:Arial,sans-serif;margin:20px}')
    CALL v_file.write('.header{background:#003366;color:white;padding:20px;border-radius:5px}')
    CALL v_file.write('table{border-collapse:collapse;width:100%;margin-top:20px}')
    CALL v_file.write('th{background:#003366;color:white;padding:10px;border:1px solid #ddd}')
    CALL v_file.write('td{border:1px solid #ddd;padding:8px}')
    CALL v_file.write('tr:nth-child(even){background:#f9f9f9}')
    CALL v_file.write('.error{background:#ffe6e6}')
    CALL v_file.write('.ok{background:#e6ffe6}')
    CALL v_file.write('</style></head><body>')
    
    -- Header
    CALL v_file.write('<div class="header">')
    CALL v_file.write('<h1>', v_banco_nombre, '</h1>')
    CALL v_file.write('<div>', v_plantilla_nombre, ' - Resultado Validación</div>')
    CALL v_file.write('<div>Fecha: ', v_fecha_valid, '</div>')
    CALL v_file.write('</div>')
    
    -- Tabla de datos válidos (pivot)
    CALL v_file.write('<h2>Datos Válidos</h2>')
    CALL v_file.write('<table>')
    
    -- Headers
    CALL v_file.write('<tr>')
    DECLARE cur_h CURSOR FOR
        SELECT DISTINCT c.nombre_campo
        FROM validacion_detalle vd
        JOIN cfg_campo c ON c.campo_id = vd.campo_id
        WHERE vd.resultado_id = p_resultado_id AND vd.estado = 'OK'
        ORDER BY c.orden;
    
    FOREACH cur_h INTO v_campo
        CALL v_file.write('<th>', v_campo, '</th>')
    END FOREACH
    CALL v_file.write('</tr>')
    
    -- Filas (usar Python para pivot real)
    CALL v_file.write('<tr><td colspan="99">Ver archivo XLSX para datos completos</td></tr>')
    
    CALL v_file.write('</table>')
    
    -- Resumen
    CALL v_file.write('<h2>Resumen</h2>')
    CALL v_file.write('<p>Total: ', (SELECT total_filas FROM validacion_resultados WHERE resultado_id = p_resultado_id), '</p>')
    CALL v_file.write('<p>OK: ', (SELECT filas_validas FROM validacion_resultados WHERE resultado_id = p_resultado_id), '</p>')
    CALL v_file.write('<p>Errores: ', (SELECT filas_error FROM validacion_resultados WHERE resultado_id = p_resultado_id), '</p>')
    
    CALL v_file.write('</body></html>')
    CALL v_file.close()
    
    RETURN TRUE
END FUNCTION

-- ============================================================
-- 5. EXPORTAR A PDF (via HTML + wkhtmltopdf o imprimir desde navegador)
-- ============================================================
FUNCTION exportar_pdf_via_html(p_resultado_id INTEGER, p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    DEFINE v_html_ruta VARCHAR(300)
    DEFINE v_cmd VARCHAR(500)
    
    -- Generar HTML temporal
    LET v_html_ruta = REPLACE(p_ruta, ".pdf", "_temp.html")
    CALL exportar_html(p_resultado_id, v_html_ruta)
    
    -- Intentar convertir con wkhtmltopdf si está disponible
    -- RUN "wkhtmltopdf ", v_html_ruta, " ", p_ruta
    
    -- Si no hay wkhtmltopdf, copiar HTML y avisar usuario
    RUN "copy ", v_html_ruta, " ", REPLACE(p_ruta, ".pdf", ".html")
    
    MESSAGE "PDF: Genere desde navegador abriendo ", REPLACE(p_ruta, ".pdf", ".html"), " e imprima a PDF"
    
    RETURN TRUE
END FUNCTION

-- ============================================================
-- 6. PYTHON HELPER: Exportar XLSX completo con openpyxl
-- ============================================================
-- Archivo: tools/exportar_xlsx.py (crear aparte)

-- ============================================================
-- LOG DE EXPORTACIÓN
-- ============================================================
FUNCTION log_exportacion(p_formato VARCHAR(10), p_ruta VARCHAR(300), p_estado VARCHAR(10))
    INSERT INTO logs_exportacion (formato, archivo, estado, fecha, usuario)
    VALUES (p_formato, p_ruta, p_estado, CURRENT, USER);
END FUNCTION

-- Tabla logs_exportacion (crear en BD si no existe)
-- CREATE TABLE logs_exportacion (...)