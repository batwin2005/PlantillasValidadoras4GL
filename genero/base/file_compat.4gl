-- ============================================================
-- MODULO: file_compat.4gl
-- Compatibilidad de archivos para Genero 1.x / 2.x / 3.x
-- Usa funciones estándar que funcionan en todas las versiones
-- ============================================================

-- ============================================================
-- LEER ARCHIVO (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION fc_leer_archivo(p_ruta VARCHAR(300))
    RETURNING LVARCHAR;
    
    DEFINE v_file TEXT
    DEFINE v_linea VARCHAR(32000)
    DEFINE v_contenido LVARCHAR(32000)
    
    LET v_contenido = ""
    
    -- Método estándar: OPEN INPUT / READ / CLOSE
    OPEN v_file FOR INPUT
    IF STATUS < 0 THEN
        RETURN ""
    END IF
    
    WHILE TRUE
        READ v_file INTO v_linea
        IF STATUS <> 0 THEN EXIT WHILE END IF
        LET v_contenido = v_contenido || v_linea
    END WHILE
    
    CLOSE v_file
    RETURN v_contenido
END FUNCTION

-- ============================================================
-- ESCRIBIR ARCHIVO (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION fc_escribir_archivo(p_ruta VARCHAR(300), p_contenido LVARCHAR(32000))
    RETURNING SMALLINT;
    
    DEFINE v_file TEXT
    
    OPEN v_file FOR OUTPUT
    IF STATUS < 0 THEN
        RETURN FALSE
    END IF
    
    PUT v_file, p_contenido
    IF STATUS <> 0 THEN
        CLOSE v_file
        RETURN FALSE
    END IF
    
    CLOSE v_file
    RETURN TRUE
END FUNCTION

-- ============================================================
-- COPIAR ARCHIVO (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION fc_copiar_archivo(p_origen VARCHAR(300), p_destino VARCHAR(300))
    RETURNING SMALLINT;
    
    RUN "copy /Y ", p_origen, " ", p_destino
    
    RETURN (STATUS = 0)
END FUNCTION

-- ============================================================
-- ARCHIVO EXISTE (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION fc_archivo_existe(p_ruta VARCHAR(300))
    RETURNING SMALLINT;
    
    RUN "if exist ", p_ruta, " (exit 0) else (exit 1)"
    
    RETURN (STATUS = 0)
END FUNCTION

-- ============================================================
-- CREAR DIRECTORIO (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION fc_crear_directorio(p_dir VARCHAR(200))
    RUN "if not exist ", p_dir, " mkdir ", p_dir
END FUNCTION

-- ============================================================
-- EJECUTAR COMANDO (compatible 1.x/2.x/3.x)
-- ============================================================
FUNCTION fc_ejecutar(p_cmd VARCHAR(500))
    RETURNING SMALLINT;
    
    RUN p_cmd
    RETURN (STATUS = 0)
END FUNCTION

-- ============================================================
-- OBTENER RUTA ARCHIVO (compatible 1.x/2.x/3.x)
-- Usa fgl_getfiledialog si está disponible
-- ============================================================
FUNCTION fc_seleccionar_archivo(p_titulo VARCHAR(100), p_filtro VARCHAR(50))
    RETURNING VARCHAR(300);
    
    DEFINE v_ruta VARCHAR(300)
    
    -- Compatible 1.x/2.x/3.x: INPUT simple
    -- En 2.x/3.x se puede reemplazar por fgl_getfiledialog
    PROMPT p_titulo || " (" || p_filtro || "): " FOR v_ruta
    
    RETURN v_ruta
END FUNCTION