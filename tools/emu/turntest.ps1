# turntest.ps1 - Utilities 7, Create a TURNKEY disk, then boot it alone.
# TURN.po is a blank 800K ProDOS volume, /NEWDISK (cp2 cdi TURN.po 800k prodos).
# progs\beta1.cob is compiled first, so UNTITLED.OBJ prints 000055.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"
A stop; Start-Sleep 1
& "$s\deploy.ps1" -Delete UNTITLED.OBJ | Out-Null
& "$s\runprog.ps1" -File "$s\progs\beta1.cob" -Tag tk-beta -CompileWait 40 -RunWait 6 | Out-Null
A stop; Start-Sleep 1
Remove-Item "$s\TURN.po" -ErrorAction SilentlyContinue
& $cp2 cdi "$s\TURN.po" 800k prodos | Out-Null
A start "D:\AppleWin1.32.0.0\COBOL32.po;$s\TURN.po"; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
A keys "8"; Start-Sleep 2; A keys "7"; Start-Sleep 1
A keys "UNTITLED~"; Start-Sleep 1; A shot "$s\tk-ask.png"
A keys "/NEWDISK~"; Start-Sleep 25; A shot "$s\tk-made.png"
A keys " "; Start-Sleep 1
A stop; Start-Sleep 1
& $cp2 catalog "$s\TURN.po"
# the turnkey disk on its own
A start "$s\TURN.po"; Start-Sleep 3; A raw "{F2}"; Start-Sleep 8
A shot "$s\tk-boot.png"
A keys "~"; Start-Sleep 1; A keys "~"; Start-Sleep 6
A shot "$s\tk-run.png"
A keys " "; Start-Sleep 4
A shot "$s\tk-quit.png"
A stop
"done"
