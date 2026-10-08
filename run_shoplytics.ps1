$ErrorActionPreference = "Stop"

function Invoke-CheckedCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $FilePath $($Arguments -join ' ')"
    }
}

function Test-PipAvailable {
    param([string]$PythonPath)

    try {
        & $PythonPath -m pip --version *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-PythonModules {
    param(
        [string]$PythonPath,
        [string[]]$Modules
    )

    $moduleList = [string]::Join(", ", ($Modules | ForEach-Object { "'$_'" }))
    $code = "import importlib.util, sys; modules = [$moduleList]; missing = [m for m in modules if importlib.util.find_spec(m) is None]; sys.exit(0 if not missing else 1)"

    try {
        & $PythonPath -c $code *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvDir = Join-Path $projectRoot ".venv"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$pythonCommand = "python"
$selectedPython = $pythonCommand

Set-Location $projectRoot

Write-Host "Checking Python installation..."
Invoke-CheckedCommand -FilePath $pythonCommand -Arguments @("--version")

if (-not (Test-Path $venvPython)) {
    Write-Host "Creating virtual environment..."
    & $pythonCommand -m venv $venvDir
}

if ((Test-Path $venvPython) -and (Test-PipAvailable -PythonPath $venvPython)) {
    $selectedPython = $venvPython
    Write-Host "Using virtual environment Python."
}
else {
    Write-Host "Virtual environment pip is unavailable. Falling back to system Python."
    if (-not (Test-PipAvailable -PythonPath $pythonCommand)) {
        throw "pip is not available for either the virtual environment or the system Python."
    }
}

Write-Host "Installing dependencies..."
$requiredModules = @("pandas", "numpy")

if (Test-PythonModules -PythonPath $selectedPython -Modules $requiredModules) {
    Write-Host "Required Python packages already available. Skipping install."
}
else {
    Invoke-CheckedCommand -FilePath $selectedPython -Arguments @("-m", "pip", "install", "--upgrade", "pip")
    Invoke-CheckedCommand -FilePath $selectedPython -Arguments @("-m", "pip", "install", "-r", (Join-Path $projectRoot "requirements.txt"))
}

Write-Host "Running Shoplytics pipeline..."
Invoke-CheckedCommand -FilePath $selectedPython -Arguments @((Join-Path $projectRoot "run_analysis.py"))

Write-Host ""
Write-Host "Done. Output files are available in:" (Join-Path $projectRoot "output")
