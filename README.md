# PlantillasValidadoras4GL

Sistema bancario para **importar, validar y exportar** datos entre Excel e Informix 14.10 usando Genero BDL 4GL.

## Flujo Principal

```
1. (Una vez por plantilla) Menú 2: Configurar Nueva Plantilla
   → Sube Excel → Wizard detecta columnas → Asignas validador a cada una → Guarda JSON

2. Usuario elige banco → Sistema carga config JSON (campos, validadores)
3. Usuario descarga plantilla con tags {{campo}} → Llena datos en Excel
4. Usuario sube archivo → Sistema valida cada campo (val_* 4GL + reglas BD)
5. Si OK → exporta a cualquier formato (XLSX, CSV, XML, PDF, HTML)
6. Si ERROR → muestra errores → usuario corrige → reintenta
```

## Estructura Simplificada

```
PlantillasValidadoras4GL/
├── config/
│   ├── nacion_clientes.json    # Definición campos/validadores por banco
│   └── galicia_cuentas.json     # (agregar más bancos aquí)
├── plantillas/                 # Excel maestras por banco
├── plantillas_tags/            # Copias generadas con tags
├── plantillas_datos/           # Usuario llena y sube
├── plantillas_errores/         # Salida con errores
├── salida/                     # Exportaciones finales
├── genero/
│   ├── base/
│   │   ├── validacion.4gl      # Funciones val_* (core)
│   │   ├── validacion_dinamica.4gl  # Reglas BD
│   │   ├── importar_exportar.4gl    # Import/Export
│   │   ├── xml_plantilla.4gl   # Parseo XML
│   │   └── principal.4gl       # Menú simple
│   ├── bdl_1x/ bdl_2x/ bdl_3x/  # Build scripts
├── tools/
│   ├── insertar_tags.py        # Agregar tags a plantilla
│   ├── validar_excel.py        # Leer Excel y retornar datos
│   ├── generar_errores_excel.py # Crear archivo con hoja ERRORES
│   └── exportar_xlsx.py        # Exportar resultados
├── db/
│   ├── 01_esquema.sql          # Tablas base
│   ├── 03_catalogos.sql        # Catálogos
│   ├── 04_sp_xml.sql           # SPs XML
│   └── reglas_validacion.sql   # Reglas dinámicas
└── README.md
```

## Configuración por Banco

Cada banco tiene un JSON en `config/` que define:

```json
{
  "banco": "nacion",
  "archivo_maestra": "plantillas/nacion_clientes.xlsx",
  "hoja": "Clientes",
  "fila_tags": 2,
  "fila_datos": 3,
  "campos": [
    {"columna": "A", "tag": "tipo_doc", "validador": "val_catalogo", "obligatorio": true},
    {"columna": "B", "tag": "num_doc", "validador": "val_documento", "obligatorio": true}
  ]
}
```

## Instalación

### 1. Base de Datos (Informix 14.10)
```bash
docker start ifx
dbaccess sysmaster db/01_esquema.sql
dbaccess banco db/03_catalogos.sql
dbaccess banco db/04_sp_xml.sql
dbaccess banco db/reglas_validacion.sql
```

### 2. Python
```bash
pip install openpyxl
```

### 3. Genero 4GL
```cmd
cd genero\bdl_2x
build.bat
fglrun principal
```

## Uso Rápido

```cmd
REM 1. Generar plantilla con tags
python tools\insertar_tags.py config\nacion_clientes.json plantillas\nacion_clientes.xlsx plantillas_tags\nacion_tags.xlsx

REM 2. Usuario llena plantilla_tags\nacion_tags.xlsx en Excel

REM 3. En Genero: cargar archivo, validar, exportar
```

## Validadores Disponibles

| Validador | Descripción |
|-----------|-------------|
| `val_nombre` | Solo letras, 2-60 chars |
| `val_documento` | Alfanumérico, 5-20 chars |
| `val_fecha` | DD/MM/YYYY, rango 1900-hoy |
| `val_email` | Formato email con @ y dominio |
| `val_telefono` | 7-20 dígitos, +() - espacio |
| `val_anio` | Entero 1900-año actual |
| `val_monto` | Decimal >= 0, max 2 decimales |
| `val_catalogo` | Valor existe en tabla catálogo |
| `val_texto` | Texto libre con longitud opcional |