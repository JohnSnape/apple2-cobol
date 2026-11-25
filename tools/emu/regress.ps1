# regress.ps1 - every small test program, one after another, screenshots as <name>-r-run.png
$s = $PSScriptRoot
$tests = @(
  @{ f = "beta1.cob"; t = "beta1-r"; k = "" },
  @{ f = "conds.cob"; t = "conds-r"; k = "" },
  @{ f = "money.cob"; t = "money-r"; k = "250.75~" },
  @{ f = "files.cob"; t = "files-r"; k = "" },
  @{ f = "qverb.cob"; t = "qverb-r"; k = "" }
)
foreach ($x in $tests) {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  & "$s\deploy.ps1" -Delete UNTITLED.OBJ,T.DAT | Out-Null
  & "$s\runprog.ps1" -File "$s\progs\$($x.f)" -Tag $x.t -CompileWait 40 -RunWait 6 -Keys $x.k | Out-Null
}
& "$s\aw.ps1" stop | Out-Null
"done"
