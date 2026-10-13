#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
insertar_tags.py
Inserta tags {{campo}} en las celdas de una plantilla Excel según config JSON.
Mantiene el diseño original (formato, estilos, validaciones, etc).

Uso: python insertar_tags.py <config.json> <plantilla.xlsx> <salida.xlsx>
"""

import sys
import json
import shutil
from pathlib import Path
import openpyxl
from openpyxl.styles import Font

def insertar_tags(config_path, plantilla_path, salida_path):
    """Inserta tags en la plantilla según config JSON"""
    try:
        # Cargar config
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)

        # Copiar plantilla
        shutil.copy2(plantilla_path, salida_path)

        # Abrir copia
        wb = openpyxl.load_workbook(salida_path)
        ws = wb[config['hoja']]

        fila_tags = config['fila_tags']

        # Insertar tags en fila especificada
        for campo in config['campos']:
            col = campo['columna']
            cell = ws[f"{col}{fila_tags}"]
            tag = "{{" + campo['tag'] + "}}"
            cell.value = tag
            cell.font = Font(bold=True, color="003366", size=8, italic=True)

        wb.save(salida_path)
        wb.close()

        print(f"[OK] Tags insertados en {salida_path}")
        print(f"     Hoja: {config['hoja']}")
        print(f"     Fila tags: {fila_tags}")
        print(f"     Fila datos: {config['fila_datos']}")
        print(f"     Campos: {len(config['campos'])}")
        return True

    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    if len(sys.argv) < 4:
        print("Uso: python insertar_tags.py <config.json> <plantilla.xlsx> <salida.xlsx>")
        sys.exit(1)

    config_path = sys.argv[1]
    plantilla_path = sys.argv[2]
    salida_path = sys.argv[3]

    if not Path(config_path).exists():
        print(f"[ERROR] Config no encontrado: {config_path}")
        sys.exit(1)

    if not Path(plantilla_path).exists():
        print(f"[ERROR] Plantilla no encontrada: {plantilla_path}")
        sys.exit(1)

    exito = insertar_tags(config_path, plantilla_path, salida_path)
    sys.exit(0 if exito else 1)

if __name__ == "__main__":
    main()