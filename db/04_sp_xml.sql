DATABASE banco;

-- ============================================================
-- FUNCIONES SPL PARA CONSULTA -> XML (Informix 14.10)
-- Usan genxmlquery / genxmlqueryhdr (requieren idsxmlvp)
-- ============================================================

-- Función simple: cualquier SELECT -> XML (sin cabecera, max 32KB)
CREATE FUNCTION f_query_to_xml(p_root VARCHAR(64), p_query LVARCHAR(32000))
RETURNING LVARCHAR(32739)
DEFINE v_xml LVARCHAR(32739);
    IF UPPER(TRIM(p_query)) NOT LIKE 'SELECT%' THEN
        LET v_xml = '<error>Solo se permiten consultas SELECT</error>';
        RETURN v_xml;
    END IF;
    EXECUTE FUNCTION genxmlquery(p_root, p_query) INTO v_xml;
    RETURN v_xml;
END FUNCTION;

-- Función con cabecera XML (recomendada para exportar)
CREATE FUNCTION f_query_to_xml_hdr(p_root VARCHAR(64), p_query LVARCHAR(32000))
RETURNING LVARCHAR(32739)
DEFINE v_xml LVARCHAR(32739);
    IF UPPER(TRIM(p_query)) NOT LIKE 'SELECT%' THEN
        LET v_xml = '<error>Solo se permiten consultas SELECT</error>';
        RETURN v_xml;
    END IF;
    EXECUTE FUNCTION genxmlqueryhdr(p_root, p_query) INTO v_xml;
    RETURN v_xml;
END FUNCTION;

-- Función paginada para resultados grandes (>32KB)
CREATE FUNCTION f_query_to_xml_pag(p_root VARCHAR(64), p_query LVARCHAR(32000), p_skip INT, p_first INT)
RETURNING LVARCHAR(32739)
DEFINE v_wrapped LVARCHAR(32000);
DEFINE v_xml LVARCHAR(32739);
    IF UPPER(TRIM(p_query)) NOT LIKE 'SELECT%' THEN
        RETURN '<error>Solo se permiten consultas SELECT</error>';
    END IF;
    LET v_wrapped = 'SELECT FIRST ' || p_first || ' SKIP ' || p_skip || ' * FROM (' || TRIM(p_query) || ') AS t_pag';
    EXECUTE FUNCTION genxmlquery(p_root, v_wrapped) INTO v_xml;
    RETURN v_xml;
END FUNCTION;

-- Procedimiento placeholder para importación (parseo real en Genero)
CREATE PROCEDURE sp_import_xml(p_xml LVARCHAR(32000))
    -- Parseo real se hace en Genero (xml_plantilla.4gl)
    -- Aquí solo marca como recibido
    RETURN;
END PROCEDURE;

GRANT EXECUTE ON f_query_to_xml TO PUBLIC;
GRANT EXECUTE ON f_query_to_xml_hdr TO PUBLIC;
GRANT EXECUTE ON f_query_to_xml_pag TO PUBLIC;
GRANT EXECUTE ON sp_import_xml TO PUBLIC;