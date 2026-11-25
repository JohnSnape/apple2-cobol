Host-side tools.  Run with the bundled node:
  node (on PATH, or %LOCALAPPDATA%\claude-tools\node-v22.14.0-win-x64\node.exe)

check.js     From src/: static-checks all 15 assemblies.  Reports duplicate
             labels, unresolved symbols, branches out of range, over-long
             lines, and each program's size against its ceiling; then checks
             that both halves of the interpreter's dispatch table hold
             exactly 256 entries.  Reproduces Merlin's arithmetic to about
             half a per cent - it sized EDIT at 4,812 when Merlin said
             4,788 - but it is NOT an assembler.  It cannot see macro or
             expression errors, and it skips DA operands (use the pattern
             in HANDOFF for those).
             cd src && node ../tools/check.js

             THE FILE LISTS ARE HARD-CODED at the bottom.  check.js does not
             follow PUT.  Add a module to LIB.S and you must add it here too,
             or it is silently not checked - which is exactly what happened
             the first time SCRSHOW and SCRINP were moved into the library.

strlen.js    From src/: checks every length-prefixed string against the
             bytes that follow it.  check.js cannot see this class of error
             because both lines assemble to the size it expects; the message
             simply prints one character short, or one character of whatever
             came next.  Handles multi-part strings (FORMATD's command bar)
             and tables of counted keywords (VERBTAB).
             cd src && node ../tools/strlen.js *.S


datamap.js   From src/: the data region address by address, with the gaps, and
             any address two symbols both claim.  EQUATES.S does not say how
             big anything is - QSPEC is one address and twenty bytes - so
             nothing can prove two allocations do not overlap.  What this
             proves is the half a machine can: exact collisions, and where
             there is room for the next module.  It found CLKSLOT sitting on
             FADDR+1, which every BLOAD writes.
             cd src && node ../tools/datamap.js

classify.js  From src/: which program owns each file, by following every PUT.
             Keep "PUT BY NOTHING" at zero: an orphan is a file check.js
             never looks at, which is how SCRINP.S carried two bugs for weeks.
             cd src && node ../tools/classify.js

refpage.js   From the project folder: builds REFERENCE.html, the one-page
             reference shaped like the GnuCOBOL Programmer's Guide.  QUICKREF.md
             is the language chapters; the limits (each from its EQU), the
             compiler errors (ERRMSG.S), the run-time messages (VMTAIL.S) and
             the keyword index are read out of the source every run.  A
             symbol it cannot find prints WARNING and shows a red "?" on the
             page.  Never edit the page; rebuild it (2026-11-22).
             node tools/refpage.js

md2txt.js    Converts .md to .txt in the book format: one paragraph per line,
             single CR, TAB-separated tables, ** ` markers kept, code fences
             preserved verbatim.
             node tools/md2txt.js FILE.md [FILE.md ...]

fwdref.js    From src/: Merlin 8's ILLEGAL FORWARD REFERENCE, found on the
             PC.  Follows each stub's PUT order and flags (1) EQU/DS/ORG/
             DUM/LUP/DO/IF using a symbol not yet defined, (2) a forward
             symbol inside ( ),Y / ( ,X) / ( ), which must be zero page
             in pass 1, and (3) an EQU giving a small value (under $100)
             to a symbol something already used - Merlin reports that
             once, AT THE EQU LINE.  Rule 3 was proven against a real
             Merlin 8 run on CLOCK.S (NSCLEN, 2026-11-07).
             cd src && node ../tools/fwdref.js [STUB.S ...]

m32build.sh  Assembles all fifteen with Merlin32 (D:\Merlin32) into
             build/obj, in seconds.  `baseline` saves the objects;
             `compare` rebuilds and checks every object byte for byte
             against the baseline - the proof that a reorganisation
             changed no code.  src/ is never touched.
             sh tools/m32build.sh [baseline|compare]

check.js now also flags any .S over 24,000 bytes (Merlin 8 cannot PUT
it: MEMORY IN USE) and warns over 22,000, and it sizes DS from EQU
symbols.  Merlin32's objects are the authority on sizes now.

regs.js      From src/: X or Y used after a library call without being
             reloaded.  The library keeps no registers except where it
             says so (KEEPS in the file: CONPUTC keeps X, Y, ZPT1, ZPT2
             since 2026-11-07; PUTC keeps X).  Found BCDTEST's digit
             loop counting in X across CONPUTC, which scrolled garbage.
             cd src && node ../tools/regs.js [FILE.S ...]

tailcall.js  From src/: JMP or branch into a routine that other code JSRs.
             Reached by a jump, that routine's RTS returns from the
             CALLER'S caller and the loop that jumped silently stops.
             Two real bugs on 2026-11-07: BEQ DDLVL in DATDIV (pass one
             quit after the first 01) and JMP PDPARA in PROCDIV (pass
             two quit after the first paragraph).  Survivors to expect:
             a routine looping to its own entry, or a tail exit from
             inside a subroutine.  Not run in LIB.S (the jump table).
             cd src && node ../tools/tailcall.js
