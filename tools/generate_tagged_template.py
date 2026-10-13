#!/usr/bin/env python3
"""
Genera plantilla .xlsx con tags {{campo}} desde master + query.
Uso: python generate_tagged_template.py "<query>" <tabla_destino> <nombre_plantilla>
"""
import sys
import json
import shutil
import os
import openpyxl
import re

MASTER_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'plantillas_base')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'plantillas_generadas')

# Mapeo tabla -> master template
MASTER_MAP = {
    'banco_cliente': 'master_cliente.xlsx',
    'solicitud_apertura_cuenta': 'master_solicitud_apertura_cuenta.xlsx',
}

CAMPO_A_LISTA = {
    "tipo_doc": "tipo_doc",
    "genero": "genero",
    "estado_civil": "estado_civil",
    "ciudad": "ciudad",
    "tipo_cuenta": "tipo_cuenta",
    "moneda": "moneda",
    "tipo_solicitud": "tipo_solicitud",
    "tipo_cuenta": "tipo_cuenta",
    "moneda": "moneda",
    "sucursal": "sucursal",
    "cliente_tipo_doc": "tipo_doc",
    "origen_fondos": "origen_fondos",
    "destino_fondos": "destino_fondos",
    "firma_digital": "firma_digital",
    "estado_solicitud": "estado_solicitud",
}

LISTAS_DEFAULTS = {
    "tipo_doc": ["DNI", "LE", "LC", "PAS", "CI", "RUT", "CIU"],
    "genero": ["M", "F", "X"],
    "estado_civil": ["S", "C", "D", "V", "U"],
    "ciudad": ["CABA", "CORD", "ROS", "MEND", "LPLT", "TUC", "SAL", "MVD", "SCL", "SPA"],
    "tipo_cuenta": ["AHO", "CTE", "CTA_CORRIENTE", "PLAZO_FIJO", "CAJA_AHORRO"],
    "moneda": ["ARS", "USD", "EUR", "BRL", "UYU", "PYG"],
    "sucursal": ["001", "002", "003", "004", "005", "006", "007", "008", "009", "010"],
    "tipo_solicitud": ["NUEVA", "ADICIONAL", "REEMPLAZO", "CAMBIO_TITULAR"],
    "tipo_cuenta": ["AHO", "CTE", "CTA_CORRIENTE", "PLAZO_FIJO", "CAJA_AHORRO"],
    "moneda": ["ARS", "USD", "EUR", "BRL", "UYU", "PYG"],
    "sucursal": ["001", "002", "003", "004", "005", "006", "007", "008", "009", "010"],
    "tipo_solicitud": ["NUEVA", "ADICIONAL", "REEMPLAZO", "CAMBIO_TITULAR"],
    "origen_fondos": ["SUELDO", "HERENCIA", "VENTA_BIENES", "AHORROS", "OTROS"],
    "destino_fondos": ["AHORRO", "INVERSION", "PAGOS", "TRANSFERENCIAS", "OTROS"],
    "firma_digital": ["SI", "NO"],
    "estado_solicitud": ["PENDIENTE", "APROBADA", "RECHAZADA", "OBSERVADA", "CANCELADA"],
}


def analizar_query_simple(query):
    """Extrae columnas y tablas de un SELECT simple."""
    query_lower = query.lower().strip()
    
    # Extraer columnas entre SELECT y FROM
    select_match = re.search(r'select\s+(.+?)\s+from', query_lower, re.IGNORECASE | re.DOTALL)
    campos = []
    if select_match:
        select_part = select_match.group(1)
        for token in select_part.split(','):
            token = token.strip()
            token = re.sub(r'\s+as\s+\w+$', '', token, flags=re.IGNORECASE)
            token = re.sub(r'\s+\w+$', '', token)
            token = token.strip()
            if token and token != '*':
                if '.' in token:
                    token = token.split('.')[-1]
                campos.append(token.strip('`"\' '))
    
    # Extraer tablas
    tablas = []
    for match in re.finditer(r'\b(from|join)\s+(\w+)', query_lower):
        tablas.append(match.group(2))
    
    return {
        'campos': campos,
        'tablas': list(dict.fromkeys(tablas))
    }


def get_master_path(tabla_destino):
    master_file = MASTER_MAP.get(tabla_destino, 'default.xlsx')
    return os.path.join(os.path.dirname(__file__), '..', '..', 'plantillas_base', master_file)


def generar_plantilla_con_tags(query, tabla_destino, nombre_plantilla):
    """Genera plantilla .xlsx con tags {{campo}} desde master template."""
    analisis = analizar_query_simple(query)
    campos_query = analisis['campos']
    tablas = analisis['tablas']
    
    if not campos_query:
        raise ValueError("No se detectaron columnas en el query")
    
    master_path = os.path.join(os.path.dirname(__file__), '..', '..', 'plantillas_base', 
                               MASTER_MAP.get(tabla_destino, 'default.xlsx'))
    
    if not os.path.exists(master_path):
        raise FileNotFoundError(f"No existe master template para {tabla_destino}")
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_filename = f"{nombre_plantilla}_{__import__('datetime').datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
    output_path = os.path.join(OUTPUT_DIR, output_filename)
    
    shutil.copy2(master_path, output_path)
    
    wb = openpyxl.load_workbook(output_path)
    ws = wb['Plantilla']
    
    # Escribir TAGS en fila 2
    for idx, campo in enumerate(campos_query, 1):
        ws.cell(row=2, column=idx, value=f"{{{{{campo}}}}}")
    
    # Ajustar columnas si query tiene más/menos campos que master
    # (openpyxl no borra columnas extra automáticamente)
    
    # Generar nombre único
    timestamp = __import__('datetime').datetime.now().strftime("%Y%m%d_%H%M%S")
    output_filename = f"{nombre_plantilla}_{timestamp}.xlsx"
    output_path = os.path.join(OUTPUT_DIR, output_filename)
    
    wb.save(output_path)
    print(f"Plantilla generada: {output_path}")
    return output_path


OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'plantillas_generadas')


def main():
    if len(sys.argv) < 4:
        print("Uso: python generate_tagged_template.py \"<query>\" <tabla_destino> <nombre_plantilla>")
        print("Ejemplo: python generate_tagged_template.py \"SELECT tipo_doc, num_doc FROM staging_clientes\" banco_cliente clientes_test")
        sys.exit(1)
    
    query = sys.argv[1]
    tabla_destino = sys.argv[2]
    nombre_plantilla = sys.argv[3]
    
    try:
        output = generar_plantilla_con_tags(query, tabla_destino, nombre_plantilla)
        print(output)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    import sys
    import json
    import shutil
    import os
    import openpyxl
    import re
    main()