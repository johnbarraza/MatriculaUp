# scripts/build_flutter_exe.ps1

Write-Host "=========================================="
Write-Host "   ⚙️ Building MatriculaUp (Flutter) ⚙️   "
Write-Host "=========================================="

# Navigate to the flutter app directory
$rootDir = (Get-Item -Path ".\").FullName
$appDir = Join-Path -Path $rootDir -ChildPath "matriculaup_app"

if (-not (Test-Path -Path $appDir)) {
    Write-Error "Could not find matriculaup_app directory. Are you running this from the repository root?"
    exit 1
}

Set-Location -Path $appDir

Write-Host "`n[1/3] Cleaning previous builds..."
flutter clean

Write-Host "`n[2/3] Fetching dependencies..."
flutter pub get

Write-Host "`n[3/3] Compiling Release executable..."
# Try to build windows release. If Developer Mode is missing on Windows, this will throw an error related to symlinks.
flutter build windows --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Build Successful!"
    $releaseDir = Join-Path -Path $appDir -ChildPath "build\windows\x64\runner\Release"
    Write-Host "Executable is located at: $releaseDir\MatriculaUp.exe"
}
else {
    Write-Host "`n❌ Build Failed. Check the error log above."
    Write-Host "If the error mentions 'Developer Mode', please enable it in your Windows Settings > Privacy & security > For developers."
}

# Return to root directory
Set-Location -Path $rootDir
