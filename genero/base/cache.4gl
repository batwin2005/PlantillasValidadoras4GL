# ============================================================
# MODULO: cache.4gl
# Sistema de Caché para Consultas
# Mejora rendimiento consultas frecuentes
# ============================================================

DATABASE banco

# ============================================================
# TIPOS DE DATOS
# ============================================================
TYPE ty_cache_entry RECORD
    query_hash VARCHAR(64),
    query_text LVARCHAR(32000),
    resultado_xml LVARCHAR(32739),
    fecha_creacion DATETIME YEAR TO FRACTION(3),
    fecha_expira DATETIME YEAR TO FRACTION(3),
    acceso_count INTEGER,
    tamano_bytes INTEGER
END RECORD

TYPE ty_cache_stats RECORD
    total_entradas INTEGER,
    total_accesos INTEGER,
    total_hits INTEGER,
    total_misses INTEGER,
    tasa_hits DECIMAL(5,2),
    memoria_total_mb DECIMAL(10,2)
END RECORD

# Configuración de caché
DEFINE g_cache_enabled BOOLEAN = TRUE
DEFINE g_cache_ttl_minutos INTEGER = 30
DEFINE g_cache_max_entradas INTEGER = 1000
DEFINE g_cache_dir VARCHAR(200) = "cache"


# ============================================================
# 1. OBTENER DE CACHÉ
# ============================================================
FUNCTION cache_get(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE r_entry ty_cache_entry
    DEFINE v_hash VARCHAR(64)
    DEFINE v_now DATETIME YEAR TO FRACTION(3)
    
    # Verificar si caché está habilitado
    IF NOT g_cache_enabled THEN
        RETURN NULL
    END IF
    
    # Generar hash del query
    LET v_hash = generar_hash(p_query)
    LET v_now = CURRENT
    
    # Buscar en caché
    SELECT 
        query_hash,
        query_text,
        resultado_xml,
        fecha_creacion,
        fecha_expira,
        acceso_count,
        tamano_bytes
    INTO r_entry.*
    FROM cache_consultas
    WHERE query_hash = v_hash
      AND fecha_expira > v_now
    
    IF STATUS = 0 AND r_entry.query_hash IS NOT NULL THEN
        # HIT: Incrementar contador de acceso
        UPDATE cache_consultas
        SET acceso_count = acceso_count + 1
        WHERE query_hash = v_hash
        
        CALL log_info("cache", 
            "HIT: ", v_hash, 
            " (accesos: ", r_entry.acceso_count + 1, ")")
        
        RETURN r_entry.resultado_xml
    ELSE
        # MISS
        CALL log_debug("cache", "MISS: ", v_hash)
        RETURN NULL
    END IF
    
END FUNCTION


# ============================================================
# 2. GUARDAR EN CACHÉ
# ============================================================
FUNCTION cache_put(p_query, p_resultado)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_resultado LVARCHAR(32739)
    DEFINE v_hash VARCHAR(64)
    DEFINE v_now DATETIME YEAR TO FRACTION(3)
    DEFINE v_expira DATETIME YEAR TO FRACTION(3)
    DEFINE v_tamano INTEGER
    
    # Verificar si caché está habilitado
    IF NOT g_cache_enabled THEN
        RETURN FALSE
    END IF
    
    # No cachear resultados que no quepan en la columna (24000 bytes)
    LET v_tamano = LENGTH(p_resultado)
    IF v_tamano > 24000 THEN
        CALL log_debug("cache", 
            "Resultado muy grande para cachear: ", v_tamano, " bytes")
        RETURN FALSE
    END IF
    
    # Generar hash y calcular expiración
    LET v_hash = generar_hash(p_query)
    LET v_now = CURRENT
    LET v_expira = v_now + (g_cache_ttl_minutos UNITS MINUTE)
    
    # Verificar límite de entradas
    CALL cache_limpiar_si_necesario()
    
    # Insertar o actualizar
    DELETE FROM cache_consultas WHERE query_hash = v_hash
    
    INSERT INTO cache_consultas (
        query_hash,
        query_text,
        resultado_xml,
        fecha_creacion,
        fecha_expira,
        acceso_count,
        tamano_bytes
    ) VALUES (
        v_hash,
        p_query,
        p_resultado,
        v_now,
        v_expira,
        0,
        v_tamano
    )
    
    IF STATUS = 0 THEN
        CALL log_debug("cache", 
            "GUARDADO: ", v_hash, 
            " (", v_tamano, " bytes)")
        RETURN TRUE
    ELSE
        CALL log_error("cache", 
            "ERROR guardando en caché: ", v_hash)
        RETURN FALSE
    END IF
    
END FUNCTION


# ============================================================
# 3. EJECUTAR CON CACHÉ
# ============================================================
FUNCTION cache_query(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE v_resultado LVARCHAR(32739)
    DEFINE v_inicio DATETIME YEAR TO FRACTION(3)
    DEFINE v_fin DATETIME YEAR TO FRACTION(3)
    
    LET v_inicio = CURRENT
    
    # 1. Intentar obtener de caché
    LET v_resultado = cache_get(p_query)
    
    IF v_resultado IS NOT NULL THEN
        LET v_fin = CURRENT
        CALL log_performance("cache_query", v_inicio, v_fin)
        RETURN v_resultado
    END IF
    
    # 2. Ejecutar query real
    LET v_resultado = ejecutar_query_xml(p_query)
    
    # 3. Guardar en caché
    IF v_resultado IS NOT NULL AND 
       LENGTH(v_resultado) > 0 THEN
        CALL cache_put(p_query, v_resultado)
    END IF
    
    LET v_fin = CURRENT
    CALL log_performance("cache_query_miss", v_inicio, v_fin)
    
    RETURN v_resultado
    
END FUNCTION


# ============================================================
# 4. EJECUTAR QUERY REAL (llama SP XML)
# ============================================================
FUNCTION ejecutar_query_xml(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE v_xml LVARCHAR(32739)
    
    # Usar SP de Informix para convertir a XML
    EXECUTE FUNCTION f_query_to_xml_hdr('resultados', p_query)
        INTO v_xml
    
    IF STATUS != 0 THEN
        CALL log_error("cache", 
            "Error ejecutando query: ", STATUS)
        RETURN NULL
    END IF
    
    RETURN v_xml
    
END FUNCTION


# ============================================================
# 5. GENERAR HASH DEL QUERY
# ============================================================
FUNCTION generar_hash(p_query)
    DEFINE p_query LVARCHAR(32000)
    DEFINE v_hash VARCHAR(64)
    DEFINE v_query_normalizada VARCHAR(32000)
    
    # Normalizar query (quitar espacios extra, lowercase)
    LET v_query_normalizada = LOWER(TRIM(p_query))
    LET v_query_normalizada = reemplazar(v_query_normalizada, 
        "  ", " ")
    LET v_query_normalizada = reemplazar(v_query_normalizada, 
        "  ", " ")
    
    # Generar hash simple (en producción usar MD5/SHA)
    LET v_hash = ""
    DEFINE i INTEGER
    DEFINE v_ascii INTEGER
    
    FOR i = 1 TO LENGTH(v_query_normalizada)
        LET v_ascii = ASCII(v_query_normalizada[i])
        LET v_hash = v_hash, 
            utilidades_hex(v_ascii MOD 256)
    END FOR
    
    # Truncar a 64 caracteres
    IF LENGTH(v_hash) > 64 THEN
        LET v_hash = v_hash[1,64]
    END IF
    
    RETURN v_hash
    
END FUNCTION


# ============================================================
# 6. LIMPIAR CACHÉ
# ============================================================
FUNCTION cache_limpiar_expiradas()
    DEFINE v_count INTEGER
    
    DELETE FROM cache_consultas
    WHERE fecha_expira < CURRENT
    
    LET v_count = SQLCA.SQLERRD[2]
    
    CALL log_info("cache", 
        "Limpiadas ", v_count, " entradas expiradas")
    
    RETURN v_count
    
END FUNCTION


FUNCTION cache_limpiar_si_necesario()
    DEFINE v_total INTEGER
    DEFINE v_a_eliminar INTEGER
    
    SELECT COUNT(*) INTO v_total
    FROM cache_consultas
    
    IF v_total >= g_cache_max_entradas THEN
        # Eliminar las menos usadas
        LET v_a_eliminar = v_total - (g_cache_max_entradas * 80 / 100)
        
        DELETE FROM cache_consultas
        WHERE query_hash IN (
            SELECT query_hash FROM cache_consultas
            ORDER BY acceso_count ASC, fecha_creacion ASC
            LIMIT v_a_eliminar
        )
        
        CALL log_info("cache", 
            "Limpiadas ", v_a_eliminar, " entradas menos usadas")
    END IF
    
END FUNCTION


FUNCTION cache_limpiar_todo()
    DEFINE v_count INTEGER
    
    DELETE FROM cache_consultas
    LET v_count = SQLCA.SQLERRD[2]
    
    CALL log_info("cache", 
        "Caché completamente limpiada: ", v_count, " entradas")
    
    RETURN v_count
    
END FUNCTION


# ============================================================
# 7. ESTADÍSTICAS DE CACHÉ
# ============================================================
FUNCTION cache_estadisticas()
    DEFINE r_stats ty_cache_stats
    
    SELECT 
        COUNT(*),
        SUM(acceso_count),
        COUNT(CASE WHEN acceso_count > 0 THEN 1 END),
        COUNT(CASE WHEN acceso_count = 0 THEN 1 END),
        0,
        SUM(tamano_bytes) / 1048576.0
    INTO r_stats.*
    FROM cache_consultas
    
    # Calcular tasa de hits
    IF r_stats.total_accesos > 0 THEN
        LET r_stats.tasa_hits = 
            (r_stats.total_hits * 100.0) / r_stats.total_accesos
    ELSE
        LET r_stats.tasa_hits = 0
    END IF
    
    RETURN r_stats.*
    
END FUNCTION


FUNCTION cache_mostrar_estadisticas()
    DEFINE r_stats ty_cache_stats
    
    LET r_stats = cache_estadisticas()
    
    CALL log_info("cache", "=== ESTADÍSTICAS DE CACHÉ ===")
    CALL log_info("cache", 
        "Total entradas: ", r_stats.total_entradas)
    CALL log_info("cache", 
        "Total accesos: ", r_stats.total_accesos)
    CALL log_info("cache", 
        "Hits: ", r_stats.total_hits)
    CALL log_info("cache", 
        "Misses: ", r_stats.total_misses)
    CALL log_info("cache", 
        "Tasa hits: ", r_stats.tasa_hits, "%")
    CALL log_info("cache", 
        "Memoria: ", r_stats.memoria_total_mb, " MB")
    
END FUNCTION


# ============================================================
# 8. CONFIGURACIÓN
# ============================================================
FUNCTION cache_configurar(p_enabled, p_ttl_minutos, p_max_entradas)
    DEFINE p_enabled BOOLEAN
    DEFINE p_ttl_minutos INTEGER
    DEFINE p_max_entradas INTEGER
    
    LET g_cache_enabled = p_enabled
    LET g_cache_ttl_minutos = p_ttl_minutos
    LET g_cache_max_entradas = p_max_entradas
    
    CALL log_info("cache", 
        "Configurado: enabled=", p_enabled,
        ", ttl=", p_ttl_minutos, "min",
        ", max=", p_max_entradas)
    
END FUNCTION


FUNCTION cache_habilitar()
    LET g_cache_enabled = TRUE
    CALL log_info("cache", "Caché habilitado")
END FUNCTION


FUNCTION cache_deshabilitar()
    LET g_cache_enabled = FALSE
    CALL log_info("cache", "Caché deshabilitado")
END FUNCTION


# ============================================================
# 9. HELPERS
# ============================================================
FUNCTION reemplazar(p_texto, p_buscar, p_reemplazar)
    DEFINE p_texto LVARCHAR(32000)
    DEFINE p_buscar VARCHAR(100)
    DEFINE p_reemplazar VARCHAR(100)
    DEFINE v_result LVARCHAR(32000)
    DEFINE v_pos INTEGER
    
    LET v_result = ""
    LET v_pos = 1
    
    WHILE v_pos <= LENGTH(p_texto)
        IF p_texto[v_pos, v_pos + LENGTH(p_buscar) - 1] = p_buscar THEN
            LET v_result = v_result, p_reemplazar
            LET v_pos = v_pos + LENGTH(p_buscar)
        ELSE
            LET v_result = v_result, p_texto[v_pos]
            LET v_pos = v_pos + 1
        END IF
    END WHILE
    
    RETURN v_result
    
END FUNCTION


FUNCTION utilidades_hex(p_num)
    DEFINE p_num INTEGER
    DEFINE v_hex VARCHAR(2)
    DEFINE v_digitos VARCHAR(16)
    
    LET v_digitos = "0123456789ABCDEF"
    
    LET v_hex = v_digitos[(p_num / 16) + 1] || 
                v_digitos[(p_num MOD 16) + 1]
    
    RETURN v_hex
    
END FUNCTION
