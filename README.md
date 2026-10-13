# PlantillasValidadoras4GL

Sistema bancario **100% Genero 4GL** para validar datos entre Excel (SpreadsheetML) e Informix 14.10. Sin Python.

## Flujo

```
1. Usuario abre template .xls con tags {{campo}} en Excel
2. Llena datos y guarda como archivo datos
3. En Genero: carga archivo -> valida con val_* -> muestra resultado
4. Si OK -> exporta archivo limpio sin tags
5. Si ERROR -> genera archivo con hoja Datos (rojo) + hoja Errores (motivo)
```

## Estructura

```
PlantillasValidadoras4GL/
├── db/
│   ├── 01_esquema.sql          # Tablas base (cliente, cuenta, catalogos)
│   ├── 02_tablas.sql           # Tabla banco
│   ├── 03_catalogos.sql        # Datos semilla
│   ├── 04_sp_xml.sql           # SPs XML (genxmlqueryhdr)
│   └── reglas_validacion.sql   # Reglas dinamicas
├── genero/
│   ├── base/
│   │   ├── principal.4gl          # Menu: validar, ver, exportar, tests
│   │   ├── spreadsheetml.4gl      # Leer/escribir SpreadsheetML
│   │   ├── validador.4gl          # Validar archivo con val_*
│   │   ├── validacion.4gl         # Funciones val_* (core)
│   │   ├── validacion_dinamica.4gl# Reglas BD
│   │   ├── file_compat.4gl        # Archivos compatible 1.x/2.x/3.x
│   │   └── test_spreadsheetml.4gl # 9 tests
│   ├── bdl_1x/build.bat
│   ├── bdl_2x/build.bat
│   └── bdl_3x/build.bat
├── plantillas/
│   ├── plantilla_minima.xls    # Template con tags (input)
│   ├── plantilla_datos.xls     # Datos validos (input)
│   ├── plantilla_errores.xls  # Datos con errores + hoja Errores
│   └── plantilla_generada.xls # Ejemplo generado
├── salida/
│   └── datos_validados.xls     # Output limpio sin tags
└── README.md
```

## Instalacion

### 1. BD Informix 14.10
```bash
dbaccess sysmaster db/01_esquema.sql
dbaccess banco db/02_tablas.sql
dbaccess banco db/03_catalogos.sql
dbaccess banco db/04_sp_xml.sql
dbaccess banco db/reglas_validacion.sql
```

### 2. Genero (cualquiera de las 3 versiones)
```cmd
cd genero\bdl_2x
build.bat
fglrun principal
```

## Validadores

| Validador | Regla |
|-----------|-------|
| `val_nombre` | Solo letras, 2-60 |
| `val_documento` | Alfanumerico, 5-20 |
| `val_fecha` | DD/MM/YYYY, 1900-hoy |
| `val_email` | Con @ y dominio |
| `val_telefono` | 7-20 digitos |
| `val_anio` | 1900-actual |
| `val_monto` | >= 0, max 2 decimales |
| `val_catalogo` | Existe en tabla |

## Compatibilidad

Codigo compatible con Genero BDL 1.x, 2.x y 3.x (sin base.Channel, sin IMPORT FGL).
