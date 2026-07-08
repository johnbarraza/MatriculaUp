# MatriculaUp — Script de Release para GitHub
# Requiere: GitHub CLI (gh) instalado y autenticado con `gh auth login`
# Uso: ejecutar desde la raíz del repositorio MatriculaUp

param(
    [string]$Tag = "v1.2.0",
    [string]$Title = "MatriculaUp $Tag - Horarios 2026-II"
)

$SetupPath = "dist\MatriculaUp_$($Tag)_Setup.exe"
$ZipPath = "dist\MatriculaUp_$($Tag)_Portable.zip"
$ReleaseDir = "matriculaup_app\build\windows\x64\runner\Release"
$JsonPath = "input\courses_2026-2_v1.json"

$Notes = @"
## MatriculaUp $Tag - Horarios 2026-II

Planificador de horarios universitarios para estudiantes de UP.

### Novedades en esta versión
- Apellido del profesor visible en cada bloque del horario semanal
- Etiqueta **Profs:** en negrita en los resultados de búsqueda
- Contador de horas semanales (Clases + Prácticas) en la barra superior
- Botón ⚙️ Configuración para cargar/actualizar JSONs en cualquier momento
- Exportar horario como PNG 📷
- Etiquetas Obligatorio/Electivo cuando se carga Plan de Estudios
- Fix: secciones G-M de cursos con continuación de página ahora aparecen correctamente en el horario

### Instrucciones de instalación
1. Descarga y ejecuta `MatriculaUp_v1.2_Setup.exe` (el instalador hará todo por ti)
2. El instalador descargará y dejará la app lista con el `courses_2026-2_v1.json` incluido
3. Abre MatriculaUp desde el acceso directo en tu Escritorio

> El JSON puede actualizarse desde dentro de la app (Configuración ⚙️) cuando salgan nuevos horarios.

*Opcional: Si no quieres instalar nada, descarga la versión `_Portable.zip`, descomprímela y ejecuta el .exe de adentro.*
"@

Write-Host "Comprimiendo versión portable en $ZipPath..."
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Force -Path @("$ReleaseDir\*", $JsonPath) -DestinationPath $ZipPath

Write-Host "Creando release $Tag en GitHub..."
gh release create $Tag `
    "$SetupPath" `
    "$ZipPath" `
    "$JsonPath" `
    --title "$Title" `
    --notes "$Notes" `
    --latest

Write-Host "Release creado: https://github.com/johnbarraza/MatriculaUp/releases/tag/$Tag"
