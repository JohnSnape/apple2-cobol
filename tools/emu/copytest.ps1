# copytest.ps1 - COPY (2026-11-11).  Puts progs\copybooks onto the volume
# (MYREC.SNP in /COBOL, the rest in /COBOL/CPYT), then:
#   ccopy  MYREC whole, FORMAT's CUSTSCR by division, */CPYT/MYPARA:
#          NAME/BALANCE painted, C1 COPIED     42 Y / F1 AMY  00000050 /
#          C2 COPIED     42
#   cdates pdates with COPY DATES twice (found in */PROCS/): same output
#   e43 (no such book) e44 (OF) e45 (COPY in a book) e47 (PROCEDURE
#   DIVISION in a book) ebook (error 15 at line 10, COPY book line 2)
# Everything it put on the volume is deleted at the end.
$s = $PSScriptRoot
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
$w = Join-Path $s "deploy-stage"; if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force "$w\CPYT" | Out-Null
function Put($src, $dst) {
  $text = (Get-Content $src | ForEach-Object { $_.TrimEnd() }) -join "`r"
  [IO.File]::WriteAllText($dst, $text + "`r", [Text.Encoding]::ASCII)
}
Put "$s\progs\copybooks\MYREC.SNP" "$w\MYREC.SNP#480000"
foreach ($f in Get-ChildItem "$s\progs\copybooks\CPYT\*.SNP") { Put $f.FullName "$w\CPYT\$($f.Name)#480000" }
Push-Location $w; & $cp2 add --overwrite --from-naps $img "MYREC.SNP#480000" CPYT | Out-Null; Pop-Location
& "$s\runfile.ps1" -File "$s\progs\ccopy.cob" -Name CCOPY -Tag cc -CompileWait 50 -RunWait 6 | Out-Null
& "$s\runfile.ps1" -File "$s\progs\cdates.cob" -Name CDATES -Tag cd -CompileWait 60 -RunWait 8 | Out-Null
foreach ($e in "e43","e44","e45","e47","ebook") {
  & "$s\runfile.ps1" -File "$s\progs\$e.cob" -Name ($e.ToUpper()) -Tag $e -CompileWait 40 -RunWait 4 | Out-Null
}
& $cp2 delete $img "MYREC.SNP" 2>$null | Out-Null
foreach ($f in Get-ChildItem "$s\progs\copybooks\CPYT\*.SNP") { & $cp2 delete $img "CPYT/$($f.Name)" 2>$null | Out-Null }
& $cp2 delete $img "CPYT" 2>$null | Out-Null
"done"
