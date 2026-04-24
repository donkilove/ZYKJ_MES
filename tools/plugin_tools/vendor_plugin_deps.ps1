param(
  [string]$PluginName = 'serial_assistant'
)

$pluginDir = Join-Path $PSScriptRoot "..\..\plugins\$PluginName"
$vendorDir = Join-Path $pluginDir "vendor"
$requirements = Join-Path $pluginDir "requirements-dev.txt"

if (Test-Path $vendorDir) {
  Remove-Item -Recurse -Force $vendorDir
}

python -m pip install --no-compile --target $vendorDir -r $requirements
