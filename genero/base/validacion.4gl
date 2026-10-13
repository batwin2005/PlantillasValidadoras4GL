-- ============================================================
-- MODULO: validacion.4gl
-- Funciones de validación bancaria (sintaxis 4GL clásica)
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

GLOBALS
    DEFINE gc_max_long_nombre SMALLINT = 60
    DEFINE gc_max_long_doc SMALLINT = 20
    DEFINE gc_min_anio SMALLINT = 1900
END GLOBALS

-- ============================================================
-- Validar nombre/apellido: solo letras, espacios, apostrofe, guion
-- ============================================================
FUNCTION val_nombre(p_cadena VARCHAR(100))
    DEFINE i SMALLINT
    DEFINE c CHAR(1)
    DEFINE valido SMALLINT
    
    LET valido = TRUE
    IF LENGTH(TRIM(p_cadena)) < 2 OR LENGTH(TRIM(p_cadena)) > gc_max_long_nombre THEN
        RETURN FALSE
    END IF
    
    FOR i = 1 TO LENGTH(p_cadena)
        LET c = SUBSTR(p_cadena, i, 1)
        IF NOT (c MATCHES "[A-Za-zÁÉÍÓÚáéíóúÑñ ]") THEN
            LET valido = FALSE
            EXIT FOR
        END IF
    END FOR
    
    RETURN valido
END FUNCTION

-- ============================================================
-- Validar teléfono/celular: solo dígitos, +, -, (, ), espacios
-- Longitud 7-20
-- ============================================================
FUNCTION val_telefono(p_cadena VARCHAR(30))
    DEFINE i SMALLINT
    DEFINE c CHAR(1)
    DEFINE digitos SMALLINT
    
    IF LENGTH(TRIM(p_cadena)) = 0 THEN
        RETURN TRUE  -- opcional
    END IF
    
    IF LENGTH(p_cadena) < 7 OR LENGTH(p_cadena) > 20 THEN
        RETURN FALSE
    END IF
    
    LET digitos = 0
    FOR i = 1 TO LENGTH(p_cadena)
        LET c = SUBSTR(p_cadena, i, 1)
        IF c MATCHES "[0-9]" THEN
            LET digitos = digitos + 1
        ELSE
            IF NOT c MATCHES "[+()- ]" THEN
                RETURN FALSE
            END IF
        END IF
    END FOR
    
    RETURN (digitos >= 7)
END FUNCTION

-- ============================================================
-- Validar año: entero entre 1900 y año actual
-- ============================================================
FUNCTION val_anio(p_valor VARCHAR(10))
    DEFINE anio INT
    DEFINE anio_actual SMALLINT
    
    IF LENGTH(TRIM(p_valor)) = 0 THEN
        RETURN FALSE
    END IF
    
    LET anio = p_valor
    IF anio IS NULL THEN
        RETURN FALSE
    END IF
    
    -- Obtener año actual
    LET anio_actual = YEAR(TODAY)
    
    RETURN (anio >= gc_min_anio AND anio <= anio_actual)
END FUNCTION

-- ============================================================
-- Validar fecha: formato MM/DD/YYYY, rango válido
-- ============================================================
FUNCTION val_fecha(p_fecha VARCHAR(20))
    DEFINE d DATE
    DEFINE anio_min DATE
    DEFINE anio_max DATE
    
    IF LENGTH(TRIM(p_fecha)) = 0 THEN
        RETURN FALSE
    END IF
    
    -- Intentar convertir (formato MDY para locale en_US)
    LET d = MDY(SUBSTR(p_fecha, 1, 2), SUBSTR(p_fecha, 4, 2), SUBSTR(p_fecha, 7, 4))
    IF d IS NULL THEN
        RETURN FALSE
    END IF
    
    LET anio_min = MDY(1, 1, gc_min_anio)
    LET anio_max = TODAY
    
    RETURN (d >= anio_min AND d <= anio_max)
END FUNCTION

-- ============================================================
-- Validar email: formato basico con @ y dominio
-- ============================================================
FUNCTION val_email(p_email VARCHAR(100))
    DEFINE pos_arroba INT
    DEFINE pos_punto INT
    DEFINE dominio VARCHAR(100)
    
    IF LENGTH(TRIM(p_email)) = 0 THEN
        RETURN TRUE  -- opcional
    END IF
    
    LET pos_arroba = INSTR(p_email, "@")
    IF pos_arroba <= 1 OR pos_arroba = LENGTH(p_email) THEN
        RETURN FALSE
    END IF
    
    LET dominio = SUBSTR(p_email, pos_arroba + 1)
    LET pos_punto = INSTR(dominio, ".")
    IF pos_punto <= 1 OR pos_punto = LENGTH(dominio) THEN
        RETURN FALSE
    END IF
    
    RETURN TRUE
END FUNCTION

-- ============================================================
-- Validar documento: alfanumérico, sin espacios, longitud
-- ============================================================
FUNCTION val_documento(p_doc VARCHAR(30))
    DEFINE i SMALLINT
    DEFINE c CHAR(1)
    
    IF LENGTH(TRIM(p_doc)) < 5 OR LENGTH(TRIM(p_doc)) > gc_max_long_doc THEN
        RETURN FALSE
    END IF
    
    FOR i = 1 TO LENGTH(p_doc)
        LET c = SUBSTR(p_doc, i, 1)
        IF NOT (c MATCHES "[A-Za-z0-9]") THEN
            RETURN FALSE
        END IF
    END FOR
    
    RETURN TRUE
END FUNCTION

-- ============================================================
-- Validar monto: numérico >= 0, max 2 decimales
-- ============================================================
FUNCTION val_monto(p_valor VARCHAR(30))
    DEFINE monto DECIMAL(16,2)
    
    IF LENGTH(TRIM(p_valor)) = 0 THEN
        RETURN FALSE
    END IF
    
    LET monto = p_valor
    IF monto IS NULL THEN
        RETURN FALSE
    END IF
    
    RETURN (monto >= 0)
END FUNCTION

-- ============================================================
-- Validar código de catálogo contra tabla
-- ============================================================
FUNCTION val_catalogo(p_tabla VARCHAR(30), p_campo VARCHAR(30), p_valor VARCHAR(30))
    DEFINE cnt INT
    
    IF LENGTH(TRIM(p_valor)) = 0 THEN
        RETURN FALSE
    END IF
    
    SELECT COUNT(*) INTO cnt FROM TABLE(p_tabla) WHERE p_campo = p_valor
    RETURN (cnt > 0)
END FUNCTION

-- ============================================================
-- Validar registro completo (usado en importación)
-- Retorna: 0=OK, >0=código de error
-- ============================================================
FUNCTION val_registro_completo(
    p_tipo_doc VARCHAR(5),
    p_num_doc VARCHAR(20),
    p_apellidos VARCHAR(60),
    p_nombres VARCHAR(60),
    p_genero CHAR(1),
    p_fecha_nac VARCHAR(20),
    p_anio_emision VARCHAR(10),
    p_telefono VARCHAR(20),
    p_celular VARCHAR(20),
    p_email VARCHAR(100),
    p_estado_civil CHAR(1),
    p_direccion VARCHAR(120),
    p_ciudad CHAR(5)
)
    DEFINE err SMALLINT
    
    IF NOT val_catalogo("cat_tipo_documento", "codigo", p_tipo_doc) THEN RETURN 1 END IF
    IF NOT val_documento(p_num_doc) THEN RETURN 2 END IF
    IF NOT val_nombre(p_apellidos) THEN RETURN 3 END IF
    IF NOT val_nombre(p_nombres) THEN RETURN 4 END IF
    IF NOT val_catalogo("cat_genero", "codigo", p_genero) THEN RETURN 5 END IF
    IF NOT val_fecha(p_fecha_nac) THEN RETURN 6 END IF
    IF NOT val_anio(p_anio_emision) THEN RETURN 7 END IF
    IF NOT val_telefono(p_telefono) THEN RETURN 8 END IF
    IF NOT val_telefono(p_celular) THEN RETURN 9 END IF
    IF NOT val_email(p_email) THEN RETURN 10 END IF
    IF NOT val_catalogo("cat_estado_civil", "codigo", p_estado_civil) THEN RETURN 11 END IF
    IF LENGTH(TRIM(p_direccion)) = 0 THEN RETURN 12 END IF
    IF NOT val_catalogo("cat_ciudad", "codigo", p_ciudad) THEN RETURN 13 END IF
    
    RETURN 0
END FUNCTION

-- ============================================================
-- Mensaje de error legible para código
-- ============================================================
FUNCTION msg_error(p_codigo SMALLINT)
    CASE p_codigo
        WHEN 1  RETURN "Tipo documento inválido"
        WHEN 2  RETURN "Número documento inválido"
        WHEN 3  RETURN "Apellidos inválidos"
        WHEN 4  RETURN "Nombres inválidos"
        WHEN 5  RETURN "Género inválido"
        WHEN 6  RETURN "Fecha nacimiento inválida"
        WHEN 7  RETURN "Año emisión inválido"
        WHEN 8  RETURN "Teléfono inválido"
        WHEN 9  RETURN "Celular inválido"
        WHEN 10 RETURN "Email inválido"
        WHEN 11 RETURN "Estado civil inválido"
        WHEN 12 RETURN "Dirección obligatoria"
        WHEN 13 RETURN "Ciudad inválida"
        OTHERWISE RETURN "Error desconocido"
    END CASE
END FUNCTION