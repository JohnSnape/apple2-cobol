# deploy.ps1 - push changed sources and Merlin32 objects to COBOL32.po
#   deploy.ps1 -Src CMPPROC,VMTAIL -Obj VM,COMPILE2
# Refuses while AppleWin is running.  Backs the image up first.
param([string[]]$Src = @(), [string[]]$Obj = @(), [string[]]$Delete = @())
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
$root = "P:\COBOL"
if (Get-Process AppleWin* -ErrorAction SilentlyContinue) { "AppleWin is running - not deploying"; exit 1 }
$w = Join-Path $PSScriptRoot "deploy-stage"; if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force "$w\SRC" | Out-Null
Copy-Item $img ([IO.Path]::ChangeExtension($img, ".backup.po")) -Force
$names = @{ LIB = "COBOL.LIB#063000"; AUXLC = "COBOL.AUX#06D000"; COBOLSYS = "COBOL.SYSTEM#ff2000"; UTIL = "UTILITIES#06a000" }
foreach ($s in $Src) { Copy-Item "$root\src\$s.S" "$w\SRC" }
foreach ($o in $Obj) { $n = if ($names[$o]) { $names[$o] } else { "$o#068000" }; Copy-Item "$root\build\obj\$o.OBJ" "$w\$n" }
Push-Location $w
if ($Src.Count) { & $cp2 import --overwrite $img merlin SRC | Out-Null }
$objs = Get-ChildItem $w -File | ForEach-Object Name
if ($objs) { & $cp2 add --overwrite --from-naps $img $objs | Out-Null }
foreach ($d in $Delete) { & $cp2 delete $img $d 2>$null | Out-Null }
Pop-Location
& $cp2 test $img | Select-Object -Last 1
"deployed src: $($Src -join ',')  obj: $($Obj -join ',')"
