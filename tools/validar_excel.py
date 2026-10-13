#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
validar_excel.py
Validación Capa 1: Validaciones nativas de Excel (openpyxl)
- Tipos de dato, listas, rangos, formatos, fórmulas custom
- Lee archivo usuario + config plantilla (cfg_campo) → valida cada celda
- Inserta resultados en validacion_detalle via SP o retorna JSON para 4GL
"""

import sys
import os
import openpyxl
from openpyxl.worksheet.datavalidation import DataValidation
from pathlib import Path
import json
import re
from datetime import datetime
from decimal import Decimal, InvalidOperation

# Agregar path local
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ============================================================
# VALIDADORES NÚCLEO (Python - validaciones Excel nativas)
# ============================================================

def validar_tipo_dato(valor, tipo_esperado):
    """Valida tipo de dato básico"""
    if valor is None or valor == '':
        return True, None  # Vacío = OK (obligatorio se valida aparte)
    
    if tipo_esperado == 'date':
        # Intentar parsear fecha
        for fmt in ['%d/%m/%Y', '%Y-%m-%d', '%d-%m-%Y', '%m/%d/%Y']:
            try:
                datetime.strptime(str(valor).strip(), fmt)
                return True, None
            except ValueError:
                continue
        return False, f"Formato fecha inválido (use DD/MM/YYYY): {valor}"
    
    elif tipo_esperado == 'number':
        try:
            float(valor)
            return True, None
        except (ValueError, TypeError):
            return False, f"Debe ser numérico: {valor}"
    
    elif tipo_esperado == 'integer':
        try:
            int(valor)
            return True, None
        except (ValueError, TypeError):
            return False, f"Debe ser entero: {valor}"
    
    elif tipo_esperado == 'decimal':
        try:
            Decimal(str(valor))
            return True, None
        except (InvalidOperation, ValueError):
            return False, f"Debe ser decimal: {valor}"
    
    return True, None  # String = siempre OK


def validar_lista(valor, valores_permitidos):
    """Valida que valor esté en lista permitida"""
    if valor is None or valor == '':
        return True, None
    if str(valor).strip().upper() in [v.upper() for v in valores_permitidos]:
        return True, None
    return False, f"Valor no permitido: {valor}. Opciones: {', '.join(valores_permitidos)}"


def validar_rango_numerico(valor, min_val, max_val):
    """Valida rango numérico"""
    if valor is None or valor == '':
        return True, None
    try:
        num = float(valor)
        if num < min_val or num > max_val:
            return False, f"Fuera de rango [{min_val}, {max_val}]: {valor}"
        return True, None
    except (ValueError, TypeError):
        return False, f"No es numérico: {valor}"


def validar_longitud(valor, min_len, max_len):
    """Valida longitud de texto"""
    if valor is None:
        return True, None
    texto = str(valor).strip()
    if len(texto) < min_len or len(texto) > max_len:
        return False, f"Longitud {len(texto)} fuera de rango [{min_len}, {max_len}]: {valor}"
    return True, None


def validar_email(valor):
    """Valida formato email básico"""
    if valor is None or valor == '':
        return True, None
    email = str(valor).strip()
    if not re.match(r'^[^@]+@[^@]+\.[^@]+$', email):
        return False, f"Email inválido: {email}"
    return True, None


def validar_documento(valor):
    """Valida documento: alfanumérico 5-20 chars"""
    if valor is None or valor == '':
        return True, None
    doc = str(valor).strip()
    if not re.match(r'^[A-Za-z0-9]{5,20}$', doc):
        return False, f"Documento inválido (5-20 alfanum): {valor}"
    return True, None


def validar_nombre(valor):
    """Valida nombre: solo letras y espacios, 2-60"""
    if valor is None or valor == '':
        return True, None
    nombre = str(valor).strip()
    if not re.match(r'^[A-Za-zÁÉÍÓÚáéíóúÑñ\s]{2,60}$', nombre):
        return False, f"Nombre inválido (solo letras 2-60): {valor}"
    return True, None


def validar_telefono(valor):
    """Valida teléfono: dígitos + +()- espacio, 7-20"""
    if valor is None or valor == '':
        return True, None  # Opcional
    tel = str(valor).strip()
    digitos = sum(1 for c in tel if c.isdigit())
    if digitos < 7 or digitos > 20:
        return False, f"Teléfono inválido (7-20 dígitos): {valor}"
    if not re.match(r'^[\d\s+\-()]+$', tel):
        return False, f"Teléfono con caracteres inválidos: {valor}"
    return True, None


def validar_anio(valor):
    """Valida año: 1900-actual"""
    if valor is None or valor == '':
        return True, None
    try:
        anio = int(valor)
        actual = datetime.now().year
        if anio < 1900 or anio > actual:
            return False, f"Año fuera de rango [1900, {actual}]: {valor}"
        return True, None
    except ValueError:
        return False, f"Año inválido: {valor}"


def validar_monto(valor):
    """Valida monto: >= 0, max 2 decimales"""
    if valor is None or valor == '':
        return False, "Monto obligatorio"
    try:
        monto = Decimal(str(valor))
        if monto < 0:
            return False, f"Monto negativo: {valor}"
        # Verificar decimales
        if monto.as_tuple().exponent < -2:
            return False, f"Máximo 2 decimales: {valor}"
        return True, None
    except (InvalidOperation, ValueError):
        return False, f"Monto inválido: {valor}"


# ============================================================
# MOTOR DE VALIDACIÓN PRINCIPAL
# ============================================================

class ExcelValidator:
    def __init__(self, archivo_datos, plantilla_id, resultado_id, config_campos):
        """
        config_campos: lista de dicts desde cfg_campo
        [
            {'campo_id': 1, 'columna_excel': 'A', 'nombre_campo': 'cliente.num_doc',
             'validador': 'val_documento', 'catalogo_tabla': None, 'catalogo_campo': None,
             'obligatorio': 'S', 'formato_excel': 'General', 'longitud_min': 5, 'longitud_max': 20},
            ...
        ]
        """
        self.archivo_datos = Path(archivo_datos)
        self.plantilla_id = plantilla_id
        self.resultado_id = resultado_id
        self.config_campos = config_campos
        self.wb = None
        self.ws = None
        self.errores = []
        self.warnings = []
        self.ok_count = 0
        self.error_count = 0
        
    def validar(self):
        """Ejecuta validación completa"""
        print(f"[INFO] Validando archivo: {self.archivo_datos}")
        print(f"       Plantilla ID: {self.plantilla_id}")
        print(f"       Resultado ID: {self.resultado_id}")
        print(f"       Campos a validar: {len(self.config_campos)}")
        
        # 1. Cargar archivo
        try:
            self.wb = openpyxl.load_workbook(self.archivo_datos, data_only=True)
            self.ws = self.wb.active
        except Exception as e:
            raise ValueError(f"Error cargando archivo: {e}")
        
        # 2. Detectar fila de inicio de datos (buscar fila con tags {{}} o asumir fila 3)
        fila_inicio = self._detectar_fila_inicio()
        print(f"[INFO] Datos inician en fila: {fila_inicio}")
        
        # 3. Validar cada fila
        max_row = self.ws.max_row
        for fila_num in range(fila_inicio, max_row + 1):
            self._validar_fila(fila_num)
        
        # 4. Cerrar
        self.wb.close()
        
        print(f"[OK] Validación completa: {self.ok_count} OK, {self.error_count} ERROR")
        return {
            'total_filas': self.ok_count + self.error_count,
            'filas_ok': self.ok_count,
            'filas_error': self.error_count,
            'detalle': self.errores + self.warnings
        }
    
    def _detectar_fila_inicio(self):
        """Detecta dónde empiezan los datos (después de headers y tags)"""
        # Buscar fila 2 por tags {{}}
        for col in range(1, self.ws.max_column + 1):
            cell = self.ws.cell(row=2, column=col)
            if cell.value and isinstance(cell.value, str) and cell.value.startswith('{{'):
                return 3  # Datos empiezan en fila 3
        return 3  # Default
    
    def _validar_fila(self, fila_num):
        """Valida una fila completa"""
        fila_tiene_error = False
        fila_tiene_datos = False
        
        for campo_cfg in self.config_campos:
            col_letter = campo_cfg['columna_excel']
            col_idx = openpyxl.utils.column_index_from_string(col_letter)
            cell = self.ws.cell(row=fila_num, column=col_idx)
            valor = cell.value
            
            # Normalizar valor
            valor_original = valor
            if valor is not None:
                if isinstance(valor, (int, float, Decimal)):
                    valor_normalizado = str(valor)
                elif isinstance(valor, datetime):
                    valor_normalizado = valor.strftime('%d/%m/%Y')
                else:
                    valor_normalizado = str(valor).strip()
                fila_tiene_datos = True
            else:
                valor_normalizado = ''
            
            # Validar obligatorio
            if campo_cfg['obligatorio'] == 'S' and not valor_normalizado:
                self._registrar_error(fila_num, campo_cfg, valor_original, valor_normalizado,
                                    'ERROR', 'ERR_OBLIGATORIO', 
                                    f"Campo obligatorio vacío: {campo_cfg['encabezado']}",
                                    'REVISAR')
                fila_tiene_error = True
                continue
            
            # Si no obligatorio y vacío, OK
            if not valor_normalizado:
                self._registrar_ok(fila_num, campo_cfg, valor_original, valor_normalizado)
                continue
            
            # Validar según validador
            es_valido, mensaje = self._aplicar_validador(valor_normalizado, campo_cfg)
            
            if es_valido:
                self._registrar_ok(fila_num, campo_cfg, valor_original, valor_normalizado)
            else:
                self._registrar_error(fila_num, campo_cfg, valor_original, valor_normalizado,
                                    'ERROR', self._codigo_error(campo_cfg['validador']),
                                    mensaje, 'CORREGIR')
                fila_tiene_error = True
        
        if fila_tiene_datos and not fila_tiene_error:
            self.ok_count += 1
        elif fila_tiene_datos and fila_tiene_error:
            self.error_count += 1
        # Si no tiene datos, no cuenta
    
    def _aplicar_validador(self, valor, campo_cfg):
        """Aplica el validador correspondiente"""
        validador = campo_cfg['validador']
        cat_tabla = campo_cfg.get('catalogo_tabla')
        cat_campo = campo_cfg.get('catalogo_campo')
        formato = campo_cfg.get('formato_excel', '')
        min_len = campo_cfg.get('longitud_min')
        max_len = campo_cfg.get('longitud_max')
        
        # 1. Catálogo (lista desplegable)
        if validador == 'val_catalogo' and cat_tabla:
            # En Python no tenemos BD, validamos contra lista conocida
            valores = self._obtener_valores_catalogo(cat_tabla, cat_campo)
            return validar_lista(valor, valores)
        
        # 2. Validadores específicos
        if validador == 'val_fecha':
            return validar_tipo_dato(valor, 'date')
        
        if validador == 'val_email':
            return validar_email(valor)
        
        if validador == 'val_documento':
            return validar_documento(valor)
        
        if validador == 'val_nombre':
            return validar_nombre(valor)
        
        if validador == 'val_telefono':
            return validar_telefono(valor)
        
        if validador == 'val_anio':
            return validar_anio(valor)
        
        if validador == 'val_monto':
            return validar_monto(valor)
        
        if validador == 'val_texto':
            # Validar longitud si especificada
            if min_len or max_len:
                return validar_longitud(valor, min_len or 0, max_len or 1000)
            return True, None
        
        # 3. Validación por formato Excel
        if formato == 'DD/MM/YYYY' or '@' in formato:
            return validar_tipo_dato(valor, 'date')
        if formato in ('#,##0.00', '0.00', '#,##0'):
            return validar_tipo_dato(valor, 'decimal')
        if formato == '0':
            return validar_tipo_dato(valor, 'integer')
        
        # Default: texto libre
        if min_len or max_len:
            return validar_longitud(valor, min_len or 0, max_len or 1000)
        
        return True, None
    
    def _obtener_valores_catalogo(self, tabla, campo):
        """Obtiene valores de catálogo (mock - en prod conectar a Informix)"""
        defaults = {
            'cat_tipo_documento': ['DNI', 'LE', 'LC', 'PAS', 'CI', 'RUT', 'CIU'],
            'cat_genero': ['M', 'F', 'X'],
            'cat_estado_civil': ['S', 'C', 'D', 'V', 'U'],
            'cat_moneda': ['ARS', 'USD', 'EUR', 'BRL', 'UYU', 'PYG'],
            'cat_tipo_cuenta': ['AHO', 'CTE', 'CTA_CORRIENTE', 'PLAZO_FIJO', 'CAJA_AHORRO'],
            'cat_ciudad': ['CABA', 'CORD', 'ROS', 'MEND', 'LPLT', 'TUC', 'SAL', 'MVD', 'SCL', 'SPA'],
        }
        return defaults.get(tabla, [])
    
    def _codigo_error(self, validador):
        """Mapea validador a código error estándar"""
        map_err = {
            'val_catalogo': 'ERR_CATALOGO',
            'val_fecha': 'ERR_FECHA',
            'val_email': 'ERR_EMAIL',
            'val_documento': 'ERR_DOCUMENTO',
            'val_nombre': 'ERR_NOMBRE',
            'val_telefono': 'ERR_TELEFONO',
            'val_anio': 'ERR_ANIO',
            'val_monto': 'ERR_MONTO',
            'val_texto': 'ERR_TEXTO',
        }
        return map_err.get(validador, 'ERR_DESCONOCIDO')
    
    def _registrar_ok(self, fila, campo_cfg, valor_orig, valor_norm):
        """Registra validación OK"""
        self.errores.append({
            'resultado_id': self.resultado_id,
            'num_fila': fila,
            'campo_id': campo_cfg['campo_id'],
            'nombre_campo': campo_cfg['nombre_campo'],
            'columna_excel': campo_cfg['columna_excel'],
            'valor_original': str(valor_orig) if valor_orig is not None else '',
            'valor_normalizado': valor_norm,
            'estado': 'OK',
            'codigo_error': None,
            'mensaje': 'OK',
            'accion_sugerida': 'INSERTAR'
        })
    
    def _registrar_error(self, fila, campo_cfg, valor_orig, valor_norm, estado, codigo, mensaje, accion):
        """Registra validación ERROR/WARNING"""
        self.errores.append({
            'resultado_id': self.resultado_id,
            'num_fila': fila,
            'campo_id': campo_cfg['campo_id'],
            'nombre_campo': campo_cfg['nombre_campo'],
            'columna_excel': campo_cfg['columna_excel'],
            'valor_original': str(valor_orig) if valor_orig is not None else '',
            'valor_normalizado': valor_norm,
            'estado': estado,
            'codigo_error': codigo,
            'mensaje': mensaje,
            'accion_sugerida': accion
        })


# ============================================================
# FUNCIÓN MAIN - ENTRY POINT PARA LLAMADA DESDE 4GL
# ============================================================

def main():
    """
    Uso desde 4GL:
    RUN python tools/validar_excel.py archivo.xlsx plantilla_id resultado_id
    
    Lee config_campos desde stdin (JSON) o desde BD via conexión
    Retorna JSON con resultados
    """
    if len(sys.argv) < 4:
        print("Uso: python validar_excel.py <archivo_datos.xlsx> <plantilla_id> <resultado_id> [config_json]")
        sys.exit(1)
    
    archivo_datos = sys.argv[1]
    plantilla_id = int(sys.argv[2])
    resultado_id = int(sys.argv[3])
    
    # Leer config_campos: desde archivo JSON (4to arg) o stdin
    if len(sys.argv) > 4:
        config_path = sys.argv[4]
        with open(config_path, 'r', encoding='utf-8') as f:
            config_campos = json.load(f)
    else:
        # Leer de stdin
        config_campos = json.load(sys.stdin)
    
    try:
        validator = ExcelValidator(archivo_datos, plantilla_id, resultado_id, config_campos)
        resultado = validator.validar()
        
        # Output JSON para que 4GL capture
        print(json.dumps(resultado, ensure_ascii=False, default=str))
        sys.exit(0)
        
    except Exception as e:
        print(json.dumps({'error': str(e)}, ensure_ascii=False))
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()