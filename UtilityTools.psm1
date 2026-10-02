#  UtilityTools.psm1 - loader only.
# Every .ps1 in .\Functions\ becomes a command in this module.

$FunctionFolder = Join-Path $PSScriptRoot 'Functions'

if (Test-Path $FunctionFolder) {
    foreach ($file in (Get-ChildItem -Path $FunctionFolder -Filter '*.ps1' -File)) {
        . $file.FullName
    }
}