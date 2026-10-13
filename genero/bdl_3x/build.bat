@echo off
REM ============================================================
REM build.bat - Compilación Genero BDL 3.x
REM PlantillasValidadoras4GL - 100% 4GL
REM ============================================================

SET FGLDIR=C:\Program Files\Fourjs\Genero_3.x
SET PATH=%FGLDIR%\bin;%PATH%
SET DBPATH=.
SET DBDATE=DMY4/
SET DBFORMAT=@.,@,
SET CLIENT_LOCALE=es_AR.utf8
SET DB_LOCALE=es_AR.utf8
SET FGLLDPATH=..\base;%FGLLDPATH%

DEL *.42m *.42f *.4gl.42m *.per.42f 2>NUL

ECHO ============================================================
ECHO Compilando PlantillasValidadoras4GL para Genero BDL 3.x
ECHO ============================================================

ECHO [1/4] Compilando validacion.4gl...
fglcomp ..\base\validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [2/4] Compilando validacion_dinamica.4gl...
fglcomp ..\base\validacion_dinamica.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [3/4] Compilando spreadsheetml.4gl...
fglcomp ..\base\spreadsheetml.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [4/4] Compilando validador.4gl...
fglcomp ..\base\validador.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [5/5] Compilando principal.4gl...
fglcomp ..\base\principal.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO Linkando principal...
fglink -o principal principal.42m validacion.42m validacion_dinamica.42m spreadsheetml.42m validador.42m

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