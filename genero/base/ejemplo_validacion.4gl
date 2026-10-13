# ============================================================
# MODULO: ejemplo_validacion.4gl
# Ejemplo de Uso de Validación Dinámica
# ============================================================

DATABASE banco

# ============================================================
# EJEMPLO 1: VALIDAR IMPORTACIÓN DE CLIENTES
# ============================================================
FUNCTION ejemplo_validar_clientes()
    DEFINE v_query LVARCHAR(32000)
    DEFINE r_resultado RECORD
        archivo_nombre VARCHAR(200),
        query_original LVARCHAR(32000),
        tablas_detectadas DYNAMIC ARRAY OF VARCHAR(64),
        campos_detectados DYNAMIC ARRAY OF VARCHAR(64),
        total_registros INTEGER,
        total_validos INTEGER,
        total_errores INTEGER,
        total_duplicados INTEGER,
        resultados DYNAMIC ARRAY OF RECORD
            num_fila INTEGER,
            campo VARCHAR(64),
            valor_original VARCHAR(200),
            estado VARCHAR(20),
            mensaje VARCHAR(500),
            accion_sugerida VARCHAR(50)
        END RECORD
    END RECORD
    
    -- Datos de ejemplo (simular archivo subido)
    DEFINE arr_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    
    -- Fila 1: Válida
    LET arr_datos[1][1] = "DNI"      -- tipo_doc
    LET arr_datos[1][2] = "12345678" -- num_doc
    LET arr_datos[1][3] = "GARCIA"   -- apellidos
    LET arr_datos[1][4] = "JUAN"     -- nombres
    LET arr_datos[1][5] = "juan@email.com"  -- email
    
    -- Fila 2: Email inválido
    LET arr_datos[2][1] = "DNI"
    LET arr_datos[2][2] = "87654321"
    LET arr_datos[2][3] = "LOPEZ"
    LET arr_datos[2][4] = "MARIA"
    LET arr_datos[2][5] = "maria@@email"  -- ERROR
    
    -- Fila 3: Documento inválido
    LET arr_datos[3][1] = "DNI"
    LET arr_datos[3][2] = "12AB"     -- ERROR
    LET arr_datos[3][3] = "MARTINEZ"
    LET arr_datos[3][4] = "PEDRO"
    LET arr_datos[3][5] = "pedro@email.com"
    
    -- Fila 4: Duplicado (mismo num_doc que fila 1)
    LET arr_datos[4][1] = "DNI"
    LET arr_datos[4][2] = "12345678" -- DUPLICADO
    LET arr_datos[4][3] = "GARCIA"
    LET arr_datos[4][4] = "JUAN PABLO"
    LET arr_datos[4][5] = "otro@email.com"
    
    -- Query dinámico
    LET v_query = "SELECT tipo_doc, num_doc, apellidos, nombres, email FROM banco_cliente"
    
    -- Ejecutar validación
    CALL validar_query_dinamico(v_query, arr_datos)
        RETURNING r_resultado
    
    -- Mostrar resultados
    CALL mostrar_resultados_validacion(r_resultado)
    
END FUNCTION


# ============================================================
# EJEMPLO 2: VALIDAR IMPORTACIÓN DE CUENTAS
# ============================================================
FUNCTION ejemplo_validar_cuentas()
    DEFINE v_query LVARCHAR(32000)
    DEFINE arr_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    
    -- Datos de ejemplo
    -- Fila 1: Cliente no existe
    LET arr_datos[1][1] = "999"        -- cliente_id (no existe)
    LET arr_datos[1][2] = "1234567890" -- num_cuenta
    LET arr_datos[1][3] = "CAJA"       -- tipo_cuenta
    LET arr_datos[1][4] = "ARS"        -- moneda
    LET arr_datos[1][5] = "1500.50"    -- saldo
    
    -- Fila 2: Saldo negativo
    LET arr_datos[2][1] = "001"        -- cliente_id (existe)
    LET arr_datos[2][2] = "0987654321" -- num_cuenta
    LET arr_datos[2][3] = "CAJA"
    LET arr_datos[2][4] = "ARS"
    LET arr_datos[2][5] = "-100"       -- ERROR: negativo
    
    -- Query dinámico
    LET v_query = "SELECT cliente_id, num_cuenta, tipo_cuenta, moneda, saldo FROM banco_cuenta"
    
    -- Validar
    CALL validar_query_dinamico(v_query, arr_datos)
        RETURNING r_resultado
    
    CALL mostrar_resultados_validacion(r_resultado)
    
END FUNCTION


# ============================================================
# EJEMPLO 3: VALIDAR QUERY PERSONALIZADO
# ============================================================
FUNCTION ejemplo_validar_query_personalizado()
    DEFINE v_query LVARCHAR(32000)
    DEFINE arr_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    
    PROMPT "Escriba su query SELECT: " FOR v_query
    
    -- Verificar que sea SELECT
    IF LOWER(TRIM(v_query)) NOT MATCHES "select*" THEN
        ERROR "Solo se permiten queries SELECT"
        RETURN
    END IF
    
    -- Obtener datos (simular o desde archivo)
    CALL cargar_datos_desde_archivo()
        RETURNING arr_datos
    
    -- Validar dinámicamente
    CALL validar_query_dinamico(v_query, arr_datos)
        RETURNING r_resultado
    
    -- Mostrar resultados
    CALL mostrar_resultados_validacion(r_resultado)
    
END FUNCTION


# ============================================================
# EJEMPLO 4: INTEGRACIÓN CON GRID DINÁMICO
# ============================================================
FUNCTION ejemplo_grid_con_validacion()
    DEFINE v_query LVARCHAR(32000)
    DEFINE arr_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE r_resultado RECORD
        total_registros INTEGER,
        total_validos INTEGER,
        total_errores INTEGER,
        total_duplicados INTEGER
    END RECORD
    
    -- Query del usuario
    LET v_query = "SELECT tipo_doc, num_doc, apellidos, nombres FROM banco_cliente"
    
    -- 1. Mostrar datos en grid
    CALL grid_ejecutar_query(v_query, "Vista Previa - Clientes")
    
    -- 2. Preguntar si desea importar
    PROMPT "¿Desea importar estos datos? (S/N): " FOR CHAR(1)
    IF UPPER(ans) != "S" THEN
        RETURN
    END IF
    
    -- 3. Validar antes de importar
    CALL validar_query_dinamico(v_query, arr_datos)
        RETURNING r_resultado
    
    -- 4. Mostrar estadísticas
    DISPLAY "Validación completada:"
    DISPLAY "  Registros: ", r_resultado.total_registros
    DISPLAY "  Válidos: ", r_resultado.total_validos
    DISPLAY "  Errores: ", r_resultado.total_errores
    DISPLAY "  Duplicados: ", r_resultado.total_duplicados
    
    -- 5. Preguntar qué hacer
    IF r_resultado.total_errores > 0 THEN
        MENU "¿Qué desea hacer?"
            COMMAND "Importar solo válidos"
                CALL importar_registros_validos(r_resultado)
            
            COMMAND "Exportar errores"
                CALL exportar_errores_validacion(r_resultado)
            
            COMMAND "Cancelar"
                RETURN
        END MENU
    ELSE
        -- Todo válido, importar directamente
        CALL importar_registros_validos(r_resultado)
    END IF
    
END FUNCTION


# ============================================================
# FUNCIÓN: CARGAR DATOS DESDE ARCHIVO
# ============================================================
FUNCTION cargar_datos_desde_archivo()
    DEFINE arr_datos DYNAMIC ARRAY OF DYNAMIC ARRAY OF VARCHAR(200)
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_file base.Channel
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_fila INTEGER
    DEFINE v_campo INTEGER
    DEFINE v_valor VARCHAR(200)
    
    PROMPT "Ruta del archivo CSV: " FOR v_ruta
    
    LET v_file = base.Channel.create()
    CALL v_file.openFile(v_ruta, "r")
    
    LET v_fila = 0
    
    WHILE TRUE
        LET v_linea = v_file.readline()
        IF v_file.endOfFile() THEN
            EXIT WHILE
        END IF
        
        LET v_fila = v_fila + 1
        
        -- Parsear CSV
        LET v_campo = 1
        WHILE LENGTH(v_linea) > 0
            LET v_valor = extraer_campo_csv(v_linea)
            LET arr_datos[v_fila][v_campo] = v_valor
            LET v_campo = v_campo + 1
        END WHILE
        
    END WHILE
    
    CALL v_file.close()
    
    CALL log_info("ejemplo", 
        "Cargados ", v_fila, " registros desde archivo")
    
    RETURN arr_datos
    
END FUNCTION


FUNCTION extraer_campo_csv(p_linea)
    DEFINE p_linea VARCHAR(32000)
    DEFINE v_pos INTEGER
    DEFINE v_fin INTEGER
    DEFINE v_valor VARCHAR(200)
    
    -- Buscar coma o fin de línea
    LET v_fin = LENGTH(p_linea)
    FOR v_pos = 1 TO LENGTH(p_linea)
        IF p_linea[v_pos] = "," THEN
            LET v_fin = v_pos - 1
            EXIT FOR
        END IF
    END FOR
    
    LET v_valor = p_linea[1, v_fin]
    
    -- Quitar comillas si existen
    IF v_valor[1] = '"' AND v_valor[LENGTH(v_valor)] = '"' THEN
        LET v_valor = v_valor[2, LENGTH(v_valor) - 1]
    END IF
    
    -- Actualizar línea
    IF v_fin < LENGTH(p_linea) THEN
        LET p_linea = p_linea[v_fin + 2, LENGTH(p_linea)]
    ELSE
        LET p_linea = ""
    END IF
    
    RETURN v_valor
    
END FUNCTION
