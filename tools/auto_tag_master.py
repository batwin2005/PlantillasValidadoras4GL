#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
auto_tag_master.py
Genera plantilla maestra con tags {{campo}} desde master Excel sin tags.
Lee encabezados fila 1 → crea tags en fila 2 + validaciones Excel nativas + hoja Listas.
"""

import sys
import os
import openpyxl
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from pathlib import Path
import re
from datetime import datetime

# Agregar path para imports locales
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ============================================================
# MAPEO DE ENCABEZADOS → VALIDADORES Y CATÁLOGOS
# ============================================================
CATALOGOS_DISPONIBLES = {
    'tipo_doc': ('cat_tipo_documento', 'codigo'),
    'tipo_documento': ('cat_tipo_documento', 'codigo'),
    'documento_tipo': ('cat_tipo_documento', 'codigo'),
    'genero': ('cat_genero', 'codigo'),
    'sexo': ('cat_genero', 'codigo'),
    'estado_civil': ('cat_estado_civil', 'codigo'),
    'ciudad': ('cat_ciudad', 'codigo'),
    'pais': ('cat_ciudad', 'pais'),
    'moneda': ('cat_moneda', 'codigo'),
    'tipo_cuenta': ('cat_tipo_cuenta', 'codigo'),
    'tipo_solicitud': ('cat_tipo_solicitud', 'codigo'),
    'origen_fondos': ('cat_origen_fondos', 'codigo'),
    'destino_fondos': ('cat_destino_fondos', 'codigo'),
    'firma_digital': ('cat_firma_digital', 'codigo'),
    'estado_solicitud': ('cat_estado_solicitud', 'codigo'),
    'sucursal': ('cat_sucursal', 'codigo'),
}

VALIDADORES_POR_PATRON = [
    (r'(doc|documento|dni|cuil|cuit|rut|pasaporte|identific)', 'val_documento', None),
    (r'(email|e_mail|correo|mail)', 'val_email', None),
    (r'(fecha.*nac|nacimiento|nacim)', 'val_fecha', None),
    (r'(fecha|fec_)', 'val_fecha', None),
    (r'(tel[ée]fono|celular|movil|phone)', 'val_telefono', None),
    (r'(nombre|apellido)', 'val_nombre', None),
    (r'(monto|importe|saldo|deposito|retiro|valor)', 'val_monto', None),
    (r'(anio|año|year)', 'val_anio', None),
    (r'(codigo|código|cod_)', 'val_catalogo', None),  # Se define por catálogo
]

FORMATOS_EXCEL = {
    'val_fecha': 'DD/MM/YYYY',
    'val_email': '@',
    'val_monto': '#,##0.00',
    'val_documento': 'General',
    'val_nombre': 'General',
    'val_telefono': 'General',
    'val_anio': '0',
    'val_catalogo': 'General',
}

# ============================================================
# UTILIDADES
# ============================================================
def slugify(text):
    """Convierte 'Número Documento' → 'numero_documento'"""
    text = text.lower().strip()
    text = text.replace('ñ', 'n').replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u')
    text = re.sub(r'[^a-z0-9]+', '_', text)
    text = re.sub(r'_+', '_', text).strip('_')
    return text

def inferir_validador_y_catalogo(encabezado):
    """Infiere validador y catálogo basado en el texto del encabezado"""
    header_lower = encabezado.lower()
    
    # Buscar catálogo primero
    for key, (tabla, campo) in CATALOGOS_DISPONIBLES.items():
        if key in header_lower:
            return 'val_catalogo', tabla, campo
    
    # Buscar por patrones de validador
    for patron, validador, _ in VALIDADORES_POR_PATRON:
        if re.search(patron, header_lower):
            return validador, None, None
    
    # Default
    return 'val_texto', None, None

def obtener_lista_catalogo(tabla, campo):
    """Obtiene valores de catálogo desde BD (mock - en producción conectar a Informix)"""
    # En producción: conectar a Informix y hacer SELECT
    # Por ahora retornamos listas por defecto conocidas
    defaults = {
        'cat_tipo_documento': ['DNI', 'LE', 'LC', 'PAS', 'CI', 'RUT', 'CIU'],
        'cat_genero': ['M', 'F', 'X'],
        'cat_estado_civil': ['S', 'C', 'D', 'V', 'U'],
        'cat_moneda': ['ARS', 'USD', 'EUR', 'BRL', 'UYU', 'PYG'],
        'cat_tipo_cuenta': ['AHO', 'CTE', 'CTA_CORRIENTE', 'PLAZO_FIJO', 'CAJA_AHORRO'],
        'cat_ciudad': ['CABA', 'CORD', 'ROS', 'MEND', 'LPLT', 'TUC', 'SAL', 'MVD', 'SCL', 'SPA'],
    }
    return defaults.get(tabla, [])

# ============================================================
# PROCESADOR PRINCIPAL
# ============================================================
class AutoTagMaster:
    def __init__(self, master_path, maestra_path, banco_codigo, nombre_plantilla):
        self.master_path = Path(master_path)
        self.maestra_path = Path(maestra_path)
        self.banco_codigo = banco_codigo
        self.nombre_plantilla = nombre_plantilla
        self.wb = None
        self.campos = []  # Lista de dicts con info de cada columna
        
    def procesar(self):
        """Ejecuta todo el proceso"""
        print(f"[INFO] Procesando master: {self.master_path}")
        
        # 1. Cargar master
        self.wb = openpyxl.load_workbook(self.master_path)
        ws = self.wb.active
        ws.title = "Datos"
        
        # 2. Leer encabezados (fila 1)
        self._leer_encabezados(ws)
        
        if not self.campos:
            raise ValueError("No se detectaron encabezados en fila 1")
        
        # 3. Escribir TAGS en fila 2
        self._escribir_tags(ws)
        
        # 4. Agregar validaciones Excel nativas
        self._agregar_validaciones_excel(ws)
        
        # 5. Crear hoja Listas con catálogos
        self._crear_hoja_listas()
        
        # 6. Estilizar hoja Datos
        self._estilizar_hoja_datos(ws)
        
        # 7. Guardar maestra
        self.maestra_path.parent.mkdir(parents=True, exist_ok=True)
        self.wb.save(self.maestra_path)
        self.wb.close()
        
        print(f"[OK] Plantilla maestra generada: {self.maestra_path}")
        print(f"     Campos detectados: {len(self.campos)}")
        for c in self.campos:
            print(f"       {c['columna']}: {c['tag']} | {c['validador']} | {c['catalogo_tabla'] or '-'}")
        
        return self.campos
    
    def _leer_encabezados(self, ws):
        """Lee fila 1 y detecta columnas con datos"""
        max_col = ws.max_column
        
        for col_idx in range(1, max_col + 1):
            cell = ws.cell(row=1, column=col_idx)
            if cell.value and isinstance(cell.value, str) and cell.value.strip():
                encabezado = cell.value.strip()
                columna_letra = get_column_letter(col_idx)
                
                # Inferir validador y catálogo
                validador, cat_tabla, cat_campo = inferir_validador_y_catalogo(encabezado)
                
                # Generar tag: {{prefijo.campo}}
                # Prefijo basado en nombre plantilla o 'cliente'
                prefijo = slugify(self.nombre_plantilla.split('_')[0]) if '_' in self.nombre_plantilla else 'cliente'
                campo_slug = slugify(encabezado)
                tag = f'{{{{{prefijo}.{campo_slug}}}}}'
                
                campo_info = {
                    'columna': columna_letra,
                    'col_idx': col_idx,
                    'encabezado': encabezado,
                    'tag': tag,
                    'nombre_campo': f'{prefijo}.{campo_slug}',
                    'validador': validador,
                    'catalogo_tabla': cat_tabla,
                    'catalogo_campo': cat_campo,
                    'obligatorio': 'S' if validador != 'val_texto' else 'N',
                    'formato_excel': FORMATOS_EXCEL.get(validador, 'General'),
                }
                self.campos.append(campo_info)
    
    def _escribir_tags(self, ws):
        """Escribe tags {{campo}} en fila 2"""
        for campo in self.campos:
            cell = ws.cell(row=2, column=campo['col_idx'], value=campo['tag'])
            cell.font = Font(bold=True, color="003366", size=10)
            cell.alignment = Alignment(horizontal="center", wrap_text=True)
    
    def _agregar_validaciones_excel(self, ws):
        """Agrega DataValidation nativas de Excel"""
        # Determinar rango de datos (desde fila 3 hasta 1000)
        max_col_letter = get_column_letter(len(self.campos))
        rango_datos = f"A3:{max_col_letter}1000"
        
        for campo in self.campos:
            col_letter = campo['columna']
            rango_col = f"{col_letter}3:{col_letter}1000"
            validador = campo['validador']
            cat_tabla = campo['catalogo_tabla']
            cat_campo = campo['catalogo_campo']
            
            dv = None
            
            if validador == 'val_catalogo' and cat_tabla:
                # Lista desplegable desde hoja Listas
                valores = obtener_lista_catalogo(cat_tabla, cat_campo)
                if valores:
                    formula = '"' + ','.join(valores) + '"'
                    dv = DataValidation(type="list", formula1=formula, allow_blank=not campo['obligatorio'] == 'S')
                    dv.error = f"Seleccione un {campo['encabezado']} válido"
                    dv.errorTitle = "Valor inválido"
                    dv.prompt = f"Seleccione {campo['encabezado']}"
                    dv.promptTitle = campo['encabezado']
            
            elif validador == 'val_fecha':
                dv = DataValidation(type="date", operator="between", 
                                   formula1="1900-01-01", formula2="2099-12-31",
                                   allow_blank=not campo['obligatorio'] == 'S')
                dv.error = "Fecha inválida (use DD/MM/YYYY)"
                dv.errorTitle = "Fecha inválida"
            
            elif validador == 'val_email':
                # Validación custom con fórmula
                dv = DataValidation(type="custom", formula1=f'ISNUMBER(SEARCH("@",{col_letter}3))', 
                                   allow_blank=not campo['obligatorio'] == 'S')
                dv.error = "Email inválido (debe contener @)"
                dv.errorTitle = "Email inválido"
            
            elif validador == 'val_monto':
                dv = DataValidation(type="decimal", operator=">=", formula1="0",
                                   allow_blank=not campo['obligatorio'] == 'S')
                dv.error = "Monto debe ser positivo"
                dv.errorTitle = "Monto inválido"
            
            elif validador == 'val_anio':
                dv = DataValidation(type="whole", operator="between", formula1="1900", formula2="2099",
                                   allow_blank=not campo['obligatorio'] == 'S')
                dv.error = "Año entre 1900 y 2099"
                dv.errorTitle = "Año inválido"
            
            elif validador == 'val_documento':
                # Solo alfanumérico, longitud 5-20
                dv = DataValidation(type="textLength", operator="between", formula1="5", formula2="20",
                                   allow_blank=not campo['obligatorio'] == 'S')
                dv.error = "Documento: 5-20 caracteres alfanuméricos"
                dv.errorTitle = "Documento inválido"
            
            elif validador == 'val_nombre':
                dv = DataValidation(type="textLength", operator="between", formula1="2", formula2="60",
                                   allow_blank=not campo['obligatorio'] == 'S')
                dv.error = "Solo letras, 2-60 caracteres"
                dv.errorTitle = "Nombre inválido"
            
            elif validador == 'val_telefono':
                dv = DataValidation(type="textLength", operator="between", formula1="7", formula2="20",
                                   allow_blank=True)  # Teléfono opcional
                dv.error = "Teléfono: 7-20 dígitos"
                dv.errorTitle = "Teléfono inválido"
            
            if dv:
                dv.sqref = rango_col
                ws.add_data_validation(dv)
    
    def _crear_hoja_listas(self):
        """Crea hoja 'Listas' con catálogos para dropdowns"""
        ws_listas = self.wb.create_sheet("Listas")
        
        # Encabezados
        ws_listas.cell(row=1, column=1, value="Catalogo").font = Font(bold=True, color="FFFFFF")
        ws_listas.cell(row=1, column=2, value="Valor").font = Font(bold=True, color="FFFFFF")
        
        header_fill = PatternFill(start_color="003366", end_color="003366", fill_type="solid")
        for cell in ws_listas[1]:
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center")
        
        # Recopilar catálogos únicos usados
        catalogos_usados = {}
        for campo in self.campos:
            if campo['catalogo_tabla'] and campo['catalogo_campo']:
                key = (campo['catalogo_tabla'], campo['catalogo_campo'])
                if key not in catalogos_usados:
                    catalogos_usados[key] = obtener_lista_catalogo(campo['catalogo_tabla'], campo['catalogo_campo'])
        
        # Escribir catálogos
        row = 2
        for (tabla, campo), valores in catalogos_usados.items():
            for val in valores:
                ws_listas.cell(row=row, column=1, value=tabla)
                ws_listas.cell(row=row, column=2, value=val)
                row += 1
            # Fila separadora
            row += 1
        
        # Ajustar anchos
        ws_listas.column_dimensions['A'].width = 25
        ws_listas.column_dimensions['B'].width = 30
    
    def _estilizar_hoja_datos(self, ws):
        """Estiliza hoja Datos: headers fila 1, tags fila 2"""
        # Fila 1: Encabezados visibles
        header_font = Font(bold=True, color="FFFFFF", size=11)
        header_fill = PatternFill(start_color="003366", end_color="003366", fill_type="solid")
        header_align = Alignment(horizontal="center", wrap_text=True)
        thin_border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
        
        for campo in self.campos:
            cell = ws.cell(row=1, column=campo['col_idx'])
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_align
            cell.border = thin_border
        
        # Fila 2: Tags
        tag_font = Font(bold=True, color="003366", size=9, italic=True)
        tag_fill = PatternFill(start_color="E8F0FE", end_color="E8F0FE", fill_type="solid")
        
        for campo in self.campos:
            cell = ws.cell(row=2, column=campo['col_idx'])
            cell.font = tag_font
            cell.fill = tag_fill
            cell.alignment = Alignment(horizontal="center", wrap_text=True)
            cell.border = thin_border
        
        # Ajustar anchos de columna
        for campo in self.campos:
            col_letter = campo['columna']
            # Ancho basado en encabezado
            ancho = max(len(campo['encabezado']) + 2, 12)
            ws.column_dimensions[col_letter].width = min(ancho, 40)
        
        # Congelar filas 1-2
        ws.freeze_panes = "A3"
        
        # Auto-filtro en fila 1
        if self.campos:
            max_col = get_column_letter(len(self.campos))
            ws.auto_filter.ref = f"A1:{max_col}1000"
    
    def obtener_config_bd(self):
        """Retorna lista de dicts listos para INSERT en cfg_campo"""
        config = []
        for campo in self.campos:
            config.append({
                'columna_excel': campo['columna'],
                'nombre_campo': campo['nombre_campo'],
                'tag_excel': campo['tag'],
                'encabezado': campo['encabezado'],
                'validador': campo['validador'],
                'catalogo_tabla': campo['catalogo_tabla'],
                'catalogo_campo': campo['catalogo_campo'],
                'obligatorio': campo['obligatorio'],
                'orden': campo['col_idx'],
                'formato_excel': campo['formato_excel'],
            })
        return config


# ============================================================
# FUNCIÓN MAIN - ENTRY POINT
# ============================================================
def main():
    if len(sys.argv) < 5:
        print("Uso: python auto_tag_master.py <master.xlsx> <maestra.xlsx> <banco_codigo> <nombre_plantilla>")
        print("Ejemplo: python auto_tag_master.py plantillas_base/master.xlsx plantillas_maestras/maestra.xlsx nacion clientes")
        sys.exit(1)
    
    master_path = sys.argv[1]
    maestra_path = sys.argv[2]
    banco_codigo = sys.argv[3]
    nombre_plantilla = sys.argv[4]
    
    if not Path(master_path).exists():
        print(f"[ERROR] Master no encontrado: {master_path}")
        sys.exit(1)
    
    try:
        processor = AutoTagMaster(master_path, maestra_path, banco_codigo, nombre_plantilla)
        campos = processor.procesar()
        
        # Output para que 4GL capture
        print(f"PLANTILLA_ID_PENDIENTE")
        print(f"CAMPOS:{len(campos)}")
        for c in campos:
            print(f"  {c['columna']}|{c['nombre_campo']}|{c['tag']}|{c['validador']}|{c['catalogo_tabla'] or ''}|{c['catalogo_campo'] or ''}|{c['obligatorio']}|{c['orden']}|{c['formato_excel']}")
        
        sys.exit(0)
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()