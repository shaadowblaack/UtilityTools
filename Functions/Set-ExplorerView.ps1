function Set-ExplorerView {
    <#
    .SYNOPSIS
    Sets Details as the default view for all folders, and Tiles for This PC.
    .DESCRIPTION
    Stops Explorer first, then deletes ALL saved per-folder views (Bags) so no folder
    can override the default, writes Details as the default for every folder type,
    restarts Explorer, and pins This PC to Tiles. Run once per machine.
    Only touches HKCU (no admin needed). Closes open Explorer windows.
    .PARAMETER NoReset
    Keep existing per-folder custom views (folders with saved views will NOT change).
    .PARAMETER Help
    Shows examples for this command.
    .EXAMPLE
    Set-ExplorerView
    .EXAMPLE
    Set-ExplorerView -NoReset
    #>
    param(
        [switch]$NoReset,
        [switch]$Help
    )
    if ($Help) { Get-Help $MyInvocation.MyCommand.Name -Examples; return }

    # 1) Explorer MUST be dead before touching Bags, or it recreates/locks them
    Write-Host "Stopping Explorer..." -ForegroundColor DarkYellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # 2) Wipe every saved per-folder view so defaults win everywhere (incl. subfolders)
    if (-not $NoReset) {
        foreach ($p in @(
                'HKCU:\Software\Microsoft\Windows\Shell\Bags',
                'HKCU:\Software\Microsoft\Windows\Shell\BagMRU',
                'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags',
                'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Streams\Defaults'
            )) {
            if (Test-Path $p) {
                Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  cleaned: $p" -ForegroundColor DarkGray
            }
        }
    }

    # 3) Write Details (LogicalViewMode 3) as default for every folder type
    Write-Host "Writing Details default for all folder types..." -ForegroundColor Cyan
    $types = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes' -ErrorAction SilentlyContinue |
        ForEach-Object PSChildName)
    if (-not $types) { $types = @('{5C4F28B5-F869-4E84-8E60-F11DB97C5CC7}') }

    foreach ($base in @(
            'HKCU:\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell',
            'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Streams\Defaults'
        )) {
        foreach ($t in $types) {
            $k = Join-Path $base $t
            New-Item -Path $k -Force | Out-Null
            Set-ItemProperty -Path $k -Name 'LogicalViewMode' -Value 3 -Type DWord
            Set-ItemProperty -Path $k -Name 'IconSize' -Value 16 -Type DWord
        }
    }

    # 4) Bring Explorer back
    Start-Process explorer.exe
    Start-Sleep -Seconds 3

    # 5) This PC -> Tiles (5), saved as its one and only custom view
    Start-Process explorer.exe '::{20D04FE0-3AEA-1069-A2D8-08002B30309D}'
    Start-Sleep -Seconds 2
    $done = $false
    try {
        $shell = New-Object -ComObject Shell.Application
        $win = $shell.Windows() | Where-Object { $_.LocationUrl -like '*20D04FE0*' } | Select-Object -First 1
        if ($win) {
            try { $win.Document.FolderView.ViewMode = 5; $done = $true }
            catch { try { $win.Document.ViewMode = 5; $done = $true } catch { } }
            if ($done) { $win.Quit() }
        }
    }
    catch { }

    if ($done) { Write-Host "This PC pinned to Tiles." -ForegroundColor Green }
    else {
        Write-Host "In the This PC window that just opened: click View > Tiles ONCE." -ForegroundColor Yellow
        Write-Host "It will stick, because everything else now defaults to Details." -ForegroundColor Yellow
    }
    Write-Host "Done. Every folder (at any depth) = Details, This PC = Tiles." -ForegroundColor Green
}