@echo off
REM ============================================================
REM build.bat - Compilación Genero BDL 1.x (Legacy)
REM PlantillasValidadoras4GL - 100% 4GL
REM ============================================================

SET FGLDIR=C:\Program Files\Fourjs\Genero_1.x
SET PATH=%FGLDIR%\bin;%PATH%
SET DBPATH=.
SET DBDATE=DMY4/
SET DBFORMAT=@.,@,
SET CLIENT_LOCALE=es_AR.850
SET DB_LOCALE=es_AR.850

DEL *.42m *.42f *.ao 2>NUL

ECHO ============================================================
ECHO Compilando PlantillasValidadoras4GL para Genero BDL 1.x
ECHO ============================================================

ECHO [1/4] Compilando validacion.4gl...
fglcomp ..\base\validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [2/4] Compilando file_compat.4gl...
fglcomp ..\base\file_compat.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [3/4] Compilando spreadsheetml.4gl...
fglcomp ..\base\spreadsheetml.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [4/5] Compilando validador.4gl...
fglcomp ..\base\validador.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [5/6] Compilando test_spreadsheetml.4gl...
fglcomp ..\base\test_spreadsheetml.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [6/6] Compilando principal.4gl...
fglcomp ..\base\principal.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO Linkando principal.42r...
fglink -o principal.42r principal.42o validacion.42o file_compat.42o spreadsheetml.42o validador.42o test_spreadsheetml.42o

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