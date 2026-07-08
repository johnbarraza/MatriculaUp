# MatriculaUp - Script de Release para GitHub
# Requiere: GitHub CLI (gh) instalado y autenticado con `gh auth login`
# Uso: ejecutar desde la raiz del repositorio MatriculaUp

param(
    [string]$Tag = "v1.2.0",
    [string]$Title = "MatriculaUp $Tag - Horarios 2026-II"
)

$SetupPath = "dist\MatriculaUp_$($Tag)_Setup.exe"
$ZipPath = "dist\MatriculaUp_$($Tag)_Portable.zip"
$ReleaseDir = "matriculaup_app\build\windows\x64\runner\Release"
$JsonPath = "input\courses_2026-2_v1.json"
$EfeJsonPath = "input\efe_courses_2026-2_v1.json"

$Notes = @"
## MatriculaUp $Tag - Horarios 2026-II

Planificador de horarios universitarios para estudiantes de UP.

### Novedades en esta version
- Oferta regular 2026-II V1 incluida.
- EFEs/SSU 2026-II V1 incluidos.
- Calendario academico 2026-II incluido.
- Profesor visible en cada bloque del horario semanal.
- Configuracion para cargar/actualizar JSONs en cualquier momento.
- Exportar horario como PNG.

### Instrucciones de instalacion
1. Descarga y ejecuta el instalador.
2. El instalador deja la app lista con `courses_2026-2_v1.json` y `efe_courses_2026-2_v1.json`.
3. Abre MatriculaUp desde el acceso directo en tu Escritorio.

El JSON puede actualizarse desde dentro de la app cuando salgan nuevos horarios.

Opcional: Si no quieres instalar nada, descarga la version `_Portable.zip`, descomprimela y ejecuta el .exe de adentro.
"@

Write-Host "Comprimiendo version portable en $ZipPath..."
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Force -Path @("$ReleaseDir\*", $JsonPath, $EfeJsonPath) -DestinationPath $ZipPath

Write-Host "Creando release $Tag en GitHub..."
gh release create $Tag `
    "$SetupPath" `
    "$ZipPath" `
    "$JsonPath" `
    "$EfeJsonPath" `
    --title "$Title" `
    --notes "$Notes" `
    --latest

Write-Host "Release creado: https://github.com/johnbarraza/MatriculaUp/releases/tag/$Tag"
