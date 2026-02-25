# scripts/build_installer.ps1
$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$localIsccPath = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
$issFile = "installer\MatriculaUp.iss"

# Check if ISCC.exe is available in path instead of just the default location
if (-not (Test-Path $isccPath)) {
    if (Test-Path $localIsccPath) {
        $isccPath = $localIsccPath
    }
    else {
        $isccCmd = Get-Command iscc -ErrorAction SilentlyContinue
        if ($isccCmd) {
            $isccPath = $isccCmd.Source
        }
    }
}

if (Test-Path $isccPath) {
    Write-Host "Building installer using $isccPath"
    & $isccPath $issFile
}
else {
    Write-Error "Inno Setup 6 (ISCC.exe) not found. Please install Inno Setup 6 to build the installer."
    Write-Host "Download from: https://jrsoftware.org/isdl.php"
    exit 1
}
