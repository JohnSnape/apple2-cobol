# a21run.ps1 - 2026-11-22, after FIXLIST A21 (error 51 for a 17th open
# group): the DATA DIVISION error tests and the programs whose records have
# groups, by runfile.ps1 (seconds a program, not runprog's typing).
# Expected results are in README.txt.
$s = $PSScriptRoot
$set = @(
  @{ n = "e33"; k = "" }, @{ n = "e34"; k = "" }, @{ n = "e35"; k = "" },
  @{ n = "e36"; k = "" }, @{ n = "e38"; k = "" }, @{ n = "e2"; k = "" },
  @{ n = "e50d"; k = "" }, @{ n = "beta1"; k = "" }, @{ n = "conds"; k = "" },
  @{ n = "files"; k = "" }, @{ n = "listd"; k = "" }, @{ n = "listm"; k = "" },
  @{ n = "lvl16"; k = "" }, @{ n = "lvl17"; k = "" }
)
foreach ($x in $set) {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  $name = $x.n.ToUpper()
  & "$s\runfile.ps1" -File "$s\progs\$($x.n).cob" -Name $name -Tag "a21-$($x.n)" -CompileWait 40 -RunWait 6 -Keys $x.k 2>$null | Out-Null
  "ran $($x.n)"
}
& "$s\aw.ps1" stop | Out-Null
& "$s\leadstest.ps1" 2>$null | Out-Null
"ran leads"
"finished"
