#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
validar_config.py
Valida que un archivo JSON de configuración de banco tenga la estructura correcta.

Uso: python validar_config.py <config.json>
"""

import sys
import json
from pathlib import Path

CAMPOS_REQUERIDOS_JSON = ['banco', 'archivo_maestra', 'hoja', 'fila_tags', 'fila_datos', 'campos']
CAMPOS_REQUERIDOS_CAMPO = ['columna', 'tag', 'encabezado', 'validador', 'obligatorio']
VALIDADORES_VALIDOS = [
    'val_nombre', 'val_documento', 'val_fecha', 'val_email',
    'val_telefono', 'val_anio', 'val_monto', 'val_catalogo', 'val_texto'
]

def validar_config(config_path):
    """Valida estructura del JSON de configuración"""
    errores = []

    # Cargar JSON
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        return [f"JSON inválido: {e}"]
    except Exception as e:
        return [f"Error leyendo archivo: {e}"]

    # Validar campos requeridos
    for campo in CAMPOS_REQUERIDOS_JSON:
        if campo not in config:
            errores.append(f"Campo requerido faltante: '{campo}'")

    if errores:
        return errores

    # Validar tipos
    if not isinstance(config['banco'], str) or not config['banco'].strip():
        errores.append("'banco' debe ser string no vacío")

    if not isinstance(config['fila_tags'], int) or config['fila_tags'] < 1:
        errores.append("'fila_tags' debe ser entero >= 1")

    if not isinstance(config['fila_datos'], int) or config['fila_datos'] < 1:
        errores.append("'fila_datos' debe ser entero >= 1")

    if not isinstance(config['campos'], list):
        errores.append("'campos' debe ser una lista")
        return errores

    # Validar cada campo
    for i, campo in enumerate(config['campos']):
        # Campos requeridos en cada campo
        for req in CAMPOS_REQUERIDOS_CAMPO:
            if req not in campo:
                errores.append(f"Campo #{i+1}: falta '{req}'")

        # Validar validador
        if 'validador' in campo:
            if campo['validador'] not in VALIDADORES_VALIDOS:
                errores.append(
                    f"Campo #{i+1} ({campo.get('tag', '?')}): "
                    f"validador '{campo['validador']}' no válido. "
                    f"Opciones: {', '.join(VALIDADORES_VALIDOS)}"
                )

        # Validar catálogo si aplica
        if campo.get('validador') == 'val_catalogo':
            if not campo.get('catalogo_tabla') or not campo.get('catalogo_campo'):
                errores.append(
                    f"Campo #{i+1} ({campo.get('tag', '?')}): "
                    f"val_catalogo requiere 'catalogo_tabla' y 'catalogo_campo'"
                )

        # Validar obligatorio es boolean
        if 'obligatorio' in campo:
            if not isinstance(campo['obligatorio'], bool):
                errores.append(f"Campo #{i+1}: 'obligatorio' debe ser true/false")

    # Validar columnas únicas
    columnas = [c.get('columna') for c in config['campos'] if 'columna' in c]
    duplicadas = [c for c in columnas if columnas.count(c) > 1]
    if duplicadas:
        errores.append(f"Columnas duplicadas: {', '.join(set(duplicadas))}")

    return errores

def main():
    if len(sys.argv) < 2:
        print("Uso: python validar_config.py <config.json>")
        sys.exit(1)

    config_path = sys.argv[1]

    if not Path(config_path).exists():
        print(f"[ERROR] Archivo no encontrado: {config_path}")
        sys.exit(1)

    print(f"Validando: {config_path}")
    print("-" * 50)

    errores = validar_config(config_path)

    if not errores:
        print("[OK] Configuración válida")
        sys.exit(0)
    else:
        print(f"[ERROR] {len(errores)} errores encontrados:")
        for err in errores:
            print(f"  - {err}")
        sys.exit(1)

if __name__ == "__main__":
    main()