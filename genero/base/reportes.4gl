-- ============================================================
-- MODULO: reportes.4gl
-- Reportes bancarios -> HTML (imprimible a PDF)
-- Sintaxis REPORT clásica 4GL
-- ============================================================

DATABASE banco

-- ============================================================
-- Reporte: Listado completo de clientes
-- ============================================================
REPORT rep_listado_clientes()
    DEFINE rec RECORD LIKE vw_cliente_cuenta.*
    DEFINE total_cuentas INT
    DEFINE total_saldo DECIMAL(20,2)
    DEFINE total_por_moneda DECIMAL(20,2)
    DEFINE moneda_actual CHAR(3)
    
    FORMAT
    EVERY ROW
    
    BEFORE GROUP OF 1
        OUTPUT "<!DOCTYPE html><html><head><meta charset='ISO-8859-1'><title>Listado Clientes - Banco Ejemplo</title>"
        OUTPUT "<style>body{font-family:Arial,Helvetica,sans-serif;font-size:11px;margin:20px} "
        OUTPUT "h1{color:#003366;border-bottom:2px solid #003366;padding-bottom:5px} "
        OUTPUT "table{border-collapse:collapse;width:100%;font-size:10px} "
        OUTPUT "th{background:#003366;color:#fff;padding:6px;border:1px solid #ccc;text-align:left} "
        OUTPUT "td{padding:4px;border:1px solid #ddd} tr:nth-child(even){background:#f9f9f9} "
        OUTPUT ".tot{background:#e8f0fe;font-weight:bold} .num{text-align:right} "
        OUTPUT ".logo{float:right;width:120px;margin-bottom:10px} "
        OUTPUT ".foot{margin-top:20px;font-size:10px;color:#666} </style></head><body>"
        OUTPUT "<img class='logo' src='logo_banco.png' alt='Banco Ejemplo' onerror='this.style.display=none'>"
        OUTPUT "<h1>BANCO EJEMPLO - Listado General de Clientes</h1>"
        OUTPUT "<p>Fecha emisión: " || TODAY || " " || CURRENT HOUR TO MINUTE || " | Usuario: " || USER || "</p>"
        OUTPUT "<table><thead><tr>"
        OUTPUT "<th>ID</th><th>Tipo Doc</th><th>Número Doc</th><th>Apellidos</th><th>Nombres</th>"
        OUTPUT "<th>Género</th><th>F.Nac</th><th>Ciudad</th><th>Cuenta</th>"
        OUTPUT "<th>Tipo Cuenta</th><th>Moneda</th><th class='num'>Saldo</th></tr></thead><tbody>"
    
    ON EVERY ROW
        OUTPUT "<tr>"
        OUTPUT "<td>" || rec.cliente_id || "</td>"
        OUTPUT "<td>" || rec.tipo_doc || "</td>"
        OUTPUT "<td>" || rec.num_doc || "</td>"
        OUTPUT "<td>" || rec.apellidos || "</td>"
        OUTPUT "<td>" || rec.nombres || "</td>"
        OUTPUT "<td>" || rec.genero || "</td>"
        OUTPUT "<td>" || rec.fecha_nac || "</td>"
        OUTPUT "<td>" || rec.ciudad || "</td>"
        OUTPUT "<td>" || rec.num_cuenta || "</td>"
        OUTPUT "<td>" || rec.tipo_cuenta || "</td>"
        OUTPUT "<td>" || rec.moneda || "</td>"
        OUTPUT "<td class='num'>" || rec.saldo || "</td>"
        OUTPUT "</tr>"
        LET total_cuentas = total_cuentas + 1
        LET total_saldo = total_saldo + rec.saldo
    
    AFTER GROUP OF 1
        OUTPUT "</tbody><tfoot><tr class='tot'>"
        OUTPUT "<td colspan=11>TOTAL CUENTAS: " || total_cuentas || "</td>"
        OUTPUT "<td class='num'>" || total_saldo || "</td></tr></tbody></table>"
        OUTPUT "<p class='foot'>Generado: " || TODAY || " " || CURRENT HOUR TO MINUTE 
        OUTPUT " | Banco Ejemplo - Sistema 4GL | Total registros: " || total_cuentas || "</p>"
        OUTPUT "</body></html>"
    
    SELECT * INTO rec.* FROM vw_cliente_cuenta ORDER BY apellidos, nombres
END REPORT

-- ============================================================
-- Reporte: Cuentas por estado y moneda
-- ============================================================
REPORT rep_cuentas_estado_moneda()
    DEFINE rec RECORD
        estado CHAR(1),
        moneda CHAR(3),
        cantidad INT,
        total_saldo DECIMAL(20,2)
    END RECORD
    DEFINE gran_total DECIMAL(20,2)
    DEFINE total_estado DECIMAL(20,2)
    DEFINE estado_ant CHAR(1)
    
    FORMAT
    BEFORE GROUP OF 1
        OUTPUT "<html><head><title>Cuentas por Estado/Moneda</title>"
        OUTPUT "<style>body{font-family:Arial;font-size:11px} "
        OUTPUT "table{border-collapse:collapse} th,td{border:1px solid #ccc;padding:4px} "
        OUTPUT "th{background:#003366;color:#fff} .num{text-align:right} "
        OUTPUT ".sub{background:#e8f0fe;font-weight:bold} </style></head><body>"
        OUTPUT "<h1>Cuentas por Estado y Moneda</h1><p>" || TODAY || "</p>"
        OUTPUT "<table><tr><th>Estado</th><th>Moneda</th><th class='num'>Cantidad</th><th class='num'>Total Saldo</th></tr>"
    
    ON EVERY ROW
        IF estado_ant <> rec.estado AND estado_ant IS NOT NULL THEN
            OUTPUT "<tr class='sub'><td colspan=2>Subtotal " || estado_ant || "</td>"
            OUTPUT "<td class='num'>&nbsp;</td><td class='num'>" || total_estado || "</td></tr>"
            LET total_estado = 0
        END IF
        OUTPUT "<tr><td>" || rec.estado || "</td><td>" || rec.moneda || "</td>"
        OUTPUT "<td class='num'>" || rec.cantidad || "</td>"
        OUTPUT "<td class='num'>" || rec.total_saldo || "</td></tr>"
        LET total_estado = total_estado + rec.total_saldo
        LET gran_total = gran_total + rec.total_saldo
        LET estado_ant = rec.estado
    
    AFTER GROUP OF 1
        OUTPUT "<tr class='sub'><td colspan=2>Subtotal " || estado_ant || "</td>"
        OUTPUT "<td class='num'>&nbsp;</td><td class='num'>" || total_estado || "</td></tr>"
        OUTPUT "<tr style='font-weight:bold;background:#fff3cd'><td colspan=2>TOTAL GENERAL</td>"
        OUTPUT "<td class='num'>&nbsp;</td><td class='num'>" || gran_total || "</td></tr>"
        OUTPUT "</table><p>Generado: " || TODAY || " " || CURRENT HOUR TO MINUTE || "</p></body></html>"
    
    SELECT estado, moneda, COUNT(*) AS cantidad, SUM(saldo) AS total_saldo
    INTO rec.* FROM banco_cuenta
    GROUP BY estado, moneda
    ORDER BY estado, moneda
END REPORT

-- ============================================================
-- Reporte: Movimientos con totales por cuenta
-- ============================================================
REPORT rep_movimientos_cuenta()
    DEFINE rec RECORD
        num_cuenta VARCHAR(25),
        fecha DATETIME YEAR TO SECOND,
        tipo CHAR(1),
        concepto VARCHAR(80),
        monto DECIMAL(16,2),
        saldo_post DECIMAL(16,2)
    END RECORD
    DEFINE cuenta_ant VARCHAR(25)
    
    FORMAT
    BEFORE GROUP OF 1
        OUTPUT "<html><head><title>Movimientos por Cuenta</title>"
        OUTPUT "<style>body{font-family:Arial;font-size:10px} table{border-collapse:collapse} "
        OUTPUT "th,td{border:1px solid #ccc;padding:3px} th{background:#003366;color:#fff} "
        OUTPUT ".num{text-align:right} .cred{color:green} .deb{color:red} </style></head><body>"
        OUTPUT "<h1>Movimientos por Cuenta</h1><p>" || TODAY || "</p>"
    
    BEFORE GROUP OF num_cuenta
        OUTPUT "<h2>Cuenta: " || rec.num_cuenta || "</h2>"
        OUTPUT "<table><tr><th>Fecha</th><th>Tipo</th><th>Concepto</th><th class='num'>Monto</th><th class='num'>Saldo</th></tr>"
    
    ON EVERY ROW
        IF rec.tipo = 'C' THEN
            OUTPUT "<tr><td>" || rec.fecha || "</td><td class='cred'>CRÉDITO</td>"
            OUTPUT "<td>" || rec.concepto || "</td><td class='num cred'>+" || rec.monto || "</td>"
        ELSE
            OUTPUT "<tr><td>" || rec.fecha || "</td><td class='deb'>DÉBITO</td>"
            OUTPUT "<td>" || rec.concepto || "</td><td class='num deb'>-" || rec.monto || "</td>"
        END IF
        OUTPUT "<td class='num'>" || rec.saldo_post || "</td></tr>"
    
    AFTER GROUP OF num_cuenta
        OUTPUT "</table><br>"
    
    AFTER GROUP OF 1
        OUTPUT "<p>Fin del reporte - " || TODAY || " " || CURRENT HOUR TO MINUTE || "</p></body></html>"
    
    SELECT cu.num_cuenta, m.fecha, m.tipo, m.concepto, m.monto, m.saldo_post
    INTO rec.* FROM banco_movimiento m
    JOIN banco_cuenta cu ON cu.cuenta_id = m.cuenta_id
    ORDER BY cu.num_cuenta, m.fecha
END REPORT

-- ============================================================
-- Función helper: ejecutar reporte y abrir en navegador
-- ============================================================
FUNCTION ejecutar_reporte_html(p_reporte VARCHAR(30), p_archivo VARCHAR(50))
    CASE p_reporte
        WHEN "listado"     START REPORT rep_listado_clientes TO FILE p_archivo
        WHEN "estado"      START REPORT rep_cuentas_estado_moneda TO FILE p_archivo
        WHEN "movimientos" START REPORT rep_movimientos_cuenta TO FILE p_archivo
    END CASE
    
    FINISH REPORT
    
    -- Abrir en navegador (Windows)
    RUN "start " || p_archivo
END FUNCTION