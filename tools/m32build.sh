#!/bin/sh
# m32build.sh - assemble every program with Merlin32, on the PC.
#
#   sh tools/m32build.sh            build all, into build/obj/
#   sh tools/m32build.sh baseline   also copy the objects to build/baseline/
#   sh tools/m32build.sh compare    build, then compare byte for byte
#                                   against build/baseline/
#
# Merlin32 is a fast stand-in for Merlin 8, proven byte-identical on
# COBOL.LIB (2026-11-07).  It is NOT the proof: it has no 24K PUT-file
# limit and forgives forward references, so tools/fwdref.js and a real
# Merlin 8 run still follow.  src/ is never touched - the copy in
# build/src gets the two things Merlin32 needs: a TYP line after DSK,
# and DSK with the ProDOS path taken off.
M32=/d/Merlin32/v1.2/Merlin32_v1.2_b2/Windows/Merlin32.exe
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="$ROOT/build"
STUBS="LIB AUXLC COBOLSYS UTIL EDIT FORMAT QUERY REPORT VM COMPILE1 COMPILE2 BCDTEST PICTEST QRYTEST KEYTEST OBJTEST LEXTEST"

rm -rf "$B/src" "$B/obj"; mkdir -p "$B/src" "$B/obj"
cp "$ROOT/src/"*.S "$B/src/"
cd "$B/src" || exit 1
sed -i 's#^ DSK /COBOL/OBJ/\(.*\)$# DSK \1\n TYP $06#; s#^ DSK \([A-Z0-9.]*\)\r\?$# DSK \1\n TYP $06#' $(echo $STUBS | sed 's/\([A-Z0-9]*\)/\1.S/g')
fail=0
for s in $STUBS; do
  obj=$(grep -m1 "^ DSK" $s.S | awk '{print $2}' | tr -d '\r')
  err=$("$M32" . $s.S 2>&1 | grep -E "=> \[|Error" | head -3 | tr -s ' ')
  if [ -f "$obj" ]; then
    mv "$obj" "$B/obj/$s.OBJ"; size=$(stat -c %s "$B/obj/$s.OBJ")
  else size="-"; fail=1; fi
  printf "%-9s %6s  %s\n" "$s" "$size" "$err"
done
rm -f "$B/src/"*_Output*.txt "$B/src/"*_Symbols.txt "$B/src/_FileInformation.txt"

if [ "$1" = "baseline" ]; then
  rm -rf "$B/baseline"; cp -r "$B/obj" "$B/baseline"; echo "baseline saved"
elif [ "$1" = "compare" ]; then
  for s in $STUBS; do
    if cmp -s "$B/obj/$s.OBJ" "$B/baseline/$s.OBJ"; then r="identical"
    else r="DIFFERENT"; fail=1; fi
    printf "%-9s %s\n" "$s" "$r"
  done
fi
exit $fail
