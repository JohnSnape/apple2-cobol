# runfile.ps1 - like runprog.ps1, but the program goes onto the volume as
# NAME.COB (TXT, CR line ends) and EDIT opens it with OA-O instead of
# having every character typed - a 150-line program in seconds.
#   runfile.ps1 -File progs\x.cob -Name X -Tag x [-CompileWait 45]
#               [-RunWait 10] [-Keys "..."] [-Steps "KEYS|TAG",...]
# -Keep leaves NAME.OBJ on the volume, for tools/pdis.js.
# Leaves AppleWin stopped.  Screenshots <tag>-compile.png, <tag>-run.png.
param([string]$File, [string]$Name, [string]$Tag = "t", [int]$CompileWait = 45,
      [int]$RunWait = 10, [string]$Keys = "", [string[]]$Steps = @(), [switch]$Keep)
$s = $PSScriptRoot
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
A stop; Start-Sleep 1
$w = Join-Path $PSScriptRoot "runfile-stage"
if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force $w | Out-Null
$text = (Get-Content $File | ForEach-Object { $_.TrimEnd() }) -join "`r"
[IO.File]::WriteAllText("$w\$Name.COB#040000", $text + "`r", [Text.Encoding]::ASCII)
Push-Location $w
& $cp2 delete $img "$Name.OBJ" 2>$null | Out-Null
& $cp2 add --overwrite --from-naps $img "$Name.COB#040000" | Out-Null
Pop-Location
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
A keys "1"; Start-Sleep 4
A raw "%o"; Start-Sleep 1; A keys "$Name.COB~"; Start-Sleep 6
A raw "{ESC}"; Start-Sleep 4
A keys "5"; Start-Sleep $CompileWait
A shot "$s\$Tag-compile.png"
A keys " "; Start-Sleep 2
A keys "6"; Start-Sleep 3
A keys "$Name~"; Start-Sleep $RunWait
if ($Keys) { A keys $Keys; Start-Sleep $RunWait }
A shot "$s\$Tag-run.png"
# -Steps "KEYS|TAG",...: more keys after the run, a screenshot after each
# (2026-11-11, for the screen paging and the menu)
foreach ($st in $Steps) {
  $p = $st.Split('|')
  if ($p[0]) { A keys $p[0] }
  Start-Sleep $RunWait
  if ($p.Count -gt 1 -and $p[1]) { A shot "$s\$($p[1]).png" }
}
A stop; Start-Sleep 1
# the root directory holds 51 entries: leave no test files behind
& $cp2 delete $img "$Name.COB" 2>$null | Out-Null
if (-not $Keep) { & $cp2 delete $img "$Name.OBJ" 2>$null | Out-Null }
"done: $Tag"
