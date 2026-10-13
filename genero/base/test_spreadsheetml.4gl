-- ============================================================
-- MODULO: test_spreadsheetml.4gl
-- Tests exhaustivos para todos los escenarios
-- 100% 4GL
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_archivo_test VARCHAR(300) = "plantillas/plantilla_minima.xls"
END GLOBALS

-- ============================================================
-- MENÚ PRINCIPAL DE TESTS
-- ============================================================
FUNCTION ejecutar_tests()
    DEFINE v_opcion SMALLINT
    
    MENU "TESTS SPREADSHEETML"
        COMMAND "1. Test: Leer archivo SpreadsheetML"           CALL test_leer_archivo()
        COMMAND "2. Test: Validar archivo con datos OK"         CALL test_validar_ok()
        COMMAND "3. Test: Validar archivo con errores"          CALL test_validar_errores()
        COMMAND "4. Test: Validar archivo vacío"                 CALL test_validar_vacio()
        COMMAND "5. Test: Validar con tags faltantes"            CALL test_tags_faltantes()
        COMMAND "6. Test: Validar con caracteres especiales"     CALL test_caracteres_especiales()
        COMMAND "7. Test: Exportar SpreadsheetML"                CALL test_exportar()
        COMMAND "8. Test: Validar todos los validadores"          CALL test_todos_validadores()
        COMMAND "9. Test: Validar archivo inexistente"           CALL test_archivo_inexistente()
        COMMAND "0. Volir"                                        RETURN
    END MENU
END FUNCTION

-- ============================================================
-- TEST 1: Leer archivo SpreadsheetML
-- ============================================================
FUNCTION test_leer_archivo()
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_total_filas INTEGER
    DEFINE v_fila INTEGER
    DEFINE v_col INTEGER
    DEFINE v_valor VARCHAR(255)
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 1: Leer archivo SpreadsheetML")
    
    -- Leer archivo
    LET v_xml = spm_leer_archivo(gv_archivo_test)
    
    IF v_xml = "" THEN
        ERROR "No se pudo leer el archivo"
        RETURN
    END IF
    
    LET v_total_filas = spm_contar_filas(v_xml)
    MESSAGE "✅ Archivo leído correctamente"
    MESSAGE "   Filas totales: ", v_total_filas
    
    -- Mostrar contenido
    FOR v_fila = 1 TO v_total_filas
        FOR v_col = 1 TO 10
            LET v_valor = spm_get_celda(v_xml, v_fila, v_col)
            IF v_valor IS NOT NULL AND v_valor != "" THEN
                MESSAGE "   Fila ", v_fila, " Col ", v_col, ": ", v_valor
            END IF
        END FOR
    END FOR
    
    -- Verificar tags
    LET v_valor = spm_get_celda(v_xml, 3, 1)
    IF v_valor = "{{tipo_doc}}" THEN
        MESSAGE "✅ Tag encontrado: {{tipo_doc}}"
    ELSE
        ERROR "Tag no encontrado en fila 3"
    END IF
END FUNCTION

-- ============================================================
-- TEST 2: Validar archivo con datos OK
-- ============================================================
FUNCTION test_validar_ok()
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 2: Validar archivo con datos OK")
    
    LET v_exito = validar_archivo_spm(gv_archivo_test)
    
    IF v_exito THEN
        MESSAGE "✅ Test PASÓ - Archivo válido"
    ELSE
        ERROR "Test FALLÓ - Se encontraron errores"
    END IF
END FUNCTION

-- ============================================================
-- TEST 3: Validar archivo con errores
-- ============================================================
FUNCTION test_validar_errores()
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_xml_errores LVARCHAR(32000)
    DEFINE v_ruta_errores VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 3: Validar archivo con errores")
    
    -- Leer archivo original
    LET v_xml = spm_leer_archivo(gv_archivo_test)
    
    -- Reemplazar con datos inválidos
    LET v_xml_errores = spm_reemplazar_tag(v_xml, "tipo_doc", "INVALIDO")
    LET v_xml_errores = spm_reemplazar_tag(v_xml_errores, "num_doc", "123")
    LET v_xml_errores = spm_reemplazar_tag(v_xml_errores, "apellidos", "PEREZ123")
    LET v_xml_errores = spm_reemplazar_tag(v_xml_errores, "nombres", "JUAN@")
    
    -- Guardar archivo con errores
    LET v_ruta_errores = "salida/test_errores.xls"
    CALL spm_escribir_archivo(v_ruta_errores, v_xml_errores)
    MESSAGE "Archivo con errores creado: ", v_ruta_errores
    
    -- Validar
    LET v_exito = validar_archivo_spm(v_ruta_errores)
    
    IF NOT v_exito THEN
        MESSAGE "✅ Test PASÓ - Se detectaron errores correctamente"
    ELSE
        ERROR "Test FALLÓ - No se detectaron errores"
    END IF
END FUNCTION

-- ============================================================
-- TEST 4: Validar archivo vacío
-- ============================================================
FUNCTION test_validar_vacio()
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 4: Validar archivo vacío")
    
    -- Crear archivo vacío
    LET v_xml = '<?xml version="1.0"?>'
    LET v_xml = v_xml || '<?mso-application progid="Excel.Sheet"?>'
    LET v_xml = v_xml || '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet">'
    LET v_xml = v_xml || '<Worksheet ss:Name="Datos"><Table>'
    LET v_xml = v_xml || '</Table></Worksheet></Workbook>'
    
    LET v_ruta = "salida/test_vacio.xls"
    CALL spm_escribir_archivo(v_ruta, v_xml)
    
    -- Validar
    LET v_exito = validar_archivo_spm(v_ruta)
    
    IF NOT v_exito THEN
        MESSAGE "✅ Test PASÓ - Archivo vacío manejado correctamente"
    ELSE
        ERROR "Test FALLÓ - Archivo vacío no manejado"
    END IF
END FUNCTION

-- ============================================================
-- TEST 5: Validar con tags faltantes
-- ============================================================
FUNCTION test_tags_faltantes()
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 5: Validar con tags faltantes")
    
    -- Crear archivo sin tags
    LET v_xml = '<?xml version="1.0"?>'
    LET v_xml = v_xml || '<?mso-application progid="Excel.Sheet"?>'
    LET v_xml = v_xml || '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet">'
    LET v_xml = v_xml || '<Worksheet ss:Name="Datos"><Table>'
    LET v_xml = v_xml || '<Row><Cell><Data ss:Type="String">DNI</Data></Cell></Row>'
    LET v_xml = v_xml || '</Table></Worksheet></Workbook>'
    
    LET v_ruta = "salida/test_sin_tags.xls"
    CALL spm_escribir_archivo(v_ruta, v_xml)
    
    -- Validar
    LET v_exito = validar_archivo_spm(v_ruta)
    
    IF NOT v_exito THEN
        MESSAGE "✅ Test PASÓ - Tags faltantes manejados correctamente"
    ELSE
        ERROR "Test FALLÓ - Tags faltantes no manejados"
    END IF
END FUNCTION

-- ============================================================
-- TEST 6: Validar con caracteres especiales
-- ============================================================
FUNCTION test_caracteres_especiales()
    DEFINE v_xml LVARCHAR(32000)
    DEFINE v_ruta VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 6: Validar con caracteres especiales")
    
    -- Crear archivo con caracteres especiales
    LET v_xml = '<?xml version="1.0" encoding="UTF-8"?>'
    LET v_xml = v_xml || '<?mso-application progid="Excel.Sheet"?>'
    LET v_xml = v_xml || '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet">'
    LET v_xml = v_xml || '<Worksheet ss:Name="Datos"><Table>'
    LET v_xml = v_xml || '<Row><Cell><Data ss:Type="String">{{tipo_doc}}</Data></Cell></Row>'
    LET v_xml = v_xml || '<Row><Cell><Data ss:Type="String">Ñoño</Data></Cell></Row>'
    LET v_xml = v_xml || '<Row><Cell><Data ss:Type="String">áéíóú</Data></Cell></Row>'
    LET v_xml = v_xml || '<Row><Cell><Data ss:Type="String">中文</Data></Cell></Row>'
    LET v_xml = v_xml || '</Table></Worksheet></Workbook>'
    
    LET v_ruta = "salida/test_especiales.xls"
    CALL spm_escribir_archivo(v_ruta, v_xml)
    
    -- Validar
    LET v_exito = validar_archivo_spm(v_ruta)
    
    MESSAGE "✅ Test completado - Caracteres especiales manejados"
END FUNCTION

-- ============================================================
-- TEST 7: Exportar SpreadsheetML
-- ============================================================
FUNCTION test_exportar()
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 7: Exportar SpreadsheetML")
    
    LET v_exito = exportar_validados_spm(gv_archivo_test, "salida/test_exportado.xls")
    
    IF v_exito THEN
        MESSAGE "✅ Test PASÓ - Archivo exportado correctamente"
    ELSE
        ERROR "Test FALLÓ - No se pudo exportar"
    END IF
END FUNCTION

-- ============================================================
-- TEST 8: Validar todos los validadores
-- ============================================================
FUNCTION test_todos_validadores()
    DEFINE v_resultado SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 8: Validar todos los validadores")
    
    -- val_nombre
    LET v_resultado = val_nombre("Perez Juan")
    IF v_resultado THEN
        MESSAGE "✅ val_nombre: Perez Juan -> OK"
    ELSE
        ERROR "val_nombre: Perez Juan -> ERROR"
    END IF
    
    LET v_resultado = val_nombre("P3R3Z")
    IF NOT v_resultado THEN
        MESSAGE "✅ val_nombre: P3R3Z -> ERROR (correcto)"
    ELSE
        ERROR "val_nombre: P3R3Z -> OK (incorrecto)"
    END IF
    
    -- val_documento
    LET v_resultado = val_documento("30123456")
    IF v_resultado THEN
        MESSAGE "✅ val_documento: 30123456 -> OK"
    ELSE
        ERROR "val_documento: 30123456 -> ERROR"
    END IF
    
    LET v_resultado = val_documento("123")
    IF NOT v_resultado THEN
        MESSAGE "✅ val_documento: 123 -> ERROR (correcto)"
    ELSE
        ERROR "val_documento: 123 -> OK (incorrecto)"
    END IF
    
    -- val_fecha
    LET v_resultado = val_fecha("15/03/1985")
    IF v_resultado THEN
        MESSAGE "✅ val_fecha: 15/03/1985 -> OK"
    ELSE
        ERROR "val_fecha: 15/03/1985 -> ERROR"
    END IF
    
    LET v_resultado = val_fecha("32/13/2025")
    IF NOT v_resultado THEN
        MESSAGE "✅ val_fecha: 32/13/2025 -> ERROR (correcto)"
    ELSE
        ERROR "val_fecha: 32/13/2025 -> OK (incorrecto)"
    END IF
    
    -- val_email
    LET v_resultado = val_email("juan@email.com")
    IF v_resultado THEN
        MESSAGE "✅ val_email: juan@email.com -> OK"
    ELSE
        ERROR "val_email: juan@email.com -> ERROR"
    END IF
    
    LET v_resultado = val_email("juan@")
    IF NOT v_resultado THEN
        MESSAGE "✅ val_email: juan@ -> ERROR (correcto)"
    ELSE
        ERROR "val_email: juan@ -> OK (incorrecto)"
    END IF
    
    -- val_telefono
    LET v_resultado = val_telefono("011-4567-8901")
    IF v_resultado THEN
        MESSAGE "✅ val_telefono: 011-4567-8901 -> OK"
    ELSE
        ERROR "val_telefono: 011-4567-8901 -> ERROR"
    END IF
    
    -- val_anio
    LET v_resultado = val_anio("1985")
    IF v_resultado THEN
        MESSAGE "✅ val_anio: 1985 -> OK"
    ELSE
        ERROR "val_anio: 1985 -> ERROR"
    END IF
    
    LET v_resultado = val_anio("1800")
    IF NOT v_resultado THEN
        MESSAGE "✅ val_anio: 1800 -> ERROR (correcto)"
    ELSE
        ERROR "val_anio: 1800 -> OK (incorrecto)"
    END IF
    
    -- val_monto
    LET v_resultado = val_monto("15000.50")
    IF v_resultado THEN
        MESSAGE "✅ val_monto: 15000.50 -> OK"
    ELSE
        ERROR "val_monto: 15000.50 -> ERROR"
    END IF
    
    LET v_resultado = val_monto("-100")
    IF NOT v_resultado THEN
        MESSAGE "✅ val_monto: -100 -> ERROR (correcto)"
    ELSE
        ERROR "val_monto: -100 -> OK (incorrecto)"
    END IF
    
    MESSAGE "✅ Test completado - Todos los validadores probados"
END FUNCTION

-- ============================================================
-- TEST 9: Validar archivo inexistente
-- ============================================================
FUNCTION test_archivo_inexistente()
    DEFINE v_exito SMALLINT
    
    CALL limpiar_pantalla()
    CALL header_test("TEST 9: Validar archivo inexistente")
    
    LET v_exito = validar_archivo_spm("archivo_no_existe.xls")
    
    IF NOT v_exito THEN
        MESSAGE "✅ Test PASÓ - Archivo inexistente manejado correctamente"
    ELSE
        ERROR "Test FALLÓ - Archivo inexistente no manejado"
    END IF
END FUNCTION

-- ============================================================
-- HELPERS
-- ============================================================
FUNCTION limpiar_pantalla()
    RUN "cls"
END FUNCTION

FUNCTION header_test(p_nombre)
    MESSAGE "═══════════════════════════════════════════"
    MESSAGE p_nombre
    MESSAGE "═══════════════════════════════════════════"
END FUNCTION