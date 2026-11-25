# suite.ps1 - everything: list A + list B tests, errors, regressions, then
# LEADS, FINANCE and the REPORT design-to-printout run, the editor's
# clipboard, the procedure library (procsuite.ps1), and - 2026-11-11 - the
# prefixes, ERASE / FROM KEY / FROM PREFIX, the screen standing in for the
# printer, menus, and REPORT's LISTR shown a page at a time
$s = $PSScriptRoot
& "$s\listall.ps1"
foreach ($t in "leadstest","fintest","rpttest","edtest","viewtest","turntest","clptest") {
  & "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
  & "$s\deploy.ps1" -Delete UNTITLED.OBJ | Out-Null
  & "$s\$t.ps1" | Out-Null
}
& "$s\aw.ps1" stop | Out-Null
& "$s\procsuite.ps1" | Out-Null
& "$s\pxtest.ps1" | Out-Null
& "$s\runfile.ps1" -File "$s\progs\scrn.cob" -Name SCRN -Tag scrn -CompileWait 45 -RunWait 5 -Steps "A|","7|scrn-end" | Out-Null
& "$s\runfile.ps1" -File "$s\progs\page.cob" -Name PAGET -Tag page -CompileWait 45 -RunWait 6 -Steps " |page-2"," |page-3" | Out-Null
& "$s\mnutest.ps1" | Out-Null
& "$s\rptscr.ps1" | Out-Null
& "$s\copytest.ps1" | Out-Null
& "$s\limtest.ps1" | Out-Null
# 2026-11-12: error 49 and its VM backstop, error 50, the free-text
# IDENTIFICATION DIVISION, and UPPERCASE ONLY / ANYCASE
& "$s\safetytest.ps1" | Out-Null
"all done"
