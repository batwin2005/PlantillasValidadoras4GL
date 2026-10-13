# ============================================================
# MODULO: importar_exportar.4gl
# Importar/Exportar archivos CSV y XML Excel
# Integrado con logs y validaciones
# ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_usuario VARCHAR(30) = USER
END GLOBALS

# ============================================================
# TIPOS DE DATOS
# ============================================================
TYPE ty_error RECORD
    fila INTEGER,
    campo VARCHAR(50),
    valor VARCHAR(200),
    error VARCHAR(200)
END RECORD

TYPE ty_movimiento RECORD
    fecha VARCHAR(20),
    documento VARCHAR(50),
    concepto VARCHAR(200),
    tercero VARCHAR(100),
    deposito DECIMAL(15,2),
    retiro DECIMAL(15,2)
END RECORD

DEFINE arr_errores DYNAMIC ARRAY OF ty_error


# ============================================================
# 1. IMPORTAR CSV
# ============================================================
FUNCTION importar_csv(p_archivo, p_cuenta_id)
    DEFINE p_archivo VARCHAR(300)
    DEFINE p_cuenta_id INTEGER
    
    DEFINE v_file base.Channel
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_fila INTEGER
    DEFINE v_total_registros INTEGER
    DEFINE arr_datos DYNAMIC ARRAY OF ty_movimiento
    DEFINE v_resultado VARCHAR(20)
    
    # Limpiar errores
    CALL arr_errores.clear()
    LET v_fila = 0
    LET v_total_registros = 0
    
    # Log inicio
    CALL log_info("import_csv", 
        "Iniciando importación: ", p_archivo)
    
    # Verificar que el archivo existe
    IF NOT file_exists(p_archivo) THEN
        CALL log_error("import_csv", 
            "Archivo no encontrado: ", p_archivo)
        RETURN "ERROR: Archivo no encontrado"
    END IF
    
    # Abrir archivo
    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_archivo, "r")
    
    # Leer línea por línea
    WHILE v_file.read(v_linea)
        LET v_fila = v_fila + 1
        
        # Saltar encabezado
        IF v_fila = 1 THEN
            CONTINUE WHILE
        END IF
        
        # Parsear línea
        CALL parsear_csv_linea(v_linea)
            RETURNING arr_datos[v_fila - 1].*
        
        # Validar fila
        CALL validar_movimiento(
            v_fila - 1,
            arr_datos[v_fila - 1].*
        )
        
        LET v_total_registros = v_total_registros + 1
        
    END WHILE
    
    CALL v_file.close()
    
    # Verificar errores
    IF arr_errores.getLength() > 0 THEN
        CALL log_error("import_csv", 
            "Importación con errores: ", arr_errores.getLength())
        RETURN "ERRORES"
    END IF
    
    # Insertar en BD
    LET v_resultado = insertar_movimientos(p_cuenta_id, arr_datos)
    
    IF v_resultado = "EXITOSO" THEN
        CALL log_info("import_csv", 
            "Importación exitosa: ", v_total_registros, " registros")
    END IF
    
    RETURN v_resultado
    
END FUNCTION


# ============================================================
# 2. IMPORTAR XML EXCEL
# ============================================================
FUNCTION importar_xml_excel(p_archivo, p_cuenta_id)
    DEFINE p_archivo VARCHAR(300)
    DEFINE p_cuenta_id INTEGER
    
    DEFINE v_file base.Channel
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_xml LVARCHAR(32000)
    DEFINE arr_datos DYNAMIC ARRAY OF ty_movimiento
    DEFINE v_resultado VARCHAR(20)
    DEFINE i INTEGER
    
    CALL arr_errores.clear()
    
    CALL log_info("import_xml", 
        "Iniciando importación XML: ", p_archivo)
    
    # Verificar archivo
    IF NOT file_exists(p_archivo) THEN
        CALL log_error("import_xml", 
            "Archivo no encontrado: ", p_archivo)
        RETURN "ERROR: Archivo no encontrado"
    END IF
    
    # Leer contenido XML
    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_archivo, "r")
    
    LET v_xml = ""
    WHILE v_file.read(v_linea)
        LET v_xml = v_xml, v_linea
    END WHILE
    CALL v_file.close()
    
    # Parsear XML
    CALL parsear_xml_movimientos(v_xml)
        RETURNING arr_datos
    
    # Validar cada registro
    FOR i = 1 TO arr_datos.getLength()
        CALL validar_movimiento(i, arr_datos[i].*)
    END FOR
    
    # Verificar errores
    IF arr_errores.getLength() > 0 THEN
        CALL log_error("import_xml", 
            "Importación con errores: ", arr_errores.getLength())
        RETURN "ERRORES"
    END IF
    
    # Insertar en BD
    LET v_resultado = insertar_movimientos(p_cuenta_id, arr_datos)
    
    IF v_resultado = "EXITOSO" THEN
        CALL log_info("import_xml", 
            "Importación exitosa: ", arr_datos.getLength(), " registros")
    END IF
    
    RETURN v_resultado
    
END FUNCTION


# ============================================================
# 3. EXPORTAR A CSV (con info del banco)
# ============================================================
FUNCTION exportar_csv(p_cuenta_id, p_fecha_desde, p_fecha_hasta)
    DEFINE p_cuenta_id INTEGER
    DEFINE p_fecha_desde DATE
    DEFINE p_fecha_hasta DATE
    
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE rec RECORD
        fecha DATE,
        documento VARCHAR(50),
        concepto VARCHAR(200),
        tercero VARCHAR(100),
        deposito DECIMAL(15,2),
        retiro DECIMAL(15,2)
    END RECORD
    DEFINE v_contador INTEGER
    DEFINE v_banco_nombre VARCHAR(100)
    DEFINE v_cuenta_numero VARCHAR(50)
    DEFINE v_moneda CHAR(3)
    DEFINE v_saldo_inicial DECIMAL(15,2)
    
    CALL log_info("export_csv", 
        "Iniciando exportación CSV")
    
    # Obtener info del banco y cuenta
    SELECT 
        b.nombre,
        c.num_cuenta,
        c.moneda,
        c.saldo_inicial
    INTO 
        v_banco_nombre,
        v_cuenta_numero,
        v_moneda,
        v_saldo_inicial
    FROM banco_cuenta c
    JOIN banco b ON c.banco_codigo = b.codigo
    WHERE c.cuenta_id = p_cuenta_id
    
    # Crear directorio export
    CALL crear_directorio("export")
    
    # Nombre de archivo
    LET v_ruta = "export/",
                 LOWER(v_banco_nombre[1,20]), "_",
                 TODAY USING "YYYYMMDD",
                 "_", CURRENT USING "HH24MISS", ".csv"
    
    # Abrir archivo
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")
    
    # BOM UTF-8 para Excel
    CALL v_file.write(x"EF BB BF")
    
    # ========================================
    # ENCABEZADO CON INFO DEL BANCO
    # ========================================
    CALL v_file.write(v_banco_nombre)
    CALL v_file.write("Libro de Movimientos")
    CALL v_file.write("Cuenta: ", v_cuenta_numero, 
                      " | Moneda: ", v_moneda)
    CALL v_file.write("Período: ", p_fecha_desde, 
                      " al ", p_fecha_hasta)
    CALL v_file.write("Generado: ", TODAY, 
                      " ", CURRENT HOUR TO MINUTE,
                      " | Usuario: ", gv_usuario)
    CALL v_file.write("")  # Línea vacía
    
    # Encabezados de columnas
    CALL v_file.write(
        "Fecha,Documento,Concepto,Tercero,Deposito,Retiro")
    
    # Consultar datos
    DECLARE cur_export CURSOR FOR
        SELECT fecha, documento, concepto, tercero,
               deposito, retiro
        FROM banco_movimiento
        WHERE cuenta_id = p_cuenta_id
          AND fecha BETWEEN p_fecha_desde AND p_fecha_hasta
        ORDER BY fecha
    
    LET v_contador = 0
    
    FOREACH cur_export INTO rec.*
        CALL v_file.write(
            '"', rec.fecha, '",',
            '"', rec.documento, '",',
            '"', rec.concepto, '",',
            '"', rec.tercero, '",',
            rec.deposito, ',',
            rec.retiro)
        LET v_contador = v_contador + 1
    END FOREACH
    
    # ========================================
    # PIE DE ARCHIVO CON TOTALES
    # ========================================
    CALL v_file.write("")
    CALL v_file.write("Total registros: ", v_contador)
    
    CALL v_file.close()
    
    CALL log_info("export_csv", 
        "Exportación exitosa: ", v_contador, " registros")
    CALL log_exportacion("CSV", v_ruta, v_contador, "EXITOSO")
    
    RETURN v_ruta
    
END FUNCTION


# ============================================================
# 4. EXPORTAR A XML EXCEL
# ============================================================
FUNCTION exportar_xml_excel(p_cuenta_id, p_fecha_desde, p_fecha_hasta)
    DEFINE p_cuenta_id INTEGER
    DEFINE p_fecha_desde DATE
    DEFINE p_fecha_hasta DATE
    
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE rec RECORD
        fecha DATE,
        documento VARCHAR(50),
        concepto VARCHAR(200),
        tercero VARCHAR(100),
        deposito DECIMAL(15,2),
        retiro DECIMAL(15,2)
    END RECORD
    DEFINE v_contador INTEGER
    DEFINE v_banco_nombre VARCHAR(100)
    DEFINE v_cuenta_numero VARCHAR(50)
    
    CALL log_info("export_xml", 
        "Iniciando exportación XML")
    
    # Obtener info del banco
    SELECT b.nombre, c.num_cuenta
    INTO v_banco_nombre, v_cuenta_numero
    FROM banco_cuenta c
    JOIN banco b ON c.banco_codigo = b.codigo
    WHERE c.cuenta_id = p_cuenta_id
    
    CALL crear_directorio("export")
    
    LET v_ruta = "export/",
                 LOWER(v_banco_nombre[1,20]), "_",
                 TODAY USING "YYYYMMDD",
                 "_", CURRENT USING "HH24MISS", ".xml"
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")
    
    # Cabecera XML SpreadsheetML
    CALL v_file.write('<?xml version="1.0" encoding="UTF-8"?>')
    CALL v_file.write('<?mso-application progid="Excel.Sheet"?>')
    CALL v_file.write(
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"')
    CALL v_file.write(
        ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">')
    
    # Estilos
    CALL v_file.write(' <Styles>')
    CALL v_file.write('  <Style ss:ID="titulo">')
    CALL v_file.write('   <Font ss:Bold="1" ss:Size="14" ss:Color="#003366"/>')
    CALL v_file.write('  </Style>')
    CALL v_file.write('  <Style ss:ID="header">')
    CALL v_file.write('   <Font ss:Bold="1" ss:Color="#FFFFFF"/>')
    CALL v_file.write(
        '   <Interior ss:Color="#003366" ss:Pattern="Solid"/>')
    CALL v_file.write('  </Style>')
    CALL v_file.write('  <Style ss:ID="money">')
    CALL v_file.write('   <NumberFormat ss:Format="#,##0.00"/>')
    CALL v_file.write('  </Style>')
    CALL v_file.write(' </Styles>')
    
    # Hoja
    CALL v_file.write(' <Worksheet ss:Name="Movimientos">')
    CALL v_file.write('  <Table>')
    
    # ========================================
    # ENCABEZADO CON INFO DEL BANCO
    # ========================================
    CALL v_file.write('   <Row>')
    CALL v_file.write(
        '    <Cell ss:StyleID="titulo"><Data ss:Type="String">', 
        v_banco_nombre, '</Data></Cell>')
    CALL v_file.write('   </Row>')
    CALL v_file.write('   <Row>')
    CALL v_file.write(
        '    <Cell><Data ss:Type="String">Libro de Movimientos</Data></Cell>')
    CALL v_file.write('   </Row>')
    CALL v_file.write('   <Row>')
    CALL v_file.write(
        '    <Cell><Data ss:Type="String">Cuenta: ', 
        v_cuenta_numero, '</Data></Cell>')
    CALL v_file.write('   </Row>')
    CALL v_file.write('   <Row>')
    CALL v_file.write(
        '    <Cell><Data ss:Type="String">Período: ', 
        p_fecha_desde, ' al ', p_fecha_hasta, '</Data></Cell>')
    CALL v_file.write('   </Row>')
    CALL v_file.write('   <Row ss:Height="5"/>')  # Espacio
    
    # Encabezados de columnas
    CALL v_file.write('   <Row>')
    CALL v_file.write(
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Fecha</Data></Cell>')
    CALL v_file.write(
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Documento</Data></Cell>')
    CALL v_file.write(
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Concepto</Data></Cell>')
    CALL v_file.write(
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Tercero</Data></Cell>')
    CALL v_file.write(
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Deposito</Data></Cell>')
    CALL v_file.write(
        '    <Cell ss:StyleID="header"><Data ss:Type="String">Retiro</Data></Cell>')
    CALL v_file.write('   </Row>')
    
    # Datos
    DECLARE cur_export_xml CURSOR FOR
        SELECT fecha, documento, concepto, tercero,
               deposito, retiro
        FROM banco_movimiento
        WHERE cuenta_id = p_cuenta_id
          AND fecha BETWEEN p_fecha_desde AND p_fecha_hasta
        ORDER BY fecha
    
    LET v_contador = 0
    
    FOREACH cur_export_xml INTO rec.*
        CALL v_file.write('   <Row>')
        CALL v_file.write(
            '    <Cell><Data ss:Type="String">', 
            rec.fecha, '</Data></Cell>')
        CALL v_file.write(
            '    <Cell><Data ss:Type="String">', 
            rec.documento, '</Data></Cell>')
        CALL v_file.write(
            '    <Cell><Data ss:Type="String">', 
            rec.concepto, '</Data></Cell>')
        CALL v_file.write(
            '    <Cell><Data ss:Type="String">', 
            rec.tercero, '</Data></Cell>')
        CALL v_file.write(
            '    <Cell ss:StyleID="money"><Data ss:Type="Number">', 
            rec.deposito, '</Data></Cell>')
        CALL v_file.write(
            '    <Cell ss:StyleID="money"><Data ss:Type="Number">', 
            rec.retiro, '</Data></Cell>')
        CALL v_file.write('   </Row>')
        
        LET v_contador = v_contador + 1
    END FOREACH
    
    CALL v_file.write('  </Table>')
    CALL v_file.write(' </Worksheet>')
    CALL v_file.write('</Workbook>')
    
    CALL v_file.close()
    
    CALL log_info("export_xml", 
        "Exportación exitosa: ", v_contador, " registros")
    CALL log_exportacion("XML", v_ruta, v_contador, "EXITOSO")
    
    RETURN v_ruta
    
END FUNCTION


# ============================================================
# 5. EXPORTAR A HTML
# ============================================================
FUNCTION exportar_html(p_cuenta_id, p_fecha_desde, p_fecha_hasta)
    DEFINE p_cuenta_id INTEGER
    DEFINE p_fecha_desde DATE
    DEFINE p_fecha_hasta DATE
    
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE rec RECORD
        fecha DATE,
        documento VARCHAR(50),
        concepto VARCHAR(200),
        tercero VARCHAR(100),
        deposito DECIMAL(15,2),
        retiro DECIMAL(15,2),
        saldo DECIMAL(15,2)
    END RECORD
    DEFINE v_contador INTEGER
    DEFINE v_banco_nombre VARCHAR(100)
    DEFINE v_banco_codigo VARCHAR(20)
    DEFINE v_cuenta_numero VARCHAR(50)
    DEFINE v_color_hex VARCHAR(7)
    
    CALL log_info("export_html", 
        "Iniciando exportación HTML")
    
    # Obtener info del banco
    SELECT b.nombre, b.codigo, c.num_cuenta, b.color_hex
    INTO v_banco_nombre, v_banco_codigo, v_cuenta_numero, v_color_hex
    FROM banco_cuenta c
    JOIN banco b ON c.banco_codigo = b.codigo
    WHERE c.cuenta_id = p_cuenta_id
    
    # Color por defecto si el banco no tiene
    IF v_color_hex IS NULL OR v_color_hex = "" THEN
        LET v_color_hex = "#003366"
    END IF
    
    CALL crear_directorio("export")
    
    LET v_ruta = "export/",
                 LOWER(v_banco_codigo), "_",
                 TODAY USING "YYYYMMDD",
                 "_", CURRENT USING "HH24MISS", ".html"
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")
    
    # HTML con estilo del banco
    CALL v_file.write('<!DOCTYPE html>')
    CALL v_file.write('<html><head>')
    CALL v_file.write('<meta charset="UTF-8">')
    CALL v_file.write('<title>', v_banco_nombre, 
                      ' - Libro de Movimientos</title>')
    CALL v_file.write('<style>')
    CALL v_file.write('body{font-family:Arial,sans-serif;margin:20px}')
    CALL v_file.write('.header{background:', v_color_hex, 
                      ';color:white;padding:20px;border-radius:5px}')
    CALL v_file.write('.header h1{margin:0;font-size:24px}')
    CALL v_file.write('.header .subtitle{font-size:14px;opacity:0.9}')
    CALL v_file.write('table{border-collapse:collapse;width:100%;margin-top:20px}')
    CALL v_file.write('th{background:', v_color_hex, 
                      ';color:white;padding:10px;border:1px solid #ddd}')
    CALL v_file.write('td{border:1px solid #ddd;padding:8px}')
    CALL v_file.write('tr:nth-child(even){background:#f9f9f9}')
    CALL v_file.write('.num{text-align:right}')
    CALL v_file.write('.money{font-family:monospace}')
    CALL v_file.write('.footer{margin-top:20px;font-size:12px;color:#666}')
    CALL v_file.write('</style></head><body>')
    
    # Encabezado con estilo del banco
    CALL v_file.write('<div class="header">')
    CALL v_file.write('<h1>', v_banco_nombre, '</h1>')
    CALL v_file.write('<div class="subtitle">Libro de Movimientos</div>')
    CALL v_file.write('</div>')
    
    # Info adicional
    CALL v_file.write('<p><strong>Cuenta:</strong> ', 
                      v_cuenta_numero, '</p>')
    CALL v_file.write('<p><strong>Período:</strong> ', 
                      p_fecha_desde, ' al ', p_fecha_hasta, '</p>')
    CALL v_file.write('<p><strong>Generado:</strong> ', 
                      TODAY, ' ', CURRENT HOUR TO MINUTE, '</p>')
    
    # Tabla
    CALL v_file.write('<table>')
    CALL v_file.write('<tr>')
    CALL v_file.write('<th>Fecha</th>')
    CALL v_file.write('<th>Documento</th>')
    CALL v_file.write('<th>Concepto</th>')
    CALL v_file.write('<th>Tercero</th>')
    CALL v_file.write('<th>Deposito</th>')
    CALL v_file.write('<th>Retiro</th>')
    CALL v_file.write('<th>Saldo</th>')
    CALL v_file.write('</tr>')
    
    DECLARE cur_export_html CURSOR FOR
        SELECT fecha, documento, concepto, tercero,
               deposito, retiro, saldo
        FROM banco_movimiento
        WHERE cuenta_id = p_cuenta_id
          AND fecha BETWEEN p_fecha_desde AND p_fecha_hasta
        ORDER BY fecha
    
    LET v_contador = 0
    
    FOREACH cur_export_html INTO rec.*
        CALL v_file.write('<tr>')
        CALL v_file.write('<td>', rec.fecha, '</td>')
        CALL v_file.write('<td>', rec.documento, '</td>')
        CALL v_file.write('<td>', rec.concepto, '</td>')
        CALL v_file.write('<td>', rec.tercero, '</td>')
        CALL v_file.write('<td class="num money">', 
                          rec.deposito, '</td>')
        CALL v_file.write('<td class="num money">', 
                          rec.retiro, '</td>')
        CALL v_file.write('<td class="num money">', 
                          rec.saldo, '</td>')
        CALL v_file.write('</tr>')
        
        LET v_contador = v_contador + 1
    END FOREACH
    
    # Pie
    CALL v_file.write('</table>')
    CALL v_file.write('<div class="footer">')
    CALL v_file.write('Total registros: ', v_contador, ' | ')
    CALL v_file.write('Generado por Plantillas4GL | ')
    CALL v_file.write(v_banco_nombre)
    CALL v_file.write('</div>')
    CALL v_file.write('</body></html>')
    
    CALL v_file.close()
    
    CALL log_info("export_html", 
        "Exportación exitosa: ", v_contador, " registros")
    CALL log_exportacion("HTML", v_ruta, v_contador, "EXITOSO")
    
    RETURN v_ruta
    
END FUNCTION


# ============================================================
# 6. FUNCIONES DE PARSEO
# ============================================================
FUNCTION parsear_csv_linea(p_linea)
    DEFINE p_linea VARCHAR(32000)
    DEFINE r_campos ty_movimiento
    DEFINE v_pos INTEGER
    DEFINE v_campo VARCHAR(32000)
    DEFINE v_indice INTEGER
    
    LET v_pos = 1
    LET v_indice = 1
    LET v_campo = ""
    
    WHILE v_pos <= LENGTH(p_linea)
        IF p_linea[v_pos] = "," THEN
            CALL asignar_campo_csv(v_indice, v_campo)
                RETURNING r_campos.*
            LET v_indice = v_indice + 1
            LET v_campo = ""
        ELSE
            LET v_campo = v_campo, p_linea[v_pos]
        END IF
        LET v_pos = v_pos + 1
    END WHILE
    
    # Último campo
    CALL asignar_campo_csv(v_indice, v_campo)
        RETURNING r_campos.*
    
    RETURN r_campos.*
    
END FUNCTION


FUNCTION asignar_campo_csv(p_indice, p_valor)
    DEFINE p_indice INTEGER
    DEFINE p_valor VARCHAR(32000)
    DEFINE r ty_movimiento
    
    CASE p_indice
        WHEN 1 THEN LET r.fecha = p_valor
        WHEN 2 THEN LET r.documento = p_valor
        WHEN 3 THEN LET r.concepto = p_valor
        WHEN 4 THEN LET r.tercero = p_valor
        WHEN 5 THEN LET r.deposito = p_valor
        WHEN 6 THEN LET r.retiro = p_valor
    END CASE
    
    RETURN r.*
    
END FUNCTION


FUNCTION parsear_xml_movimientos(p_xml)
    DEFINE p_xml LVARCHAR(32000)
    DEFINE arr_datos DYNAMIC ARRAY OF ty_movimiento
    DEFINE v_pos INTEGER
    DEFINE v_fila INTEGER
    DEFINE v_temp VARCHAR(32000)
    
    # Buscar tags <movimiento>
    LET v_pos = 1
    LET v_fila = 0
    
    WHILE v_pos < LENGTH(p_xml)
        # Buscar <movimiento>
        LET v_temp = buscar_tag(p_xml, v_pos, "<movimiento>")
        
        IF v_temp IS NULL THEN
            EXIT WHILE
        END IF
        
        LET v_fila = v_fila + 1
        
        # Extraer campos
        LET arr_datos[v_fila].fecha = 
            extraer_tag(p_xml, v_pos, "fecha")
        LET arr_datos[v_fila].documento = 
            extraer_tag(p_xml, v_pos, "documento")
        LET arr_datos[v_fila].concepto = 
            extraer_tag(p_xml, v_pos, "concepto")
        LET arr_datos[v_fila].tercero = 
            extraer_tag(p_xml, v_pos, "tercero")
        LET arr_datos[v_fila].deposito = 
            extraer_tag(p_xml, v_pos, "deposito")
        LET arr_datos[v_fila].retiro = 
            extraer_tag(p_xml, v_pos, "retiro")
        
        LET v_pos = v_pos + LENGTH(v_temp)
        
    END WHILE
    
    RETURN arr_datos
    
END FUNCTION


# ============================================================
# 7. VALIDACIONES
# ============================================================
FUNCTION validar_movimiento(p_fila, p_datos)
    DEFINE p_fila INTEGER
    DEFINE p_datos ty_movimiento
    
    # Validar fecha
    IF p_datos.fecha IS NULL OR p_datos.fecha = "" THEN
        CALL agregar_error(p_fila, "fecha", "",
            "Fecha es obligatoria")
    ELSE
        IF NOT validar_fecha(p_datos.fecha) THEN
            CALL agregar_error(p_fila, "fecha", 
                p_datos.fecha,
                "Formato inválido (DD/MM/YYYY)")
        END IF
    END IF
    
    # Validar concepto (obligatorio)
    IF p_datos.concepto IS NULL OR 
       LENGTH(TRIM(p_datos.concepto)) = 0 THEN
        CALL agregar_error(p_fila, "concepto", "",
            "Concepto es obligatorio")
    END IF
    
    # Validar depósito
    IF p_datos.deposito < 0 THEN
        CALL agregar_error(p_fila, "deposito",
            p_datos.deposito,
            "Depósito no puede ser negativo")
    END IF
    
    # Validar retiro
    IF p_datos.retiro < 0 THEN
        CALL agregar_error(p_fila, "retiro",
            p_datos.retiro,
            "Retiro no puede ser negativo")
    END IF
    
    # Validar que no tenga ambos
    IF p_datos.deposito > 0 AND p_datos.retiro > 0 THEN
        CALL agregar_error(p_fila, "deposito/retiro",
            p_datos.deposito || "/" || p_datos.retiro,
            "No puede tener depósito y retiro juntos")
    END IF
    
END FUNCTION


FUNCTION validar_fecha(p_fecha)
    DEFINE p_fecha VARCHAR(20)
    DEFINE v_dia INTEGER
    DEFINE v_mes INTEGER
    DEFINE v_anio INTEGER
    
    IF LENGTH(p_fecha) != 10 THEN
        RETURN FALSE
    END IF
    
    IF p_fecha[3] != "/" OR p_fecha[6] != "/" THEN
        RETURN FALSE
    END IF
    
    LET v_dia = p_fecha[1,2]
    LET v_mes = p_fecha[4,5]
    LET v_anio = p_fecha[7,10]
    
    IF v_dia < 1 OR v_dia > 31 THEN
        RETURN FALSE
    END IF
    
    IF v_mes < 1 OR v_mes > 12 THEN
        RETURN FALSE
    END IF
    
    IF v_anio < 1900 OR v_anio > 2100 THEN
        RETURN FALSE
    END IF
    
    RETURN TRUE
    
END FUNCTION


# ============================================================
# 8. INSERTAR EN BD
# ============================================================
FUNCTION insertar_movimientos(p_cuenta_id, p_datos)
    DEFINE p_cuenta_id INTEGER
    DEFINE p_datos DYNAMIC ARRAY OF ty_movimiento
    DEFINE i INTEGER
    DEFINE v_err INTEGER
    DEFINE v_contador INTEGER
    
    LET v_contador = 0
    
    BEGIN WORK
    
    FOR i = 1 TO p_datos.getLength()
        INSERT INTO banco_movimiento (
            cuenta_id, fecha, documento, concepto,
            tercero, deposito, retiro, usuario
        ) VALUES (
            p_cuenta_id,
            convertir_fecha(p_datos[i].fecha),
            p_datos[i].documento,
            p_datos[i].concepto,
            p_datos[i].tercero,
            p_datos[i].deposito,
            p_datos[i].retiro,
            gv_usuario
        )
        
        LET v_err = STATUS
        
        IF v_err <> 0 THEN
            ROLLBACK WORK
            CALL log_error("import", 
                "Error insertando fila: ", i)
            RETURN "ERROR: Error insertando en BD"
        END IF
        
        LET v_contador = v_contador + 1
        
    END FOR
    
    COMMIT WORK
    
    RETURN "EXITOSO"
    
END FUNCTION


# ============================================================
# 9. HELPERS
# ============================================================
FUNCTION agregar_error(p_fila, p_campo, p_valor, p_error)
    DEFINE p_fila INTEGER
    DEFINE p_campo VARCHAR(50)
    DEFINE p_valor VARCHAR(200)
    DEFINE p_error VARCHAR(200)
    
    LET arr_errores[arr_errores.getLength() + 1].fila = p_fila
    LET arr_errores[arr_errores.getLength()].campo = p_campo
    LET arr_errores[arr_errores.getLength()].valor = p_valor
    LET arr_errores[arr_errores.getLength()].error = p_error
    
END FUNCTION


FUNCTION file_exists(p_archivo)
    DEFINE p_archivo VARCHAR(300)
    
    RUN "if exist ", p_archivo, " (exit 0) else (exit 1)"
    
    RETURN (STATUS = 0)
    
END FUNCTION


FUNCTION crear_directorio(p_dir)
    DEFINE p_dir VARCHAR(200)
    
    RUN "if not exist ", p_dir, " mkdir ", p_dir
    
END FUNCTION


FUNCTION convertir_fecha(p_fecha)
    DEFINE p_fecha VARCHAR(20)
    DEFINE v_result DATE
    
    # Convertir DD/MM/YYYY a DATE
    LET v_today = p_fecha[7,10], "-", 
                  p_fecha[4,5], "-",
                  p_fecha[1,2]
    
    LET v_result = v_today
    
    RETURN v_result
    
END FUNCTION
