* REPORT.S  the print-layout designer (slice 1)
* An overlay: loaded to $8000 by COBOL.SYSTEM,
* runs, and RTSes back into the menu at $2000.
* Sibling to FORMAT.  Where FORMAT paints a SCREEN
* and exports the DISPLAY/ACCEPT that draws it,
* REPORT paints a printed PAGE and exports the
* group items and DISPLAY ... UPON PRINTER that
* print it.  The format and the whole design are
* in REPORT.md, which wins on anything here.
*
* ================= THE SCREEN =================
*   row 0      the report name at the left, the
*              bound dictionary at the right
*   row 1      a rule: PAGE LINE n OF m, and the
*              band that line falls in
*   rows 2-21  twenty lines of the printed page
*   row 22     the command bar
*   row 23     the question line (PROMPT's LINEIN)
*
* ================= SIXTY-SIX LINES ==============
* A page is 66 lines and the window is 20, so this
* is the second overlay in the system that scrolls
* a document taller than the screen - and NOT the
* second one that needs EDIT's ring.
*   EDIT caches lines because a program lives in
* auxiliary memory, where scrolling would cost a
* record read a row.  A report is sixty-four
* entries in MAIN memory, four kilobytes, already
* resident.  So a window row is built by clearing
* ROWBUF and walking the entry list for entries on
* that page line - about thirteen hundred compares
* for a full repaint, less than the blit that
* follows it.  No cache, no valid flag, no reload.
*   The lesson is worth the paragraph: the ring is
* not what scrolling costs.  It is what scrolling
* costs when the document does not fit in memory.
*
* ================= WHAT IS NOT HERE YET =========
* Slice 1 is the window and nothing else.  There
* is no way to add an entry, so the page draws
* empty - but RPTDRW already walks the entry list,
* so slice 2 adds the prompt chain and no drawing.
* Bands, save/load, export and the preview are
* slices 4 to 7.  DOPREV is an RTS until slice 7.

* ---- the window ----
* NINETEEN rows since 2026-11-08: row 21 is the
* second command bar
PGROW EQU 2
NPAGE EQU 19

* ---- the report ----
* Sixty-four entries of sixty-four bytes.  The
* stride is a shift, not an estimate: entry n sits
* RPTENT + (n << 6), so the table is exactly four
* pages and no multiply is needed to reach one.
MAXENT EQU 64
ENTSZ EQU 64
DEFPLEN EQU 66
DEFPWID EQU 80

* ---- where the report lives ----
* An ADDRESS, not a DS, exactly as EDIT's ring is:
* four kilobytes have no business inside a file
* BLOADed from a floppy every time REPORT runs.
* The header sits immediately BELOW the table and
* the two are contiguous, so saving is one write
* of 32 + entrycount*64 bytes from memory, and
* loading is one read back over the same ground.
* REPORT's code must stay below RPTHDR.
RPTHDR EQU $97E0
RPTENT EQU $9800

* ---- the header fields (REPORT.md section 5) ---
HSIG EQU RPTHDR+0
HVER EQU RPTHDR+4
HORG EQU RPTHDR+5
HPLEN EQU RPTHDR+6
HPWID EQU RPTHDR+7
HECNT EQU RPTHDR+8
HDSPC EQU RPTHDR+9
* the six band marks are CONTIGUOUS, which is what
* lets BANDOF walk them as three pairs
HHTOP EQU RPTHDR+10
HHBOT EQU RPTHDR+11
HDTOP EQU RPTHDR+12
HDBOT EQU RPTHDR+13
HFTOP EQU RPTHDR+14
HFBOT EQU RPTHDR+15
HEOFF EQU RPTHDR+16
HFEND EQU RPTHDR+18
HDNAME EQU RPTHDR+20

* ---- the entry record, offsets within one ----
EKIND EQU 0
ELINE EQU 1
ECOL EQU 2
EWIDTH EQU 3
EFLAGS EQU 4
EDECS EQU 5
EBAND EQU 6
ELLEN EQU 7
ENAME EQU 8
EPICT EQU 18
ETEXT EQU 32

* ---- entry kinds ----
KLIT EQU 0
KFLD EQU 1
KTOT EQU 2
KPAGE EQU 3
KDATE EQU 4
KRULE EQU 5

* $6000 (LOWBASE) since 2026-11-08, loaded by RUNLOW
* as EDIT is: the code has $6000-$97DF
 ORG $6000
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/REPORT
 JMP START
* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC
 PUT EQUATES
 PUT EQUATES2

* ---- zone P: this overlay's hot state ----
* Only one driver is ever live, so REPORT may keep
* a pointer here and know nothing else touches it.
RPTR EQU ZPDRV

* ================= REPORT, IN PIECES ============
* A STUB of PUTs, the same shape as LIB, EDIT,
* FORMAT and VM.  Merlin holds only THIS file in
* the editor and streams the rest from disk, so
* main file stays small however large the program
* gets.
*
* PROMPT is shared with FORMAT - it is the row-23
* question line, and it was inside FORMATD until
* REPORT wanted it.  It reads two symbols this
* overlay must define: CMDLIST (in RPTBAR) and
* DOPREV (in RPTENT).
*
* RPTVAR must stay LAST: RPTEND is marked at its
* foot, and RPTEND is what says whether the code
* has grown into the report.
 PUT PROMPT
 PUT RPTENT
 PUT RPTDRW
 PUT RPTADD
 PUT RPTIO
 PUT RPTEXP
 PUT RPTBAR
 PUT RPTVAR
