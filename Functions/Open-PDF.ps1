function Open-Pdf {
    <#
    .SYNOPSIS
    Opens PDF files with Okular.
    .DESCRIPTION
    Accepts PDF files or folders (all PDFs inside get opened).
    Uses the hardcoded path "C:\Program Files\Okular\bin\okular.exe" by default.
    All PDFs open in a single Okular instance (in tabs).
    .PARAMETER Path
    PDF files or folders containing PDFs. Default: current folder.
    .PARAMETER Recurse
    When Path is a folder, include PDFs in subfolders too.
    .PARAMETER OkularPath
    Full path to okular.exe, if you want to override the default.
    .PARAMETER Help
    Shows examples for this command.
    .EXAMPLE
    Open-Pdf
    .EXAMPLE
    Open-Pdf .\Auditors_Report.pdf
    .EXAMPLE
    Open-Pdf "D:\Audits\IBF\2025-2026\3100_Client_Provided" -Recurse
    #>
    param(
        [Parameter(Position = 0)]
        [string[]]$Path = (Get-Location),
        [switch]$Recurse,
        [string]$OkularPath,
        [switch]$Help
    )
    if ($Help) { Get-Help $MyInvocation.MyCommand.Name -Examples; return }

    # ---- locate okular.exe (hardcoded exact path first) ----
    if (-not $OkularPath) {
        $onPath = Get-Command okular.exe -ErrorAction SilentlyContinue
        if ($onPath) { $OkularPath = $onPath.Source }
    }
    if (-not $OkularPath) {
        $OkularPath = @(
            'C:\Program Files\Okular\bin\okular.exe',  # <-- Your exact path
            "$env:ProgramFiles\Okular\bin\okular.exe",
            "${env:ProgramFiles(x86)}\Okular\bin\okular.exe",
            "$HOME\scoop\apps\okular\current\okular.exe",
            "$HOME\AppData\Local\Programs\Okular\okular.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    
    # Registry fallback just in case
    if (-not $OkularPath) {
        $uninst = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                                   'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
                  Where-Object { $_.DisplayName -like '*Okular*' } | Select-Object -First 1
        if ($uninst -and $uninst.InstallLocation) {
            $OkularPath = @(
                (Join-Path $uninst.InstallLocation 'okular.exe'),
                (Join-Path $uninst.InstallLocation 'bin\okular.exe')
            ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        }
    }

    if (-not $OkularPath -or -not (Test-Path $OkularPath)) {
        Write-Host "Okular not found at C:\Program Files\Okular\bin\okular.exe." -ForegroundColor Red
        return
    }

    # ---- collect the PDFs ----
    $pdfs = @()
    foreach ($p in $Path) {
        $item = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
        if (-not $item) { Write-Host "Not found: $p" -ForegroundColor DarkYellow; continue }
        
        if ($item.PSIsContainer) {
            $pdfs += Get-ChildItem -LiteralPath $item.FullName -Filter *.pdf -Recurse:$Recurse -File
        }
        elseif ($item.Extension -eq '.pdf') { 
            $pdfs += $item 
        }
        else { 
            Write-Host "Skipped (not a PDF): $($item.Name)" -ForegroundColor DarkYellow 
        }
    }
    
    if (-not $pdfs) { Write-Host "No PDF files found." -ForegroundColor Yellow; return }

    # ---- open everything in one Okular instance ----
    $argList = ($pdfs | ForEach-Object { "`"$($_.FullName)`"" }) -join ' '
    Start-Process -FilePath $OkularPath -ArgumentList $argList
    Write-Host "Opened $($pdfs.Count) PDF(s) in Okular." -ForegroundColor Green
}