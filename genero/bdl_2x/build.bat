@echo off
REM ============================================================
REM build.bat - Compilación Genero BDL 2.10/2.11
REM PlantillasValidadoras4GL
REM ============================================================

SET FGLDIR=C:\Program Files\Fourjs\Genero_2.x
SET PATH=%FGLDIR%\bin;%PATH%
SET DBPATH=.
SET DBDATE=DMY4/
SET DBFORMAT=@.,@,
SET CLIENT_LOCALE=es_AR.utf8
SET DB_LOCALE=es_AR.utf8

REM Limpiar
DEL *.42m *.42f *.4gl.42m *.per.42f 2>NUL

ECHO ============================================================
ECHO Compilando PlantillasValidadoras4GL para Genero BDL 2.x
ECHO ============================================================

REM Compilar módulos base con IMPORT FGL
ECHO [1/6] Compilando validacion.4gl...
fglcomp ..\base\validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [2/6] Compilando xml_plantilla.4gl...
fglcomp ..\base\xml_plantilla.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [3/6] Compilando importar_exportar.4gl...
fglcomp ..\base\importar_exportar.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [4/6] Compilando excel_tags.4gl...
fglcomp ..\base\excel_tags.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [5/6] Compilando exportar_formatos.4gl...
fglcomp ..\base\exportar_formatos.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [6/6] Compilando menu_validacion.4gl...
fglcomp ..\base\menu_validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [7/7] Compilando principal.4gl...
fglcomp ..\base\principal.4gl
IF ERRORLEVEL 1 GOTO ERROR

REM Compilar formularios
ECHO Compilando formularios...
fglform ..\base\banco.per
fglform ..\base\consulta.per
fglform ..\base\lote.per
fglform ..\base\menu_validacion.per
fglform ..\base\master_carga.per
fglform ..\base\descargar_tags.per
fglform ..\base\validar_datos.per
fglform ..\base\exportar.per
fglform ..\base\banco_sel.per

REM Linkear (Genero 2.x usa .42m)
ECHO Linkando principal...
fglink -o principal principal.42m validacion.42m xml_plantilla.42m importar_exportar.42m excel_tags.42m exportar_formatos.42m menu_validacion.42m

ECHO.
ECHO ============================================================
ECHO Compilación exitosa! Ejecutar: fglrun principal
ECHO ============================================================
GOTO END

:ERROR
ECHO.
ECHO ============================================================
ECHO ERROR DE COMPILACIÓN
ECHO ============================================================
PAUSE

:END