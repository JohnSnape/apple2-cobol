# errtest.ps1 - compile-error programs (e33/e14/e34), then the regression set
$s = $PSScriptRoot
foreach ($n in "e33","e14","e34","e35","e36","e38") {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  & "$s\deploy.ps1" -Delete UNTITLED.OBJ | Out-Null
  & "$s\runprog.ps1" -File "$s\progs\$n.cob" -Tag $n -CompileWait 40 -RunWait 4 | Out-Null
}
& "$s\aw.ps1" stop | Out-Null
& "$s\regress.ps1"
