# PlantillasValidadoras4GL

Sistema bancario completo para **importar, validar y exportar** datos entre Excel e Informix 14.10 usando Genero BDL 4GL.

## 🎯 Flujo Principal (5 Opciones)

```
┌─────────────────────────────────────────────────────────────────────┐
│              PLANTILLAS VALIDADORAS 4GL - MENÚ                      │
├─────────────────────────────────────────────────────────────────────┤
│  1. 🏦 SELECCIONAR BANCO / PLANTILLA                                │
│     └─ Lista bancos activos → Elige plantilla parametrizada         │
│                                                                     │
│  2. 📥 CARGAR PLANTILLA MASTER (XLS/XLSX SIN TAGS)                 │
│     └─ Usuario sube master → Sistema genera MAESTRA CON TAGS       │
│        automáticos + validaciones Excel nativas + hoja Listas      │
│     └─ Mensaje: "✅ Plantilla maestra creada: <archivo>"           │
│                                                                     │
│  3. 📤 DESCARGAR PLANTILLA CON TAGS (PARA LLENAR DATOS)            │
│     └─ Genera .xlsx limpio con tags {{campo}} en fila 2            │
│        Validaciones: listas, fechas, rangos, formatos              │
│     └─ Usuario la llena en Excel → Guarda como archivo datos       │
│                                                                     │
│  4. ✅ CARGAR Y VALIDAR DATOS (CORE DEL SISTEMA)                   │
│     └─ Lee archivo → Valida (doble capa: Excel + 4GL)              │
│     ├── ✅ TODO OK → Muestra grilla → [Guardar BD] [Exportar]      │
│     └── ❌ CON ERRORES → Genera mismo archivo + hoja "ERRORES"     │
│          (Fila, Campo, Valor, Error, Acción Sugerida)              │
│          → Usuario corrige y reintenta                             │
│                                                                     │
│  5. 📊 EXPORTAR RESULTADOS (MÚLTIPLES FORMATOS)                    │
│     └─ XLSX | CSV | XML SpreadsheetML | PDF | HTML                │
└─────────────────────────────────────────────────────────────────────┘
```

## 🏗️ Arquitectura

```
PlantillasValidadoras4GL/
├── db/                          # Scripts BD Informix 14.10
│   ├── 01_esquema.sql           # Tablas base (cliente, cuenta, catálogos)
│   ├── 02_tablas.sql            # Tabla banco + estilos
│   ├── 02_tablas_validacion.sql # NUEVO: cfg_plantilla, cfg_campo, validacion_*
│   ├── 03_catalogos.sql         # Datos semilla
│   ├── 04_sp_xml.sql            # SPs XML (genxmlqueryhdr)
│   ├── 05_sp_validacion.sql     # NUEVO: SPs validación (iniciar, registrar, finalizar)
│   └── reglas_validacion.sql    # Reglas dinámicas por campo
│
├── genero/
│   ├── base/                    # Código fuente canónico (compatible 1.x/2.x/3.x)
│   │   ├── principal.4gl        # Menú principal
│   │   ├── menu_validacion.4gl  # NUEVO: Lógica 5 opciones
│   │   ├── excel_tags.4gl       # NUEVO: Auto-tags + validación Python
│   │   ├── exportar_formatos.4gl# NUEVO: Export XLSX/CSV/XML/PDF/HTML
│   │   ├── validacion.4gl       # Funciones val_* (nombre, fecha, email, etc.)
│   │   ├── validacion_dinamica.4gl # Motor reglas BD
│   │   ├── importar_exportar.4gl # Import/Export CSV/XML/HTML
│   │   ├── xml_plantilla.4gl    # Parseo SpreadsheetML
│   │   ├── logs.4gl             # Sistema logging
│   │   └── *.per                # Formularios
│   ├── bdl_1x/                  # Genero 1.x (legacy)
│   ├── bdl_2x/                  # Genero 2.10/2.11
│   └── bdl_3x/                  # Genero 3.x
│
├── tools/                       # Herramientas Python
│   ├── excel_template_processor.py  # Procesador tags {{tag}} + Named Ranges
│   ├── auto_tag_master.py         # NUEVO: Master → Maestra con tags
│   ├── validar_excel.py           # NUEVO: Validación nativa Excel (Capa 1)
│   ├── generar_errores_excel.py   # NUEVO: Archivo + hoja ERRORES
│   ├── exportar_xlsx.py           # NUEVO: Export XLSX completo
│   ├── generate_tagged_template.py # Generar plantilla desde query
│   └── registro_bancos.py         # Registro multi-banco (JSON)
│
├── plantillas_base/             # Masters originales (sin tags)
├── plantillas_maestras/         # Generadas con tags (automático)
├── plantillas_datos/            # Para que usuario llene
├── plantillas_procesadas/       # Con datos válidos
├── plantillas_errores/          # Con hoja ERRORES
└── salida/                      # Exportaciones finales
```

## 🗄️ Base de Datos (Informix 14.10)

### Tablas Nuevas
- **cfg_plantilla**: Configuración plantillas por banco
- **cfg_campo**: Definición columnas (tag, validador, catálogo, formato)
- **validacion_resultados**: Cabecera cada validación
- **validacion_detalle**: Una fila por celda validada (OK/ERROR)

### SPs Principales
- `sp_obtener_config_plantilla()` → XML config completa
- `sp_obtener_campos_plantilla()` → XML campos ordenados
- `sp_iniciar_validacion()` → Crea cabecera validación
- `sp_registrar_validacion()` → Registra cada celda
- `sp_finalizar_validacion()` → Actualiza contadores/estado
- `sp_obtener_errores_export()` → XML para hoja ERRORES
- `sp_obtener_datos_validos()` → XML datos OK para exportar/cargar
- `sp_insertar_datos_validados()` → INSERT transaccional en BD

## 🔧 Validación Doble Capa

| Capa | Qué valida | Tecnología |
|------|------------|------------|
| **1. Excel Nativa** | Tipos, listas dropdown, rangos, formatos, fórmulas | openpyxl DataValidation |
| **2. 4GL Negocio** | Reglas BD: EXISTE_BD, UNIQUE, FORMATO_DOCUMENTO, REGEX | `validacion.4gl` + `validacion_dinamica.4gl` |

## 🚀 Instalación Rápida

### 1. Base de Datos (Informix 14.10 Developer)
```bash
# Docker recomendado
docker pull icr.io/informix/informix-developer-database:14.10.FC9W1DE
docker run -d --name ifx -h ifx --privileged -e LICENSE=accept \
  -e DBSERVERNAME=oltp -p 9088:9088 -p 9089:9089 \
  icr.io/informix/informix-developer-database:14.10.FC9W1DE

# Ejecutar scripts en orden
dbaccess sysmaster db/01_esquema.sql
dbaccess banco db/02_tablas.sql
dbaccess banco db/02_tablas_validacion.sql
dbaccess banco db/03_catalogos.sql
dbaccess banco db/04_sp_xml.sql
dbaccess banco db/05_sp_validacion.sql
dbaccess banco db/reglas_validacion.sql
dbaccess banco db/05_datos_prueba.sql
```

### 2. Python (para herramientas)
```bash
pip install openpyxl
```

### 3. Genero 4GL (elige tu versión)
```cmd
cd genero\bdl_2x   (o bdl_1x / bdl_3x)
build.bat
fglrun principal
```

## 📋 Requisitos

| Componente | Versión | Notas |
|------------|---------|-------|
| Informix | 14.10 Developer/Innovator | `idsxmlvp` para SPs XML |
| Genero BDL | 1.x / 2.10+ / 3.x | 3 versiones soportadas |
| Python | 3.8+ | `openpyxl` para herramientas |
| Excel | 2003+ | Abre XML SpreadsheetML y .xlsx |
| OS | Windows (GDC) / Linux | Docker para Informix |

## 📖 Documentación

- `README.md` - Este archivo
- `db/*.sql` - Scripts BD comentados
- `genero/base/*.4gl` - Código 4GL documentado
- `tools/*.py` - Herramientas Python con docstrings

## 🔄 Flujo Completo de Uso

1. **Admin** configura banco en `registro_bancos.py` → `bancos_config.json`
2. **Usuario** abre Genero → Opción 1: Selecciona banco/plantilla
3. **Admin** Opción 2: Sube master Excel → Sistema genera maestra con tags
4. **Usuario** Opción 3: Descarga plantilla con tags → Llena en Excel
5. **Usuario** Opción 4: Carga archivo lleno → Validación automática
   - OK → Grilla datos → [Guardar BD] / [Exportar]
   - ERROR → Archivo con hoja ERRORES → Corrige → Reintenta
6. **Usuario** Opción 5: Exporta a XLSX/CSV/XML/PDF/HTML

## 📝 Licencia

Proyecto interno - Solo desarrollo/pruebas.
Informix Developer Edition: solo desarrollo/test (no producción).