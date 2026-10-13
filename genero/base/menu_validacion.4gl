-- ============================================================
-- MODULO: menu_validacion.4gl
-- Menú principal del validador de plantillas
-- Compatible: Genero BDL 1.x / 2.x / 3.x
-- ============================================================

GLOBALS
    DEFINE gv_plantilla_id INTEGER
    DEFINE gv_banco_codigo VARCHAR(20)
    DEFINE gv_banco_nombre VARCHAR(100)
    DEFINE gv_plantilla_nombre VARCHAR(100)
    DEFINE gv_archivo_maestra VARCHAR(300)
    DEFINE gv_archivo_datos VARCHAR(300)
    DEFINE gv_resultado_id INTEGER
    DEFINE gv_usuario VARCHAR(30) = USER
END GLOBALS

-- ============================================================
-- FUNCIÓN PRINCIPAL: Menú validador
-- ============================================================
FUNCTION menu_validacion_principal()
    DEFINE opcion SMALLINT
    DEFINE continuar SMALLINT
    
    LET continuar = TRUE
    
    WHILE continuar
        CALL limpiar_pantalla()
        CALL mostrar_encabezado("MENÚ VALIDADOR DE PLANTILLAS")
        
        MENU "VALIDADOR"
            COMMAND "1. Seleccionar Banco/Plantilla"    CALL opcion_seleccionar_banco()
            COMMAND "2. Cargar Plantilla Master (XLS/XLSX)" CALL opcion_cargar_master()
            COMMAND "3. Descargar Plantilla con Tags"   CALL opcion_descargar_tags()
            COMMAND "4. Cargar y Validar Datos"         CALL opcion_validar_datos()
            COMMAND "5. Exportar Resultados"            CALL opcion_exportar()
            COMMAND "0. Volver"                         LET continuar = FALSE
        END MENU
    END WHILE
END FUNCTION

-- ============================================================
-- OPCIÓN 1: Seleccionar Banco / Plantilla
-- ============================================================
FUNCTION opcion_seleccionar_banco()
    DEFINE v_bancos DYNAMIC ARRAY OF RECORD
        codigo VARCHAR(20),
        nombre VARCHAR(100),
        plantillas DYNAMIC ARRAY OF RECORD
            plantilla_id INTEGER,
            nombre VARCHAR(100),
            archivo_maestra VARCHAR(300),
            estado CHAR(1)
        END RECORD
    END RECORD
    DEFINE v_idx_banco SMALLINT
    DEFINE v_idx_plant SMALLINT
    DEFINE v_seleccionado SMALLINT
    
    -- Cargar bancos activos con sus plantillas
    CALL cargar_bancos_con_plantillas(v_bancos)
    
    IF v_bancos.getLength() = 0 THEN
        ERROR "No hay bancos con plantillas configuradas"
        RETURN
    END IF
    
    -- Mostrar lista para selección
    OPEN WINDOW w_bancos WITH FORM "banco_sel"
    DISPLAY "Seleccione Banco y Plantilla:" TO titulo
    
    -- Llenar array para CONSTRUCT
    -- (Simplificado: usamos DISPLAY ARRAY con INPUT)
    FOREACH v_bancos INTO v_idx_banco
        DISPLAY v_bancos[v_idx_banco].codigo, v_bancos[v_idx_banco].nombre TO banco_lista.*
    END FOREACH
    
    -- INPUT para selección
    INPUT BY NAME v_idx_banco, v_idx_plant FROM banco_sel.*
        ON ACTION seleccionar
            IF v_idx_banco > 0 AND v_idx_plant > 0 THEN
                LET gv_banco_codigo = v_bancos[v_idx_banco].codigo
                LET gv_banco_nombre = v_bancos[v_idx_banco].nombre
                LET gv_plantilla_id = v_bancos[v_idx_banco].plantillas[v_idx_plant].plantilla_id
                LET gv_plantilla_nombre = v_bancos[v_idx_banco].plantillas[v_idx_plant].nombre
                LET gv_archivo_maestra = v_bancos[v_idx_banco].plantillas[v_idx_plant].archivo_maestra
                MESSAGE "✅ Seleccionado: ", gv_banco_nombre, " - ", gv_plantilla_nombre
                EXIT INPUT
            END IF
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
    
    CLOSE WINDOW w_bancos
END FUNCTION

-- ============================================================
-- OPCIÓN 2: Cargar Plantilla Master (XLS/XLSX sin tags)
-- Genera maestra con tags automáticos
-- ============================================================
FUNCTION opcion_cargar_master()
    DEFINE v_archivo VARCHAR(300)
    DEFINE v_nombre VARCHAR(100)
    DEFINE v_ruta_master VARCHAR(300)
    DEFINE v_ruta_maestra VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    IF gv_plantilla_id = 0 THEN
        ERROR "Primero seleccione un banco/plantilla (Opción 1)"
        RETURN
    END IF
    
    -- Pedir archivo master
    OPEN WINDOW w_master WITH FORM "master_carga"
    DISPLAY "Cargar Plantilla Master (sin tags)" TO titulo
    DISPLAY "Banco: ", gv_banco_nombre TO lbl_banco
    DISPLAY "Plantilla actual: ", gv_plantilla_nombre TO lbl_plantilla
    
    INPUT BY NAME v_archivo FROM master_carga.*
        ON ACTION examinar
            CALL file_dialog("Seleccionar Master (.xls/.xlsx)", "xlsx,xls", v_archivo)
            DISPLAY v_archivo TO archivo_master
        ON ACTION procesar
            IF v_archivo IS NULL OR v_archivo = "" THEN
                ERROR "Seleccione un archivo master"
                CONTINUE INPUT
            END IF
            
            -- Pedir nombre para la plantilla
            CALL input_string("Nombre plantilla:", gv_plantilla_nombre, v_nombre)
            IF v_nombre IS NULL OR v_nombre = "" THEN
                CONTINUE INPUT
            END IF
            
            -- Generar rutas
            LET v_ruta_master = "plantillas_base/", v_nombre, "_master.xlsx"
            LET v_ruta_maestra = "plantillas_maestras/maestra_", v_nombre, ".xlsx"
            
            -- Copiar master a plantillas_base
            CALL copiar_archivo(v_archivo, v_ruta_master)
            
            -- LLAMAR PYTHON: auto_tag_master.py
            MESSAGE "Generando plantilla maestra con tags..."
            LET v_exito = CALL python_auto_tag(v_ruta_master, v_ruta_maestra, gv_banco_codigo, v_nombre)
            
            IF v_exito THEN
                -- Guardar en BD cfg_plantilla + cfg_campo
                CALL sp_guardar_config_plantilla(gv_banco_codigo, v_nombre, v_ruta_master, v_ruta_maestra)
                    RETURNING gv_plantilla_id
                
                LET gv_archivo_maestra = v_ruta_maestra
                MESSAGE "✅ Plantilla maestra creada: ", gv_archivo_maestra
                MESSAGE "   Tags generados automáticamente desde encabezados"
                MESSAGE "   Validaciones Excel nativas aplicadas"
            ELSE
                ERROR "Error generando plantilla maestra"
            END IF
            EXIT INPUT
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
    
    CLOSE WINDOW w_master
END FUNCTION

-- ============================================================
-- OPCIÓN 3: Descargar Plantilla con Tags (para que usuario llene)
-- ============================================================
FUNCTION opcion_descargar_tags()
    DEFINE v_destino VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    IF gv_plantilla_id = 0 THEN
        ERROR "Primero seleccione un banco/plantilla (Opción 1)"
        RETURN
    END IF
    
    IF gv_archivo_maestra IS NULL OR gv_archivo_maestra = "" THEN
        ERROR "No hay plantilla maestra generada. Use Opción 2 primero."
        RETURN
    END IF
    
    OPEN WINDOW w_descargar WITH FORM "descargar_tags"
    DISPLAY "Descargar Plantilla con Tags" TO titulo
    DISPLAY "Archivo origen: ", gv_archivo_maestra TO lbl_origen
    
    INPUT BY NAME v_destino FROM descargar_tags.*
        ON ACTION examinar
            CALL file_save_dialog("Guardar plantilla para llenar", "xlsx", v_destino)
            DISPLAY v_destino TO archivo_destino
        ON ACTION descargar
            IF v_destino IS NULL OR v_destino = "" THEN
                ERROR "Seleccione destino"
                CONTINUE INPUT
            END IF
            
            -- Copiar maestra a destino (usuario la llenará)
            CALL copiar_archivo(gv_archivo_maestra, v_destino)
            
            MESSAGE "✅ Plantilla lista para llenar: ", v_destino
            MESSAGE "   Contiene tags {{campo}} en fila 2"
            MESSAGE "   Validaciones: listas, fechas, rangos, formatos"
            MESSAGE "   Hoja 'Listas' con catálogos para dropdowns"
            MESSAGE "   Llene datos desde fila 3 en adelante"
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
    
    CLOSE WINDOW w_descargar
END FUNCTION

-- ============================================================
-- OPCIÓN 4: Cargar y Validar Datos (CORE DEL SISTEMA)
-- ============================================================
FUNCTION opcion_validar_datos()
    DEFINE v_archivo VARCHAR(300)
    DEFINE v_exito SMALLINT
    DEFINE v_total_filas INTEGER
    DEFINE v_filas_ok INTEGER
    DEFINE v_filas_error INTEGER
    
    IF gv_plantilla_id = 0 THEN
        ERROR "Primero seleccione un banco/plantilla (Opción 1)"
        RETURN
    END IF
    
    OPEN WINDOW w_validar WITH FORM "validar_datos"
    DISPLAY "Cargar y Validar Datos" TO titulo
    DISPLAY "Plantilla: ", gv_plantilla_nombre TO lbl_plantilla
    DISPLAY "Maestra: ", gv_archivo_maestra TO lbl_maestra
    
    INPUT BY NAME v_archivo FROM validar_datos.*
        ON ACTION examinar
            CALL file_dialog("Seleccionar archivo con datos (.xlsx)", "xlsx", v_archivo)
            DISPLAY v_archivo TO archivo_datos
        ON ACTION validar
            IF v_archivo IS NULL OR v_archivo = "" THEN
                ERROR "Seleccione archivo con datos"
                CONTINUE INPUT
            END IF
            
            MESSAGE "Validando archivo... (doble validación: Excel + 4GL)"
            
            -- 1. Iniciar validación en BD
            CALL sp_iniciar_validacion(gv_plantilla_id, v_archivo, gv_usuario)
                RETURNING gv_resultado_id
            
            -- 2. VALIDACIÓN CAPA 1: Validaciones nativas Excel (openpyxl)
            -- Se hace via Python tool que retorna errores de Excel
            LET v_exito = CALL python_validar_excel(v_archivo, gv_plantilla_id, gv_resultado_id)
            
            -- 3. VALIDACIÓN CAPA 2: Validaciones 4GL (funciones val_*)
            -- Para cada fila OK en Excel, validar reglas de negocio
            CALL validar_reglas_4gl(gv_resultado_id)
                RETURNING v_total_filas, v_filas_ok, v_filas_error
            
            -- 4. Finalizar y generar hoja ERRORES si hay
            IF v_filas_error > 0 THEN
                CALL generar_archivo_con_errores(gv_resultado_id, v_archivo)
                    RETURNING gv_archivo_datos
                
                CALL sp_finalizar_validacion(gv_resultado_id, gv_archivo_datos)
                
                ERROR "⚠️ Validación con ", v_filas_error, " errores."
                MESSAGE "Archivo con hoja ERRORES generado: ", gv_archivo_datos
                MESSAGE "Corrija y vuelva a validar (Opción 4)"
            ELSE
                CALL sp_finalizar_validacion(gv_resultado_id, "")
                
                MESSAGE "✅ Validación exitosa: ", v_filas_ok, " registros OK"
                
                -- Mostrar grilla con datos válidos
                CALL mostrar_grilla_validos(gv_resultado_id)
                
                -- Preguntar qué hacer
                CALL menu_post_validacion()
            END IF
            
            EXIT INPUT
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
    
    CLOSE WINDOW w_validar
END FUNCTION

-- ============================================================
-- Menú post-validación exitosa
-- ============================================================
FUNCTION menu_post_validacion()
    DEFINE opcion SMALLINT
    
    MENU "VALIDACIÓN EXITOSA"
        COMMAND "1. Guardar en Base de Datos"  CALL opcion_guardar_bd()
        COMMAND "2. Exportar a XLSX/CSV/XML/PDF" CALL opcion_exportar()
        COMMAND "3. Ver Detalle Validación"     CALL ver_detalle_validacion()
        COMMAND "0. Volver al Menú Principal"  RETURN
    END MENU
END FUNCTION

-- ============================================================
-- OPCIÓN 5: Exportar Resultados (múltiples formatos)
-- ============================================================
FUNCTION opcion_exportar()
    DEFINE v_formato VARCHAR(10)
    DEFINE v_destino VARCHAR(300)
    DEFINE v_exito SMALLINT
    
    IF gv_resultado_id = 0 THEN
        ERROR "No hay validación previa. Use Opción 4 primero."
        RETURN
    END IF
    
    OPEN WINDOW w_export WITH FORM "exportar"
    DISPLAY "Exportar Resultados Validados" TO titulo
    DISPLAY "Formatos: XLSX, CSV, XML, PDF, HTML" TO lbl_formatos
    
    INPUT BY NAME v_formato, v_destino FROM exportar.*
        ON ACTION examinar
            CALL file_save_dialog("Guardar exportación", v_formato, v_destino)
            DISPLAY v_destino TO archivo_destino
        ON ACTION exportar
            IF v_destino IS NULL OR v_destino = "" THEN
                ERROR "Seleccione destino"
                CONTINUE INPUT
            END IF
            
            MESSAGE "Exportando a ", UPPER(v_formato), "..."
            
            CASE UPPER(v_formato)
                WHEN "XLSX"  CALL exportar_xlsx(gv_resultado_id, v_destino) RETURNING v_exito
                WHEN "CSV"   CALL exportar_csv(gv_resultado_id, v_destino) RETURNING v_exito
                WHEN "XML"   CALL exportar_xml_spreadsheetml(gv_resultado_id, v_destino) RETURNING v_exito
                WHEN "PDF"   CALL exportar_pdf(gv_resultado_id, v_destino) RETURNING v_exito
                WHEN "HTML"  CALL exportar_html(gv_resultado_id, v_destino) RETURNING v_exito
                OTHERWISE
                    ERROR "Formato no soportado: ", v_formato
                    CONTINUE INPUT
            END CASE
            
            IF v_exito THEN
                MESSAGE "✅ Exportado exitosamente: ", v_destino
                CALL log_exportacion(v_formato, v_destino, "EXITOSO")
            ELSE
                ERROR "Error en exportación"
            END IF
            EXIT INPUT
        ON ACTION cancelar
            EXIT INPUT
    END INPUT
    
    CLOSE WINDOW w_export
END FUNCTION

-- ============================================================
-- HELPERS
-- ============================================================
FUNCTION cargar_bancos_con_plantillas(p_bancos)
    -- Implementar: SELECT banco + cfg_plantilla WHERE estado='A'
    -- Retorna array estructurado
END FUNCTION

FUNCTION python_auto_tag(p_master, p_maestra, p_banco, p_nombre)
    -- Llamar: python tools/auto_tag_master.py "master" "maestra" "banco" "nombre"
    -- Retorna TRUE/FALSE
    RETURN TRUE  -- Placeholder
END FUNCTION

FUNCTION python_validar_excel(p_archivo, p_plantilla_id, p_resultado_id)
    -- Llamar: python tools/validar_excel.py archivo plantilla_id resultado_id
    -- Valida: tipos, listas, rangos, formatos, fórmulas
    -- Inserta en validacion_detalle estado OK/ERROR
    RETURN TRUE  -- Placeholder
END FUNCTION

FUNCTION validar_reglas_4gl(p_resultado_id)
    -- Para cada fila OK en Excel, aplicar validaciones 4GL:
    -- val_documento, val_fecha, val_email, val_nombre, val_monto, val_catalogo
    -- Actualiza validacion_detalle con estado final
    RETURN 0, 0, 0  -- Placeholder
END FUNCTION

FUNCTION generar_archivo_con_errores(p_resultado_id, p_archivo_original)
    -- 1. Copiar archivo original a plantillas_errores/
    -- 2. Agregar hoja "ERRORES" con datos de validacion_detalle
    -- 3. Retornar ruta nuevo archivo
    RETURN ""  -- Placeholder
END FUNCTION

FUNCTION mostrar_grilla_validos(p_resultado_id)
    -- DISPLAY ARRAY con datos válidos (pivot fila→columnas)
END FUNCTION

FUNCTION opcion_guardar_bd()
    CALL sp_insertar_datos_validados(gv_resultado_id) RETURNING filas
    IF filas > 0 THEN
        MESSAGE "✅ ", filas, " registros insertados en BD"
    ELSE
        ERROR "Error insertando en BD"
    END IF
END FUNCTION

FUNCTION ver_detalle_validacion()
    -- Mostrar ventana con validacion_detalle
END FUNCTION

FUNCTION copiar_archivo(p_origen, p_destino)
    RUN "copy /Y ", p_origen, " ", p_destino
END FUNCTION

FUNCTION file_dialog(p_titulo, p_filtro, p_resultado)
    -- Usar fgl_getfiledialog o similar según versión Genero
END FUNCTION

FUNCTION file_save_dialog(p_titulo, p_ext, p_resultado)
    -- Usar fgl_getfiledialog modo save
END FUNCTION

FUNCTION input_string(p_prompt, p_defecto, p_resultado)
    -- INPUT simple para string
END FUNCTION

FUNCTION limpiar_pantalla()
    -- CLEAR SCREEN o equivalent
END FUNCTION

FUNCTION mostrar_encabezado(p_titulo)
    DISPLAY "═══════════════════════════════════════════"
    DISPLAY p_titulo
    DISPLAY "═══════════════════════════════════════════"
END FUNCTION