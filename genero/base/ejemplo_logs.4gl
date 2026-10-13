# ============================================================
# ejemplo_logs.4gl - Ejemplo de uso del sistema de logs
# Genero BDL 4GL
# ============================================================

# ============================================================
# EJEMPLO 1: Log básico
# ============================================================
FUNCTION ejemplo_log_basico()
    
    # Info general
    CALL log_info("ejemplo", "Función iniciada")
    
    # Warning
    CALL log_warning("ejemplo", "Campo opcional vacío")
    
    # Error
    CALL log_error("ejemplo", "Error al conectar con BD")
    
    # Debug (solo si nivel = DEBUG)
    CALL log_debug("ejemplo", "Valor de variable: ", 123)
    
END FUNCTION


# ============================================================
# EJEMPLO 2: Log de usuario
# ============================================================
FUNCTION ejemplo_log_usuario()
    
    CALL log_usuario("LOGIN", "Usuario inició sesión")
    CALL log_usuario("EXPORT_CSV", "Exportó movimientos a CSV")
    CALL log_usuario("GENERAR_REPORTE", "Generó libro de bancos")
    CALL log_usuario("LOGOUT", "Usuario cerró sesión")
    
END FUNCTION


# ============================================================
# EJEMPLO 3: Log de base de datos
# ============================================================
FUNCTION ejemplo_log_database()
    DEFINE v_inicio DATETIME YEAR TO FRACTION(3)
    DEFINE v_fin DATETIME YEAR TO FRACTION(3)
    DEFINE v_tiempo INTEGER
    
    # Simular consulta
    LET v_inicio = CURRENT
    
    # ... consulta aquí ...
    
    LET v_fin = CURRENT
    LET v_tiempo = (v_fin - v_inicio) * 1000
    
    CALL log_database("SELECT", "movimientos",
        "SELECT * FROM movimientos WHERE fecha > '2024-01-01'",
        v_tiempo, 150)
    
END FUNCTION


# ============================================================
# EJEMPLO 4: Log de performance
# ============================================================
FUNCTION ejemplo_log_performance()
    DEFINE v_inicio DATETIME YEAR TO FRACTION(3)
    DEFINE v_fin DATETIME YEAR TO FRACTION(3)
    
    LET v_inicio = CURRENT
    
    # ... función lenta aquí ...
    # Por ejemplo: generar reporte PDF
    
    LET v_fin = CURRENT
    
    CALL log_performance("generar_pdf", v_inicio, v_fin)
    
END FUNCTION


# ============================================================
# EJEMPLO 5: Log de exportación
# ============================================================
FUNCTION ejemplo_log_exportacion()
    
    CALL log_exportacion("CSV", 
        "export/libro_bancos_20241011.csv", 
        150, "EXITOSO")
    
    CALL log_exportacion("PDF",
        "export/reporte_20241011.pdf",
        150, "EXITOSO")
    
    CALL log_exportacion("XML",
        "export/datos_20241011.xml",
        0, "ERROR: Sin datos")
    
END FUNCTION


# ============================================================
# EJEMPLO 6: Log de plantilla
# ============================================================
FUNCTION ejemplo_log_plantilla()
    
    CALL log_plantilla("galicia", 
        "plantillas/galicia_libro.xlsx", "CARGADA")
    
    CALL log_plantilla("nacion",
        "plantillas/nacion_libro.xlsx", "PROCESADA")
    
    CALL log_plantilla("santander",
        "plantillas/santander_libro.xlsx", "ERROR: No encontrada")
    
END FUNCTION


# ============================================================
# EJEMPLO 7: Configurar y usar logs
# ============================================================
FUNCTION ejemplo_configurar_logs()
    
    # Configurar directorio y nivel
    CALL configurar_log("logs", "DEBUG", TRUE)
    
    # Usar logs
    CALL log_debug("app", "Debug habilitado")
    CALL log_info("app", "Aplicación iniciada")
    
    # Deshabilitar logs temporalmente
    LET g_log_enabled = FALSE
    # Este NO se logueará:
    CALL log_info("app", "Este mensaje NO se guardará")
    
    # Habilitar logs
    LET g_log_enabled = TRUE
    CALL log_info("app", "Logs habilitados nuevamente")
    
END FUNCTION


# ============================================================
# EJEMPLO 8: Flujo completo con logs
# ============================================================
FUNCTION ejemplo_flujo_completo()
    DEFINE v_inicio DATETIME YEAR TO FRACTION(3)
    DEFINE v_fin DATETIME YEAR TO FRACTION(3)
    
    LET v_inicio = CURRENT
    
    CALL log_info("flujo", "=== INICIO FLUJO COMPLETO ===")
    
    # 1. Login
    CALL log_usuario("LOGIN", "Usuario: admin")
    
    # 2. Consultar datos
    CALL log_info("flujo", "Consultando datos de Informix...")
    CALL log_database("SELECT", "movimientos",
        "SELECT * FROM movimientos WHERE banco='galicia'",
        150, 1000)
    
    # 3. Cargar plantilla
    CALL log_plantilla("galicia",
        "plantillas/galicia.xlsx", "CARGADA")
    
    # 4. Procesar
    CALL log_info("flujo", "Procesando plantilla...")
    
    # 5. Exportar
    CALL log_exportacion("CSV",
        "export/galicia_2024.csv", 1000, "EXITOSO")
    
    # 6. Performance total
    LET v_fin = CURRENT
    CALL log_performance("flujo_completo", v_inicio, v_fin)
    
    CALL log_info("flujo", "=== FIN FLUJO COMPLETO ===")
    
END FUNCTION
