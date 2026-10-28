<#
.SYNOPSIS
    Summarise an Nginx access log (combined log format).

.DESCRIPTION
    Reports the top N IP addresses, requested paths, response status codes
    and user agents. Windows counterpart of analyse-logs.sh; works in
    Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER LogFile
    Path to the Nginx access log.

.PARAMETER Top
    Number of entries to show per section (default: 5).

.EXAMPLE
    .\analyse-logs.ps1 .\sample\access.sample.log

.EXAMPLE
    .\analyse-logs.ps1 -LogFile C:\logs\access.log -Top 10
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$LogFile,

    [ValidateRange(1, 1000000)]
    [int]$Top = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LogFile -PathType Leaf)) {
    throw "Cannot read '$LogFile'"
}
# .NET resolves relative paths against the process directory, not the
# PowerShell location, so resolve to a full path first.
$fullPath = (Resolve-Path -LiteralPath $LogFile).ProviderPath

# Ordinal comparer = case-sensitive keys (a PowerShell [hashtable] is not).
$ordinal = [System.StringComparer]::Ordinal
$ips      = [System.Collections.Generic.Dictionary[string, int]]::new($ordinal)
$paths    = [System.Collections.Generic.Dictionary[string, int]]::new($ordinal)
$statuses = [System.Collections.Generic.Dictionary[string, int]]::new($ordinal)
$agents   = [System.Collections.Generic.Dictionary[string, int]]::new($ordinal)

function Add-Count {
    param($Counter, [string]$Key)
    if ($Counter.ContainsKey($Key)) { $Counter[$Key]++ } else { $Counter[$Key] = 1 }
}

# Combined log format:
# IP - user [date] "METHOD /path HTTP/x" status size "referrer" "user agent"
$pattern = [regex]::new(
    '^(?<ip>\S+) \S+ \S+ \[[^\]]+\] "(?<req>[^"]*)" (?<status>\d{3}) \S+ "(?<ref>[^"]*)" "(?<ua>[^"]*)"',
    [System.Text.RegularExpressions.RegexOptions]::Compiled)

$skipped = 0
foreach ($line in [System.IO.File]::ReadLines($fullPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $m = $pattern.Match($line)
    if (-not $m.Success) { $skipped++; continue }

    $parts = $m.Groups['req'].Value.Split(' ')
    $path = if ($parts.Count -ge 2 -and $parts[1]) { $parts[1] } else { '-' }
    $agent = if ($m.Groups['ua'].Value) { $m.Groups['ua'].Value } else { '-' }

    Add-Count $ips      $m.Groups['ip'].Value
    Add-Count $paths    $path
    Add-Count $statuses $m.Groups['status'].Value
    Add-Count $agents   $agent
}

if ($skipped -gt 0) {
    Write-Warning "Skipped $skipped malformed line(s)"
}

function Show-Top {
    param([string]$Title, $Counter)

    Write-Output $Title
    Write-Output ''
    $Counter.GetEnumerator() |
        Sort-Object -Property @{ Expression = 'Value'; Descending = $true },
                              @{ Expression = 'Key';   Descending = $false } |
        Select-Object -First $Top |
        ForEach-Object {
            $noun = if ($_.Value -eq 1) { 'request' } else { 'requests' }
            '{0} - {1} {2}' -f $_.Key, $_.Value, $noun
        }
}

Show-Top "Top $Top IP addresses with the most requests:" $ips
Write-Output ''
Show-Top "Top $Top most requested paths:" $paths
Write-Output ''
Show-Top "Top $Top response status codes:" $statuses
Write-Output ''
Show-Top "Top $Top user agents:" $agents
