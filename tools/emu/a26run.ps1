# a26run.ps1 - 2026-11-22: the file regression after bad names were refused
# (DECISIONS 8.10, FIXLIST A26).  Expected results are README.txt's.
$s = "P:\COBOL\tools\emu"
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
$set = @(
  @{ n = "asn" }, @{ n = "files" }, @{ n = "fchk" }, @{ n = "qfile" }, @{ n = "qsort" },
  @{ n = "scrn"; st = @("A|", "7|rg-scrn-end") }
)
foreach ($x in $set) {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  $steps = if ($x.st) { $x.st } else { @() }
  & "$s\runfile.ps1" -File "$s\progs\$($x.n).cob" -Name $x.n.ToUpper() -Tag "rg-$($x.n)" -CompileWait 45 -RunWait 6 -Steps $steps 2>$null | Out-Null
  "ran $($x.n)"
}
foreach ($f in "EAST.DAT", "WEST.DAT", "FCHK.DAT") { & $cp2 delete $img $f 2>$null | Out-Null }
& "$s\aw.ps1" stop | Out-Null
& "$s\pxtest.ps1" 2>$null | Out-Null; "ran pxtest"
& "$s\aw.ps1" stop | Out-Null
& "$s\prttest.ps1" 2>$null | Out-Null; "ran prttest"
Copy-Item "$s\print-test.txt" "$s\print-prttest.txt" -Force
& "$s\aw.ps1" stop | Out-Null
& "$s\rptscr.ps1" 2>$null | Out-Null; "ran rptscr"
& "$s\aw.ps1" stop | Out-Null
& "$s\leadstest.ps1" 2>$null | Out-Null; "ran leads"
& "$s\aw.ps1" stop | Out-Null
& "$s\sdbtest.ps1" 2>$null | Out-Null; "ran sdbtest"
& "$s\aw.ps1" stop | Out-Null
foreach ($f in "EAST.DAT", "WEST.DAT") { & $cp2 delete $img $f 2>$null | Out-Null }
"finished"
