@echo off
setlocal enabledelayedexpansion

:: =============== CONFIGURATION ===============
if "%~1"=="" (
    echo ❌ Usage: %~nx0 "snapshot.txt"
    exit /b 1
)

set "SNAPSHOT_FILE=%~f1"
if not exist "%SNAPSHOT_FILE%" (
    echo ❌ Fichier introuvable : %SNAPSHOT_FILE%
    exit /b 1
)

for %%i in ("%~dp0..\..") do set "COMFYUI_ROOT=%%~fi"
set "CUSTOM_NODES_DIR=%COMFYUI_ROOT%\custom_nodes"
set "VENV_DIR=%COMFYUI_ROOT%\venv"

echo 📁 ComfyUI : %COMFYUI_ROOT%
echo 📄 Snapshot : %SNAPSHOT_FILE%
echo.

:: =============== ÉTAPE 1 : Vérifier l'environnement ===============
echo 🔹 ÉTAPE 1/4 : Vérification de l'environnement

if not exist "%VENV_DIR%" (
    echo ❌ venv manquant : %VENV_DIR%
    exit /b 1
)

call "%VENV_DIR%\Scripts\activate.bat" >nul

for /f "tokens=2" %%a in ('findstr "^Python:" "%SNAPSHOT_FILE%"') do set "PYTHON_EXPECTED=%%a"
for /f "tokens=2,*" %%a in ('findstr "^PyTorch:" "%SNAPSHOT_FILE%"') do set "PYTORCH_EXPECTED=%%a %%b"
for /f "tokens=2" %%a in ('findstr "^CUDA:" "%SNAPSHOT_FILE%"') do set "CUDA_EXPECTED=%%a"

for /f "delims=" %%a in ('python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2^>nul') do set "PYTHON_CURRENT=%%a"
for /f "delims=" %%a in ('python -c "import torch; print(torch.__version__)" 2^>nul') do set "PYTORCH_CURRENT=%%a"
for /f "delims=" %%a in ('python -c "import torch; print(torch.version.cuda or 'N/A')" 2^>nul') do set "CUDA_CURRENT=%%a"

if not defined PYTHON_CURRENT set "PYTHON_CURRENT=N/A"
if not defined PYTORCH_CURRENT set "PYTORCH_CURRENT=N/A"
if not defined CUDA_CURRENT set "CUDA_CURRENT=N/A"

echo    Python : attendu=%PYTHON_EXPECTED% ^| actuel=%PYTHON_CURRENT%
echo    PyTorch: attendu=%PYTORCH_EXPECTED% ^| actuel=%PYTORCH_CURRENT%
echo    CUDA   : attendu=%CUDA_EXPECTED% ^| actuel=%CUDA_CURRENT%

set "MATCH=1"
if not "%PYTHON_EXPECTED%"=="%PYTHON_CURRENT%" set "MATCH=0"
if not "%PYTORCH_EXPECTED%"=="%PYTORCH_CURRENT%" set "MATCH=0"
if not "%CUDA_EXPECTED%"=="%CUDA_CURRENT%" set "MATCH=0"

if %MATCH%==0 (
    echo ⚠️  L'environnement ne correspond pas.
)

set /p "CONFIRM=✅ Continuer vers la sélection des commits ? (O/n) : "
if /i "%CONFIRM%"=="n" (
    echo ❌ Annulé.
    exit /b 1
)
echo.

:: =============== ÉTAPE 2 : Analyser le snapshot (via PowerShell) ===============
echo 🔹 ÉTAPE 2/4 : Détection des commits à mettre à jour...

:: Créer un fichier temporaire pour stocker les actions
set "ACTIONS_FILE=%TEMP%\comfy_actions.txt"
if exist "%ACTIONS_FILE%" del "%ACTIONS_FILE%"

:: Extraire ComfyUI SHA
for /f "tokens=2" %%a in ('findstr "^ComfyUI " "%SNAPSHOT_FILE%" ^| findstr /v "ComfyUI-"') do set "COMFYUI_COMMIT=%%a"
if not defined COMFYUI_COMMIT (
    echo ❌ SHA ComfyUI non trouvé
    exit /b 1
)

:: Vérifier ComfyUI
for /f "delims=" %%a in ('git -C "%COMFYUI_ROOT%" rev-parse HEAD 2^>nul') do set "CURRENT=%%a"
if not "%CURRENT%"=="%COMFYUI_COMMIT%" (
    echo comfyui-core|%COMFYUI_COMMIT%|update|>>"%ACTIONS_FILE%"
)

:: Utiliser PowerShell pour parser les lignes avec SHA
powershell -Command ^
    "$content = Get-Content '%SNAPSHOT_FILE%'; " ^
    "foreach ($line in $content) { " ^
    "  if ($line -match '^([a-zA-Z0-9_.-]+)\s+([a-f0-9]{40})') { " ^
    "    $name = $matches[1]; " ^
    "    $sha = $matches[2]; " ^
    "    if ($name -notin @('__pycache__', 'Python', 'PyTorch', 'CUDA', 'GPU', 'ComfyUI')) { " ^
    "      $url = ''; " ^
    "      $parts = $line -split '\s+', 3; " ^
    "      if ($parts.Count -ge 3 -and $parts[2] -match '^https?://') { $url = $parts[2] } " ^
    "      $nodeDir = '%CUSTOM_NODES_DIR%\$name'; " ^
    "      if (-not (Test-Path \"$nodeDir\.git\")) { " ^
    "        Add-Content '%ACTIONS_FILE%' \"$name|$sha|clone|$url\" " ^
    "      } else { " ^
    "        $current = git -C \"$nodeDir\" rev-parse HEAD 2>$null; " ^
    "        if ($current -ne $sha) { " ^
    "          Add-Content '%ACTIONS_FILE%' \"$name|$sha|update|\" " ^
    "        } " ^
    "      } " ^
    "    } " ^
    "  } " ^
    "}"

:: Lire les actions et afficher le menu
if not exist "%ACTIONS_FILE%" (
    echo    ✅ Tous les commits sont à jour.
    set "HAS_ACTIONS=0"
) else (
    set "HAS_ACTIONS=1"
    echo    📋 Sélectionnez les commits à appliquer :
    set "IDX=0"
    for /f "usebackq tokens=1-4 delims=|" %%a in ("%ACTIONS_FILE%") do (
        set /a IDX+=1
        set "NAME=%%a"
        set "COMMIT=%%b"
        set "TYPE=%%c"
        if "!TYPE!"=="clone" (
            echo    !IDX!. ➕ Cloner : !NAME! @ !COMMIT:~0,8!
        ) else (
            echo    !IDX!. 🔄 Mettre à jour : !NAME! @ !COMMIT:~0,8!
        )
    )
    echo    all. Tous les éléments ci-dessus
    echo.
    set /p "CHOICE=Votre choix (ex: 1 3 5 ou 'all') : "
)

:: =============== ÉTAPE 3 : Appliquer les commits ===============
echo.
echo 🔹 ÉTAPE 3/4 : Application des commits sélectionnés...

set "MODIFIED_NODES_FILE=%TEMP%\comfy_modified.txt"
if exist "%MODIFIED_NODES_FILE%" del "%MODIFIED_NODES_FILE%"

if "%HAS_ACTIONS%"=="1" (
    if "%CHOICE%"=="all" (
        :: Appliquer toutes les actions
        set "IDX=0"
        for /f "usebackq tokens=1-4 delims=|" %%a in ("%ACTIONS_FILE%") do (
            set /a IDX+=1
            call :apply_action "%%a" "%%b" "%%c" "%%d"
        )
    ) else (
        :: Appliquer les choix spécifiés
        for %%n in (%CHOICE%) do (
            set "TARGET_IDX=%%n"
            set "CURR_IDX=0"
            for /f "usebackq tokens=1-4 delims=|" %%a in ("%ACTIONS_FILE%") do (
                set /a CURR_IDX+=1
                if "!CURR_IDX!"=="!TARGET_IDX!" (
                    call :apply_action "%%a" "%%b" "%%c" "%%d"
                )
            )
        )
    )
    echo    ✅ Commits appliqués.
) else (
    echo    ✅ Aucune action nécessaire.
)

:: =============== ÉTAPE 4 : Dépendances ===============
echo.
set /p "CONFIRM_DEPS=✅ Continuer vers la gestion des dépendances ? (O/n) : "
if /i "%CONFIRM_DEPS%"=="n" (
    echo ❌ Annulé.
    exit /b 1
)

echo 🔹 ÉTAPE 4/4 : Installation des dépendances (nodes modifiés)...

if not exist "%MODIFIED_NODES_FILE%" (
    echo    ℹ️  Aucun node modifié → aucune dépendance à installer.
) else (
    for /f "usebackq delims=" %%n in ("%MODIFIED_NODES_FILE%") do (
        set "NAME=%%n"
        set "NODE_DIR=%CUSTOM_NODES_DIR%\!NAME!"
        if exist "!NODE_DIR!" (
            if exist "!NODE_DIR!\install.py" (
                echo      - !NAME! : exécution de install.py
                cd /d "!NODE_DIR!" && python install.py
            ) else if exist "!NODE_DIR!\requirements.txt" (
                echo      - !NAME! : installation via requirements.txt
                findstr /r "^cgal" "!NODE_DIR!\requirements.txt" >nul
                if errorlevel 1 (
                    pip install -r "!NODE_DIR!\requirements.txt"
                ) else (
                    echo        ⚠️ cgal ignoré (bug connu)
                )
            ) else (
                echo      - !NAME! : aucun fichier d'installation trouvé
            )
        )
    )
)

if exist "%COMFYUI_ROOT%\requirements.txt" (
    echo    ℹ️  ComfyUI : requirements.txt présent (pas d'installation auto)
)

echo.
echo ✨ Restauration terminée !
echo 🚀 Redémarrez ComfyUI pour appliquer les changements.
exit /b 0

:: =============== FONCTION : apply_action ===============
:apply_action
set "NAME=%~1"
set "COMMIT=%~2"
set "TYPE=%~3"
set "URL=%~4"

if "%TYPE%"=="clone" (
    echo    Clonage : %NAME%
    mkdir "%CUSTOM_NODES_DIR%" 2>nul
    if not "%URL%"=="" (
        git clone "%URL%" "%CUSTOM_NODES_DIR%\%NAME%" >nul 2>&1
        echo %NAME%>>"%MODIFIED_NODES_FILE%"
    ) else (
        echo    ⚠️ %NAME% : URL manquante, ignoré
    )
) else (
    if "%NAME%"=="comfyui-core" (
        echo    Mise à jour : ComfyUI
        cd /d "%COMFYUI_ROOT%" && git fetch >nul 2>&1 && git checkout "%COMMIT%" >nul 2>&1
    ) else (
        echo    Mise à jour : %NAME%
        cd /d "%CUSTOM_NODES_DIR%\%NAME%" && git fetch >nul 2>&1 && git checkout "%COMMIT%" >nul 2>&1
        echo %NAME%>>"%MODIFIED_NODES_FILE%"
    )
)
exit /b