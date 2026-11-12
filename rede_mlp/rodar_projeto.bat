@echo off
setlocal EnableDelayedExpansion
rem ====================================================================
rem  RODAR_PROJETO.BAT  (Windows)
rem  Dois cliques: procura o MATLAB ou o GNU Octave no computador,
rem  oferece instalar o Octave se nenhum dos dois existir, e roda o
rem  projeto (rodar_projeto.m desta pasta, rede MLP).
rem ====================================================================
cd /d "%~dp0"
title Reconhecimento de DIREITA e ESQUERDA - rede neural MLP

echo.
echo  Reconhecimento das palavras DIREITA e ESQUERDA com rede neural MLP
echo  ------------------------------------------------------------------
echo     1 - rodar o programa 2 com a rede ja treinada  [cerca de 3 minutos]
echo     2 - refazer tudo do zero: segmentacao, treino e programa 2  [cerca de 10 minutos]
echo.
choice /c 12 /n /m "Escolha 1 ou 2: "
set "COMANDO=rodar_projeto"
if errorlevel 2 set "COMANDO=rodar_projeto('tudo')"

rem ---- 1. MATLAB ------------------------------------------------------
set "MATLAB="
for /f "delims=" %%i in ('where matlab 2^>nul') do if not defined MATLAB set "MATLAB=%%i"
if not defined MATLAB goto procura_octave
echo.
echo  MATLAB encontrado: !MATLAB!
"!MATLAB!" -batch "cd('%~dp0'); !COMANDO!"
goto fim

rem ---- 2. GNU Octave --------------------------------------------------
:procura_octave
call :achar_octave
if defined OCTAVE goto roda_octave

echo.
echo  Nenhum MATLAB ou GNU Octave foi encontrado neste computador.
where winget >nul 2>nul
if errorlevel 1 goto sem_winget
choice /c SN /m " Instalar o GNU Octave agora pelo winget, cerca de 400 MB"
if errorlevel 2 goto fim
winget install --id GNU.Octave -e --accept-package-agreements --accept-source-agreements
call :achar_octave
if defined OCTAVE goto roda_octave
echo.
echo  O Octave foi instalado, mas nao foi encontrado. Feche esta janela e
echo  rode o rodar_projeto.bat de novo.
goto fim

:sem_winget
echo  Instale o GNU Octave pelo site https://octave.org/download
echo  e depois rode o rodar_projeto.bat de novo.
goto fim

:roda_octave
echo.
echo  GNU Octave encontrado: !OCTAVE!
"!OCTAVE!" --no-gui --quiet --eval "!COMANDO!"
goto fim

:fim
echo.
pause
exit /b

rem ---- Procura o octave.exe nas pastas onde o instalador costuma colocar
:achar_octave
set "OCTAVE="
for /d %%d in ("%LOCALAPPDATA%\Programs\GNU Octave\Octave-*" "%ProgramFiles%\GNU Octave\Octave-*" "C:\Octave\Octave-*") do (
    if exist "%%~d\mingw64\bin\octave.exe" set "OCTAVE=%%~d\mingw64\bin\octave.exe"
)
if not defined OCTAVE for /f "delims=" %%i in ('where octave.exe 2^>nul') do if not defined OCTAVE set "OCTAVE=%%i"
exit /b
