# a25run.ps1 - 2026-11-22: deploy the room-for-bigger-programs build
# (programs at $8000, p-code in aux; DECISIONS 8.8) and run a22run.ps1
# (which now includes bigpg and sz49), then sdbtest.ps1.
$s = $PSScriptRoot
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
& "$s\deploy.ps1" -Src CMPCON,CMPEMIT,CMPOBJ,CMPPROC4,CMPVAR,CMPFILE,VM,EQUATES2,ERRMSG,COMPILE2 -Obj AUXLC,COBOLSYS,VM,COMPILE1,COMPILE2
& "$s\a22run.ps1"
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
& "$s\sdbtest.ps1"
"a25 finished"
