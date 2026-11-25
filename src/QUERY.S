* QUERY.S  the query designer overlay
* Assembles to QUERY, a BIN file loaded to $8000 by
* the menu.  An overlay is a SUBROUTINE: JSR $8000,
* RTS back to the menu at $2000.
*
* THE ONLY THING THAT WRITES A .QRY.
* QUERY.md specified the file and SELECT.S reads it;
* until now nothing produced one, which made the
* whole query engine unreachable from a COBOL
* program.  This is the front end opcode $D3 (QBE)
* reserves - query by example, in the sense that the
* operator picks fields out of a loaded dictionary
* rather than writing a predicate by hand.
*
* THE SHAPE IS FORMAT'S AND REPORT'S.
* A dictionary is loaded, a list is built on screen,
* and a file is written that some other program
* consumes.  Same command letters, same row-23
* prompt through PROMPT.S, same ESC to leave.  A
* third designer that worked a fourth way would be a
* worse tool for being novel.
*
* WHAT IT DOES NOT DO
* It does not RUN the query.  Building the cursor is
* SELECT.S's job and it needs records in auxiliary
* memory to run against, which needs RECMAN.  The
* designer writes the question; running it is the
* runtime's business, exactly as FORMAT writes a
* screen it never displays.

* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one.
 XC
 PUT EQUATES
 PUT EQUATES2

* ---- the table sizes ----
* Here and not in QRYVAR: QRYADD and QRYIO use them
* first, and Merlin 8 must meet a small EQU before
* anything uses it.
MAXCOND EQU 8
MAXKEY EQU 4
MAXLIT EQU 20

 ORG $8000
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/QUERY

 JMP QSTART

 PUT PRODOS
 PUT PROMPT
 PUT QRYENT
 PUT QRYADD
 PUT QRYIO
* QRYVAR last, so QRYEND is the end of the code
 PUT QRYVAR
