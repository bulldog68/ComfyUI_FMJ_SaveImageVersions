@echo off
REM restore_snapshot.bat
REM Usage: restore_snapshot.bat "chemin\vers\fichier.snapshot.txt"

setlocal enabledelayedexpansion

REM === Vérification argument ===
if "%~1"=="" (
    echo ❌ Usage: %0 "chemin\vers\fichier.snapshot.txt"
    exit /b 1
)
set "SNAPSHOT_FILE=%~1"

REM === Convertir en chemin absolu si relatif ===
if not "%SNAPSHOT_FILE:~0,1%"=="\" (
    set "SNAPSHOT_FILE=%CD%\%SNAPSHOT_FILE%"
)

if not exist "%SNAPSHOT_FILE%" (
    echo ❌ Fichier introuvable : %SNAPSHOT_FILE%
    exit /b 1
)

REM === Détection racine ComfyUI (2 niveaux) ===
for %%i in ("%~dp0..\..") do set "COMFYUI_ROOT=%%~fi"

echo 📁 Racine ComfyUI : %COMFYUI_ROOT%
echo 📄 Snapshot : %SNAPSHOT_FILE%
echo.

REM === Activation venv ===
set "VENV_DIR=%COMFYUI_ROOT%\venv"
if not exist "%VENV_DIR%" (
    echo ❌ Dossier venv introuvable : %VENV_DIR%
    echo 💡 Créez-le avec : python -m venv venv
    exit /b 1
)

echo ➡️ Activation du venv...
call "%VENV_DIR%\Scripts\activate.bat"
echo ✅ Venv activé.
echo.

REM === Lecture versions attendues ===
for /f "tokens=2" %%a in ('findstr "^Python:" "%SNAPSHOT_FILE%"') do set "PYTHON_EXPECTED=%%a"
for /f "tokens=2,*" %%a in ('findstr "^PyTorch:" "%SNAPSHOT_FILE%"') do set "PYTORCH_EXPECTED=%%a %%b"
for /f "tokens=2" %%a in ('findstr "^CUDA:" "%SNAPSHOT_FILE%"') do set "CUDA_EXPECTED=%%a"

echo 📦 Versions attendues :
echo    Python : %PYTHON_EXPECTED%
echo    PyTorch: %PYTORCH_EXPECTED%
echo    CUDA   : %CUDA_EXPECTED%
echo.

REM === Versions actuelles (dans venv) ===
for /f "delims=" %%a in ('python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2^>nul') do set "PYTHON_CURRENT=%%a"

python -c "import torch" >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%a in ('python -c "import torch; print(torch.__version__)" 2^>nul') do set "PYTORCH_CURRENT=%%a"
    for /f "delims=" %%a in ('python -c "import torch; print(torch.version.cuda or 'N/A')" 2^>nul') do set "CUDA_CURRENT=%%a"
) else (
    set "PYTORCH_CURRENT=non installé"
    set "CUDA_CURRENT=N/A"
)

echo ⚙️ Versions actuelles :
echo    Python : %PYTHON_CURRENT%
echo    PyTorch: %PYTORCH_CURRENT%
echo    CUDA   : %CUDA_CURRENT%
echo.

REM === Confirmation ===
set "MATCH=1"
if not "%PYTHON_EXPECTED%"=="%PYTHON_CURRENT%" set "MATCH=0"
if not "%PYTORCH_EXPECTED%"=="%PYTORCH_CURRENT%" set "MATCH=0"
if not "%CUDA_EXPECTED%"=="%CUDA_CURRENT%" set "MATCH=0"

if %MATCH% equ 0 (
    echo ⚠️ ATTENTION : L'environnement NE CORRESPOND PAS.
    set /p "CONFIRM=Continuer quand même ? (o/N) : "
    if /i not "%CONFIRM%"=="o" (
        echo ❌ Annulé.
        exit /b 1
    )
) else (
    set /p "CONFIRM=Continuer la restauration ? (O/n) : "
    if /i "%CONFIRM%"=="n" (
        echo ❌ Annulé.
        exit /b 1
    )
)

REM === Restauration ComfyUI ===
for /f "tokens=2" %%a in ('findstr "^ComfyUI " "%SNAPSHOT_FILE%" ^| findstr /v "ComfyUI-"') do set "COMFYUI_COMMIT=%%a"

if "%COMFYUI_COMMIT%"=="" (
    echo ❌ Commit ComfyUI non trouvé.
    exit /b 1
)

echo.
echo 🔄 Restauration de ComfyUI @ %COMFYUI_COMMIT:~0,8%...
cd /d "%COMFYUI_ROOT%"
git fetch
git checkout %COMFYUI_COMMIT%
echo ✅ ComfyUI restauré.
echo.

REM === Restauration custom nodes (basique) ===
echo 🔄 Restauration des custom nodes (manuelle recommandée sous Windows)...
echo ⚠️ Ce script ne restaure pas automatiquement les nodes sous Windows.
echo    Utilisez WSL ou copiez-les manuellement.
echo.

REM === Dépendances ===
echo 📥 Installation des dépendances...
pip install -r requirements.txt

echo.
echo ✅ Restauration terminée (partielle sous Windows) !
echo 🚀 Redémarrez ComfyUI.