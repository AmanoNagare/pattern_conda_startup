$ErrorActionPreference = "Stop"
$userInput = Read-Host "Conda環境名を入力してください"
if ([string]::IsNullOrWhiteSpace($userInput)) {
    Write-Host "error" -ForegroundColor Red
    exit 1
}
$envName = $userInput.Trim()
if(-not (Get-Command "code" -ErrorAction SilentlyContinue)){
    $vscodeDefaultPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"
    if (Test-Path "$vscodeDefaultPath\code.cmd") {
        $env:Path += ";$vscodeDefaultPath"
    } else {
        $vsInstallerPath = "$env:TEMP\VSCodeUserSetup.exe"
        Invoke-WebRequest -Uri "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -OutFile $vsInstallerPath
        Start-Process -FilePath $vsInstallerPath -ArgumentList "/verysilent", "/mergetasks=!runcode,addtopath" -Wait
        Remove-Item -Path $vsInstallerPath -Force
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

$minicondaDir = "$env:USERPROFILE\miniconda3"
$condaHook    = "$minicondaDir\shell\condabin\conda-hook.ps1"

if(-not (Test-Path "$minicondaDir\Scripts\conda.exe")){
    $miniInstallerPath = "$env:TEMP\Miniconda3-latest-Windows-x86_64.exe"
    $miniUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
    Invoke-WebRequest -Uri $miniUrl -OutFile $miniInstallerPath
    Start-Process -FilePath $miniInstallerPath -ArgumentList "/InstallationType=JustMe", "/RegisterPython=0", "/S", "/D=$minicondaDir" -Wait
    Remove-Item -Path $miniInstallerPath -Force
    & "$minicondaDir\Scripts\conda.exe" init powershell
}

$workDir   = Join-Path $HOME "work\pr"
$vscodeDir = Join-Path $workDir ".vscode"

if (-not (Test-Path $workDir))   { New-Item -ItemType Directory -Path $workDir -Force | Out-Null }
if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null }
$extensions = @(
    "ms-python.python",
    "ms-python.vscode-pylance",
    "charliermarsh.ruff"
)
foreach ($ext in $extensions) {
    code --install-extension $ext --force
}
& $condaHook
$targetEnvPath = "$minicondaDir\envs\$envName"
if (-not (Test-Path $targetEnvPath)) {
    conda create -n $envName --override-channels -c conda-forge `
        python=3.11 opencv numpy tqdm face_recognition "setuptools<70" -y
}
$escapedPython    = "$targetEnvPath\python.exe" -replace '\\', '/'
$escapedCondaHook = $condaHook -replace '\\', '/'
$settingsJson = @"
{
    "python.defaultInterpreterPath": "$escapedPython",
    "python.terminal.activateEnvironment": true,
    "python.locator": "environmentVariables",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": "explicit"
    },
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff"
    },
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "terminal.integrated.profiles.windows": {
        "PowerShell": {
            "source": "PowerShell",
            "args": [
                "-NoExit",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                "& '$escapedCondaHook'; conda activate $envName"
            ]
        }
    }
}
"@
Set-Content -Path (Join-Path $vscodeDir "settings.json") -Value $settingsJson -Encoding UTF8
$testFile = Join-Path $workDir "test_env.py"
$sampleCode = @"
import cv2
import numpy as np
import face_recognition
from tqdm import tqdm
print(" OpenCV Version   :", cv2.__version__)
print(" NumPy Version    :", np.__version__)
print(" face_recognition : Loaded successfully")
"@
Set-Content -Path $testFile -Value $sampleCode -Encoding UTF8
Set-Location -Path $workDir
code . "test_env.py"