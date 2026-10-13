-- ============================================================
-- MODULO: datos.4gl
-- Acceso a BD: SPs XML, CRUD, consultas
-- Sintaxis 4GL clásica (DATABASE, PREPARE, DECLARE, OPEN, FETCH)
-- ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_usuario VARCHAR(30) = USER
END GLOBALS

-- ============================================================
-- Llamar SP f_query_to_xml_hdr -> XML con cabecera
-- ============================================================
FUNCTION datos_query_to_xml_hdr(p_root VARCHAR(64), p_query LVARCHAR(32000))
    DEFINE v_xml LVARCHAR(32000)
    
    EXECUTE FUNCTION f_query_to_xml_hdr(p_root, p_query) INTO v_xml
    RETURN v_xml
END FUNCTION

-- ============================================================
-- Llamar SP f_query_to_xml (sin cabecera)
-- ============================================================
FUNCTION datos_query_to_xml(p_root VARCHAR(64), p_query LVARCHAR(32000))
    DEFINE v_xml LVARCHAR(32000)
    
    EXECUTE FUNCTION f_query_to_xml(p_root, p_query) INTO v_xml
    RETURN v_xml
END FUNCTION

-- ============================================================
-- Llamar SP f_query_to_xml_pag (paginado)
-- ============================================================
FUNCTION datos_query_to_xml_pag(p_root VARCHAR(64), p_query LVARCHAR(32000), p_skip INT, p_first INT)
    DEFINE v_xml LVARCHAR(32000)
    
    EXECUTE FUNCTION f_query_to_xml_pag(p_root, p_query, p_skip, p_first) INTO v_xml
    RETURN v_xml
END FUNCTION

-- ============================================================
-- Fallback 4GL: construir XML desde cursor (sin SP)
-- Usado cuando no hay genxmlquery disponible
-- ============================================================
FUNCTION datos_build_xml_from_cursor(p_root VARCHAR(64), p_query LVARCHAR(32000))
    DEFINE v_xml VARCHAR(32000)
    DEFINE v_stmt LVARCHAR(32000)
    DEFINE v_row VARCHAR(2000)
    DEFINE v_col_val VARCHAR(255)
    DEFINE v_col_name VARCHAR(64)
    DEFINE v_cols SMALLINT
    DEFINE i SMALLINT
    DEFINE stmt_id INT
    DEFINE cursor_id INT
    
    -- Preparar statement
    LET v_stmt = p_query
    PREPARE stmt_id FROM v_stmt
    IF STATUS <> 0 THEN
        RETURN "<error>Error preparando query</error>"
    END IF
    
    DECLARE cursor_id CURSOR FOR stmt_id
    OPEN cursor_id
    IF STATUS <> 0 THEN
        FREE stmt_id
        RETURN "<error>Error abriendo cursor</error>"
    END IF
    
    -- Obtener metadata de columnas
    -- En 4GL clásico usar DESCRIBE o contar con GET DESCRIPTOR
    -- Simplificación: asumimos columnas conocidas o usar genxmlquery
    
    LET v_xml = "<" || p_root || ">"
    
    WHILE TRUE
        FETCH cursor_id INTO v_col_val  -- Simplificado: una columna
        IF STATUS = 100 THEN EXIT WHILE END IF  -- NOTFOUND
        IF STATUS <> 0 THEN EXIT WHILE END IF
        
        LET v_row = "<row>"
        LET v_row = v_row || "<col>" || xml_escape(v_col_val) || "</col>"
        LET v_row = v_row || "</row>"
        LET v_xml = v_xml || v_row
    END WHILE
    
    CLOSE cursor_id
    FREE cursor_id
    FREE stmt_id
    
    LET v_xml = v_xml || "</" || p_root || ">"
    RETURN v_xml
END FUNCTION

-- ============================================================
-- INSERT cliente desde datos validados
-- ============================================================
FUNCION insert_cliente(p_datos RECORD LIKE banco_cliente.*)
    DEFINE err SMALLINT
    
    BEGIN WORK
        INSERT INTO banco_cliente VALUES (
            0,  -- SERIAL
            p_datos.tipo_doc,
            p_datos.num_doc,
            p_datos.apellidos,
            p_datos.nombres,
            p_datos.genero,
            p_datos.fecha_nac,
            p_datos.anio_emision,
            p_datos.telefono,
            p_datos.celular,
            p_datos.email,
            p_datos.estado_civil,
            p_datos.direccion,
            p_datos.ciudad,
            p_datos.pais,
            p_datos.ocupacion,
            TODAY,
            gv_usuario
        )
        LET err = STATUS
    COMMIT WORK
    
    IF err <> 0 THEN
        ROLLBACK WORK
    END IF
    
    RETURN (err = 0)
END FUNCTION

-- ============================================================
-- INSERT cuenta
-- ============================================================
FUNCTION insert_cuenta(p_cliente_id INT, p_num_cuenta VARCHAR(25), p_tipo_cuenta CHAR(10), p_moneda CHAR(3), p_saldo DECIMAL(16,2))
    DEFINE err SMALLINT
    
    BEGIN WORK
        INSERT INTO banco_cuenta (cliente_id, num_cuenta, tipo_cuenta, moneda, saldo, fecha_apertura, estado)
        VALUES (p_cliente_id, p_num_cuenta, p_tipo_cuenta, p_moneda, p_saldo, TODAY, 'A')
        LET err = STATUS
    COMMIT WORK
    
    IF err <> 0 THEN ROLLBACK WORK END IF
    
    RETURN (err = 0)
END FUNCTION

-- ============================================================
-- Consultar cliente por documento
-- ============================================================
FUNCTION get_cliente_by_doc(p_tipo_doc CHAR(5), p_num_doc VARCHAR(20))
    DEFINE rec RECORD LIKE banco_cliente.*
    
    SELECT * INTO rec.* FROM banco_cliente WHERE tipo_doc = p_tipo_doc AND num_doc = p_num_doc
    IF STATUS = 0 THEN
        RETURN rec
    END IF
    RETURN NULL
END FUNCTION

-- ============================================================
-- Listar clientes (para reportes/export)
-- ============================================================
FUNCTION list_clientes(p_filtro VARCHAR(100))
    DEFINE v_query LVARCHAR(32000)
    
    LET v_query = "SELECT * FROM vw_cliente_cuenta"
    IF LENGTH(TRIM(p_filtro)) > 0 THEN
        LET v_query = v_query || " WHERE " || p_filtro
    END IF
    LET v_query = v_query || " ORDER BY apellidos, nombres"
    
    RETURN datos_query_to_xml_hdr("clientes", v_query)
END FUNCTION

-- ============================================================
-- Ejecutar SP importación XML (placeholder)
-- ============================================================
FUNCTION sp_import_xml(p_xml LVARCHAR(32000))
    EXECUTE PROCEDURE sp_import_xml(p_xml)
    RETURN (STATUS = 0)
END FUNCTION