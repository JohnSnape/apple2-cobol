# a22run.ps1 - 2026-11-22, after ASSIGN TO a data name, FIXLIST A22 (DISPLAY
# a b c UPON PRINTER) and A23 (40-character literals): the new tests, then
# every program that opens a file or prints, by runfile.ps1.  Since the
# same day also bigpg (past both old size limits) and sz49 (the new one).  Expected
# results are in README.txt.  sdbtest.ps1 is the SALESDB run on its own.
$s = $PSScriptRoot
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
$set = @(
  @{ n = "asn" }, @{ n = "asne15" }, @{ n = "asne18" }, @{ n = "prt17" },
  @{ n = "files" }, @{ n = "fchk" }, @{ n = "fchk2" }, @{ n = "qfile" },
  @{ n = "qsort" }, @{ n = "beta1" }, @{ n = "conds" }, @{ n = "lista" },
  @{ n = "listd" }, @{ n = "listm" },
  @{ n = "scrn"; st = @("A|", "7|a22-scrn-end") },
  @{ n = "page"; st = @(" |a22-page-2", " |a22-page-3") },
  @{ n = "bigpg"; cw = 150 }, @{ n = "sz49" }
)
foreach ($x in $set) {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  $steps = if ($x.st) { $x.st } else { @() }
  & "$s\runfile.ps1" -File "$s\progs\$($x.n).cob" -Name $x.n.ToUpper() -Tag "a22-$($x.n)" -CompileWait $(if ($x.cw) { $x.cw } else { 45 }) -RunWait 6 -Steps $steps 2>$null | Out-Null
  "ran $($x.n)"
}
foreach ($f in "EAST.DAT", "WEST.DAT", "FCHK.DAT") { & $cp2 delete $img $f 2>$null | Out-Null }
& "$s\aw.ps1" stop | Out-Null
& "$s\prttest.ps1" 2>$null | Out-Null; "ran prttest"
& "$s\aw.ps1" stop | Out-Null
& "$s\rptscr.ps1" 2>$null | Out-Null; "ran rptscr"
& "$s\aw.ps1" stop | Out-Null
& "$s\leadstest.ps1" 2>$null | Out-Null; "ran leads"
& "$s\aw.ps1" stop | Out-Null
"finished"
