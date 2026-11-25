# safetytest.ps1 - the two safety fixes and the case rule (2026-11-12)
#   sz49     31 x X(250): error 49 PROGRAM AND DATA OVER 7,680 BYTES
#   e50a     LINKAGE SECTION: error 50 at line 8
#   e50b     ORGANIZATION IS INDEXED: error 50 at line 8
#   e50c     JUSTIFIED RIGHT: error 50 at line 8
#   e50d     a level 66: error 50 at line 9
#   envok    E1 00 / E2 00 / E3 ABCD 00 / E4 Y / E5 2 -005
#   caseup   type abc, def, q: C2 [ABC  ] [DEF  ] [Q]
#   caseany  ANYCASE, the same keys: C2 [abc  ] [def  ] [q]
$s = $PSScriptRoot
& "$s\runfile.ps1" -File "$s\progs\sz49.cob" -Name SZ49 -Tag sz49 -CompileWait 60 -RunWait 4 | Out-Null
foreach ($e in "e50a","e50b","e50c","e50d") {
  & "$s\runfile.ps1" -File "$s\progs\$e.cob" -Name ($e.ToUpper()) -Tag $e -CompileWait 40 -RunWait 4 | Out-Null
}
& "$s\runfile.ps1" -File "$s\progs\envok.cob" -Name ENVOK -Tag envok -CompileWait 60 -RunWait 6 | Out-Null
& "$s\runfile.ps1" -File "$s\progs\caseup.cob" -Name CASEUP -Tag caseup -CompileWait 40 -RunWait 3 -Steps "abc~|","def~|","q|caseup-end" | Out-Null
& "$s\runfile.ps1" -File "$s\progs\caseany.cob" -Name CASEANY -Tag caseany -CompileWait 40 -RunWait 3 -Steps "abc~|","def~|","q|caseany-end" | Out-Null
& "$s\aw.ps1" stop | Out-Null
& "$s\deploy.ps1" -Delete ENVOK.DAT | Out-Null
"done"
