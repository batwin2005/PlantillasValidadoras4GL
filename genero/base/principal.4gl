-- ============================================================
-- MODULO: principal.4gl
-- Programa principal - Menú simplificado 100% 4GL
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_usuario VARCHAR(30) = USER
END GLOBALS

MAIN
    DEFINE continuar SMALLINT
    
    CALL inicializar_entorno()
    
    DATABASE banco
    IF SQLCA.SQLCODE < 0 THEN
        ERROR "Error conectando a BD: ", SQLCA.SQLCODE
        EXIT PROGRAM 1
    END IF
    
    CALL verificar_sps_xml()
    CALL log_info("principal", "Aplicación iniciada - Usuario: " || gv_usuario)
    
    LET continuar = TRUE
    
    WHILE continuar
        CALL limpiar_pantalla()
        CALL mostrar_banner()
        
        MENU "PRINCIPAL"
            COMMAND "1. Validar Archivo SpreadsheetML"  CALL validar_archivo_menu()
            COMMAND "2. Ver Datos de Archivo"           CALL ver_datos_menu()
            COMMAND "3. Exportar Datos Validados"       CALL exportar_menu()
            COMMAND "4. Ejecutar Tests"                 CALL ejecutar_tests()
            COMMAND "5. Verificar Entorno"              CALL check_entorno()
            COMMAND "0. Salir"                          LET continuar = FALSE
        END MENU
    END WHILE
    
    CALL log_info("principal", "Aplicación finalizada")
    CLOSE DATABASE
END MAIN

-- ============================================================
-- MENÚ 1: Validar archivo
-- ============================================================
FUNCTION validar_archivo_menu()
    DEFINE v_archivo VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    INPUT BY NAME v_archivo WITHOUT DEFAULTS
        ON ACTION examinar
            CALL file_dialog("Seleccionar archivo SpreadsheetML (.xls)", "xls", v_archivo)
            DISPLAY v_archivo TO archivo
        ON ACTION validar
            IF v_archivo IS NULL OR v_archivo = "" THEN
                ERROR "Seleccione un archivo"
                CONTINUE INPUT
            END IF
            
            LET v_exito = validar_archivo_spm(v_archivo)
            
            IF v_exito THEN
                MESSAGE "✅ Validación exitosa - todos los datos son válidos"
            ELSE
                ERROR "⚠️ Hay errores en los datos - revise el archivo"
            END IF
            EXIT INPUT
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
END FUNCTION

-- ============================================================
-- MENÚ 2: Ver datos
-- ============================================================
FUNCTION ver_datos_menu()
    DEFINE v_archivo VARCHAR(300)
    
    INPUT BY NAME v_archivo WITHOUT DEFAULTS
        ON ACTION examinar
            CALL file_dialog("Seleccionar archivo SpreadsheetML (.xls)", "xls", v_archivo)
            DISPLAY v_archivo TO archivo
        ON ACTION ver
            IF v_archivo IS NULL OR v_archivo = "" THEN
                ERROR "Seleccione un archivo"
                CONTINUE INPUT
            END IF
            CALL mostrar_datos_spm(v_archivo)
            EXIT INPUT
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
END FUNCTION

-- ============================================================
-- MENÚ 3: Exportar
-- ============================================================
FUNCTION exportar_menu()
    DEFINE v_origen VARCHAR(300)
    DEFINE v_destino VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    INPUT BY NAME v_origen, v_destino WITHOUT DEFAULTS
        ON ACTION examinar_origen
            CALL file_dialog("Seleccionar archivo origen (.xls)", "xls", v_origen)
            DISPLAY v_origen TO archivo_origen
        ON ACTION examinar_destino
            CALL file_save_dialog("Guardar exportación", "xls", v_destino)
            DISPLAY v_destino TO archivo_destino
        ON ACTION exportar
            IF v_origen IS NULL OR v_origen = "" THEN
                ERROR "Seleccione archivo origen"
                CONTINUE INPUT
            END IF
            IF v_destino IS NULL OR v_destino = "" THEN
                ERROR "Seleccione destino"
                CONTINUE INPUT
            END IF
            
            LET v_exito = exportar_validados_spm(v_origen, v_destino)
            IF v_exito THEN
                MESSAGE "✅ Exportado: ", v_destino
            ELSE
                ERROR "Error exportando"
            END IF
            EXIT INPUT
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
END FUNCTION

-- ============================================================
-- INICIALIZACIÓN
-- ============================================================
FUNCTION inicializar_entorno()
    RUN "if not exist plantillas mkdir plantillas"
    RUN "if not exist salida mkdir salida"
    RUN "if not exist logs mkdir logs"
END FUNCTION

FUNCTION verificar_sps_xml()
    DEFINE v_test LVARCHAR(1000)
    SELECT genxmlqueryhdr('test', 'SELECT 1 AS col FROM systables WHERE tabid=1') 
    INTO v_test FROM systables WHERE tabid=1;
    IF v_test IS NULL THEN
        ERROR "SP genxmlqueryhdr no disponible"
    END IF
END FUNCTION

FUNCTION mostrar_banner()
    DISPLAY "╔═══════════════════════════════════════════════════════════════╗"
    DISPLAY "║          PLANTILLAS VALIDADORAS 4GL v2.0 (100% 4GL)         ║"
    DISPLAY "║     SpreadsheetML • Validación • Exportar                  ║"
    DISPLAY "║     Informix 14.10  |  Genero BDL 1.x/2.x/3.x              ║"
    DISPLAY "╠═══════════════════════════════════════════════════════════════╣"
    DISPLAY "║  Usuario: ", gv_usuario CLIPPED, "                                        ║"
    DISPLAY "║  BD: banco  |  Fecha: ", TODAY, "                              ║"
    DISPLAY "╚═══════════════════════════════════════════════════════════════╝"
END FUNCTION

FUNCTION limpiar_pantalla()
    RUN "cls"
END FUNCTION

-- ============================================================
-- UTILIDADES
-- ============================================================
FUNCTION file_dialog(p_titulo, p_filtro, p_resultado)
    DEFINE p_titulo VARCHAR(100)
    DEFINE p_filtro VARCHAR(50)
    DEFINE p_resultado VARCHAR(300)
    
    PROMPT p_titulo || " (" || p_filtro || "): " FOR p_resultado
END FUNCTION

FUNCTION file_save_dialog(p_titulo, p_ext, p_resultado)
    DEFINE p_titulo VARCHAR(100)
    DEFINE p_ext VARCHAR(10)
    DEFINE p_resultado VARCHAR(300)
    
    PROMPT p_titulo || " (." || p_ext || "): " FOR p_resultado
END FUNCTION

FUNCTION check_entorno()
    MESSAGE "Pendiente: check_entorno"
END FUNCTION