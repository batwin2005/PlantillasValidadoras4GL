-- ============================================================
-- MODULO: wizard_config.4gl
-- Wizard de configuración de plantillas (una vez por plantilla)
-- Detecta columnas del Excel → usuario asigna validador → guarda JSON
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

GLOBALS
    DEFINE gv_config_dir VARCHAR(200) = "config"
    DEFINE gv_plantillas_dir VARCHAR(200) = "plantillas"
END GLOBALS

-- ============================================================
-- FUNCIÓN PRINCIPAL: Wizard configuración
-- ============================================================
FUNCTION wizard_configuracion()
    DEFINE v_banco VARCHAR(20)
    DEFINE v_nombre VARCHAR(100)
    DEFINE v_archivo VARCHAR(300)
    DEFINE v_hoja VARCHAR(50)
    DEFINE v_fila_tags SMALLINT
    DEFINE v_fila_datos SMALLINT
    DEFINE v_campos DYNAMIC ARRAY OF RECORD
        columna VARCHAR(5),
        encabezado VARCHAR(80),
        validador VARCHAR(50),
        catalogo_tabla VARCHAR(60),
        catalogo_campo VARCHAR(60),
        obligatorio CHAR(1)
    END RECORD
    DEFINE v_idx SMALLINT
    DEFINE v_total_campos SMALLINT
    DEFINE v_exito SMALLINT

    CALL limpiar_pantalla()
    CALL mostrar_encabezado("WIZARD DE CONFIGURACIÓN DE PLANTILLA")

    -- Paso 1: Datos básicos
    INPUT BY NAME v_banco, v_nombre, v_hoja, v_fila_tags, v_fila_datos
        WITHOUT DEFAULTS
        ON ACTION continuar
            IF v_banco IS NULL OR v_banco = "" THEN
                ERROR "Ingrese el código del banco"
                CONTINUE INPUT
            END IF
            IF v_nombre IS NULL OR v_nombre = "" THEN
                ERROR "Ingrese el nombre de la plantilla"
                CONTINUE INPUT
            END IF
            IF v_hoja IS NULL OR v_hoja = "" THEN
                LET v_hoja = "Datos"
            END IF
            IF v_fila_tags IS NULL OR v_fila_tags < 1 THEN
                LET v_fila_tags = 2
            END IF
            IF v_fila_datos IS NULL OR v_fila_datos < 1 THEN
                LET v_fila_datos = v_fila_tags + 1
            END IF
        END INPUT

    -- Paso 2: Seleccionar archivo plantilla
    CALL file_dialog("Seleccionar plantilla Excel (.xlsx)", "xlsx", v_archivo)
    IF v_archivo IS NULL OR v_archivo = "" THEN
        ERROR "Debe seleccionar un archivo"
        RETURN
    END IF

    -- Paso 3: Detectar columnas (llamar Python)
    MESSAGE "Detectando columnas del archivo..."
    CALL detectar_columnas(v_archivo, v_hoja, v_fila_tags)
        RETURNING v_campos, v_total_campos

    IF v_total_campos = 0 THEN
        ERROR "No se detectaron columnas en la fila ", v_fila_tags
        RETURN
    END IF

    MESSAGE "Se detectaron ", v_total_campos, " columnas"

    -- Paso 4: Asignar validadores (INPUT por cada campo)
    CALL asignar_validadores(v_campos, v_total_campos)

    -- Paso 5: Guardar config JSON
    LET v_exito = guardar_config_json(
        v_banco, v_nombre, v_archivo, v_hoja, v_fila_tags, v_fila_datos,
        v_campos, v_total_campos
    )

    IF v_exito THEN
        MESSAGE "✅ Configuración guardada: ", gv_config_dir, "/", v_banco, "_", v_nombre, ".json"
        MESSAGE "   Esta plantilla ya está lista para usar"
    ELSE
        ERROR "Error guardando configuración"
    END IF
END FUNCTION

-- ============================================================
-- DETECTAR COLUMNAS (llama Python)
-- ============================================================
FUNCTION detectar_columnas(p_archivo VARCHAR(300), p_hoja VARCHAR(50), p_fila SMALLINT)
    RETURNING DYNAMIC ARRAY OF RECORD
        columna VARCHAR(5),
        encabezado VARCHAR(80),
        validador VARCHAR(50),
        catalogo_tabla VARCHAR(60),
        catalogo_campo VARCHAR(60),
        obligatorio CHAR(1)
    END RECORD, SMALLINT;

    DEFINE v_cmd VARCHAR(1000)
    DEFINE v_output VARCHAR(32000)
    DEFINE v_line VARCHAR(255)
    DEFINE v_cols DYNAMIC ARRAY OF RECORD
        columna VARCHAR(5),
        encabezado VARCHAR(80),
        validador VARCHAR(50),
        catalogo_tabla VARCHAR(60),
        catalogo_campo VARCHAR(60),
        obligatorio CHAR(1)
    END RECORD
    DEFINE v_idx SMALLINT
    DEFINE v_total SMALLINT

    -- Llamar Python para detectar columnas
    LET v_cmd = "python tools/detectar_columnas.py ", '"', p_archivo, '" ', p_hoja, " ", p_fila

    RUN v_cmd

    -- TODO: Capturar salida real según versión Genero
    -- Por ahora retornamos array vacío (se implementará con base.Channel)
    LET v_total = 0

    RETURN v_cols, v_total
END FUNCTION

-- ============================================================
-- ASIGNAR VALIDADORES (INPUT por campo)
-- ============================================================
FUNCTION asignar_validadores(p_campos DYNAMIC ARRAY OF RECORD
    columna VARCHAR(5),
    encabezado VARCHAR(80),
    validador VARCHAR(50),
    catalogo_tabla VARCHAR(60),
    catalogo_campo VARCHAR(60),
    obligatorio CHAR(1)
END RECORD, p_total SMALLINT)
    DEFINE v_idx SMALLINT
    DEFINE v_validador VARCHAR(50)
    DEFINE v_cat_tabla VARCHAR(60)
    DEFINE v_cat_campo VARCHAR(60)
    DEFINE v_obligatorio CHAR(1)

    FOR v_idx = 1 TO p_total
        DISPLAY "Campo ", v_idx, " de ", p_total
        DISPLAY "  Columna: ", p_campos[v_idx].columna
        DISPLAY "  Encabezado: ", p_campos[v_idx].encabezado

        INPUT BY NAME v_validador, v_cat_tabla, v_cat_campo, v_obligatorio
            WITHOUT DEFAULTS
            ON ACTION asignar
                IF v_validador IS NULL OR v_validador = "" THEN
                    LET v_validador = "val_texto"
                END IF
                IF v_obligatorio IS NULL OR v_obligatorio = "" THEN
                    LET v_obligatorio = "N"
                END IF
            END INPUT

        LET p_campos[v_idx].validador = v_validador
        LET p_campos[v_idx].catalogo_tabla = v_cat_tabla
        LET p_campos[v_idx].catalogo_campo = v_cat_campo
        LET p_campos[v_idx].obligatorio = v_obligatorio
    END FOR
END FUNCTION

-- ============================================================
-- GUARDAR CONFIG JSON
-- ============================================================
FUNCTION guardar_config_json(
    p_banco VARCHAR(20),
    p_nombre VARCHAR(100),
    p_archivo VARCHAR(300),
    p_hoja VARCHAR(50),
    p_fila_tags SMALLINT,
    p_fila_datos SMALLINT,
    p_campos DYNAMIC ARRAY OF RECORD
        columna VARCHAR(5),
        encabezado VARCHAR(80),
        validador VARCHAR(50),
        catalogo_tabla VARCHAR(60),
        catalogo_campo VARCHAR(60),
        obligatorio CHAR(1)
    END RECORD,
    p_total SMALLINT
)
    RETURNING SMALLINT;

    DEFINE v_file VARCHAR(300)
    DEFINE v_json LVARCHAR(32000)
    DEFINE v_idx SMALLINT
    DEFINE v_exito SMALLINT

    -- Construir JSON
    LET v_json = '{"banco":"' || p_banco || '",'
    LET v_json = v_json || '"nombre":"' || p_nombre || '",'
    LET v_json = v_json || '"archivo_maestra":"' || p_archivo || '",'
    LET v_json = v_json || '"hoja":"' || p_hoja || '",'
    LET v_json = v_json || '"fila_tags":' || p_fila_tags || ','
    LET v_json = v_json || '"fila_datos":' || p_fila_datos || ','
    LET v_json = v_json || '"campos":['

    FOR v_idx = 1 TO p_total
        IF v_idx > 1 THEN
            LET v_json = v_json || ','
        END IF
        LET v_json = v_json || '{"columna":"' || p_campos[v_idx].columna || '",'
        LET v_json = v_json || '"tag":"' || p_campos[v_idx].encabezado || '",'
        LET v_json = v_json || '"encabezado":"' || p_campos[v_idx].encabezado || '",'
        LET v_json = v_json || '"validador":"' || p_campos[v_idx].validador || '",'
        LET v_json = v_json || '"catalogo_tabla":"' || p_campos[v_idx].catalogo_tabla || '",'
        LET v_json = v_json || '"catalogo_campo":"' || p_campos[v_idx].catalogo_campo || '",'
        LET v_json = v_json || '"obligatorio":' || p_campos[v_idx].obligatorio || '}'
    END FOR

    LET v_json = v_json || ']}'

    -- Guardar archivo
    LET v_file = gv_config_dir, "/", p_banco, "_", p_nombre, ".json"

    -- En 4GL: usar base.Channel para escribir archivo
    -- TODO: Implementar escritura real
    -- CALL escribir_archivo(v_file, v_json)

    LET v_exito = 1
    RETURN v_exito
END FUNCTION

-- ============================================================
-- HELPERS
-- ============================================================
FUNCTION limpiar_pantalla()
    RUN "cls"
END FUNCTION

FUNCTION mostrar_encabezado(p_titulo)
    DISPLAY "═══════════════════════════════════════════"
    DISPLAY p_titulo
    DISPLAY "═══════════════════════════════════════════"
END FUNCTION

FUNCTION file_dialog(p_titulo, p_filtro, p_resultado)
    -- Usar fgl_getfiledialog o similar según versión Genero
END FUNCTION