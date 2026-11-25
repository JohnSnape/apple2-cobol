# procsuite.ps1 - the procedure library (PROCS\*.SNP): deploy it, build a
# test program for each from progs\p*.drv (mkproc.js), compile and run
# each through runfile.ps1, then place DATES with SA-P (plproc.ps1).
# Expected results are in each test's own DISPLAY labels.
$s = $PSScriptRoot
# node: from PATH, or else the copy under %LOCALAPPDATA%
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  $node = @("$env:LOCALAPPDATA\claude-tools\node-v22.14.0-win-x64\node.exe",
    "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\claude-tools\node-v22.14.0-win-x64\node.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $node) { "node not found - put it on PATH"; exit 1 }
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
& "$s\deployprocs.ps1" | Out-Null
$runs = @(
  @{ n = "DATES";  t = "pdates";  w = 15;  k = "" },
  @{ n = "TEXT";   t = "ptext";   w = 25;  k = "" },
  @{ n = "SCREEN"; t = "pscreen"; w = 8;   k = "x~y~7~3~500~42.5~~" },
  @{ n = "MONEY";  t = "pmoney";  w = 150; k = "" },
  @{ n = "WORDS";  t = "pwords";  w = 20;  k = "" }
)
foreach ($r in $runs) {
  & $node "$s\mkproc.js" "$s\progs\$($r.t).drv" "$s\progs\$($r.t).cob" "P:\COBOL\PROCS\$($r.n).SNP" | Out-Null
  & "$s\runfile.ps1" -File "$s\progs\$($r.t).cob" -Name $r.t.ToUpper() -Tag $r.t -CompileWait 50 -RunWait $r.w -Keys $r.k | Out-Null
}
& "$s\plproc.ps1" | Out-Null
& "$s\aw.ps1" stop | Out-Null
"procs done"
