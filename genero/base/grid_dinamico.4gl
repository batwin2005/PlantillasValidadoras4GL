# ============================================================
# MODULO: grid_dinamico.4gl
# Grid Dinámico - Muestra resultados de queries en pantalla
# Se adapta a cualquier query automáticamente
# ============================================================

DATABASE banco

# ============================================================
# TIPOS DE DATOS
# ============================================================
TYPE ty_columna_grid RECORD
    nombre VARCHAR(64),
    titulo VARCHAR(100),
    tipo VARCHAR(20),
    ancho INTEGER,
    formato VARCHAR(50),
    alineacion VARCHAR(10)
END RECORD

TYPE ty_grid_config RECORD
    titulo VARCHAR(200),
    subtitulo VARCHAR(200),
    columnas DYNAMIC ARRAY OF ty_columna_grid,
    datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(32000),
    total_filas INTEGER,
    total_columnas INTEGER,
    color_header VARCHAR(7),
    mostrar_paginacion CHAR(1),
    filas_por_pagina INTEGER,
    pagina_actual INTEGER
END RECORD

TYPE ty_filtro RECORD
    columna VARCHAR(64),
    operador VARCHAR(20),
    valor VARCHAR(200)
END RECORD

TYPE ty_orden RECORD
    columna VARCHAR(64),
    direccion VARCHAR(4)  -- ASC o DESC
END RECORD

# Configuración global
DEFINE g_grid_color_default VARCHAR(7) = '#003366'
DEFINE g_grid_filas_pagina INTEGER = 50


# ============================================================
# 1. EJECUTAR QUERY Y MOSTRAR EN GRID
# ============================================================
FUNCTION grid_ejecutar_query(p_query, p_titulo)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_titulo VARCHAR(200)
    
    DEFINE r_grid ty_grid_config
    DEFINE v_xml LVARCHAR(32739)
    DEFINE v_win WINDOW
    
    CALL log_info("grid", "Ejecutando query en grid: ", p_titulo)
    
    # 1. Obtener datos (con caché)
    LET v_xml = cache_query(p_query)
    
    IF v_xml IS NULL OR LENGTH(v_xml) = 0 THEN
        CALL mostrar_error_grid("No se obtuvieron resultados")
        RETURN FALSE
    END IF
    
    # 2. Parsear XML a grid
    CALL parsear_xml_a_grid(v_xml, p_titulo)
        RETURNING r_grid
    
    # 3. Mostrar grid en pantalla
    CALL mostrar_grid(r_grid)
    
    RETURN TRUE
    
END FUNCTION


# ============================================================
# 2. EJECUTAR QUERY CON FILTROS
# ============================================================
FUNCTION grid_ejecutar_query_filtrada(p_query_base, p_filtros, p_orden)
    DEFINE p_query_base LVARCHAR(32000)
    DEFINE p_filtros DYNAMIC ARRAY OF ty_filtro
    DEFINE p_orden DYNAMIC ARRAY OF ty_orden
    
    DEFINE v_query LVARCHAR(32000)
    DEFINE i INTEGER
    
    # Construir query con filtros
    LET v_query = construir_query_filtrada(
        p_query_base, p_filtros, p_orden)
    
    # Ejecutar
    CALL grid_ejecutar_query(v_query, "Consulta con filtros")
    
END FUNCTION


# ============================================================
# 3. CONSTRUIR QUERY CON FILTROS Y ORDEN
# ============================================================
FUNCTION construir_query_filtrada(p_query_base, p_filtros, p_orden)
    DEFINE p_query_base LVARCHAR(32000)
    DEFINE p_filtros DYNAMIC ARRAY OF ty_filtro
    DEFINE p_orden DYNAMIC ARRAY OF ty_orden
    
    DEFINE v_query LVARCHAR(32000)
    DEFINE i INTEGER
    DEFINE v_where VARCHAR(32000)
    DEFINE v_order VARCHAR(500)
    
    LET v_query = p_query_base
    LET v_where = ""
    LET v_order = ""
    
    # Agregar filtros WHERE
    FOR i = 1 TO p_filtros.getLength()
        IF v_where != "" THEN
            LET v_where = v_where, " AND "
        END IF
        
        CASE p_filtros[i].operador
            WHEN "="
                LET v_where = v_where, p_filtros[i].columna, 
                    " = '", p_filtros[i].valor, "'"
            WHEN ">"
                LET v_where = v_where, p_filtros[i].columna, 
                    " > '", p_filtros[i].valor, "'"
            WHEN "<"
                LET v_where = v_where, p_filtros[i].columna, 
                    " < '", p_filtros[i].valor, "'"
            WHEN "LIKE"
                LET v_where = v_where, p_filtros[i].columna, 
                    " LIKE '%", p_filtros[i].valor, "%'"
            WHEN "BETWEEN"
                LET v_where = v_where, p_filtros[i].columna, 
                    " BETWEEN '", p_filtros[i].valor, "'"
        END CASE
    END FOR
    
    # Agregar WHERE a query
    IF v_where != "" THEN
        # Verificar si ya tiene WHERE
        IF LOWER(v_query) MATCHES "*where*" THEN
            LET v_query = v_query, " AND ", v_where
        ELSE
            LET v_query = v_query, " WHERE ", v_where
        END IF
    END IF
    
    # Agregar ORDER BY
    FOR i = 1 TO p_orden.getLength()
        IF v_order != "" THEN
            LET v_order = v_order, ", "
        END IF
        
        LET v_order = v_order, p_orden[i].columna, " ", 
                      p_orden[i].direccion
    END FOR
    
    IF v_order != "" THEN
        LET v_query = v_query, " ORDER BY ", v_order
    END IF
    
    RETURN v_query
    
END FUNCTION


# ============================================================
# 4. PARSEAR XML A GRID
# ============================================================
FUNCTION parsear_xml_a_grid(p_xml, p_titulo)
    DEFINE p_xml LVARCHAR(32739)
    DEFINE p_titulo VARCHAR(200)
    DEFINE r_grid ty_grid_config
    
    DEFINE v_pos INTEGER
    DEFINE v_fila INTEGER
    DEFINE v_columna INTEGER
    DEFINE v_valor VARCHAR(32000)
    DEFINE v_tag VARCHAR(100)
    
    LET r_grid.titulo = p_titulo
    LET r_grid.total_filas = 0
    LET r_grid.total_columnas = 0
    LET r_grid.color_header = g_grid_color_default
    LET r_grid.mostrar_paginacion = "S"
    LET r_grid.filas_por_pagina = g_grid_filas_pagina
    LET r_grid.pagina_actual = 1
    
    # Buscar cabeceras (primera fila con nombres de columnas)
    LET v_pos = buscar_tag(p_xml, "<row>", 1)
    
    IF v_pos > 0 THEN
        # Extraer columnas de la primera fila
        CALL extraer_columnas_fila(p_xml, v_pos)
            RETURNING r_grid.columnas
        
        LET r_grid.total_columnas = r_grid.columnas.getLength()
    END IF
    
    # Extraer datos (filas siguientes)
    LET v_fila = 1
    LET v_pos = buscar_tag(p_xml, "<row>", v_pos + 5)
    
    WHILE v_pos > 0
        # Extraer valores de la fila
        CALL extraer_valores_fila(p_xml, v_pos, 
            r_grid.total_columnas)
            RETURNING r_grid.datos[v_fila]
        
        LET v_fila = v_fila + 1
        LET v_pos = buscar_tag(p_xml, "<row>", v_pos + 5)
        
        IF v_fila > 10000 THEN
            EXIT WHILE  # Límite de seguridad
        END IF
    END WHILE
    
    LET r_grid.total_filas = v_fila - 1
    
    RETURN r_grid.*
    
END FUNCTION


# ============================================================
# 5. MOSTRAR GRID EN PANTALLA
# ============================================================
FUNCTION mostrar_grid(p_grid)
    DEFINE p_grid ty_grid_config
    DEFINE v_win WINDOW
    DEFINE i INTEGER
    DEFINE j INTEGER
    
    # Crear ventana dinámica
    OPEN WINDOW v_win WITH 24 ROWS, 80 COLUMNS
        ATTRIBUTE(STYLE="grid_dinamico")
    
    # Título
    DISPLAY "╔══════════════════════════════════════════════════════════════════════════╗" 
        AT 1,1
    DISPLAY "║ ", p_grid.titulo, 
        " ║" AT 2,1
    DISPLAY "╚══════════════════════════════════════════════════════════════════════════╝" 
        AT 3,1
    
    # Info
    DISPLAY "Filas: ", p_grid.total_filas, 
        " | Columnas: ", p_grid.total_columnas
        AT 4,1
    
    # Encabezados de columnas
    LET i = 1
    WHILE i <= p_grid.total_columnas AND i <= 10
        DISPLAY p_grid.columnas[i].titulo,
            AT 6, (i - 1) * 8 + 2
        LET i = i + 1
    END WHILE
    
    # Línea separadora
    DISPLAY "────────────────────────────────────────────────────────────────────────"
        AT 7,1
    
    # Datos (primeras 15 filas)
    FOR i = 1 TO p_grid.total_filas
        IF i > 15 THEN
            EXIT FOR
        END IF
        
        FOR j = 1 TO p_grid.total_columnas
            IF j > 10 THEN
                EXIT FOR
            END IF
            
            DISPLAY p_grid.datos[i][j],
                AT 7 + i, (j - 1) * 8 + 2
        END FOR
    END FOR
    
    # Menú de acciones
    MENU "Acciones Grid"
        ATTRIBUTE(STYLE="menu_grid")
        
        COMMAND "📄 Exportar CSV"
            CALL grid_exportar_csv(p_grid)
        
        COMMAND "📊 Exportar Excel"
            CALL grid_exportar_excel(p_grid)
        
        COMMAND "🔍 Filtrar"
            CALL grid_mostrar_filtros(p_grid)
        
        COMMAND "🔄 Refrescar"
            # Recargar datos
            CALL mostrar_grid(p_grid)
        
        COMMAND "📈 Estadísticas"
            CALL grid_mostrar_estadisticas(p_grid)
        
        COMMAND "❌ Cerrar"
            EXIT MENU
    
    END MENU
    
    CLOSE WINDOW v_win
    
END FUNCTION


# ============================================================
# 6. EXPORTAR GRID A CSV
# ============================================================
FUNCTION grid_exportar_csv(p_grid)
    DEFINE p_grid ty_grid_config
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE i INTEGER
    DEFINE j INTEGER
    
    CALL crear_directorio("export")
    
    LET v_ruta = "export/grid_",
                 TODAY USING "YYYYMMDD",
                 "_", CURRENT USING "HH24MISS", ".csv"
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")
    
    # BOM UTF-8
    CALL v_file.write(x"EF BB BF")
    
    # Info del grid
    CALL v_file.write(p_grid.titulo)
    CALL v_file.write("Total filas: ", p_grid.total_filas)
    CALL v_file.write("")
    
    # Encabezados
    LET v_linea = ""
    FOR j = 1 TO p_grid.total_columnas
        IF j > 1 THEN
            LET v_linea = v_linea, ","
        END IF
        LET v_linea = v_linea, '"', p_grid.columnas[j].titulo, '"'
    END FOR
    CALL v_file.write(v_linea)
    
    # Datos
    FOR i = 1 TO p_grid.total_filas
        LET v_linea = ""
        FOR j = 1 TO p_grid.total_columnas
            IF j > 1 THEN
                LET v_linea = v_linea, ","
            END IF
            LET v_linea = v_linea, '"', p_grid.datos[i][j], '"'
        END FOR
        CALL v_file.write(v_linea)
    END FOR
    
    CALL v_file.close()
    
    CALL log_info("grid", "Grid exportado a CSV: ", v_ruta)
    
    # Abrir archivo
    RUN "start ", v_ruta
    
    RETURN v_ruta
    
END FUNCTION


# ============================================================
# 7. EXPORTAR GRID A EXCEL
# ============================================================
FUNCTION grid_exportar_excel(p_grid)
    DEFINE p_grid ty_grid_config
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE i INTEGER
    DEFINE j INTEGER
    
    CALL crear_directorio("export")
    
    LET v_ruta = "export/grid_",
                 TODAY USING "YYYYMMDD",
                 "_", CURRENT USING "HH24MISS", ".xml"
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")
    
    # XML SpreadsheetML
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
    CALL v_file.write('   <Interior ss:Color="#003366" ss:Pattern="Solid"/>')
    CALL v_file.write('  </Style>')
    CALL v_file.write(' </Styles>')
    
    # Hoja
    CALL v_file.write(' <Worksheet ss:Name="Resultados">')
    CALL v_file.write('  <Table>')
    
    # Título
    CALL v_file.write('   <Row>')
    CALL v_file.write(
        '    <Cell ss:StyleID="titulo"><Data ss:Type="String">', 
        p_grid.titulo, '</Data></Cell>')
    CALL v_file.write('   </Row>')
    
    # Encabezados
    CALL v_file.write('   <Row>')
    FOR j = 1 TO p_grid.total_columnas
        CALL v_file.write(
            '    <Cell ss:StyleID="header"><Data ss:Type="String">', 
            p_grid.columnas[j].titulo, '</Data></Cell>')
    END FOR
    CALL v_file.write('   </Row>')
    
    # Datos
    FOR i = 1 TO p_grid.total_filas
        CALL v_file.write('   <Row>')
        FOR j = 1 TO p_grid.total_columnas
            CALL v_file.write(
                '    <Cell><Data ss:Type="String">', 
                p_grid.datos[i][j], '</Data></Cell>')
        END FOR
        CALL v_file.write('   </Row>')
    END FOR
    
    CALL v_file.write('  </Table>')
    CALL v_file.write(' </Worksheet>')
    CALL v_file.write('</Workbook>')
    
    CALL v_file.close()
    
    CALL log_info("grid", "Grid exportado a Excel: ", v_ruta)
    
    # Abrir archivo
    RUN "start ", v_ruta
    
    RETURN v_ruta
    
END FUNCTION


# ============================================================
# 8. MOSTRAR FILTROS
# ============================================================
FUNCTION grid_mostrar_filtros(p_grid)
    DEFINE p_grid ty_grid_config
    DEFINE v_win WINDOW
    DEFINE arr_filtros DYNAMIC ARRAY OF ty_filtro
    DEFINE i INTEGER
    
    OPEN WINDOW v_win WITH 15 ROWS, 60 COLUMNS
        ATTRIBUTE(STYLE="filtros")
    
    DISPLAY "╔══════════════════════════════════════════════════════════╗" AT 1,1
    DISPLAY "║              FILTRAR RESULTADOS                        ║" AT 2,1
    DISPLAY "╚══════════════════════════════════════════════════════════╝" AT 3,1
    
    # Mostrar columnas disponibles
    DISPLAY "Columnas disponibles:" AT 5,2
    FOR i = 1 TO p_grid.total_columnas
        DISPLAY i, ". ", p_grid.columnas[i].nombre
            AT 5 + i, 4
    END FOR
    
    MENU "Filtros"
        COMMAND "Agregar filtro"
            # Lógica para agregar filtro
            CALL log_info("grid", "Agregar filtro")
        
        COMMAND "Aplicar"
            # Aplicar filtros
            CALL log_info("grid", "Aplicar filtros")
        
        COMMAND "Limpiar"
            # Limpiar filtros
            CALL log_info("grid", "Limpiar filtros")
        
        COMMAND "Cancelar"
            EXIT MENU
    
    END MENU
    
    CLOSE WINDOW v_win
    
END FUNCTION


# ============================================================
# 9. ESTADÍSTICAS DEL GRID
# ============================================================
FUNCTION grid_mostrar_estadisticas(p_grid)
    DEFINE p_grid ty_grid_config
    DEFINE v_win WINDOW
    DEFINE i INTEGER
    DEFINE j INTEGER
    DEFINE v_numerico DECIMAL(20,2)
    DEFINE v_suma DECIMAL(20,2)
    DEFINE v_promedio DECIMAL(20,2)
    DEFINE v_min DECIMAL(20,2)
    DEFINE v_max DECIMAL(20,2)
    DEFINE v_conteo INTEGER
    
    OPEN WINDOW v_win WITH 20 ROWS, 60 COLUMNS
        ATTRIBUTE(STYLE="estadisticas")
    
    DISPLAY "╔══════════════════════════════════════════════════════════╗" AT 1,1
    DISPLAY "║           ESTADÍSTICAS DEL GRID                        ║" AT 2,1
    DISPLAY "╚══════════════════════════════════════════════════════════╝" AT 3,1
    
    DISPLAY "Total filas: ", p_grid.total_filas AT 5,2
    DISPLAY "Total columnas: ", p_grid.total_columnas AT 6,2
    
    # Calcular estadísticas por columna numérica
    DISPLAY "" AT 8,2
    DISPLAY "Columnas numéricas:" AT 9,2
    
    FOR j = 1 TO p_grid.total_columnas
        # Intentar detectar si es numérica
        LET v_suma = 0
        LET v_conteo = 0
        LET v_min = NULL
        LET v_max = NULL
        
        FOR i = 1 TO p_grid.total_filas
            LET v_numerico = p_grid.datos[i][j]
            IF v_numerico IS NOT NULL THEN
                LET v_suma = v_suma + v_numerico
                LET v_conteo = v_conteo + 1
                
                IF v_min IS NULL OR v_numerico < v_min THEN
                    LET v_min = v_numerico
                END IF
                
                IF v_max IS NULL OR v_numerico > v_max THEN
                    LET v_max = v_numerico
                END IF
            END IF
        END FOR
        
        IF v_conteo > 0 THEN
            LET v_promedio = v_suma / v_conteo
            DISPLAY j, ". ", p_grid.columnas[j].nombre,
                " | Suma: ", v_suma,
                " | Prom: ", v_promedio,
                " | Min: ", v_min,
                " | Max: ", v_max
                AT 10 + j, 2
        END IF
    END FOR
    
    MENU "Estadísticas"
        COMMAND "Cerrar"
            EXIT MENU
    END MENU
    
    CLOSE WINDOW v_win
    
END FUNCTION


# ============================================================
# 10. HELPERS
# ============================================================
FUNCTION buscar_tag(p_texto, p_tag, p_desde)
    DEFINE p_texto LVARCHAR(32739)
    DEFINE p_tag VARCHAR(50)
    DEFINE p_desde INTEGER
    DEFINE i INTEGER
    
    FOR i = p_desde TO LENGTH(p_texto) - LENGTH(p_tag)
        IF p_texto[i, i + LENGTH(p_tag) - 1] = p_tag THEN
            RETURN i
        END IF
    END FOR
    
    RETURN 0
    
END FUNCTION


FUNCTION extraer_columnas_fila(p_xml, p_pos)
    DEFINE p_xml LVARCHAR(32739)
    DEFINE p_pos INTEGER
    DEFINE arr_columnas DYNAMIC ARRAY OF ty_columna_grid
    DEFINE v_pos INTEGER
    DEFINE v_fin INTEGER
    DEFINE v_contenido VARCHAR(32000)
    DEFINE i INTEGER
    
    # Buscar fin de la fila
    LET v_fin = buscar_tag(p_xml, "</row>", p_pos)
    
    IF v_fin = 0 THEN
        RETURN arr_columnas
    END IF
    
    # Extraer contenido de la fila
    LET v_contenido = p_xml[p_pos + 5, v_fin - 1]
    
    # Extraer valores
    LET v_pos = 1
    LET i = 1
    
    WHILE v_pos < LENGTH(v_contenido)
        # Buscar <Data>
        IF v_contenido[v_pos, v_pos + 5] = "<Data>" THEN
            LET arr_columnas[i].nombre = extraer_hasta_tag(
                v_contenido, v_pos + 6, "</Data>")
            LET arr_columnas[i].titulo = arr_columnas[i].nombre
            LET arr_columnas[i].ancho = 15
            LET i = i + 1
            LET v_pos = v_pos + 6
        ELSE
            LET v_pos = v_pos + 1
        END IF
    END WHILE
    
    RETURN arr_columnas
    
END FUNCTION


FUNCTION extraer_valores_fila(p_xml, p_pos, p_total_columnas)
    DEFINE p_xml LVARCHAR(32739)
    DEFINE p_pos INTEGER
    DEFINE p_total_columnas INTEGER
    DEFINE arr_valores DYNAMIC ARRAY OF VARCHAR(32000)
    DEFINE v_pos INTEGER
    DEFINE v_fin INTEGER
    DEFINE v_contenido VARCHAR(32000)
    DEFINE i INTEGER
    
    # Buscar fin de la fila
    LET v_fin = buscar_tag(p_xml, "</row>", p_pos)
    
    IF v_fin = 0 THEN
        RETURN arr_valores
    END IF
    
    # Extraer contenido
    LET v_contenido = p_xml[p_pos + 5, v_fin - 1]
    
    # Extraer valores
    LET v_pos = 1
    LET i = 1
    
    WHILE v_pos < LENGTH(v_contenido) AND i <= p_total_columnas
        IF v_contenido[v_pos, v_pos + 5] = "<Data>" THEN
            LET arr_valores[i] = extraer_hasta_tag(
                v_contenido, v_pos + 6, "</Data>")
            LET i = i + 1
            LET v_pos = v_pos + 6
        ELSE
            LET v_pos = v_pos + 1
        END IF
    END WHILE
    
    RETURN arr_valores
    
END FUNCTION


FUNCTION extraer_hasta_tag(p_texto, p_pos, p_tag_fin)
    DEFINE p_texto VARCHAR(32000)
    DEFINE p_pos INTEGER
    DEFINE p_tag_fin VARCHAR(50)
    DEFINE v_result VARCHAR(32000)
    DEFINE i INTEGER
    
    LET v_result = ""
    
    FOR i = p_pos TO LENGTH(p_texto) - LENGTH(p_tag_fin)
        IF p_texto[i, i + LENGTH(p_tag_fin) - 1] = p_tag_fin THEN
            EXIT FOR
        END IF
        LET v_result = v_result, p_texto[i]
    END FOR
    
    RETURN v_result
    
END FUNCTION


FUNCTION crear_directorio(p_dir)
    DEFINE p_dir VARCHAR(200)
    
    RUN "if not exist ", p_dir, " mkdir ", p_dir
    
END FUNCTION


FUNCTION mostrar_error_grid(p_mensaje)
    DEFINE p_mensaje VARCHAR(500)
    
    CALL log_error("grid", p_mensaje)
    
    OPEN WINDOW v_error WITH 5 ROWS, 40 COLUMNS
    DISPLAY "╔══════════════════════════════════════╗" AT 1,1
    DISPLAY "║           ERROR                     ║" AT 2,1
    DISPLAY "╚══════════════════════════════════════╝" AT 3,1
    DISPLAY p_mensaje AT 4,2
    
    MENU "Error"
        COMMAND "Aceptar"
            EXIT MENU
    END MENU
    
    CLOSE WINDOW v_error
    
END FUNCTION
