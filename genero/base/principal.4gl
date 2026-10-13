-- ============================================================
-- MODULO: principal.4gl
-- Programa principal - Menú de entrada
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

DATABASE banco

GLOBALS
    DEFINE gv_usuario VARCHAR(30) = USER
END GLOBALS

MAIN
    DEFINE opcion SMALLINT
    DEFINE continuar SMALLINT
    
    -- Inicializar entorno
    CALL inicializar_entorno()
    
    -- Conectar BD
    DATABASE banco
    IF SQLCA.SQLCODE < 0 THEN
        ERROR "Error conectando a BD: ", SQLCA.SQLCODE
        EXIT PROGRAM 1
    END IF
    
    -- Verificar SPs XML
    CALL verificar_sps_xml()
    
    -- Configurar logs
    CALL configurar_log("logs", "INFO", TRUE)
    CALL log_info("principal", "Aplicación iniciada - Usuario: " || gv_usuario)
    
    LET continuar = TRUE
    
    WHILE continuar
        CALL limpiar_pantalla()
        CALL mostrar_banner()
        
        MENU "PRINCIPAL"
            COMMAND "1. Validador de Plantillas"     CALL menu_validacion_principal()
            COMMAND "2. Gestión de Bancos"           CALL menu_gestion_bancos()
            COMMAND "3. Consultas y Reportes"        CALL menu_consultas()
            COMMAND "4. Ver Logs"                    CALL menu_logs()
            COMMAND "5. Utilidades"                  CALL menu_utilidades()
            COMMAND "0. Salir"                       LET continuar = FALSE
        END MENU
    END WHILE
    
    CALL log_info("principal", "Aplicación finalizada")
    CLOSE DATABASE
END MAIN

-- ============================================================
-- FUNCIONES DE INICIALIZACIÓN
-- ============================================================
FUNCTION inicializar_entorno()
    -- Verificar directorios necesarios
    RUN "if not exist plantillas_base mkdir plantillas_base"
    RUN "if not exist plantillas_maestras mkdir plantillas_maestras"
    RUN "if not exist plantillas_datos mkdir plantillas_datos"
    RUN "if not exist plantillas_procesadas mkdir plantillas_procesadas"
    RUN "if not exist plantillas_errores mkdir plantillas_errores"
    RUN "if not exist salida mkdir salida"
    RUN "if not exist logs mkdir logs"
END FUNCTION

FUNCTION verificar_sps_xml()
    DEFINE v_test LVARCHAR(1000)
    
    -- Test genxmlqueryhdr
    SELECT genxmlqueryhdr('test', 'SELECT 1 AS col FROM systables WHERE tabid=1') 
    INTO v_test FROM systables WHERE tabid=1;
    
    IF v_test IS NULL THEN
        ERROR "SP genxmlqueryhdr no disponible. Verificar idsxmlvp."
    END IF
END FUNCTION

FUNCTION mostrar_banner()
    DISPLAY "╔═══════════════════════════════════════════════════════════════╗"
    DISPLAY "║          PLANTILLAS VALIDADORAS 4GL v1.0                    ║"
    DISPLAY "║     Importar • Validar • Exportar datos bancarios           ║"
    DISPLAY "║     Informix 14.10  |  Genero BDL 1.x/2.x/3.x              ║"
    DISPLAY "╠═══════════════════════════════════════════════════════════════╣"
    DISPLAY "║  Usuario: ", gv_usuario CLIPPED, "                                        ║"
    DISPLAY "║  BD: banco  |  Fecha: ", TODAY, "                              ║"
    DISPLAY "╚═══════════════════════════════════════════════════════════════╝"
END FUNCTION

FUNCTION limpiar_pantalla()
    -- En Genero: CLEAR SCREEN o CALL fgl_clearscr()
    -- Para compatibilidad usamos RUN
    RUN "cls"
END FUNCTION

-- ============================================================
-- MENÚS SECUNDARIOS (Stubs - implementar después)
-- ============================================================
FUNCTION menu_gestion_bancos()
    MENU "GESTIÓN BANCOS"
        COMMAND "1. Listar Bancos"           CALL listar_bancos()
        COMMAND "2. Registrar Nuevo Banco"   CALL registrar_banco_ui()
        COMMAND "3. Ver Plantillas Banco"    CALL ver_plantillas_banco()
        COMMAND "0. Volver"                  RETURN
    END MENU
END FUNCTION

FUNCTION menu_consultas()
    MENU "CONSULTAS Y REPORTES"
        COMMAND "1. Consulta Libre SQL → XML"    CALL consulta_libre_xml()
        COMMAND "2. Reporte Movimientos"         CALL reporte_movimientos()
        COMMAND "3. Reporte Clientes"            CALL reporte_clientes()
        COMMAND "0. Volver"                      RETURN
    END MENU
END FUNCTION

FUNCTION menu_logs()
    MENU "LOGS DEL SISTEMA"
        COMMAND "1. Ver Log General (hoy)"       CALL ver_log("app")
        COMMAND "2. Ver Log Errores (hoy)"       CALL ver_log("errores")
        COMMAND "3. Ver Log Usuarios (hoy)"      CALL ver_log("usuarios")
        COMMAND "4. Ver Log Exportaciones"       CALL ver_log("export")
        COMMAND "0. Volver"                      RETURN
    END MENU
END FUNCTION

FUNCTION menu_utilidades()
    MENU "UTILIDADES"
        COMMAND "1. Generar Plantilla Ejemplo"   CALL generar_plantilla_ejemplo()
        COMMAND "2. Verificar Entorno"           CALL check_entorno()
        COMMAND "3. Limpiar Archivos Temporales" CALL limpiar_temp()
        COMMAND "0. Volver"                      RETURN
    END MENU
END FUNCTION

-- ============================================================
-- STUBS PARA FUNCIONES NO IMPLEMENTADAS
-- ============================================================
FUNCTION listar_bancos()
    MESSAGE "Pendiente: listar_bancos desde registro_bancos.py"
END FUNCTION

FUNCTION registrar_banco_ui()
    MESSAGE "Pendiente: registrar_banco_ui"
END FUNCTION

FUNCTION ver_plantillas_banco()
    MESSAGE "Pendiente: ver_plantillas_banco"
END FUNCTION

FUNCTION consulta_libre_xml()
    MESSAGE "Pendiente: consulta_libre_xml (usar f_query_to_xml_hdr)"
END FUNCTION

FUNCTION reporte_movimientos()
    MESSAGE "Pendiente: reporte_movimientos"
END FUNCTION

FUNCTION reporte_clientes()
    MESSAGE "Pendiente: reporte_clientes"
END FUNCTION

FUNCTION ver_log(p_tipo)
    MESSAGE "Pendiente: ver_log ", p_tipo
END FUNCTION

FUNCTION generar_plantilla_ejemplo()
    MESSAGE "Pendiente: generar_plantilla_ejemplo (python)"
END FUNCTION

FUNCTION check_entorno()
    MESSAGE "Pendiente: check_entorno"
END FUNCTION

FUNCTION limpiar_temp()
    MESSAGE "Pendiente: limpiar_temp"
END FUNCTION