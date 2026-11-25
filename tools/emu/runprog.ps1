# runprog.ps1 - boot COBOL32.po, type a .cob file into EDIT, compile, run.
#   runprog.ps1 -File prog.txt -Tag beta  [-RunWait 15] [-Keys "..."]
# Screenshots: <tag>-compile.png, <tag>-run.png in the scratchpad.
param([string]$File, [string]$Tag = "t", [int]$CompileWait = 25, [int]$RunWait = 12, [string]$Keys = "")
$s = $PSScriptRoot
$lines = Get-Content $File | ForEach-Object { $_.TrimEnd() }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
& "$s\aw.ps1" raw "{F2}" | Out-Null; Start-Sleep 6
& "$s\aw.ps1" keys "1" | Out-Null; Start-Sleep 4
& "$s\aw.ps1" keys ($lines -join "~") | Out-Null; Start-Sleep ([Math]::Max(6, [int]($lines.Count / 2)))
& "$s\aw.ps1" raw "{ESC}" | Out-Null; Start-Sleep 4
& "$s\aw.ps1" keys "5" | Out-Null; Start-Sleep $CompileWait
& "$s\aw.ps1" shot "$s\$Tag-compile.png" | Out-Null
& "$s\aw.ps1" keys " " | Out-Null; Start-Sleep 2
& "$s\aw.ps1" keys "6" | Out-Null; Start-Sleep 3
& "$s\aw.ps1" keys "UNTITLED~" | Out-Null; Start-Sleep $RunWait
if ($Keys) { & "$s\aw.ps1" keys $Keys | Out-Null; Start-Sleep $RunWait }
& "$s\aw.ps1" shot "$s\$Tag-run.png" | Out-Null
"done: $Tag"
