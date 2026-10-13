-- ============================================================
-- db/05_sp_validacion.sql
-- Stored Procedures para validación de plantillas
-- Informix 14.10 SPL
-- ============================================================

DATABASE banco;

-- ============================================================
-- SP: Obtener configuración completa de una plantilla
-- Devuelve XML con cfg_plantilla + cfg_campo para Genero 4GL
-- ============================================================
CREATE FUNCTION sp_obtener_config_plantilla(p_plantilla_id INTEGER)
    RETURNING LVARCHAR AS config_xml;
    
    DEFINE v_query LVARCHAR(32000);
    DEFINE v_xml LVARCHAR(32739);
    
    LET v_query = 'SELECT 
        p.plantilla_id, p.banco_codigo, p.nombre, p.descripcion,
        p.archivo_master, p.archivo_maestra, p.hoja_datos, 
        p.fila_inicio, p.fila_datos, p.version, p.estado
    FROM cfg_plantilla p WHERE p.plantilla_id = ' || p_plantilla_id;
    
    EXECUTE FUNCTION genxmlqueryhdr('plantilla', v_query) INTO v_xml;
    
    RETURN v_xml;
END FUNCTION;

-- ============================================================
-- SP: Obtener campos de una plantilla ordenados
-- ============================================================
CREATE FUNCTION sp_obtener_campos_plantilla(p_plantilla_id INTEGER)
    RETURNING LVARCHAR AS campos_xml;
    
    DEFINE v_query LVARCHAR(32000);
    DEFINE v_xml LVARCHAR(32739);
    
    LET v_query = 'SELECT 
        c.campo_id, c.columna_excel, c.nombre_campo, c.tag_excel,
        c.encabezado, c.tabla_bd, c.campo_bd, c.validador,
        c.catalogo_tabla, c.catalogo_campo, c.obligatorio,
        c.orden, c.formato_excel, c.longitud_min, c.longitud_max,
        c.valor_default, c.observaciones
    FROM cfg_campo c 
    WHERE c.plantilla_id = ' || p_plantilla_id || 
    ' ORDER BY c.orden, c.columna_excel';
    
    EXECUTE FUNCTION genxmlqueryhdr('campos', v_query) INTO v_xml;
    
    RETURN v_xml;
END FUNCTION;

-- ============================================================
-- SP: Crear cabecera de validación (inicio de proceso)
-- Retorna resultado_id
-- ============================================================
CREATE FUNCTION sp_iniciar_validacion(
    p_plantilla_id INTEGER,
    p_archivo_origen VARCHAR(300),
    p_usuario VARCHAR(30)
)
    RETURNING INTEGER AS resultado_id;
    
    DEFINE v_resultado_id INTEGER;
    
    INSERT INTO validacion_resultados (
        plantilla_id, archivo_origen, estado, usuario, fecha_validacion
    ) VALUES (
        p_plantilla_id, p_archivo_origen, 'VALIDANDO', p_usuario, CURRENT
    );
    
    SELECT DBINFO('sqlca.sqlerrd1') INTO v_resultado_id FROM systables WHERE tabid=1;
    
    RETURN v_resultado_id;
END FUNCTION;

-- ============================================================
-- SP: Registrar validación de una celda/fila
-- ============================================================
CREATE FUNCTION sp_registrar_validacion(
    p_resultado_id INTEGER,
    p_num_fila INTEGER,
    p_campo_id INTEGER,
    p_nombre_campo VARCHAR(60),
    p_columna_excel VARCHAR(5),
    p_valor_original LVARCHAR(1000),
    p_valor_normalizado LVARCHAR(1000),
    p_estado VARCHAR(10),          -- OK, ERROR, WARNING, DUPLICADO
    p_codigo_error VARCHAR(30),
    p_mensaje LVARCHAR(1000),
    p_accion_sugerida VARCHAR(20)
)
    RETURNING INTEGER AS detalle_id;
    
    DEFINE v_detalle_id INTEGER;
    
    INSERT INTO validacion_detalle (
        resultado_id, num_fila, campo_id, nombre_campo, columna_excel,
        valor_original, valor_normalizado, estado, codigo_error,
        mensaje, accion_sugerida, fecha_validacion
    ) VALUES (
        p_resultado_id, p_num_fila, p_campo_id, p_nombre_campo, p_columna_excel,
        p_valor_original, p_valor_normalizado, p_estado, p_codigo_error,
        p_mensaje, p_accion_sugerida, CURRENT
    );
    
    SELECT DBINFO('sqlca.sqlerrd1') INTO v_detalle_id FROM systables WHERE tabid=1;
    
    RETURN v_detalle_id;
END FUNCTION;

-- ============================================================
-- SP: Finalizar validación (actualizar contadores y estado)
-- ============================================================
CREATE FUNCTION sp_finalizar_validacion(
    p_resultado_id INTEGER,
    p_archivo_errores VARCHAR(300)
)
    RETURNING SMALLINT AS exito;
    
    DEFINE v_total INTEGER;
    DEFINE v_ok INTEGER;
    DEFINE v_err INTEGER;
    DEFINE v_dup INTEGER;
    DEFINE v_estado VARCHAR(20);
    
    -- Contar resultados
    SELECT 
        COUNT(*),
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END),
        SUM(CASE WHEN estado = 'ERROR' THEN 1 ELSE 0 END),
        SUM(CASE WHEN estado = 'DUPLICADO' THEN 1 ELSE 0 END)
    INTO v_total, v_ok, v_err, v_dup
    FROM validacion_detalle
    WHERE resultado_id = p_resultado_id;
    
    -- Determinar estado final
    IF v_err > 0 OR v_dup > 0 THEN
        LET v_estado = 'CON_ERRORES';
    ELSE
        LET v_estado = 'VALIDADO_OK';
    END IF;
    
    -- Actualizar cabecera
    UPDATE validacion_resultados
    SET total_filas = v_total,
        filas_validas = v_ok,
        filas_error = v_err,
        filas_duplicadas = v_dup,
        estado = v_estado,
        archivo_errores = p_archivo_errores,
        fecha_validacion = CURRENT
    WHERE resultado_id = p_resultado_id;
    
    RETURN 1;
END FUNCTION;

-- ============================================================
-- SP: Obtener errores para generar hoja ERRORES en Excel
-- ============================================================
CREATE FUNCTION sp_obtener_errores_export(p_resultado_id INTEGER)
    RETURNING LVARCHAR AS errores_xml;
    
    DEFINE v_query LVARCHAR(32000);
    DEFINE v_xml LVARCHAR(32739);
    
    LET v_query = 'SELECT 
        vd.num_fila, vd.columna_excel, vd.nombre_campo,
        vd.valor_original, vd.valor_normalizado, vd.estado,
        vd.codigo_error, vd.mensaje, vd.accion_sugerida
    FROM validacion_detalle vd
    WHERE vd.resultado_id = ' || p_resultado_id || 
    ' AND vd.estado IN (''ERROR'',''WARNING'',''DUPLICADO'')
    ORDER BY vd.num_fila, vd.campo_id';
    
    EXECUTE FUNCTION genxmlqueryhdr('errores', v_query) INTO v_xml;
    
    RETURN v_xml;
END FUNCTION;

-- ============================================================
-- SP: Obtener datos válidos para exportar/cargar a BD
-- ============================================================
CREATE FUNCTION sp_obtener_datos_validos(p_resultado_id INTEGER)
    RETURNING LVARCHAR AS datos_xml;
    
    DEFINE v_query LVARCHAR(32000);
    DEFINE v_xml LVARCHAR(32739);
    
    -- Pivot: filas → columnas por campo
    -- Genero 4GL hará el pivot en memoria, aquí traemos plano
    LET v_query = 'SELECT 
        vd.num_fila, vd.nombre_campo, vd.valor_normalizado,
        c.tabla_bd, c.campo_bd, c.validador
    FROM validacion_detalle vd
    JOIN cfg_campo c ON c.campo_id = vd.campo_id
    WHERE vd.resultado_id = ' || p_resultado_id || 
    ' AND vd.estado = ''OK''
    ORDER BY vd.num_fila, c.orden';
    
    EXECUTE FUNCTION genxmlqueryhdr('datos_validos', v_query) INTO v_xml;
    
    RETURN v_xml;
END FUNCTION;

-- ============================================================
-- SP: Insertar datos validados en tablas destino (transaccional)
-- ============================================================
CREATE FUNCTION sp_insertar_datos_validados(p_resultado_id INTEGER)
    RETURNING INTEGER AS filas_insertadas;
    
    DEFINE v_filas INTEGER;
    DEFINE v_sql LVARCHAR(32000);
    DEFINE v_tabla VARCHAR(60);
    DEFINE v_campos LVARCHAR(32000);
    DEFINE v_valores LVARCHAR(32000);
    DEFINE v_num_fila INTEGER;
    DEFINE v_done SMALLINT;
    
    -- Cursor para agrupar por tabla_bd y num_fila
    DECLARE cur_tablas CURSOR FOR
        SELECT DISTINCT c.tabla_bd
        FROM validacion_detalle vd
        JOIN cfg_campo c ON c.campo_id = vd.campo_id
        WHERE vd.resultado_id = p_resultado_id 
          AND vd.estado = 'OK'
          AND c.tabla_bd IS NOT NULL;
    
    LET v_filas = 0;
    
    BEGIN WORK;
    
    FOREACH cur_tablas INTO v_tabla
        -- Por cada tabla, agrupar filas
        DECLARE cur_filas CURSOR FOR
            SELECT vd.num_fila
            FROM validacion_detalle vd
            JOIN cfg_campo c ON c.campo_id = vd.campo_id
            WHERE vd.resultado_id = p_resultado_id 
              AND vd.estado = 'OK'
              AND c.tabla_bd = v_tabla
            GROUP BY vd.num_fila
            ORDER BY vd.num_fila;
        
        FOREACH cur_filas INTO v_num_fila
            -- Construir INSERT dinámico para esta fila/tabla
            LET v_campos = "";
            LET v_valores = "";
            
            SELECT LIST(c.campo_bd || ','), 
                   LIST('''' || REPLACE(vd.valor_normalizado, '''', '''''') || ''',')
            INTO v_campos, v_valores
            FROM validacion_detalle vd
            JOIN cfg_campo c ON c.campo_id = vd.campo_id
            WHERE vd.resultado_id = p_resultado_id 
              AND vd.estado = 'OK'
              AND c.tabla_bd = v_tabla
              AND vd.num_fila = v_num_fila;
            
            -- Quitar última coma
            LET v_campos = SUBSTR(v_campos, 1, LENGTH(v_campos) - 1);
            LET v_valores = SUBSTR(v_valores, 1, LENGTH(v_valores) - 1);
            
            LET v_sql = 'INSERT INTO ' || v_tabla || ' (' || v_campos || ') VALUES (' || v_valores || ')';
            
            PREPARE stmt_ins FROM v_sql;
            EXECUTE stmt_ins;
            FREE stmt_ins;
            
            LET v_filas = v_filas + 1;
        END FOREACH;
    END FOREACH;
    
    COMMIT WORK;
    
    -- Actualizar estado a CARGADO_BD
    UPDATE validacion_resultados
    SET estado = 'CARGADO_BD', fecha_validacion = CURRENT
    WHERE resultado_id = p_resultado_id;
    
    RETURN v_filas;
    
EXCEPTION
    WHEN ERROR THEN
        ROLLBACK WORK;
        RETURN -1;
END FUNCTION;

-- ============================================================
-- SP: Validar existencia en catálogo (wrapper para 4GL)
-- ============================================================
CREATE FUNCTION sp_validar_catalogo(
    p_tabla VARCHAR(60),
    p_campo VARCHAR(60),
    p_valor VARCHAR(200)
)
    RETURNING SMALLINT AS existe;
    
    DEFINE v_sql LVARCHAR(32000);
    DEFINE v_count INTEGER;
    
    LET v_sql = 'SELECT COUNT(*) FROM ' || p_tabla || ' WHERE ' || p_campo || ' = ?';
    
    PREPARE stmt_cat FROM v_sql;
    DECLARE cur_cat CURSOR FOR stmt_cat;
    OPEN cur_cat USING p_valor;
    FETCH cur_cat INTO v_count;
    CLOSE cur_cat;
    FREE stmt_cat;
    
    RETURN CASE WHEN v_count > 0 THEN 1 ELSE 0 END;
END FUNCTION;

-- ============================================================
-- SP: Validar UNIQUE en tabla destino
-- ============================================================
CREATE FUNCTION sp_validar_unique_bd(
    p_tabla VARCHAR(60),
    p_campo VARCHAR(60),
    p_valor VARCHAR(200),
    p_excluir_id INTEGER
)
    RETURNING SMALLINT AS es_unico;
    
    DEFINE v_sql LVARCHAR(32000);
    DEFINE v_count INTEGER;
    DEFINE v_id_col VARCHAR(60);
    
    -- Determinar PK según tabla
    IF p_tabla = 'banco_cliente' THEN
        LET v_id_col = 'cliente_id';
    ELIF p_tabla = 'banco_cuenta' THEN
        LET v_id_col = 'cuenta_id';
    ELIF p_tabla = 'banco_movimiento' THEN
        LET v_id_col = 'mov_id';
    ELSE
        LET v_id_col = 'cliente_id';
    END IF;
    
    LET v_sql = 'SELECT COUNT(*) FROM ' || p_tabla || ' WHERE ' || p_campo || ' = ?';
    
    IF p_excluir_id IS NOT NULL THEN
        LET v_sql = v_sql || ' AND ' || v_id_col || ' != ' || p_excluir_id;
    END IF;
    
    PREPARE stmt_uq FROM v_sql;
    DECLARE cur_uq CURSOR FOR stmt_uq;
    OPEN cur_uq USING p_valor;
    FETCH cur_uq INTO v_count;
    CLOSE cur_uq;
    FREE stmt_uq;
    
    RETURN CASE WHEN v_count = 0 THEN 1 ELSE 0 END;
END FUNCTION;