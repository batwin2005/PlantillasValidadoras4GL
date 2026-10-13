# ============================================================
# MODULO: metadatos.4gl
# Motor de Metadatos - Analiza queries automáticamente
# Detecta tablas, campos, tipos y relaciones
# ============================================================

DATABASE banco

# ============================================================
# TIPOS DE DATOS
# ============================================================
TYPE ty_campo RECORD
    nombre VARCHAR(64),
    tabla VARCHAR(64),
    tipo VARCHAR(20),
    tamano INTEGER,
    obligatorio CHAR(1),
    es_primary_key CHAR(1),
    es_foreign_key CHAR(1),
    tabla_ref VARCHAR(64),
    campo_ref VARCHAR(64)
END RECORD

TYPE ty_tabla RECORD
    nombre VARCHAR(64),
    descripcion VARCHAR(200),
    total_registros INTEGER
END RECORD

TYPE ty_relacion RECORD
    tabla_origen VARCHAR(64),
    campo_origen VARCHAR(64),
    tabla_destino VARCHAR(64),
    campo_destino VARCHAR(64),
    tipo_relacion VARCHAR(20)
END RECORD

TYPE ty_metadatos RECORD
    tablas DYNAMIC ARRAY OF ty_tabla,
    campos DYNAMIC ARRAY OF ty_campo,
    relaciones DYNAMIC ARRAY OF ty_relacion,
    total_campos INTEGER,
    total_tablas INTEGER,
    total_relaciones INTEGER
END RECORD

TYPE ty_analisis_query RECORD
    query_original LVARCHAR(32000),
    tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
    campos_detectados DYNAMIC ARRAY OF VARCHAR(100),
    joins_detectados DYNAMIC ARRAY OF VARCHAR(200),
    where_detectado LVARCHAR(32000),
    order_by_detectado VARCHAR(500),
    group_by_detectado VARCHAR(500),
    es_valida CHAR(1),
    error_mensaje VARCHAR(500)
END RECORD


# ============================================================
# 1. ANALIZAR QUERY - Detectar tablas y campos
# ============================================================
FUNCTION analizar_query(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE r_analisis ty_analisis_query
    DEFINE v_query_lower LVARCHAR(32000)
    DEFINE v_pos INTEGER
    DEFINE v_temp VARCHAR(500)
    DEFINE i INTEGER
    
    LET r_analisis.query_original = p_query
    LET v_query_lower = LOWER(p_query)
    
    # ========================================
    # 1.1 DETECTAR TABLAS (FROM y JOIN)
    # ========================================
    LET i = 1
    
    # Buscar después de FROM
    LET v_pos = buscar_patron(v_query_lower, " from ")
    IF v_pos > 0 THEN
        LET v_temp = extraer_nombre_tabla(v_query_lower, v_pos + 6)
        IF v_temp IS NOT NULL AND v_temp != "" THEN
            LET r_analisis.tablas_detectadas[i] = v_temp
            LET i = i + 1
        END IF
    END IF
    
    # Buscar JOINs
    LET v_pos = 1
    WHILE v_pos < LENGTH(v_query_lower)
        LET v_temp = buscar_patron_desde(v_query_lower, v_pos, " join ")
        IF v_temp IS NULL THEN
            EXIT WHILE
        END IF
        
        LET r_analisis.tablas_detectadas[i] = v_temp
        LET i = i + 1
        LET v_pos = v_pos + LENGTH(v_temp) + 6
    END WHILE
    
    # ========================================
    # 1.2 DETECTAR CAMPOS (SELECT)
    # ========================================
    LET i = 1
    LET v_pos = buscar_patron(v_query_lower, " select ")
    
    IF v_pos > 0 THEN
        # Extraer campos entre SELECT y FROM
        LET v_temp = extraer_campos_select(p_query, v_pos + 8)
        CALL parsear_lista_campos(v_temp)
            RETURNING r_analisis.campos_detectados
    END IF
    
    # ========================================
    # 1.3 DETECTAR JOINS (ON)
    # ========================================
    LET v_pos = 1
    LET i = 1
    WHILE v_pos < LENGTH(v_query_lower)
        LET v_temp = buscar_patron_desde(v_query_lower, v_pos, " on ")
        IF v_temp IS NULL THEN
            EXIT WHILE
        END IF
        
        LET r_analisis.joins_detectados[i] = v_temp
        LET i = i + 1
        LET v_pos = v_pos + LENGTH(v_temp) + 4
    END WHILE
    
    # ========================================
    # 1.4 DETECTAR WHERE
    # ========================================
    LET v_pos = buscar_patron(v_query_lower, " where ")
    IF v_pos > 0 THEN
        LET r_analisis.where_detectado = 
            extraer_hasta(p_query, v_pos + 7, 
                " order ", " group ", " having ")
    END IF
    
    # ========================================
    # 1.5 DETECTAR ORDER BY
    # ========================================
    LET v_pos = buscar_patron(v_query_lower, " order by ")
    IF v_pos > 0 THEN
        LET r_analisis.order_by_detectado = 
            extraer_hasta(p_query, v_pos + 10, 
                " limit ", " offset ")
    END IF
    
    # ========================================
    # 1.6 DETECTAR GROUP BY
    # ========================================
    LET v_pos = buscar_patron(v_query_lower, " group by ")
    IF v_pos > 0 THEN
        LET r_analisis.group_by_detectado = 
            extraer_hasta(p_query, v_pos + 10, 
                " having ", " order ")
    END IF
    
    # ========================================
    # 1.7 VALIDAR QUERY
    # ========================================
    IF r_analisis.tablas_detectadas.getLength() = 0 THEN
        LET r_analisis.es_valida = "N"
        LET r_analisis.error_mensaje = "No se detectaron tablas (FROM)"
    ELSE
        LET r_analisis.es_valida = "S"
    END IF
    
    RETURN r_analisis.*
    
END FUNCTION


# ============================================================
# 2. OBTENER METADATOS DE TABLA
# ============================================================
FUNCTION obtener_metadatos_tabla(p_tabla)
    DEFINE p_tabla VARCHAR(64)
    DEFINE r_meta ty_metadatos
    DEFINE v_count INTEGER
    
    LET r_meta.total_campos = 0
    LET r_meta.total_tablas = 0
    LET r_meta.total_relaciones = 0
    
    # ========================================
    # 2.1 OBTENER CAMPOS DESDE systables
    # ========================================
    DECLARE cur_campos CURSOR FOR
        SELECT 
            c.colname,
            c.tabname,
            CASE c.coltype
                WHEN 0 THEN 'CHAR'
                WHEN 1 THEN 'SMALLINT'
                WHEN 2 THEN 'INTEGER'
                WHEN 3 THEN 'FLOAT'
                WHEN 4 THEN 'SMALLFLOAT'
                WHEN 5 THEN 'DECIMAL'
                WHEN 6 THEN 'SERIAL'
                WHEN 7 THEN 'DATE'
                WHEN 8 THEN 'MONEY'
                WHEN 10 THEN 'NULL'
                WHEN 11 THEN 'DTIME'
                WHEN 12 THEN 'BYTE'
                WHEN 13 THEN 'TEXT'
                WHEN 14 THEN 'VARCHAR'
                WHEN 15 THEN 'NVARCHAR'
                WHEN 16 THEN 'INT8'
                WHEN 17 THEN 'SERIAL8'
                WHEN 43 THEN 'LVARCHAR'
                ELSE 'UNKNOWN'
            END,
            c.collength,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM systables t, syscolumns c2
                    WHERE t.tabname = c.tabname
                      AND c2.colno = c.colno
                      AND t.tabid IN (
                        SELECT tabid FROM systables 
                        WHERE tabname = 'sysconstraints'
                      )
                ) THEN 'S'
                ELSE 'N'
            END
        INTO 
            r_meta.campos[r_meta.total_campos + 1].nombre,
            r_meta.campos[r_meta.total_campos + 1].tabla,
            r_meta.campos[r_meta.total_campos + 1].tipo,
            r_meta.campos[r_meta.total_campos + 1].tamano,
            r_meta.campos[r_meta.total_campos + 1].es_primary_key
        FROM systables t
        JOIN syscolumns c ON t.tabid = c.tabid
        WHERE t.tabname = p_tabla
        ORDER BY c.colno
    
    FOREACH cur_campos
        LET r_meta.total_campos = r_meta.total_campos + 1
    END FOREACH
    
    # ========================================
    # 2.2 CONTAR REGISTROS
    # ========================================
    LET v_count = 0
    EXECUTE IMMEDIATE 
        'SELECT COUNT(*) FROM ' || p_tabla INTO v_count
    
    LET r_meta.tablas[1].nombre = p_tabla
    LET r_meta.tablas[1].total_registros = v_count
    LET r_meta.total_tablas = 1
    
    RETURN r_meta.*
    
END FUNCTION


# ============================================================
# 3. OBTENER METADATOS COMPLETO (múltiples tablas)
# ============================================================
FUNCTION obtener_metadatos_completo(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE r_analisis ty_analisis_query
    DEFINE r_meta ty_metadatos
    DEFINE i INTEGER
    
    # Analizar query
    LET r_analisis = analizar_query(p_query)
    
    # Obtener metadatos de cada tabla detectada
    FOR i = 1 TO r_analisis.tablas_detectadas.getLength()
        CALL obtener_metadatos_tabla(r_analisis.tablas_detectadas[i])
            RETURNING r_meta
        
        # Acumular campos
        CALL combinar_metadatos(r_meta)
    END FOR
    
    # Detectar relaciones
    CALL detectar_relaciones(r_analisis)
        RETURNING r_meta.relaciones
    
    LET r_meta.total_relaciones = r_meta.relaciones.getLength()
    
    RETURN r_meta.*
    
END FUNCTION


# ============================================================
# 4. DETECTAR RELACIONES (Foreign Keys)
# ============================================================
FUNCTION detectar_relaciones(p_analisis)
    DEFINE p_analisis ty_analisis_query
    DEFINE arr_relaciones DYNAMIC ARRAY OF ty_relacion
    DEFINE i INTEGER
    DEFINE v_query LVARCHAR(32000)
    
    # Buscar relaciones en sysreferences
    DECLARE cur_rel CURSOR FOR
        SELECT 
            t1.tabname,
            c1.colname,
            t2.tabname,
            c2.colname,
            'FK'
        FROM sysreferences r
        JOIN systables t1 ON r.tabid = t1.tabid
        JOIN syscolumns c1 ON r.tabid = c1.tabid 
                            AND r.constrlevel = c1.colno
        JOIN systables t2 ON r.ptabid = t2.tabid
        JOIN syscolumns c2 ON r.ptabid = c2.colid
        WHERE t1.tabname IN (
            SELECT VALUE FROM TABLE(
                MULTISET(SELECT VALUE 
                FROM UNNEST(?)) 
            )
        )
    
    LET i = 1
    FOREACH cur_rel INTO arr_relaciones[i].*
        LET i = i + 1
    END FOREACH
    
    RETURN arr_relaciones
    
END FUNCTION


# ============================================================
# 5. GENERAR PLANTILLA AUTOMÁTICA
# ============================================================
FUNCTION generar_plantilla_automatica(p_query, p_banco)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_banco VARCHAR(20)
    DEFINE r_meta ty_metadatos
    DEFINE v_html LVARCHAR(32000)
    DEFINE v_color VARCHAR(7)
    DEFINE v_nombre_banco VARCHAR(100)
    DEFINE i INTEGER
    
    # Obtener metadatos
    LET r_meta = obtener_metadatos_completo(p_query)
    
    # Obtener info del banco
    SELECT nombre, color_hex 
    INTO v_nombre_banco, v_color
    FROM banco WHERE codigo = p_banco
    
    IF v_color IS NULL THEN
        LET v_color = '#003366'
    END IF
    
    # Generar HTML
    LET v_html = '<!DOCTYPE html><html><head>'
    LET v_html = v_html, '<meta charset="UTF-8">'
    LET v_html = v_html, '<title>Consulta Automática</title>'
    LET v_html = v_html, '<style>'
    LET v_html = v_html, 'body{font-family:Arial}'
    LET v_html = v_html, '.header{background:', v_color, ';color:white;padding:15px}'
    LET v_html = v_html, 'table{border-collapse:collapse;width:100%}'
    LET v_html = v_html, 'th{background:', v_color, ';color:white;padding:8px}'
    LET v_html = v_html, 'td{border:1px solid #ddd;padding:6px}'
    LET v_html = v_html, '</style></head><body>'
    
    # Header
    LET v_html = v_html, '<div class="header">'
    LET v_html = v_html, '<h1>', v_nombre_banco, '</h1>'
    LET v_html = v_html, '<p>Reporte Automático</p>'
    LET v_html = v_html, '</div>'
    
    # Tabla con campos detectados
    LET v_html = v_html, '<table><tr>'
    FOR i = 1 TO r_meta.total_campos
        LET v_html = v_html, '<th>', r_meta.campos[i].nombre, '</th>'
    END FOR
    LET v_html = v_html, '</tr>'
    
    LET v_html = v_html, '</table>'
    LET v_html = v_html, '<p>Campos detectados: ', 
                  r_meta.total_campos, '</p>'
    LET v_html = v_html, '</body></html>'
    
    RETURN v_html
    
END FUNCTION


# ============================================================
# 6. HELPERS - Análisis de strings
# ============================================================
FUNCTION buscar_patron(p_texto, p_patron)
    DEFINE p_texto LVARCHAR(32000)
    DEFINE p_patron VARCHAR(100)
    DEFINE i INTEGER
    DEFINE v_len_patron INTEGER
    
    LET v_len_patron = LENGTH(p_patron)
    
    FOR i = 1 TO LENGTH(p_texto) - v_len_patron + 1
        IF p_texto[i, i + v_len_patron - 1] = p_patron THEN
            RETURN i
        END IF
    END FOR
    
    RETURN 0
    
END FUNCTION


FUNCTION buscar_patron_desde(p_texto, p_desde, p_patron)
    DEFINE p_texto LVARCHAR(32000)
    DEFINE p_desde INTEGER
    DEFINE p_patron VARCHAR(100)
    DEFINE i INTEGER
    DEFINE v_len_patron INTEGER
    DEFINE v_pos INTEGER
    
    LET v_len_patron = LENGTH(p_patron)
    
    FOR i = p_desde TO LENGTH(p_texto) - v_len_patron + 1
        IF p_texto[i, i + v_len_patron - 1] = p_patron THEN
            # Extraer nombre después del patrón
            RETURN extraer_nombre_tabla(p_texto, i + v_len_patron)
        END IF
    END FOR
    
    RETURN NULL
    
END FUNCTION


FUNCTION extraer_nombre_tabla(p_texto, p_pos)
    DEFINE p_texto LVARCHAR(32000)
    DEFINE p_pos INTEGER
    DEFINE v_result VARCHAR(64)
    DEFINE i INTEGER
    
    LET v_result = ""
    
    FOR i = p_pos TO LENGTH(p_texto)
        IF p_texto[i] MATCHES "[a-zA-Z0-9_]" THEN
            LET v_result = v_result, p_texto[i]
        ELSE
            EXIT WHILE
        END IF
    END FOR
    
    RETURN v_result
    
END FUNCTION


FUNCTION extraer_campos_select(p_query, p_pos)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_pos INTEGER
    DEFINE v_result VARCHAR(32000)
    DEFINE v_depth INTEGER
    DEFINE i INTEGER
    
    LET v_result = ""
    LET v_depth = 0
    
    FOR i = p_pos TO LENGTH(p_query)
        IF p_query[i] = "(" THEN
            LET v_depth = v_depth + 1
        ELSIF p_query[i] = ")" THEN
            LET v_depth = v_depth - 1
        END IF
        
        # Buscar FROM al nivel 0
        IF v_depth = 0 AND 
           LOWER(p_query[i, i+4]) = " from" THEN
            EXIT FOR
        END IF
        
        LET v_result = v_result, p_query[i]
    END FOR
    
    RETURN v_result
    
END FUNCTION


FUNCTION parsear_lista_campos(p_lista)
    DEFINE p_lista VARCHAR(32000)
    DEFINE arr_campos DYNAMIC ARRAY OF VARCHAR(100)
    DEFINE v_campo_actual VARCHAR(100)
    DEFINE v_pos INTEGER
    DEFINE v_depth INTEGER
    DEFINE i INTEGER
    
    LET v_pos = 1
    LET v_depth = 0
    LET v_campo_actual = ""
    
    FOR i = 1 TO LENGTH(p_lista)
        IF p_lista[i] = "(" THEN
            LET v_depth = v_depth + 1
        ELSIF p_lista[i] = ")" THEN
            LET v_depth = v_depth - 1
        ELSIF p_lista[i] = "," AND v_depth = 0 THEN
            # Campo completo
            LET arr_campos[arr_campos.getLength() + 1] = 
                TRIM(v_campo_actual)
            LET v_campo_actual = ""
        ELSE
            LET v_campo_actual = v_campo_actual, p_lista[i]
        END IF
    END FOR
    
    # Último campo
    IF LENGTH(TRIM(v_campo_actual)) > 0 THEN
        LET arr_campos[arr_campos.getLength() + 1] = 
            TRIM(v_campo_actual)
    END IF
    
    RETURN arr_campos
    
END FUNCTION


FUNCTION extraer_hasta(p_texto, p_pos, p_stop1, p_stop2, p_stop3)
    DEFINE p_texto LVARCHAR(32000)
    DEFINE p_pos INTEGER
    DEFINE p_stop1 VARCHAR(50)
    DEFINE p_stop2 VARCHAR(50)
    DEFINE p_stop3 VARCHAR(50)
    DEFINE v_result LVARCHAR(32000)
    DEFINE i INTEGER
    DEFINE v_stop BOOLEAN
    
    LET v_result = ""
    
    FOR i = p_pos TO LENGTH(p_texto)
        LET v_stop = FALSE
        
        IF p_stop1 IS NOT NULL AND LENGTH(p_stop1) > 0 THEN
            IF LOWER(p_texto[i, i + LENGTH(p_stop1) - 1]) = p_stop1 THEN
                LET v_stop = TRUE
            END IF
        END IF
        
        IF NOT v_stop AND p_stop2 IS NOT NULL AND LENGTH(p_stop2) > 0 THEN
            IF LOWER(p_texto[i, i + LENGTH(p_stop2) - 1]) = p_stop2 THEN
                LET v_stop = TRUE
            END IF
        END IF
        
        IF NOT v_stop AND p_stop3 IS NOT NULL AND LENGTH(p_stop3) > 0 THEN
            IF LOWER(p_texto[i, i + LENGTH(p_stop3) - 1]) = p_stop3 THEN
                LET v_stop = TRUE
            END IF
        END IF
        
        IF v_stop THEN
            EXIT FOR
        END IF
        
        LET v_result = v_result, p_texto[i]
    END FOR
    
    RETURN TRIM(v_result)
    
END FUNCTION


FUNCTION combinar_metadatos(p_meta_nuevo)
    DEFINE p_meta_nuevo ty_metadatos
    DEFINE i INTEGER
    
    # En una implementación real, aquí combinarías
    # los metadatos con los existentes
    # Por ahora solo retornamos el nuevo
    
    RETURN p_meta_nuevo.*
    
END FUNCTION
