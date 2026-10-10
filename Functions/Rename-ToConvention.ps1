function Rename-ToConvention {
    <#
    .SYNOPSIS
    Enforces naming convention: spaces/hyphens become single underscores, every word capitalized.
    .DESCRIPTION
    Renames files and folders so runs of spaces/hyphens/underscores collapse to one
    underscore and each underscore-separated word starts with a capital letter.
    Already-correct names are skipped. Collisions with other items are skipped with a warning.
    .PARAMETER Path
    Folder to clean. Default: current location.
    .PARAMETER Recurse
    Include all subfolders (deepest first, so child folders rename before parents).
    .PARAMETER Preview
    Show what would change without renaming anything.
    .PARAMETER Help
    Shows examples for this command.
    .EXAMPLE
    Rename-ToConvention -Preview
    .EXAMPLE
    Rename-ToConvention
    .EXAMPLE
    Rename-ToConvention -Path "D:\Audits\IBF\2025-2026" -Recurse
    #>
    param(
        [string]$Path = (Get-Location),
        [switch]$Recurse,
        [switch]$Preview,
        [switch]$Help
    )
    if ($Help) { Get-Help $MyInvocation.MyCommand.Name -Examples; return }

    if (-not (Test-Path $Path)) {
        Write-Host "Path not found: $Path" -ForegroundColor Red
        return
    }

    # Sort by length descending so child items rename before their parent folders
    $items = Get-ChildItem -Path $Path -Recurse:$Recurse |
             Sort-Object { $_.FullName.Length } -Descending

    $changed = 0
    $skipped = 0
    $locked = 0 # New counter for files locked by other processes

    foreach ($item in $items) {
        $oldName = $item.Name
        $newName = $oldName -replace '[ _-]+', '_'

        $newName = ($newName -split '_' | ForEach-Object {
            if ($_.Length -gt 0) { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }
            else { $_ }
        }) -join '_'

        # Skip if the name is already in the correct convention
        if ($newName -ceq $oldName) { continue }

        $newFull = Join-Path (Split-Path $item.FullName -Parent) $newName

        # Skip if a file with the new name already exists (collision)
        if ((Test-Path -LiteralPath $newFull) -and ($newFull -ne $item.FullName)) {
            Write-Host "  SKIP (exists): $oldName" -ForegroundColor DarkYellow
            $skipped++
            continue
        }

        if ($Preview) {
            Write-Host "  would rename: $oldName  ->  $newName" -ForegroundColor Cyan
            $changed++
        } 
        else {
            try {
                # -ErrorAction Stop forces PowerShell to trigger the 'catch' block on failure
                Rename-Item -LiteralPath $item.FullName -NewName $newName -ErrorAction Stop
                Write-Host "  renamed: $oldName  ->  $newName" -ForegroundColor Green
                $changed++
            }
            catch {
                # Catches "used by another process" or "access denied" errors gracefully
                Write-Warning "  skipped (locked): '$oldName' is in use by another process or access denied."
                $locked++
            }
        }
    }

    # Final Summary Output
    if ($Preview) { 
        Write-Host "`nPreview: $changed item(s) would be renamed." -ForegroundColor Cyan 
    }
    else { 
        Write-Host "`nDone: $changed renamed, $skipped skipped (collision), $locked skipped (locked)." -ForegroundColor Green 
    }
}