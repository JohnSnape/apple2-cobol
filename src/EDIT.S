* EDIT.S  the COBOL source editor
* An overlay at $8000.  COBOL.SYSTEM BLOADs it and
* JSRs $8000; ESC returns with an RTS.
*
* IT CANNOT BE BRUN ON ITS OWN.  The ring at
* $9800-$ABFF and the file buffers at $B000 sit on
* top of BASIC.SYSTEM, which lives from $9A00 up.
* Reach it through COBOL.SYSTEM, which owns all of
* low memory and loads no BASIC.  (An earlier note
* here said BRUN $8000 worked; it did, before the
* ring moved up into that space.)
*
* ================= THE SCREEN =================
*   row 0      prefix and file name at the left,
*              space remaining at the right
*   row 1      a rule carrying LINE, OF and COLUMN,
*              and the line questions are asked on
*   rows 2-21  twenty lines of the program
*   row 22     the Open-Apple commands
*   row 23     the Solid-Apple commands
*
* ================= A LINE IS EIGHTY =============
* All eighty columns are text.  There is no line
* number in a gutter, and so screen column n IS
* source column n: column 1 is the indicator
* ('*' = comment), Area A starts at 2 and Area B at
* 6 - standard COBOL's 7, 8 and 12 with the card
* sequence field removed.  TAB moves four columns,
* which is exactly the Area A to Area B step.
*
* WHY NO NUMBERS DOWN THE SIDE
* A gutter costs six of the eighty columns, and it
* is worth them only if numbers are how you find a
* line.  They are not, here: the current line shows
* in the rule, OA-G goes to any line by number, and
* COMPILE is our own program - it can put the
* editor on the offending line rather than printing
* a number for someone to hunt.  A number a machine
* can act on does not need to be on the screen.
*
* ================= WHERE THE TEXT LIVES ==========
* Every line is one record in auxiliary memory,
* record number = line number, reached through
* AUXMEM's AMGET/AMPUT.  Those map a record to a
* bank and an address, so a program can be longer
* than one 64K bank without this file knowing that
* banks exist.  At 80 bytes a record, 512 records
* fill 40,960 of a bank's 45,824 usable bytes.
*
* THE RING - why scrolling does not touch aux
* Fifty-two consecutive lines are held in MAIN
* memory: sixteen above the window, the twenty on
* the screen, and sixteen below.  Scrolling one
* line therefore costs ONE record read - the line
* entering the far margin - instead of twenty.
*   Line L always sits in slot L AND 63.  The ring
* is 64 slots and 64 divides 256, so the low byte
* of the line number IS the slot: no head pointer,
* no wrap arithmetic, and a line that leaves the
* ring simply has its slot taken by the line
* arriving 52 lines away.
*   The cache is the WORKING COPY.  Typing changes
* the ring in place and marks the line dirty; the
* record is written back to auxiliary memory when
* the cursor leaves the line.  A key press moves no
* data across the bank boundary at all.
*
* WHY THE SCREEN IS STILL REPAINTED
* Scrolling the display in place would mean reading
* the screen, and reading the auxiliary half means
* turning RAMRD on, which redirects instruction
* fetch - the loop would bank itself out.  (It is
* the same hazard CONSOLE's shadow exists to dodge.)
* Moving the rows with AUXMOVE instead costs about
* what a repaint costs, so we repaint, out of main
* memory, through PUTROW: about 1200 cycles a row.
*   Every row is built into ROWBUF split the way
* the screen is - even columns first, then odd - so
* the blit is two forty-byte copies.  The split
* happens while we are copying the line anyway.
*
* ================= FILES =========================
* OA-O opens a file and OA-S saves one, streamed a
* line at a time through a 512-byte staging buffer.
* See OPEN AND SAVE below for why it is not a
* single FLOAD or FSAVE.
*
* ================= WHAT IS NOT HERE YET ==========
* The clipboard and undo.  Also: INSLIN moves every
* record below the insertion point, which is the
* one slow operation in the editor.  The cure, if a
* program ever gets long enough to notice, is a
* table of record numbers - move two bytes a line
* instead of eighty.
*
* SIZE.  Roughly 4.5K of the 6K between $8000 and
* the ring at $9800 is now used.  The clipboard and
* undo have to fit in what is left, and undo in
* particular wants a buffer.  Read EDEND after
* every assembly; if it reaches $9800 the code has
* grown into the cache and the first symptom will
* be corrupted text, not a crash.

RECSZ EQU 80
TOPROW EQU 2
NPROG EQU 20
CBACK EQU 16
CSPAN EQU 52
CMASK EQU 63
AXSH EQU 9

* The ring: 64 slots of 80 bytes, $9800-$ABFF.
* An address, not a DS - 5120 bytes have no
* business inside a file loaded from a floppy every
* time the editor is called.  EDIT's code must stay
* below this.
EDCACHE EQU $9800

* ---- $AC00-$AFFF: the buffers above the ring ----
* The ring ends at $ABFF and ProDOS's buffer starts
* at $B000, and the kilobyte between was spare.  The
* five buffers that need no starting value moved up
* here as ADDRESSES on 2026-11-08, when VIEW pushed
* the code past $9800 - 222 bytes back, for the
* same reason the ring is an address: a buffer is
* not something to load off a floppy.
EDHIGH EQU $AC00
HDRBUF EQU EDHIGH
PFXBUF EQU EDHIGH+40
SHFBUF EQU EDHIGH+104
NAMBUF EQU EDHIGH+184
* the safe save's temporary name: FNBUF1 (at most
* 15 typed) plus .T, length-prefixed
ETMPNB EQU EDHIGH+204

* LOWBASE, $6000 since 2026-11-08 (was $8000, then
* $7000): the menu loads EDIT with RUNLOW, like VM
* and the compiler, and the code has $6000-$97FF.
* Written as a number because the equates are PUT
* below this line.
 ORG $6000
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/EDIT
 JMP EDIT
* $8003: the same editor, showing a data file read
* only - menu option 7, EDITVW.S
 JMP EDVIEW
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
* Only one driver is ever live, so the editor may
* keep pointers here and know no service will touch
* them.
EDPTR EQU ZPDRV
EDPTR2 EQU ZPDRV+2


* ================= THE EDITOR, IN PIECES =========
* EDIT is a STUB.  Every section of the editor is
* its own source file, PUT in below.  Merlin holds
* only THIS file in the editor and streams the rest
* from disk at assembly time, so the source no
* longer has to fit in the editor buffer whole -
* the same shape LIB.S has always had.
*
* THE ORDER IS THE ORIGINAL ORDER.  PUT concatenates
* each file at its line, so the assembled bytes are
* identical to the former single file, fall-throughs
* and all.  Do not reorder these without a reason:
* JMP EDIT above lands on the first byte of EDITENT,
* and EDITVAR must stay last because EDEND marks the
* end there.
 PUT EDITENT
 PUT EDITRNG
 PUT EDITSHF
 PUT EDITDRW
 PUT EDITRUL
 PUT EDITCUR
 PUT EDITDSP
 PUT EDITCMD
 PUT EDITIO
 PUT EDITBAR
 PUT EDITVW
 PUT EDITPRT
 PUT EDITPLC
 PUT EDITCLP
 PUT EDITVAR
