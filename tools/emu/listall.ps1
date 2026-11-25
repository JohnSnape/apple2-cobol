# listall.ps1 - every FIXLIST list A test, then the error set and regressions
$s = $PSScriptRoot
$runs = @(
  @{ f = "at.cob";    t = "at";    k = "JOE~123.45~" },
  @{ f = "lista.cob"; t = "lista"; k = "" },
  @{ f = "listd.cob"; t = "listd"; k = "" },
  @{ f = "listm.cob"; t = "listm"; k = "" },
  @{ f = "listv.cob"; t = "listv"; k = "" },
  @{ f = "a14.cob";   t = "a14";   k = "" },
  @{ f = "a15.cob";   t = "a15";   k = "" },
  @{ f = "a2.cob";    t = "a2";    k = "" },
  @{ f = "conds2.cob"; t = "conds2"; k = "" },
  @{ f = "perf2.cob";  t = "perf2";  k = "" },
  @{ f = "then.cob";   t = "then";   k = "" },
  @{ f = "size.cob";   t = "size";   k = "" }
)
foreach ($x in $runs) {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  & "$s\deploy.ps1" -Delete UNTITLED.OBJ | Out-Null
  & "$s\runprog.ps1" -File "$s\progs\$($x.f)" -Tag $x.t -CompileWait 45 -RunWait 8 -Keys $x.k | Out-Null
}
& "$s\aw.ps1" stop | Out-Null
& "$s\errtest.ps1"
