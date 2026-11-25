# limtest.ps1 - names to 30 characters, 128 names, 128 items (2026-11-11;
# the symbol table moved to the aux card, SYMAUX.S).
#   longnm  L1 0000100 0000200 0000300 / L2 YES / L3 DONE
#   many    121 items, 123 names: M1 120 / M2 001 / M3 END
#   e48     a 31-character name: error 48 at line 7
#   e5      129 names (128 88-levels): error 5 TOO MANY NAMES (128 MAX)
#   e2      131 items (FILLERs): error 2 TOO MANY DATA ITEMS (128 MAX)
$s = $PSScriptRoot
& "$s\runfile.ps1" -File "$s\progs\longnm.cob" -Name LONGNM -Tag ln -CompileWait 45 -RunWait 5 | Out-Null
& "$s\runfile.ps1" -File "$s\progs\many.cob" -Name MANY -Tag many -CompileWait 120 -RunWait 6 | Out-Null
foreach ($e in "e48","e5","e2") {
  & "$s\runfile.ps1" -File "$s\progs\$e.cob" -Name ($e.ToUpper()) -Tag $e -CompileWait 75 -RunWait 4 | Out-Null
}
"done"
