# ============================================================
# MODULO: validacion_dinamica.4gl
# Motor de Validación Dinámica por Query
# Detecta tablas/campos y aplica reglas automáticamente
# ============================================================

DATABASE banco

# ============================================================
# TIPOS DE DATOS
# ============================================================
TYPE ty_regla_validacion RECORD
    tabla VARCHAR(64),
    campo VARCHAR(64),
    tipo_validacion VARCHAR(50),
    parametro VARCHAR(200),
    mensaje_error VARCHAR(200),
    es_obligatorio CHAR(1)
END RECORD

TYPE ty_campo_metadato RECORD
    nombre VARCHAR(64),
    tipo_columna VARCHAR(50),
    longitud INTEGER,
    es_obligatorio CHAR(1),
    es_primary_key CHAR(1),
    es_unique CHAR(1),
    tabla_referencia VARCHAR(64),
    campo_referencia VARCHAR(64)
END RECORD

TYPE ty_validacion_resultado RECORD
    num_fila INTEGER,
    campo VARCHAR(64),
    valor_original VARCHAR(200),
    estado VARCHAR(20),      -- OK, ERROR, WARNING
    mensaje VARCHAR(500),
    accion_sugerida VARCHAR(50)  -- INSERTAR, ACTUALIZAR, OMITIR
END RECORD

TYPE ty_validacion_archivo RECORD
    archivo_nombre VARCHAR(200),
    query_original LVARCHAR(32000),
    tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
    campos_detectados DYNAMIC ARRAY OF VARCHAR(64),
    total_registros INTEGER,
    total_validos INTEGER,
    total_errores INTEGER,
    total_duplicados INTEGER,
    resultados DYNAMIC ARRAY OF ty_validacion_resultado,
    metadatos_tablas DYNAMIC ARRAY OF ty_campo_metadato
END RECORD


# ============================================================
# 1. VALIDAR QUERY DINÁMICO COMPLETO
# ============================================================
FUNCTION validar_query_dinamico(p_query, p_datos)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    
    DEFINE r_resultado ty_validacion_archivo
    DEFINE r_analisis RECORD
        tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        campos_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        aliases DYNAMIC ARRAY OF VARCHAR(64)
    END RECORD
    
    DEFINE i INTEGER
    DEFINE j INTEGER
    DEFINE k INTEGER
    
    -- Inicializar resultado
    LET r_resultado.query_original = p_query
    LET r_resultado.total_registros = p_datos.getLength()
    LET r_resultado.total_validos = 0
    LET r_resultado.total_errores = 0
    LET r_resultado.total_duplicados = 0
    
    -- 1. Analizar query para detectar tablas y campos
    LET r_analisis = analizar_query_simple(p_query)
    
    LET r_resultado.tablas_detectadas = r_analisis.tablas_detectadas
    LET r_resultado.campos_detectados = r_analisis.campos_detectadas
    
    -- 2. Obtener metadatos de cada tabla detectada
    FOR i = 1 TO r_resultado.tablas_detectadas.getLength()
        CALL obtener_metadatos_tabla(
            r_resultado.tablas_detectadas[i])
            RETURNING r_resultado.metadatos_tablas[i]
    END FOR
    
    -- 3. Validar cada registro
    FOR i = 1 TO p_datos.getLength()
        
        -- Validar campos individuales
        CALL validar_registro(i, p_datos[i], 
            r_resultado.tablas_detectadas, 
            r_resultado.campos_detectados,
            r_resultado.metadatos_tablas)
            RETURNING r_resultado.resultados
        
        -- Validar duplicados en archivo
        CALL validar_duplicados_archivo(i, p_datos, 
            r_resultado.resultados)
        
        -- Validar contra BD
        CALL validar_contra_bd(i, p_datos[i],
            r_resultado.tablas_detectadas,
            r_resultado.campos_detectados)
            RETURNING r_resultado.resultados
        
    END FOR
    
    -- 4. Calcular estadísticas
    CALL calcular_estadisticas(r_resultado)
    
    RETURN r_resultado
    
END FUNCTION


# ============================================================
# 1B. VALIDAR SOLO FORMATO (paramétrico, SIN consultar BD)
# ============================================================
FUNCTION validar_solo_formato(p_query, p_datos)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    
    DEFINE r_resultado ty_validacion_archivo
    DEFINE r_analisis RECORD
        tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        campos_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        aliases DYNAMIC ARRAY OF VARCHAR(64)
    END RECORD
    
    DEFINE i INTEGER
    DEFINE j INTEGER
    DEFINE k INTEGER
    
    -- Inicializar resultado
    LET r_resultado.query_original = p_query
    LET r_resultado.total_registros = p_datos.getLength()
    LET r_resultado.total_validos = 0
    LET r_resultado.total_errores = 0
    LET r_resultado.total_duplicados = 0
    
    -- 1. Analizar query para detectar tablas y campos
    LET r_analisis = analizar_query_simple(p_query)
    
    LET r_resultado.tablas_detectadas = r_analisis.tablas_detectadas
    LET r_resultado.campos_detectados = r_analisis.campos_detectadas
    
    -- 2. Obtener metadatos de cada tabla detectada (tipos, longitud, PK, FK)
    FOR i = 1 TO r_resultado.tablas_detectadas.getLength()
        CALL obtener_metadatos_tabla(
            r_resultado.tablas_detectadas[i])
            RETURNING r_resultado.metadatos_tablas[i]
    END FOR
    
    -- 3. Validar cada registro (solo formato + duplicados en archivo)
    FOR i = 1 TO p_datos.getLength()
        
        -- Validar campos individuales (reglas: EMAIL, SOLO_LETRAS, FORMATO_DOCUMENTO, etc.)
        CALL validar_registro(i, p_datos[i], 
            r_resultado.tablas_detectadas, 
            r_resultado.campos_detectados,
            r_resultado.metadatos_tablas)
            RETURNING r_resultado.resultados
        
        -- Validar duplicados en archivo
        CALL validar_duplicados_archivo(i, p_datos, 
            r_resultado.resultados)
        
        -- NOTA: NO se llama validar_contra_bd() -- nada de UNIQUE ni EXISTE_BD
        
    END FOR
    
    -- 4. Calcular estadísticas
    CALL calcular_estadisticas(r_resultado)
    
    RETURN r_resultado
    
END FUNCTION


# ============================================================
# 2. ANALIZAR QUERY SIMPLE
# ============================================================
FUNCTION analizar_query_simple(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE r_result RECORD
        tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        campos_detectados DYNAMIC ARRAY OF VARCHAR(64),
        aliases DYNAMIC ARRAY OF VARCHAR(64)
    END RECORD
    
    DEFINE v_query_lower VARCHAR(32000)
    DEFINE v_pos INTEGER
    DEFINE i INTEGER
    DEFINE v_campo VARCHAR(100)
    DEFINE v_tabla VARCHAR(100)
    
    LET v_query_lower = LOWER(TRIM(p_query))
    
    -- Extraer tablas (FROM y JOIN)
    LET v_pos = 1
    WHILE v_pos <= LENGTH(v_query_lower)
        -- Buscar FROM
        IF v_query_lower[v_pos, v_pos + 4] = "from " THEN
            LET v_tabla = extraer_siguiente_token(
                v_query_lower, v_pos + 5)
            LET r_result.tablas_detectadas[
                r_result.tablas_detectadas.getLength() + 1] = 
                limpiar_token(v_tabla)
            LET v_pos = v_pos + 5 + LENGTH(v_tabla)
        -- Buscar JOIN
        ELSEIF v_query_lower[v_pos, v_pos + 4] = "join " THEN
            LET v_tabla = extraer_siguiente_token(
                v_query_lower, v_pos + 5)
            LET r_result.tablas_detectadas[
                r_result.tablas_detectadas.getLength() + 1] = 
                limpiar_token(v_tabla)
            LET v_pos = v_pos + 5 + LENGTH(v_tabla)
        ELSE
            LET v_pos = v_pos + 1
        END IF
    END WHILE
    
    -- Extraer campos (después de SELECT hasta FROM)
    LET v_pos = 6  -- Después de "select"
    WHILE v_pos < LENGTH(v_query_lower)
        IF v_query_lower[v_pos, v_pos + 3] = "from" THEN
            EXIT WHILE
        END IF
        
        LET v_campo = extraer_siguiente_token(v_query_lower, v_pos)
        LET v_campo = limpiar_token(v_campo)
        
        IF LENGTH(v_campo) > 0 AND v_campo != "," AND 
           v_campo != "*" THEN
            -- Quitar alias si existe
            IF v_campo MATCHES "*.*" THEN
                LET r_result.campos_detectados[
                    r_result.campos_detectados.getLength() + 1] = 
                    v_campo
            ELSE
                LET r_result.campos_detectados[
                    r_result.campos_detectados.getLength() + 1] = 
                    v_campo
            END IF
        END IF
        
        LET v_pos = v_pos + LENGTH(v_campo) + 1
    END WHILE
    
    RETURN r_result.*
    
END FUNCTION


# ============================================================
# 3. OBTENER METADATOS DE TABLA
# ============================================================
FUNCTION obtener_metadatos_tabla(p_tabla)
    DEFINE p_tabla VARCHAR(64)
    DEFINE arr_metadatos DYNAMIC ARRAY OF ty_campo_metadato
    
    DEFINE i INTEGER
    
    -- Obtener columnas de la tabla
    SELECT 
        c.colname,
        CASE 
            WHEN c.coltype = 0 THEN 'CHAR'
            WHEN c.coltype = 1 THEN 'SMALLINT'
            WHEN c.coltype = 2 THEN 'INTEGER'
            WHEN c.coltype = 3 THEN 'FLOAT'
            WHEN c.coltype = 4 THEN 'SMALLFLOAT'
            WHEN c.coltype = 5 THEN 'DECIMAL'
            WHEN c.coltype = 11 THEN 'DATE'
            WHEN c.coltype = 12 THEN 'MONEY'
            WHEN c.coltype = 13 THEN 'NULL'
            WHEN c.coltype = 14 THEN 'DTIME'
            WHEN c.coltype = 15 THEN 'BYTES'
            WHEN c.coltype = 16 THEN 'TEXT'
            WHEN c.coltype = 17 THEN 'VARCHAR'
            ELSE 'OTHER'
        END,
        c.collength,
        CASE WHEN c.coltype > 255 THEN 'S' ELSE 'N' END,
        CASE 
            WHEN i.indexname IS NOT NULL THEN 'S' 
            ELSE 'N' 
        END,
        CASE 
            WHEN i.indexname IS NOT NULL AND 
                 i.indexkeys[1] = c.colno THEN 'S'
            ELSE 'N'
        END,
        '',
        ''
    INTO arr_metadatos[1].*
    FROM systables t
    JOIN syscolumns c ON t.tabid = c.tabid
    LEFT JOIN sysindexes i ON t.tabid = i.tabid
        AND i.indexkeys[1] = c.colno
    WHERE t.tabname = p_tabla
    ORDER BY c.colno
    
    LET i = 1
    WHILE STATUS = 0 AND arr_metadatos[i].nombre IS NOT NULL
        LET i = i + 1
        SELECT 
            c.colname,
            CASE 
                WHEN c.coltype = 0 THEN 'CHAR'
                WHEN c.coltype = 17 THEN 'VARCHAR'
                WHEN c.coltype = 2 THEN 'INTEGER'
                WHEN c.coltype = 5 THEN 'DECIMAL'
                WHEN c.coltype = 11 THEN 'DATE'
                ELSE 'OTHER'
            END,
            c.collength,
            CASE WHEN c.coltype > 255 THEN 'S' ELSE 'N' END,
            'N', 'N', '', ''
        INTO arr_metadatos[i].*
        FROM systables t
        JOIN syscolumns c ON t.tabid = c.tabid
        WHERE t.tabname = p_tabla
          AND c.colno = i
    END WHILE
    
    RETURN arr_metadatos
    
END FUNCTION


# ============================================================
# 4. OBTENER REGLAS DE VALIDACIÓN
# ============================================================
FUNCTION obtener_reglas_validacion(p_tabla)
    DEFINE p_tabla VARCHAR(64)
    DEFINE arr_reglas DYNAMIC ARRAY OF ty_regla_validacion
    
    SELECT 
        tabla, campo, tipo_validacion, parametro,
        mensaje_error, es_obligatorio
    INTO arr_reglas[1].*
    FROM reglas_validacion
    WHERE tabla = p_tabla
    ORDER BY campo
    
    RETURN arr_reglas
    
END FUNCTION


# ============================================================
# 5. VALIDAR REGISTRO INDIVIDUAL
# ============================================================
FUNCTION validar_registro(p_num_fila, p_datos_fila, 
    p_tablas, p_campos, p_metadatos)
    
    DEFINE p_num_fila INTEGER
    DEFINE p_datos_fila DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE p_tablas DYNAMIC ARRAY OF VARCHAR(64)
    DEFINE p_campos DYNAMIC ARRAY OF VARCHAR(64)
    DEFINE p_metadatos DYNAMIC ARRAY OF ty_campo_metadato
    
    DEFINE arr_resultados DYNAMIC ARRAY OF ty_validacion_resultado
    DEFINE arr_reglas DYNAMIC ARRAY OF ty_regla_validacion
    
    DEFINE i INTEGER
    DEFINE j INTEGER
    DEFINE k INTEGER
    DEFINE v_indice_campo INTEGER
    DEFINE v_estado VARCHAR(20)
    DEFINE v_mensaje VARCHAR(500)
    
    -- Para cada tabla detectada
    FOR i = 1 TO p_tablas.getLength()
        
        -- Obtener reglas de la tabla
        LET arr_reglas = obtener_reglas_validacion(p_tablas[i])
        
        -- Aplicar cada regla
        FOR j = 1 TO arr_reglas.getLength()
            
            -- Buscar el campo en el query
            LET v_indice_campo = -1
            FOR k = 1 TO p_campos.getLength()
                IF p_campos[k] MATCHES "*" || arr_reglas[j].campo || 
                   "*" OR p_campos[k] = arr_reglas[j].campo THEN
                    LET v_indice_campo = k
                    EXIT FOR
                END IF
            END FOR
            
            IF v_indice_campo > 0 THEN
                -- Validar el valor
                CALL validar_valor(
                    p_datos_fila[v_indice_campo],
                    arr_reglas[j].*,
                    p_metadatos[i]
                )
                RETURNING v_estado, v_mensaje
                
                -- Agregar resultado
                LET arr_resultados[arr_resultados.getLength() + 1].num_fila = p_num_fila
                LET arr_resultados[arr_resultados.getLength()].campo = arr_reglas[j].campo
                LET arr_resultados[arr_resultados.getLength()].valor_original = p_datos_fila[v_indice_campo]
                LET arr_resultados[arr_resultados.getLength()].estado = v_estado
                LET arr_resultados[arr_resultados.getLength()].mensaje = v_mensaje
                
                IF v_estado = "OK" THEN
                    LET arr_resultados[arr_resultados.getLength()].accion_sugerida = "INSERTAR"
                ELSEIF v_estado = "ERROR" THEN
                    LET arr_resultados[arr_resultados.getLength()].accion_sugerida = "OMITIR"
                ELSE
                    LET arr_resultados[arr_resultados.getLength()].accion_sugerida = "REVISAR"
                END IF
            END IF
            
        END FOR
        
    END FOR
    
    RETURN arr_resultados
    
END FUNCTION


# ============================================================
# 6. VALIDAR VALOR SEGÚN REGLA
# ============================================================
FUNCTION validar_valor(p_valor, p_regla, p_metadato)
    DEFINE p_valor VARCHAR(200)
    DEFINE p_regla ty_regla_validacion
    DEFINE p_metadato ty_campo_metadato
    
    DEFINE v_estado VARCHAR(20)
    DEFINE v_mensaje VARCHAR(500)
    DEFINE v_longitud INTEGER
    
    -- Verificar obligatorio
    IF p_regla.es_obligatorio = 'S' AND 
       (LENGTH(TRIM(p_valor)) = 0 OR p_valor IS NULL) THEN
        RETURN "ERROR", "Campo obligatorio vacío"
    END IF
    
    -- Si está vacío y no es obligatorio, es OK
    IF LENGTH(TRIM(p_valor)) = 0 OR p_valor IS NULL THEN
        RETURN "OK", ""
    END IF
    
    -- Aplicar validación según tipo
    CASE p_regla.tipo_validacion
        
        WHEN "FORMATO_DOCUMENTO"
            IF NOT val_documento(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
        WHEN "EMAIL"
            IF NOT val_email(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
        WHEN "SOLO_LETRAS"
            IF NOT val_solo_letras(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
            -- Verificar longitud si hay parámetro
            IF p_regla.parametro IS NOT NULL THEN
                IF NOT val_longitud_rango(p_valor, p_regla.parametro) THEN
                    RETURN "ERROR", p_regla.mensaje_error
                END IF
            END IF
            
        WHEN "SOLO_DIGITOS"
            IF NOT val_solo_digitos(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
        WHEN "ALFANUMERICO"
            IF NOT val_alfanumerico(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
            IF p_regla.parametro IS NOT NULL THEN
                IF NOT val_longitud_rango(p_valor, p_regla.parametro) THEN
                    RETURN "ERROR", p_regla.mensaje_error
                END IF
            END IF
            
        WHEN "NUMERO_POSITIVO"
            IF NOT val_numero_positivo(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
        WHEN "NUMERO_ENTERO"
            IF NOT val_numero_entero(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
        WHEN "FECHA"
            IF NOT val_fecha(p_valor) THEN
                RETURN "ERROR", p_regla.mensaje_error
            END IF
            
        WHEN "LONGITUD"
            IF p_regla.parametro IS NOT NULL THEN
                IF NOT val_longitud_rango(p_valor, p_regla.parametro) THEN
                    RETURN "ERROR", p_regla.mensaje_error
                END IF
            END IF
            
        WHEN "UNIQUE"
            -- Se valida después contra BD
            RETURN "OK", ""
            
        WHEN "EXISTE_BD"
            -- Se valida después contra BD
            RETURN "OK", ""
            
        OTHERWISE
            -- Tipo de validación no reconocido
            RETURN "WARNING", "Tipo validación no soportado"
            
    END CASE
    
    RETURN "OK", ""
    
END FUNCTION


# ============================================================
# 7. VALIDAR DUPLICADOS EN ARCHIVO
# ============================================================
FUNCTION validar_duplicados_archivo(p_num_fila, p_datos, p_resultados)
    DEFINE p_num_fila INTEGER
    DEFINE p_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE p_resultados DYNAMIC ARRAY OF ty_validacion_resultado
    
    DEFINE i INTEGER
    DEFINE j INTEGER
    DEFINE k INTEGER
    DEFINE v_duplicado BOOLEAN
    
    -- Solo verificar si no es el último registro
    IF p_num_fila >= p_datos.getLength() THEN
        RETURN
    END IF
    
    LET v_duplicado = FALSE
    
    -- Comparar con registros siguientes
    FOR i = p_num_fila + 1 TO p_datos.getLength()
        -- Comparar todos los campos
        FOR j = 1 TO p_datos[p_num_fila].getLength()
            IF p_datos[p_num_fila][j] = p_datos[i][j] AND
               LENGTH(TRIM(p_datos[p_num_fila][j])) > 0 THEN
                
                LET v_duplicado = TRUE
                
                -- Marcar como duplicado
                LET p_resultados[p_resultados.getLength() + 1].num_fila = p_num_fila
                LET p_resultados[p_resultados.getLength()].campo = "FILA_DUPLICADA"
                LET p_resultados[p_resultados.getLength()].valor_original = 
                    "Fila " || p_num_fila || " duplica fila " || i
                LET p_resultados[p_resultados.getLength()].estado = "WARNING"
                LET p_resultados[p_resultados.getLength()].mensaje = 
                    "Registro duplicado en archivo"
                LET p_resultados[p_resultados.getLength()].accion_sugerida = "OMITIR"
                
                EXIT FOR
            END IF
        END FOR
        
        IF v_duplicado THEN
            EXIT FOR
        END IF
    END FOR
    
END FUNCTION


# ============================================================
# 8. VALIDAR CONTRA LA BD
# ============================================================
FUNCTION validar_contra_bd(p_num_fila, p_datos_fila, 
    p_tablas, p_campos)
    
    DEFINE p_num_fila INTEGER
    DEFINE p_datos_fila DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE p_tablas DYNAMIC ARRAY OF VARCHAR(64)
    DEFINE p_campos DYNAMIC ARRAY OF VARCHAR(64)
    
    DEFINE arr_resultados DYNAMIC ARRAY OF ty_validacion_resultado
    DEFINE arr_reglas DYNAMIC ARRAY OF ty_regla_validacion
    
    DEFINE i INTEGER
    DEFINE j INTEGER
    DEFINE k INTEGER
    DEFINE v_existe INTEGER
    DEFINE v_indice_campo INTEGER
    DEFINE v_valor VARCHAR(200)
    
    -- Para cada tabla
    FOR i = 1 TO p_tablas.getLength()
        
        -- Obtener reglas UNIQUE y EXISTE_BD
        SELECT tabla, campo, tipo_validacion, parametro,
               mensaje_error, es_obligatorio
        INTO arr_reglas[1].*
        FROM reglas_validacion
        WHERE tabla = p_tablas[i]
          AND tipo_validacion IN ('UNIQUE', 'EXISTE_BD')
        
        -- Aplicar cada regla
        FOR j = 1 TO arr_reglas.getLength()
            
            -- Buscar campo en el query
            LET v_indice_campo = -1
            FOR k = 1 TO p_campos.getLength()
                IF p_campos[k] = arr_reglas[j].campo OR
                   p_campos[k] MATCHES "*." || arr_reglas[j].campo THEN
                    LET v_indice_campo = k
                    EXIT FOR
                END IF
            END FOR
            
            IF v_indice_campo > 0 THEN
                LET v_valor = p_datos_fila[v_indice_campo]
                
                IF arr_reglas[j].tipo_validacion = "UNIQUE" THEN
                    -- Verificar si ya existe
                    SELECT COUNT(*) INTO v_existe
                    FROM systables t
                    JOIN systables c ON 1=0
                    WHERE 1=0  -- Placeholder
                    
                    -- Consulta dinámica
                    CALL consultar_existencia(
                        p_tablas[i], arr_reglas[j].campo, v_valor)
                        RETURNING v_existe
                    
                    IF v_existe > 0 THEN
                        LET arr_resultados[arr_resultados.getLength() + 1].num_fila = p_num_fila
                        LET arr_resultados[arr_resultados.getLength()].campo = arr_reglas[j].campo
                        LET arr_resultados[arr_resultados.getLength()].valor_original = v_valor
                        LET arr_resultados[arr_resultados.getLength()].estado = "WARNING"
                        LET arr_resultados[arr_resultados.getLength()].mensaje = 
                            arr_reglas[j].mensaje_error
                        LET arr_resultados[arr_resultados.getLength()].accion_sugerida = "ACTUALIZAR"
                    END IF
                    
                ELSEIF arr_reglas[j].tipo_validacion = "EXISTE_BD" THEN
                    -- Verificar relación foreign key
                    -- parametro formato: "tabla_destino,campo_destino"
                    CALL validar_foreign_key(
                        arr_reglas[j].parametro, v_valor)
                        RETURNING v_existe
                    
                    IF v_existe = 0 THEN
                        LET arr_resultados[arr_resultados.getLength() + 1].num_fila = p_num_fila
                        LET arr_resultados[arr_resultados.getLength()].campo = arr_reglas[j].campo
                        LET arr_resultados[arr_resultados.getLength()].valor_original = v_valor
                        LET arr_resultados[arr_resultados.getLength()].estado = "ERROR"
                        LET arr_resultados[arr_resultados.getLength()].mensaje = 
                            arr_reglas[j].mensaje_error
                        LET arr_resultados[arr_resultados.getLength()].accion_sugerida = "OMITIR"
                    END IF
                END IF
                
            END IF
            
        END FOR
        
    END FOR
    
    RETURN arr_resultados
    
END FUNCTION


# ============================================================
# 9. CONSULTAR EXISTENCIA EN BD
# ============================================================
FUNCTION consultar_existencia(p_tabla, p_campo, p_valor)
    DEFINE p_tabla VARCHAR(64)
    DEFINE p_campo VARCHAR(64)
    DEFINE p_valor VARCHAR(200)
    
    DEFINE v_sql LVARCHAR(32000)
    DEFINE v_count INTEGER
    
    LET v_sql = "SELECT COUNT(*) FROM ", p_tabla,
                " WHERE ", p_campo, " = '", p_valor, "'"
    
    PREPARE stmt_exist FROM v_sql
    EXECUTE stmt_exist INTO v_count
    
    IF STATUS != 0 THEN
        RETURN 0
    END IF
    
    RETURN v_count
    
END FUNCTION


# ============================================================
# 10. VALIDAR FOREIGN KEY
# ============================================================
FUNCTION validar_foreign_key(p_parametro, p_valor)
    DEFINE p_parametro VARCHAR(200)
    DEFINE p_valor VARCHAR(200)
    
    DEFINE v_tabla_destino VARCHAR(64)
    DEFINE v_campo_destino VARCHAR(64)
    DEFINE v_pos INTEGER
    
    -- Parsear parámetro: "tabla_destino,campo_destino"
    LET v_pos = 0
    FOR i = 1 TO LENGTH(p_parametro)
        IF p_parametro[i] = "," THEN
            LET v_pos = i
            EXIT FOR
        END IF
    END FOR
    
    IF v_pos = 0 THEN
        RETURN 0
    END IF
    
    LET v_tabla_destino = p_parametro[1, v_pos - 1]
    LET v_campo_destino = p_parametro[v_pos + 1, LENGTH(p_parametro)]
    
    -- Verificar existencia
    RETURN consultar_existencia(v_tabla_destino, v_campo_destino, p_valor)
    
END FUNCTION


# ============================================================
# 11. CALCULAR ESTADÍSTICAS
# ============================================================
FUNCTION calcular_estadisticas(p_resultado)
    DEFINE p_resultado ty_validacion_archivo
    
    DEFINE i INTEGER
    
    LET p_resultado.total_validos = 0
    LET p_resultado.total_errores = 0
    LET p_resultado.total_duplicados = 0
    
    FOR i = 1 TO p_resultado.resultados.getLength()
        CASE p_resultado.resultados[i].estado
            WHEN "OK"
                LET p_resultado.total_validos = 
                    p_resultado.total_validos + 1
            WHEN "ERROR"
                LET p_resultado.total_errores = 
                    p_resultado.total_errores + 1
            WHEN "WARNING"
                IF p_resultado.resultados[i].campo = "FILA_DUPLICADA" THEN
                    LET p_resultado.total_duplicados = 
                        p_resultado.total_duplicados + 1
                END IF
        END CASE
    END FOR
    
END FUNCTION


# ============================================================
# 12. MOSTRAR RESULTADOS DE VALIDACIÓN
# ============================================================
FUNCTION mostrar_resultados_validacion(p_resultado)
    DEFINE p_resultado ty_validacion_archivo
    DEFINE v_win WINDOW
    DEFINE i INTEGER
    DEFINE v_total_registros INTEGER
    
    OPEN WINDOW v_win WITH 24 ROWS, 100 COLUMNS
        ATTRIBUTE(STYLE="validacion")
    
    DISPLAY "╔══════════════════════════════════════════════════════════════════════════════════════╗" AT 1,1
    DISPLAY "║                    RESULTADO DE VALIDACIÓN DINÁMICA                               ║" AT 2,1
    DISPLAY "╚══════════════════════════════════════════════════════════════════════════════════════╝" AT 3,1
    
    -- Info del query
    DISPLAY "📋 Query: ", p_resultado.query_original[1, 60], "..." AT 5, 2
    DISPLAY "🗂️ Tablas: ", p_resultado.tablas_detectadas[1] AT 6, 2
    
    -- Estadísticas
    DISPLAY "📊 ESTADÍSTICAS:" AT 8, 2
    DISPLAY "   Total registros: ", p_resultado.total_registros AT 9, 2
    DISPLAY "   ✅ Válidos: ", p_resultado.total_validos AT 10, 2
    DISPLAY "   ❌ Errores: ", p_resultado.total_errores AT 11, 2
    DISPLAY "   ⚠️ Duplicados: ", p_resultado.total_duplicados AT 12, 2
    
    -- Detalle de errores
    DISPLAY "🔍 DETALLE DE ERRORES:" AT 14, 2
    LET i = 1
    WHILE i <= p_resultado.resultados.getLength() AND i <= 10
        IF p_resultado.resultados[i].estado = "ERROR" THEN
            DISPLAY "   Fila ", p_resultado.resultados[i].num_fila,
                ": ", p_resultado.resultados[i].mensaje
                AT 14 + i, 4
        END IF
        LET i = i + 1
    END WHILE
    
    -- Menú
    MENU "Acciones"
        COMMAND "Exportar Errores"
            CALL exportar_errores_validacion(p_resultado)
        
        COMMAND "Importar Solo Válidos"
            CALL importar_registros_validos(p_resultado)
        
        COMMAND "Cancelar"
            EXIT MENU
    
    END MENU
    
    CLOSE WINDOW v_win
    
END FUNCTION


# ============================================================
# 13. FUNCIONES DE VALIDACIÓN (helpers)
# ============================================================
FUNCTION val_solo_letras(p_valor)
    DEFINE p_valor VARCHAR(200)
    DEFINE i INTEGER
    
    FOR i = 1 TO LENGTH(p_valor)
        IF p_valor[i] NOT MATCHES "[A-Za-z ]" THEN
            RETURN FALSE
        END IF
    END FOR
    
    RETURN TRUE
    
END FUNCTION


FUNCTION val_solo_digitos(p_valor)
    DEFINE p_valor VARCHAR(200)
    DEFINE i INTEGER
    
    FOR i = 1 TO LENGTH(p_valor)
        IF p_valor[i] NOT MATCHES "[0-9]" THEN
            RETURN FALSE
        END IF
    END FOR
    
    RETURN TRUE
    
END FUNCTION


FUNCTION val_alfanumerico(p_valor)
    DEFINE p_valor VARCHAR(200)
    DEFINE i INTEGER
    
    FOR i = 1 TO LENGTH(p_valor)
        IF p_valor[i] NOT MATCHES "[A-Za-z0-9]" THEN
            RETURN FALSE
        END IF
    END FOR
    
    RETURN TRUE
    
END FUNCTION


FUNCTION val_numero_positivo(p_valor)
    DEFINE p_valor VARCHAR(200)
    DEFINE v_num DECIMAL(20,2)
    
    LET v_num = p_valor
    IF v_num < 0 THEN
        RETURN FALSE
    END IF
    
    RETURN TRUE
    EXCEPTION
        RETURN FALSE
    
END FUNCTION


FUNCTION val_numero_entero(p_valor)
    DEFINE p_valor VARCHAR(200)
    DEFINE v_num INTEGER
    
    LET v_num = p_valor
    RETURN TRUE
    EXCEPTION
        RETURN FALSE
    
END FUNCTION


FUNCTION val_longitud_rango(p_valor, p_rango)
    DEFINE p_valor VARCHAR(200)
    DEFINE p_rango VARCHAR(50)  -- "min-max"
    
    DEFINE v_min INTEGER
    DEFINE v_max INTEGER
    DEFINE v_pos INTEGER
    DEFINE v_longitud INTEGER
    
    LET v_longitud = LENGTH(TRIM(p_valor))
    
    -- Parsear rango
    LET v_pos = 0
    FOR i = 1 TO LENGTH(p_rango)
        IF p_rango[i] = "-" THEN
            LET v_pos = i
            EXIT FOR
        END IF
    END FOR
    
    IF v_pos = 0 THEN
        RETURN TRUE
    END IF
    
    LET v_min = p_rango[1, v_pos - 1]
    LET v_max = p_rango[v_pos + 1, LENGTH(p_rango)]
    
    IF v_longitud < v_min OR v_longitud > v_max THEN
        RETURN FALSE
    END IF
    
    RETURN TRUE
    
END FUNCTION


# ============================================================
# 14. EXPORTAR ERRORES
# ============================================================
FUNCTION exportar_errores_validacion(p_resultado)
    DEFINE p_resultado ty_validacion_archivo
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE i INTEGER
    
    CALL crear_directorio("export")
    
    LET v_ruta = "export/errores_validacion_",
                 TODAY USING "YYYYMMDD", ".csv"
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "w")
    CALL v_file.write(x"EF BB BF")
    
    # Encabezados
    CALL v_file.write("Fila,Campo,Valor,Estado,Mensaje,Accion")
    
    # Detalle de errores
    FOR i = 1 TO p_resultado.resultados.getLength()
        IF p_resultado.resultados[i].estado != "OK" THEN
            CALL v_file.write(
                p_resultado.resultados[i].num_fila, ",",
                p_resultado.resultados[i].campo, ",",
                '"', p_resultado.resultados[i].valor_original, '",',
                p_resultado.resultados[i].estado, ",",
                '"', p_resultado.resultados[i].mensaje, '",',
                p_resultado.resultados[i].accion_sugerida
            )
        END IF
    END FOR
    
    CALL v_file.close()
    
    CALL log_info("validacion", "Errores exportados: ", v_ruta)
    
    RETURN v_ruta
    
END FUNCTION


# ============================================================
# 15. INSERT DINÁMICO POR QUERY (genérico, sin recompilar)
#     Se adapta a lo que el usuario pase en el query.
#     Opción A: p_datos vacío -> ejecuta el query (INSERT ... SELECT).
#     Opción B: p_datos con filas (Excel/plantilla) -> INSERT por fila.
#     Devuelve: nº de filas insertadas, o código negativo de error.
#       -1 sin columnas detectables (SELECT *)
#       -2 tabla destino inexistente
#       -3 campo del query no existe en la tabla destino
#       -4 error ejecutando el INSERT
#       -5 el query no es un SELECT
# ============================================================
FUNCTION insertar_query_dinamico(p_query, p_tabla_destino, p_datos)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_tabla_destino VARCHAR(64)
    DEFINE p_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)

    DEFINE r_analisis RECORD
        tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        campos_detectados DYNAMIC ARRAY OF VARCHAR(64),
        aliases DYNAMIC ARRAY OF VARCHAR(64)
    END RECORD

    DEFINE arr_cols_nombre DYNAMIC ARRAY OF VARCHAR(64)
    DEFINE arr_cols_tipo   DYNAMIC ARRAY OF VARCHAR(20)
    DEFINE arr_map_idx     DYNAMIC ARRAY OF INTEGER

    DEFINE v_sql LVARCHAR(32000)
    DEFINE v_cols_lista LVARCHAR(8000)
    DEFINE v_vals_lista LVARCHAR(8000)
    DEFINE v_lit LVARCHAR(400)
    DEFINE v_campo_limpio VARCHAR(64)
    DEFINE v_encontrado INTEGER
    DEFINE v_insertados INTEGER
    DEFINE v_con_datos SMALLINT
    DEFINE i INTEGER
    DEFINE j INTEGER

    -- 1. Detectar columnas que selecciona el query (reusa analizar_query_simple)
    LET r_analisis = analizar_query_simple(p_query)
    IF r_analisis.campos_detectados.getLength() = 0 THEN
        RETURN -1
    END IF

    -- 2. Obtener columnas y tipos REALES de la tabla destino
    CALL iq_obtener_columnas(p_tabla_destino)
        RETURNING arr_cols_nombre, arr_cols_tipo
    IF arr_cols_nombre.getLength() = 0 THEN
        RETURN -2
    END IF

    -- 3. Mapear cada campo del query a su columna destino (por nombre)
    FOR i = 1 TO r_analisis.campos_detectados.getLength()
        LET v_campo_limpio = iq_limpiar_campo(r_analisis.campos_detectados[i])
        LET v_encontrado = 0
        FOR j = 1 TO arr_cols_nombre.getLength()
            IF LOWER(arr_cols_nombre[j]) = LOWER(v_campo_limpio) THEN
                LET v_encontrado = j
                EXIT FOR
            END IF
        END FOR
        IF v_encontrado = 0 THEN
            RETURN -3
        END IF
        LET arr_map_idx[i] = v_encontrado
    END FOR

    -- Lista de columnas destino en el orden del query
    LET v_cols_lista = ""
    FOR i = 1 TO arr_map_idx.getLength()
        IF i > 1 THEN
            LET v_cols_lista = v_cols_lista || ", "
        END IF
        LET v_cols_lista = v_cols_lista || arr_cols_nombre[arr_map_idx[i]]
    END FOR

    -- Quitar ';' final del query si existe
    IF LENGTH(p_query) > 0 THEN
        IF p_query[LENGTH(p_query)] = ";" THEN
            LET p_query = p_query[1, LENGTH(p_query) - 1]
        END IF
    END IF

    LET v_con_datos = (p_datos.getLength() > 0)

    IF v_con_datos THEN
        -- ======================
        -- Opción B: INSERT por fila desde p_datos
        -- ======================
        LET v_insertados = 0
        BEGIN WORK
        FOR i = 1 TO p_datos.getLength()
            LET v_vals_lista = ""
            FOR j = 1 TO arr_map_idx.getLength()
                IF j > 1 THEN
                    LET v_vals_lista = v_vals_lista || ", "
                END IF
                IF j <= p_datos[i].getLength() THEN
                    CALL iq_convertir_valor(
                        p_datos[i][j], arr_cols_tipo[arr_map_idx[j]])
                        RETURNING v_lit
                ELSE
                    LET v_lit = "NULL"
                END IF
                LET v_vals_lista = v_vals_lista || v_lit
            END FOR

            LET v_sql = "INSERT INTO ", p_tabla_destino,
                        " (", v_cols_lista, ") VALUES (", v_vals_lista, ")"
            EXECUTE IMMEDIATE v_sql
            IF STATUS <> 0 THEN
                ROLLBACK WORK
                RETURN -4
            END IF
            LET v_insertados = v_insertados + 1
        END FOR
        COMMIT WORK
    ELSE
        -- ======================
        -- Opción A: INSERT ... SELECT (el query manda los datos)
        -- ======================
        IF LOWER(LTRIM(p_query))[1, 6] <> "select" THEN
            RETURN -5
        END IF
        LET v_sql = "INSERT INTO ", p_tabla_destino,
                    " (", v_cols_lista, ") ", p_query
        EXECUTE IMMEDIATE v_sql
        IF STATUS <> 0 THEN
            RETURN -4
        END IF
        LET v_insertados = DBINFO('sqlca.sqlerrd2')
    END IF

    RETURN v_insertados

END FUNCTION


# ============================================================
# 15.1 Helper: columnas y tipos REALES de una tabla
#      (decodifica syscolumns; base = coltype - 256 si NOT NULL)
# ============================================================
FUNCTION iq_obtener_columnas(p_tabla)
    DEFINE p_tabla VARCHAR(64)
    DEFINE arr_nombre DYNAMIC ARRAY OF VARCHAR(64)
    DEFINE arr_tipo   DYNAMIC ARRAY OF VARCHAR(20)
    DEFINE v_nombre VARCHAR(64)
    DEFINE v_coltype INTEGER
    DEFINE v_base INTEGER
    DEFINE i INTEGER

    LET i = 0
    FOREACH SELECT colname, coltype
        INTO v_nombre, v_coltype
        FROM systables t, syscolumns c
        WHERE t.tabid = c.tabid
          AND t.tabname = p_tabla
        ORDER BY c.colno

        LET i = i + 1
        LET arr_nombre[i] = v_nombre

        LET v_base = v_coltype
        IF v_base >= 256 THEN
            LET v_base = v_base - 256
        END IF
        CASE v_base
            WHEN 0  LET arr_tipo[i] = "CHAR"
            WHEN 1  LET arr_tipo[i] = "SMALLINT"
            WHEN 2  LET arr_tipo[i] = "INTEGER"
            WHEN 5  LET arr_tipo[i] = "DECIMAL"
            WHEN 6  LET arr_tipo[i] = "SERIAL"
            WHEN 7  LET arr_tipo[i] = "DATE"
            WHEN 8  LET arr_tipo[i] = "MONEY"
            WHEN 10 LET arr_tipo[i] = "DATETIME"
            WHEN 13 LET arr_tipo[i] = "VARCHAR"
            WHEN 43 LET arr_tipo[i] = "LVARCHAR"
            OTHERWISE LET arr_tipo[i] = "TEXT"
        END CASE
    END FOREACH

    RETURN arr_nombre, arr_tipo

END FUNCTION


# ============================================================
# 15.2 Helper: limpiar nombre de campo del query
#      (quita alias tras espacio y prefijo "tabla.")
# ============================================================
FUNCTION iq_limpiar_campo(p_campo)
    DEFINE p_campo VARCHAR(100)
    DEFINE v VARCHAR(60)

    LET v = p_campo

    -- cortar en el primer espacio (alias o resto)
    IF INSTR(v, " ") > 0 THEN
        LET v = v[1, INSTR(v, " ") - 1]
    END IF

    -- quitar prefijo de tabla "tabla.campo"
    IF INSTR(v, ".") > 0 THEN
        LET v = v[INSTR(v, ".") + 1, LENGTH(v)]
    END IF

    RETURN v

END FUNCTION


# ============================================================
# 15.3 Helper: convertir un valor (string) a literal SQL según tipo
# ============================================================
FUNCTION iq_convertir_valor(p_valor, p_tipo)
    DEFINE p_valor VARCHAR(200)
    DEFINE p_tipo VARCHAR(20)
    DEFINE v VARCHAR(200)

    LET v = TRIM(NVL(p_valor, ""))

    -- vacío -> NULL (la BD hará cumplir NOT NULL si corresponde)
    IF v = "" THEN
        RETURN "NULL"
    END IF

    CASE p_tipo
        WHEN "CHAR", "VARCHAR", "LVARCHAR", "TEXT"
            RETURN iq_escapar_texto(v)
        WHEN "SMALLINT", "INTEGER", "SERIAL", "DECIMAL", "MONEY"
            RETURN v
        WHEN "DATE"
            RETURN "'" || iq_normalizar_fecha(v) || "'"
        WHEN "DATETIME"
            RETURN "'" || v || "'"
        OTHERWISE
            RETURN iq_escapar_texto(v)
    END CASE

END FUNCTION


# ============================================================
# 15.4 Helper: escapar comillas simples y envolver en comillas
# ============================================================
FUNCTION iq_escapar_texto(p)
    DEFINE p VARCHAR(200)
    DEFINE r LVARCHAR(500)
    DEFINE i INTEGER

    LET r = "'"
    FOR i = 1 TO LENGTH(p)
        IF p[i] = "'" THEN
            LET r = r || "''"
        ELSE
            LET r = r || p[i]
        END IF
    END FOR
    LET r = r || "'"
    RETURN r

END FUNCTION


# ============================================================
# 15.5 Helper: normalizar fecha DD/MM/YYYY -> YYYY-MM-DD
#      (otros formatos se pasan tal cual y los resuelve la BD/DBDATE)
# ============================================================
FUNCTION iq_normalizar_fecha(p)
    DEFINE p VARCHAR(20)

    IF LENGTH(p) = 10 AND p[3] = "/" AND p[6] = "/" THEN
        RETURN p[7, 10] || "-" || p[4, 5] || "-" || p[1, 2]
    END IF
    RETURN p

END FUNCTION


# ============================================================
# 16. LEER CSV -> encabezados + datos (para Opción B)
#     Primera fila = encabezados (se devuelve aparte).
#     Devuelve: arr_headers (nombres de columna)
#               arr_datos   (filas de datos, sin encabezado)
# ============================================================
FUNCTION iq_leer_csv_a_datos(p_ruta)
    DEFINE p_ruta VARCHAR(300)
    DEFINE arr_headers DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE arr_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)

    DEFINE v_file base.Channel
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_fila INTEGER
    DEFINE v_num_col INTEGER
    DEFINE v_first SMALLINT
    DEFINE arr_campos DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE i INTEGER

    LET v_file = base.Channel.create()
    CALL v_file.openFile(p_ruta, "r")

    LET v_fila = 0
    LET v_first = TRUE

    WHILE v_file.read(v_linea)
        CALL iq_partir_csv(v_linea)
            RETURNING arr_campos, v_num_col

        IF v_first THEN
            -- primera fila = encabezados
            FOR i = 1 TO arr_campos.getLength()
                LET arr_headers[i] = TRIM(arr_campos[i])
            END FOR
            LET v_first = FALSE
        ELSE
            -- filas de datos
            LET v_fila = v_fila + 1
            FOR i = 1 TO arr_campos.getLength()
                LET arr_datos[v_fila][i] = arr_campos[i]
            END FOR
        END IF
    END WHILE

    CALL v_file.close()
    RETURN arr_headers, arr_datos

END FUNCTION


# ============================================================
# 16.1 Helper: partir una línea CSV en campos (respeta comillas)
# ============================================================
FUNCTION iq_partir_csv(p_linea)
    DEFINE p_linea VARCHAR(32000)
    DEFINE arr_campos DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE v_campo VARCHAR(200)
    DEFINE v_num_col INTEGER
    DEFINE i INTEGER
    DEFINE v_len INTEGER
    DEFINE v_c CHAR(1)
    DEFINE v_entre_comillas SMALLINT

    LET v_campo = ""
    LET v_num_col = 0
    LET v_entre_comillas = FALSE
    LET v_len = LENGTH(p_linea)

    FOR i = 1 TO v_len
        LET v_c = p_linea[i]

        IF v_c = '"' THEN
            -- alternar estado de comillas (coma dentro de comillas no separa)
            LET v_entre_comillas = NOT v_entre_comillas
        ELSE
            IF v_c = "," AND v_entre_comillas = FALSE THEN
                LET v_num_col = v_num_col + 1
                LET arr_campos[v_num_col] = v_campo
                LET v_campo = ""
            ELSE
                LET v_campo = v_campo || v_c
            END IF
        END IF
    END FOR

    -- último campo (aunque la línea esté vacía, deja al menos 1 columna)
    LET v_num_col = v_num_col + 1
    LET arr_campos[v_num_col] = v_campo

    RETURN arr_campos, v_num_col

END FUNCTION


FUNCTION crear_directorio(p_dir)
    DEFINE p_dir VARCHAR(200)
    RUN "if not exist ", p_dir, " mkdir ", p_dir
END FUNCTION
