@echo off
REM ============================================================
REM build.bat - Compilacion Genero BDL 4.x
REM PlantillasValidadoras4GL - 100% 4GL
REM ============================================================

SET FGLDIR=C:\Program Files\Fourjs\Genero_4.x
SET PATH=%FGLDIR%\bin;%PATH%
SET DBPATH=.
SET DBDATE=DMY4/
SET DBFORMAT=@.,@,
SET CLIENT_LOCALE=es_AR.utf8
SET DB_LOCALE=es_AR.utf8
SET FGLLDPATH=..\base;%FGLLDPATH%

DEL *.42m *.42f *.4gl.42m *.per.42f 2>NUL

ECHO ============================================================
ECHO Compilando PlantillasValidadoras4GL para Genero BDL 4.x
ECHO ============================================================

ECHO [1/5] Compilando validacion.4gl...
fglcomp ..\base\validacion.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [2/5] Compilando file_compat.4gl...
fglcomp ..\base\file_compat.4gl
IF ERRORLEVEL 1 GOTO ERROR

ECHO [3/5] Compilando spreadsheetml.4gl...
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

ECHO Linkando principal...
fglink -o principal principal.42m validacion.42m file_compat.42m spreadsheetml.42m validador.42m test_spreadsheetml.42m

ECHO.
ECHO ============================================================
ECHO Compilacion exitosa! Ejecutar: fglrun principal
ECHO Nota GBC: en modo web usar fglrun --web o Genero Application Server
ECHO ============================================================
GOTO END

:ERROR
ECHO.
ECHO ============================================================
ECHO ERROR DE COMPILACION
ECHO ============================================================
PAUSE

:END