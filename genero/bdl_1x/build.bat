@echo off
REM ============================================================
REM build.bat - Compilación Genero BDL 1.x (Legacy)
REM PlantillasValidadoras4GL
REM ============================================================

SET FGLDIR=C:\Program Files\Fourjs\Genero_1.x
SET PATH=%FGLDIR%\bin;%PATH%
SET DBPATH=.
SET DBDATE=DMY4/
SET DBFORMAT=@.,@,
SET CLIENT_LOCALE=es_AR.850
SET DB_LOCALE=es_AR.850

REM Limpiar compilaciones previas
DEL *.42m *.42f *.ao 2>NUL

ECHO ============================================================
ECHO Compilando PlantillasValidadoras4GL para Genero BDL 1.x
ECHO ============================================================

REM Compilar módulos base
ECHO [1/5] Compilando validacion.4gl...
fglcomp ..\base\validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [2/5] Compilando xml_plantilla.4gl...
fglcomp ..\base\xml_plantilla.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [3/5] Compilando importar_exportar.4gl...
fglcomp ..\base\importar_exportar.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [4/5] Compilando menu_validacion.4gl...
fglcomp ..\base\menu_validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [5/5] Compilando principal.4gl...
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

REM Linkear ejecutable
ECHO Linkando principal.42r...
fglink -o principal.42r principal.42o validacion.42o xml_plantilla.42o importar_exportar.42o menu_validacion.42o

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