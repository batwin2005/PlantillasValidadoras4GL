# ============================================================
# logs.4gl - Sistema de Logging para Plantillas4GL
# Genero BDL 4GL - Archivos de log (no depende de BD)
# ============================================================

# ============================================================
# CONFIGURACIÓN
# ============================================================
GLOBALS "globals.4gl"

# Niveles de log
CONSTANT LOG_DEBUG   = "DEBUG"
CONSTANT LOG_INFO    = "INFO"
CONSTANT LOG_WARNING = "WARNING"
CONSTANT LOG_ERROR   = "ERROR"

# Configuración
DEFINE g_log_dir VARCHAR(200) = "logs"
DEFINE g_log_level VARCHAR(10) = "INFO"
DEFINE g_log_enabled BOOLEAN = TRUE


# ============================================================
# 1. LOG BÁSICO A ARCHIVO
# ============================================================
FUNCTION log_message(p_nivel, p_modulo, p_mensaje)
    DEFINE p_nivel VARCHAR(10)
    DEFINE p_modulo VARCHAR(50)
    DEFINE p_mensaje LVARCHAR(32000)
    
    DEFINE v_file base.Channel
    DEFINE v_fecha VARCHAR(20)
    DEFINE v_hora VARCHAR(20)
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_linea LVARCHAR(32000)
    
    # Verificar si logging está habilitado
    IF NOT g_log_enabled THEN
        RETURN
    END IF
    
    # Verificar nivel
    IF NOT debe_loguear(p_nivel) THEN
        RETURN
    END IF
    
    # Preparar fecha/hora
    LET v_fecha = TODAY USING "YYYY-MM-DD"
    LET v_hora = CURRENT USING "HH:MM:SS"
    
    # Ruta del archivo (rotación diaria)
    LET v_ruta = g_log_dir, "/app_", 
                 TODAY USING "YYYYMMDD", ".log"
    
    # Crear directorio si no existe
    CALL crear_directorio_log(g_log_dir)
    
    # Abrir archivo en modo append
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "a")
    
    # Formato: [FECHA] [HORA] [NIVEL] [MODULO] [USUARIO] MENSAJE
    LET v_linea = "[", v_fecha, "] ",
                  "[", v_hora, "] ",
                  "[", p_nivel, "] ",
                  "[", p_modulo, "] ",
                  "[", NVL(g_usuario_actual, "system"), "] ",
                  p_mensaje
    
    CALL v_file.write(v_linea)
    CALL v_file.close()
    
END FUNCTION


# ============================================================
# 2. FUNCIONES DE CONVENIENCIA
# ============================================================
FUNCTION log_debug(p_modulo, p_mensaje)
    CALL log_message(LOG_DEBUG, p_modulo, p_mensaje)
END FUNCTION

FUNCTION log_info(p_modulo, p_mensaje)
    CALL log_message(LOG_INFO, p_modulo, p_mensaje)
END FUNCTION

FUNCTION log_warning(p_modulo, p_mensaje)
    CALL log_message(LOG_WARNING, p_modulo, p_mensaje)
END FUNCTION

FUNCTION log_error(p_modulo, p_mensaje)
    CALL log_message(LOG_ERROR, p_modulo, p_mensaje)
END FUNCTION


# ============================================================
# 3. LOG DE USUARIOS (Auditoría)
# ============================================================
FUNCTION log_usuario(p_accion, p_detalles)
    DEFINE p_accion VARCHAR(50)
    DEFINE p_detalles LVARCHAR(32000)
    
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_linea LVARCHAR(32000)
    
    IF NOT g_log_enabled THEN
        RETURN
    END IF
    
    LET v_ruta = g_log_dir, "/usuarios_", 
                 TODAY USING "YYYYMMDD", ".log"
    
    CALL crear_directorio_log(g_log_dir)
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "a")
    
    # Formato: [FECHA_HORA] [USUARIO] [ACCION] [IP] DETALLES
    LET v_linea = "[", CURRENT USING "YYYY-MM-DD HH:MM:SS", "] ",
                  "[", NVL(g_usuario_actual, "anonymous"), "] ",
                  "[", p_accion, "] ",
                  "[", NVL(GETENV("CLIENT_IP"), "unknown"), "] ",
                  p_detalles
    
    CALL v_file.write(v_linea)
    CALL v_file.close()
    
END FUNCTION


# ============================================================
# 4. LOG DE BASE DE DATOS
# ============================================================
FUNCTION log_database(p_operacion, p_tabla, p_query, p_tiempo_ms, p_registros)
    DEFINE p_operacion VARCHAR(20)
    DEFINE p_tabla VARCHAR(100)
    DEFINE p_query LVARCHAR(32000)
    DEFINE p_tiempo_ms INTEGER
    DEFINE p_registros INTEGER
    
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_linea LVARCHAR(32000)
    
    IF NOT g_log_enabled THEN
        RETURN
    END IF
    
    # Solo log queries importantes o lentas
    IF p_tiempo_ms < 100 AND p_operacion = "SELECT" THEN
        RETURN
    END IF
    
    LET v_ruta = g_log_dir, "/database_", 
                 TODAY USING "YYYYMMDD", ".log"
    
    CALL crear_directorio_log(g_log_dir)
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "a")
    
    LET v_linea = "[", CURRENT USING "YYYY-MM-DD HH:MM:SS", "] ",
                  "[", p_operacion, "] ",
                  "[", p_tabla, "] ",
                  "[", p_tiempo_ms, "ms] ",
                  "[", p_registros, " rows] ",
                  p_query
    
    CALL v_file.write(v_linea)
    CALL v_file.close()
    
END FUNCTION


# ============================================================
# 5. LOG DE PERFORMANCE
# ============================================================
FUNCTION log_performance(p_funcion, p_inicio, p_fin)
    DEFINE p_funcion VARCHAR(100)
    DEFINE p_inicio DATETIME YEAR TO FRACTION(3)
    DEFINE p_fin DATETIME YEAR TO FRACTION(3)
    
    DEFINE v_tiempo_ms INTEGER
    DEFINE v_file base.Channel
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_linea LVARCHAR(32000)
    
    IF NOT g_log_enabled THEN
        RETURN
    END IF
    
    # Calcular diferencia en ms
    LET v_tiempo_ms = (p_fin - p_inicio) * 1000
    
    # Solo loguear si es lento
    IF v_tiempo_ms > 500 THEN
        LET v_ruta = g_log_dir, "/performance_", 
                     TODAY USING "YYYYMMDD", ".log"
        
        CALL crear_directorio_log(g_log_dir)
        
        LET v_file = base.Channel.create()
        CALL v_file.openFile(v_ruta, "a")
        
        LET v_linea = "[", CURRENT USING "YYYY-MM-DD HH:MM:SS", "] ",
                      "[", v_tiempo_ms, "ms] ",
                      "[", p_funcion, "]"
        
        CALL v_file.write(v_linea)
        CALL v_file.close()
    END IF
    
END FUNCTION


# ============================================================
# 6. LOG DE EXPORTACIÓN
# ============================================================
FUNCTION log_exportacion(p_formato, p_archivo, p_registros, p_estado)
    DEFINE p_formato VARCHAR(20)
    DEFINE p_archivo VARCHAR(300)
    DEFINE p_registros INTEGER
    DEFINE p_estado VARCHAR(20)
    
    CALL log_usuario("EXPORT_" || p_formato,
        "Archivo: ", p_archivo,
        " | Registros: ", p_registros,
        " | Estado: ", p_estado)
    
END FUNCTION


# ============================================================
# 7. LOG DE PLANTILLA
# ============================================================
FUNCTION log_plantilla(p_banco, p_plantilla, p_estado)
    DEFINE p_banco VARCHAR(20)
    DEFINE p_plantilla VARCHAR(300)
    DEFINE p_estado VARCHAR(20)
    
    CALL log_info("plantilla",
        "Banco: ", p_banco,
        " | Plantilla: ", p_plantilla,
        " | Estado: ", p_estado)
    
END FUNCTION


# ============================================================
# 8. HELPERS
# ============================================================
FUNCTION debe_loguear(p_nivel)
    DEFINE p_nivel VARCHAR(10)
    
    CASE g_log_level
        WHEN LOG_DEBUG
            RETURN TRUE
        WHEN LOG_INFO
            RETURN p_nivel != LOG_DEBUG
        WHEN LOG_WARNING
            RETURN p_nivel IN (LOG_WARNING, LOG_ERROR)
        WHEN LOG_ERROR
            RETURN p_nivel = LOG_ERROR
        OTHERWISE
            RETURN TRUE
    END CASE
    
END FUNCTION


FUNCTION crear_directorio_log(p_dir)
    DEFINE p_dir VARCHAR(200)
    
    RUN "if not exist ", p_dir, " mkdir ", p_dir
    
END FUNCTION


FUNCTION configurar_log(p_dir, p_level, p_enabled)
    DEFINE p_dir VARCHAR(200)
    DEFINE p_level VARCHAR(10)
    DEFINE p_enabled BOOLEAN
    
    LET g_log_dir = p_dir
    LET g_log_level = p_level
    LET g_log_enabled = p_enabled
    
    CALL log_info("config", 
        "Log configurado: dir=", p_dir,
        ", level=", p_level,
        ", enabled=", p_enabled)
    
END FUNCTION


FUNCTION limpiar_logs(p_dias)
    DEFINE p_dias INTEGER
    
    RUN "forfiles /p ", g_log_dir, 
        " /m *.log /d -", p_dias,
        " /c \"cmd /c del @path\""
    
    CALL log_info("logs", 
        "Logs anteriores a ", p_dias, " días eliminados")
    
END FUNCTION
