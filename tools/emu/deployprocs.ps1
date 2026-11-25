# deployprocs.ps1 - the procedure library (PROCS\*.SNP) into /COBOL/PROCS
# on the volume: TXT-shaped text, CR line ends, type $48 like every .SNP.
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
if (Get-Process AppleWin* -ErrorAction SilentlyContinue) { "AppleWin is running - not deploying"; exit 1 }
$w = Join-Path $PSScriptRoot "procs-stage"; if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force "$w\PROCS" | Out-Null
foreach ($f in Get-ChildItem "P:\COBOL\PROCS\*.SNP") {
  $text = (Get-Content $f.FullName | ForEach-Object { $_.TrimEnd() }) -join "`r"
  [IO.File]::WriteAllText("$w\PROCS\$($f.Name)#480000", $text + "`r", [Text.Encoding]::ASCII)
}
Push-Location $w
& $cp2 add --overwrite --from-naps $img PROCS | Out-Null
Pop-Location
& $cp2 catalog $img | Where-Object { $_ -match "PROCS" }
