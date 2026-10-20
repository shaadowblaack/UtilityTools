function Get-Updates {
    <#
    .SYNOPSIS
    Checks the ICAB notice board and prints clean summaries of new notices.
    .EXAMPLE
    Get-Updates -ICAB
    Get-Updates -ICAB -Latest 3
    #>
    param(
        [switch]$ICAB,
        [switch]$All,
        [switch]$Notify,
        [switch]$Reset,
        [int]$Latest = 0,
        [switch]$Help
    )
    if ($Help) { Get-Help $MyInvocation.MyCommand.Name -Examples; return }

    function Wrap-Text {
        param([string]$Text, [int]$Width = 75)
        if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
        $words = $Text -split '\s+'
        $lines = [System.Collections.ArrayList]@()
        $currentLine = ""
        
        foreach ($word in $words) {
            if (($currentLine.Length + $word.Length + 1) -gt $Width) {
                [void]$lines.Add($currentLine.Trim())
                $currentLine = $word
            } else {
                if ($currentLine) { $currentLine += " " }
                $currentLine += $word
            }
        }
        if ($currentLine.Trim()) { [void]$lines.Add($currentLine.Trim()) }
        return $lines
    }

    function Show-NoticeDetail {
        param($n)
        
        Write-Host ""
        Write-Host "  [$($n.category)]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($n.title)" -ForegroundColor Cyan
        Write-Host "  Published: $($n.date)" -ForegroundColor DarkGray
        
        if ($n.summary) {
            Write-Host ""
            Write-Host "  Summary:" -ForegroundColor White
            $wrapped = Wrap-Text $n.summary 75
            foreach ($line in $wrapped) {
                Write-Host "    $line" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "  $('-' * 70)" -ForegroundColor DarkGray
    }

    $python = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $python) { Write-Host "Python not found." -ForegroundColor Red; return }
    $script = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\get_updates.py'

    $sources = @()
    if ($ICAB) { $sources += 'icab' }
    if ($All -or (-not $ICAB)) { $sources += 'icab' }

    foreach ($src in $sources) {
        $pyArgs = @($script, '--source', $src, '--json')
        if ($Reset) { $pyArgs += '--reset' }
        if ($Latest -gt 0) { $pyArgs += @('--latest', $Latest) }

        $res = & $python @pyArgs 2>$null | ConvertFrom-Json
        if ($res.error) { Write-Host "[$src] ERROR: $($res.error)" -ForegroundColor Red; continue }

        if ($Latest -gt 0) {
            Write-Host "`n[$src] Latest $($res.latest.Count) notice(s):" -ForegroundColor Cyan
            foreach ($n in $res.latest) { Show-NoticeDetail $n }
            continue
        }

        if ($res.reset) { Write-Host "[$src] history cleared." -ForegroundColor Yellow; continue }
        if ($res.first_run) {
            Write-Host "[$($res.name)] baseline saved: $($res.known_count) notices." -ForegroundColor Cyan
            Write-Host "Most recent on record:" -ForegroundColor DarkGray
            foreach ($r in $res.recent) { Write-Host "  - $($r.title) ($($r.date))" -ForegroundColor Gray }
            continue
        }
        if (-not $res.new -or $res.new.Count -eq 0) {
            Write-Host "[$($res.name)] no new notices." -ForegroundColor Green
            continue
        }

        Write-Host "`n[$($res.name)] NEW $($res.new.Count) notice(s):" -ForegroundColor Yellow
        foreach ($n in $res.new) { Show-NoticeDetail $n }

        if ($Notify -and (Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue)) {
            New-BurntToastNotification -Text "ICAB Updates", "$($res.new.Count) new notice(s)! Check terminal."
        }
    }
}