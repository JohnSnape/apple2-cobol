* EQUATES2.S  equates, part two
*
* The second half of EQUATES.S, split off because
* Merlin cannot load a PUT file over about 24K.
* Every stub PUTs EQUATES then EQUATES2; nothing
* here may be used before EQUATES is read.

* ===== THE NUM8 NUMERIC CELL =====
* Every COBOL numeric variable is one 8-byte cell,
* whatever its PICTURE says.  One size means one
* ADD routine, one COMPARE, one MULTIPLY - no
* length parameter anywhere and no short/long
* cases in the interpreter.  Small variables waste
* a few bytes; the runtime saves far more.
*
*   +0      flags
*   +1..+7  packed BCD magnitude, 14 digits,
*           most significant first
*
* The sign lives in the flag byte, NOT in the last
* nibble as COMP-3 stores it.  That one change
* deletes all the masking that packed-decimal
* arithmetic normally needs: the magnitude bytes
* are nothing but digits, so ADD is a flat seven
* byte loop in decimal mode.
*
* Scale is not in the cell.  The compiler knows
* every field's PICTURE and emits BCDSHL/BCDSHR to
* line decimal points up before it calls in.
NCELL EQU 8
NDIG EQU 14
NMSB EQU 1
NLSB EQU 7

* ---- flag bits ----
* UNINITIALIZED is the one COMP-3 could never
* have: there is no spare bit in a packed field,
* so a debugger cannot tell zero from never-set.
FNEG EQU $80
FUNIN EQU $40
FOVFL EQU $20
FINVD EQU $10

* --- decimal arithmetic parameters ---
* digit count for BCDSHR / BCDSHL / BCDRND
BCDDIG EQU $0CD1
* result of every compare and test:
*   0 equal / zero, 1 = B greater, $FF = B less
BCMPR EQU $0CD2
* 0 ok, 1 overflow (ON SIZE ERROR), 2 divide by 0,
* 3 an operand was never initialised
BCDERR EQU $0CD3
* --- alphanumeric and conversion parameters ---
ALEN EQU $0CD4
BLEN EQU $0CD5
FILLC EQU $0CD6
BINVAL EQU $0CD7

* --- DSCREEN parameters ---
* LINE and COLUMN are 1-based, as COBOL writes
* them; DSAT is the only place that converts.
DSLINE EQU $0CD9
DSCOL EQU $0CDA
DSLEN EQU $0CDB
* bit7 numeric only, bit6 fold upper case,
* bit5 required
DSFLGS EQU $0CDC
* --- DIVIDE ... REMAINDER lands here ----
BCDREM EQU $0CE0
* --- the query engine's parameters ($0C90) ----
* In what has been free since the jump table moved
* up with its code.  QUERY.md 12 is the whole map.
*   QSRC   0 records in auxiliary memory,
*          1 a relative file - which returns status
*          5 until RECMAN is written
*   QBANK  the bank the cursor lives at the top of
*   QMAX   how many entries it may hold
*   QNREC  records to scan, 0..QNREC-1
*   QCOUNT entries in the cursor
*   QIDX   where QRYNEXT has got to
*   QREC   record number, in and out
*   QFNO   field number for QRYFLD, 0-based
*   QKEYN  sort keys in QSPEC, 0-4
*   QKEYL  the composite key length, set by QRYINIT
*   QESZ   entry size = QKEYL + 2
*   QSTAT  0 ok - QUERY.md 9 lists the rest
*   QDICT  the dictionary the field numbers mean
*   QRES   the last predicate's answer
QSRC EQU $0C90
QBANK EQU $0C91
QMAX EQU $0C92
QNREC EQU $0C94
QCOUNT EQU $0C96
QIDX EQU $0C98
QREC EQU $0C9A
QFNO EQU $0C9C
QKEYN EQU $0C9D
QKEYL EQU $0C9E
QESZ EQU $0C9F
QSTAT EQU $0CA0
QFLEN EQU $0CA1
QFTYP EQU $0CA2
QBASE EQU $0CA3
QPLEN EQU $0CA5
QDICT EQU $0CA6
QRES EQU $0CA8

* --- the Apple command keys ($0CA9) ----
* KEYMOD  bit7 Open-Apple, bit6 Solid-Apple, as
*         they were AT THE KEYSTROKE.  Written by
*         READMOD from inside every key wait.
* KEYCMD  0 = the Apple keys are ignored and every
*         accept routine behaves exactly as it
*         always did; 1 = a modified key ends an
*         ACCEPT.  Set by the ENTER prologue when
*         the program declared a CRT STATUS, so the
*         feature is opt-in and costs nothing to
*         programs that never heard of it.
* KEYTERM how the last accept ended, as an ASCII
*         digit: '0' RETURN, '1' ESC, '2' TAB,
*         '3' Open-Apple, '4' Solid-Apple, '5' both
* KEYCHAR the command key itself, upper-cased, or a
*         space
* The two together ARE the COBOL CRT STATUS item -
* two characters, the way FILE STATUS is two
* characters, so a program can DISPLAY it and an 88
* level can test it.
KEYMOD EQU $0CA9
KEYCMD EQU $0CAA
KEYTERM EQU $0CAB
KEYCHAR EQU $0CAC
* --- the clock ($0CB2) ----
* What the operator typed, or what a card supplied.
DTY EQU $0CB2
DTM EQU $0CB3
DTD EQU $0CB4
DTHH EQU $0CB5
DTMM EQU $0CB6
DTIX EQU $0CB7
DTBUF EQU $0CB8
* Which slot to probe for a No-Slot Clock.  0 skips
* the scan entirely and asks instead - which is also
* the only safe setting on a machine with a Z80
* card in it.  See CLOCK.S.
* Moved off $0CC8 on 2026-08-23: that is FADDR+1,
* the high byte of the file-I/O address parameter,
* and every BLOAD in the system writes it.  It has
* worked only because CLOCKUP sets CLKSLOT and
* calls CLKFIND three instructions later, with no
* file touched in between - which is not a property
* worth relying on for a byte the comment above
* invites somebody to set once and leave.
CLKSLOT EQU $0CB1
* --- the printer ($0CAD) ----
* PRSLOT 1-7, or 0 for no printer at all - which is
* not an error: a report printed to nowhere should
* run to the end rather than hang.
* PRMODE 0 the Pascal 1.1 firmware entry, 1 a Super
* Serial Card driven directly.
* PRFOUND 0 none, 1 firmware/serial, 2 the old CSW
* entry - the one case where a card may write to
* the screen.
PRSLOT EQU $0CAD
PRMODE EQU $0CAE
PRFOUND EQU $0CAF
PRLINE EQU $0CB0
* $0CAD-$0CBF is free.

* --- auxiliary bank count ---
NBANKS EQU $0CEC

* --- AUXMEM: records across the banks ---
* Every bank's usable space starts here, bank 0
* included, so there is one mapping and no special
* case.  Bank 0 has the text pages below $0C00;
* the others have nothing there, and we give up
* those 2,560 bytes a bank to keep the arithmetic
* identical everywhere.
AXBASE EQU $0C00
* AXRPB, records per bank, must be a POWER OF TWO
* and AXSHIFT is its log - that is what turns the
* division into a shift.  512 records of 80 bytes
* fills 40,960 of a bank's 45,824.
AXSHIFT EQU $0CED
AXRSZ EQU $0CEE
AXREC EQU $0CEF
AXBANK EQU $0CF1
AXADDR EQU $0CF2
AXBUF EQU $0CF4
AXLEN EQU $0CF6
AXCAPV EQU $0CF8
AXUSED EQU $0CFA
* free bytes, 24 bits - a record count times a
* record size does not fit in sixteen
AXFREE EQU $0CFC

* ---- NUMFMT's working space ----
* In the old jump-table site at $0C80, which has
* been free since the table moved up with its code.
NFVAL EQU $0C80
NFBUF EQU $0C84

* ---- auxiliary bank table ----
* In the data region, not up in high memory: what
* used to be free RAM at $8F00 is now inside the
* overlay band, and the first overlay loaded would
* have erased it.
BANKTBL EQU $0C00

* ===== THE DATA REGION ($0C00-$1FFF) =====
* Never loaded from disk.  Every big buffer in the
* library is an address here rather than a DS in
* the code, which keeps COBOL.LIB small on disk and
* keeps the 12K of code region for code.
* $0C00-$0CBF is free - it used to hold the jump
* table, before the table moved up with its code.

* ---- ROWBUF: one screen row, 80 screen codes ----
* The source PUTROW draws from, and it has the
* SCREEN's shape, not the line's: the first 40
* bytes are the even columns (auxiliary half) and
* the last 40 the odd (main half), exactly like
* CSHADOW.  That is what makes a row two straight
* copies instead of eighty parity tests.
* At a fixed address rather than behind a pointer
* so the blit can use absolute,Y and keep the one
* indirect index for the screen - see TEXTDRV.
* Anyone may fill it; nobody may assume it survives
* a call to anything that draws.
ROWBUF EQU $0D00

* ---- PICTURE's buffers ----
* The edited result, and the two arrays de-editing
* gathers typed digits into - integers in one,
* the fraction in the other, so neither has to know
* where the point was until they are placed.
PICBUF EQU $0D50
PICMAX EQU 40
PNBUF EQU $0D80
PFBUF EQU $0D90

* ---- the query engine's buffers ----
* QFBUF  a field, as fetched from a record
* QLBUF  a literal, normalised into that field's
*        terms
* QSPEC  the sort spec: four entries of field,
*        direction, width.  The WIDTH is an output
*        - QRYINIT fills it in from the dictionary,
*        because a caller that guessed could
*        disagree with the descriptor
QFBUF EQU $0DA0
QLBUF EQU $0DC8
QSPEC EQU $0DF0

* ---- CATALOG's buffers ----
* ---- the relative-record manager ----------------
* Two file control blocks of sixteen bytes, then the
* public parameters.  $0E50-$0E7F was free: CATALOG
* ends at $0E4F and QPROG starts at $0E80, and 48
* bytes is exactly what this needs.
*
* RMLEN is an INPUT to OPEN OUTPUT and an OUTPUT of
* every other OPEN.  A file that does not exist yet
* has no aux field to be asked for its record
* length; one that does is the authority on it.
RMFCB0 EQU $0E50
RMFCB1 EQU $0E60
RMFNO EQU $0E70
RMMODE EQU $0E71
RMREC EQU $0E72
RMBUF EQU $0E74
RMNAMP EQU $0E76
* two ASCII characters, the way CRT STATUS is.
* This IS the COBOL FILE STATUS item.
RMSTAT EQU $0E78
RMLEN EQU $0E7A
* NAMBAD: 1 when the last name the prefix service
* expanded broke ProDOS's rules (PREFIX.S PXCHK),
* 0 when it did not.  Every load, save and OPEN
* expands its name first, so after a failure this
* says whether the NAME was the reason - the tools
* say "Bad file name" from it (DECISIONS 8.10).
* Written from the aux card, which writes main.
NAMBAD EQU $0E7C
* CGWARN: CONGETLN beeps on every character that
* takes the line past this many - 0, the default,
* never.  The VM sets it for an ACCEPT into a file
* name (DECISIONS 8.11) and clears it after; no
* other caller touches it.
CGWARN EQU $0E7D

CATPATH EQU $0E00
* CATFL is a file-type list and is capped at 16
* bytes by CATCPY, so $0E50 upward is free.
CATFL EQU $0E40

* ---- the predicate program ----
* 96 bytes, and the limit is real: the evaluator's
* program counter is a one-byte OFFSET indexed
* absolutely, because zone S is caller-saved and
* the evaluator calls AXGET between every opcode.
QPROG EQU $0E80

* ---- BCD's unpacked digit arrays ----
* One digit per byte, for multiply and divide.
* DP holds a product of up to 28 digits.
DA EQU $0F00
DB EQU $0F24
DP EQU $0F48
DR EQU $0F6C

* ---- the query engine's cursor entries ----
* QKBUF an entry under construction, QEBUF the one
* the sort is holding, QEBF2 the one it is being
* compared with.  24 bytes each: the key is capped
* at 20 and the record number takes two.
QKBUF EQU $0F90
QEBUF EQU $0FA8
QEBF2 EQU $0FC0

* ---- the directory block buffer ----
* QRYLOAD borrows this to stage a .QRY.  Nothing is
* cataloguing while a query loads, and 512 bytes is
* more than a query can be.
CATBLK EQU $1000

* ---- the loaded dictionary ----
DCTBUF EQU $1200

* ---- CONSOLE's shadow screen ----
* 24 rows of 80 bytes: the first 40 of each row are
* the even columns (auxiliary half), the last 40
* the odd (main half), stored as screen codes.
* Same shape as the display, so a repaint is two
* block copies a row rather than eighty shifts.
* $1500-$1C7F.
CSHADOW EQU $1500

* $1C80-$1EFF is work space for whichever overlay
* is resident.  EDIT's line cache does NOT live
* here - 52 lines is over 4K, so it stays inside
* EDIT's own overlay space at $8000.
* Claimed so far: EDIT's 512-byte STAGE and
* REPORT's RPSTAGE both at $1C80; COMPILE's LEXBUF
* and LEXNAME, 80 bytes each, at $1C80 and $1CD0.
OVLWORK EQU $1C80

* ---- $1F00-$1FFF: state that OUTLIVES an overlay -
* Everything else in OVLWORK is scratch for the
* overlay that is running.  This last page is the
* opposite: it is what one overlay leaves for the
* NEXT one, and the only thing that uses it is the
* compiler, which is two overlays and one compile.
*
* COMPILE1 and COMPILE2 both PUT CMPVAR, but they
* are different sizes, so a variable declared with
* DS lands at a different address in each - which is
* fine for scratch and fatal for anything that has
* to be handed over.  The handover set is therefore
* EQUated here, at addresses neither pass can move.
*
* It is HERE and not in CMPVAR because SYSMENU reads
* CMPERR between the two passes to decide whether to
* load the second, and SYSMENU does not PUT the
* compiler's variables.  Two files needing the same
* address is exactly what this file is for.
CMPXFR EQU $1F00
CODLEN EQU CMPXFR+0
LITLEN EQU CMPXFR+2
NITEMS EQU CMPXFR+4
DSEG EQU CMPXFR+6
CMPERR EQU CMPXFR+8
NSYMS EQU CMPXFR+9
NSRC EQU CMPXFR+10
LEXLN EQU CMPXFR+12
* the QUERY STATUS IS item, or $FFFF for none.
* SPECIAL-NAMES is read in pass one and the operand
* goes out in pass two, so this crosses too.
QSTITM EQU CMPXFR+14
* which pass has run: 0 none, 1 the DATA DIVISION.
* Pass two refuses to run on its own, because a
* PROCEDURE DIVISION compiled against an empty
* symbol table does not fail loudly - every data
* name is simply unknown - and that is a confusing
* way to be told the compiler was driven wrongly.
CMPPHS EQU CMPXFR+16
* how many SELECTs the program declared, 0-2
NFILES EQU CMPXFR+17

* ---- $1F40: the compiler's FILE TABLE ----------
* Two entries of sixteen bytes, one per SELECT.  It
* crosses the pass boundary for the same reason
* CMPXFR does: FILE-CONTROL is read in pass one and
* the file verbs are compiled in pass two, and
* CMPVAR lands at a different address in each.
*
* The file NAME is not here - it is in the symbol
* table at $A000, kind KFILE, with its index in
* this table as the value.  One lookup mechanism,
* not two.
CMPFIL EQU $1F40
FLPATH EQU 0
FLREC EQU 2
FLKEY EQU 4
FLSTAT EQU 6
FLFLG EQU 8

* ---- $1F60: the TABLE LIST ---------------------
* One entry of four bytes per OCCURS, eight at most:
* the first item number, the last (an OCCURS group
* covers every item under it), the count and the
* stride - the length of one occurrence.  Pass one
* writes it; pass two looks every data name up in
* it, because a table item needs a subscript and
* the SUBS instruction carries the count and the
* stride (FIXLIST A2).
NOCC EQU $1F60
OCCTAB EQU $1F61

* ---- $1F20: the SOURCE handover -----------------
* EDIT leaves a program in auxiliary memory and then
* RTSes back to the menu, taking its variables with
* it - NLINES lives at $8000-something inside EDIT's
* own overlay and is gone the moment anything else
* loads.  So the count has to be published somewhere
* outside the band, and this is it.
*
* It is NOT the compiler's block: anything that
* leaves a document in aux writes it, and anything
* that wants to read one reads it.  COMPILE1 is
* simply the first consumer.
*
* SRCSIG is checked, not assumed.  Cold-booting and
* pressing 5 without ever entering the editor would
* otherwise compile whatever the previous session
* left in aux, which is the kind of failure that
* produces an object file rather than a message.
* SYSBOOT clears it.
SRCXFR EQU $1F20
SRCSIG EQU SRCXFR+0
SRCLIN EQU SRCXFR+2
* the record geometry the lines were written with.
* AXSHIFT and AXRSZ are global and the query engine
* sets its own, so a reader restores these rather
* than trusting what it finds.
SRCSHF EQU SRCXFR+4
SRCRSZ EQU SRCXFR+5
* the program name, length-prefixed, as EDIT knows
* it - so a compile can name its object without
* asking again
SRCNAM EQU SRCXFR+6
SRCEND EQU SRCXFR+24

* ---- program regions ----
* COBOL.SYSTEM loads at $2000 and stays: no
* relocation, no two-phase boot.  Overlays load
* above it and RTS back into the menu.
SYSBASE EQU $2000
* COBOL.LIB: $3000-$7FFF, 20K.  Far more than the
* ~6K the modules are expected to need, but the
* TOP of the library is not part of the frozen
* ABI - only the base at $3000 is - so this
* boundary can move later without invalidating a
* single compiled object.  Only the base is
* permanent.
* $4000 since 2026-11-08: the library now ends
* below $7000 (BCD, PICTURE and ERRMSG went to the
* aux language card), and $7000-$7FFF belongs to
* LOWBASE below.
LIBLEN EQU $4000
* THE LOW BAND: the interpreter, both compiler
* passes, EDIT and REPORT load here, into what the
* library gave back.  $6000 since 2026-11-08 (was
* $7000): the library ends near $5F90, and list B
* had filled COMPILE2.  So the library must now end
* below $6000 - anything new for it goes on the aux
* language card, which has room (tools/check.js
* holds LIB to $6000).  The other overlays keep
* $8000 - their own layouts are built around it.
* Each low overlay is read no further than the
* data it must not overwrite: the VM stops at
* RUNBASE (the object is already there), the
* compiler at OBCODE.
LOWBASE EQU $6000
* the overlay band: $8000-$AFFF, 12K, one at a
* time.  When a compiled program runs, no overlay
* is ever loaded, so this whole band becomes the
* p-code object and its WORKING-STORAGE.
OVLBASE EQU $8000
* the main menu's left edge: its longest line, 45
* characters, centred in 80.  The compiler indents
* its messages to it, so they sit under the menu.
MENUCOL EQU 17
OVLMAX EQU $3000
* where a compiled object is loaded to run.  VM.S
* has its own OBJBASE EQU and the two MUST agree -
* this one is for the menu, which does the loading,
* and that one is for the interpreter, which does
* the running.  $8000 and 12,288 bytes since
* 2026-11-22 ($9200 and 7,680 before): the
* interpreter ends at $7B8A, and the 5.7K above it
* was unused (VM.S).
RUNBASE EQU $8000
RUNMAX EQU $3000
* How many pages a low overlay may read (RUNLOW).
* Written as numbers on purpose: Merlin reads
* expressions left to right and #> of a difference
* is a trap.  VMPGS = (RUNBASE - LOWBASE) / 256;
* CMPPGS = (CODSTG + its 2,816 - LOWBASE) / 256:
* the compilers may still run to $A4FF, and the
* old code buffer above that is now CODSTG, a
* staging area (CMPCON.S) - change one, change both.
VMPGS EQU $20
CMPPGS EQU $45
* EDPGS = (EDCACHE - LOWBASE) / 256: EDIT and VIEW
* load at $7000 since 2026-11-08, and the line ring
* at $9800 is the ceiling
EDPGS EQU $38
* RPPGS: REPORT, likewise, under its header at $97E0
RPPGS EQU $37

* ===== FILE BUFFERS ($B000-$BEFF) =====
* A ProDOS file buffer is 1024 bytes and must start
* on a page boundary - not 512, which is the size
* of the block it reads.  One per OPEN file, so
* three of them: a COBOL program with two SELECTs
* can still list a directory to pick a file.
IOBUF EQU $B000
IOBUF2 EQU $B400
IOBUF3 EQU $B800

* ---- pathname buffers ----
* Full pathnames, prefix and all, not bare names.
* ProDOS would apply the current prefix for us, but
* source lives in one subdirectory and data in
* another, and a running program needs both without
* switching the prefix under itself.
* ProDOS caps a pathname at 64 characters; 128
* bytes each is room and a half.
FNBUF1 EQU $BC00
FNBUF2 EQU $BC80

* $BD00-$BD28 is ERRBUF (below).
* ---- the two prefixes main memory keeps ----------
* (2026-11-11, PREFIX.S has the scheme.)  SYSPFX is
* */, the boot prefix: COBOL.SYSTEM's SETPFX reads
* it here at boot, and LOADF puts it back in force
* for a moment whenever an overlay is loaded, so the
* system's own files come from where it booted
* whatever 0/ says.  WRKPFX is where LOADF parks 0/
* meanwhile.  The aux card has a copy of */ too, for
* name expansion; this one is for ProDOS.
SYSPFX EQU $BE00
WRKPFX EQU $BE40
* $BE80-$BEFF free.

* ---- COBOL.SETTINGS, staged in CATBLK ------------
* Read at boot, written by Utilities.  Layout:
*   +0  'SET1'   +4 printer slot  +5 printer mode
*   +6  two bytes kept for later
*   +8  prefixes 1/-9/, 64 bytes each, length first
*   +584 0/, the program prefix
* 648 bytes, in CATBLK and DCTBUF's front - nobody
* is cataloguing or holding a dictionary at boot or
* while Utilities runs.
SETBUF EQU $1000
SETLEN EQU 648

* ---- the Utilities overlay ($A000) ---------------
* Utilities left COBOL.SYSTEM on 2026-11-11: it was
* 1,947 of the 4,096 bytes there, with ten to spare,
* and the prefixes needed five hundred.  It loads
* above the copy buffer, which is $6000-$9FFF.
UTLBASE EQU $A000
* COBOL.SYSTEM's two entries the overlay calls, at
* fixed addresses just past TKNAME (COBOLSYS.S)
XTOSYS EQU $2013
XTOWRK EQU $2016

* ---- system ----
MLI EQU $BF00
* ProDOS page-usage bitmap.  Pages $08-$1F are
* free as far as ProDOS knows, so startup MUST
* claim them or an MLI OPEN will drop a 1K file
* buffer into text page 2 or the library.
* $BF59 = pages $08-$0F, $BF5A = $10-$17,
* $BF5B = $18-$1F.  Set all three to $FF.
* ---- the ProDOS clock globals ----
* Four bytes ProDOS stamps every file it creates
* from.  MACHID bit 0 says whether it believes
* there is a clock; with it clear its CLOCK routine
* is an RTS, so these keep whatever they hold - and
* writing them once at startup is the whole fix.
* KVERSION: the kernel's version.  ProDOS keeps a
* small number here; COBOL.OS $C0 and up.  Start-up
* tests it, so this build never runs on COBOL.OS
* (SYSBOOT.S).
KVERS EQU $BFFF
DATELO EQU $BF90
TIMELO EQU $BF92
MACHID EQU $BF98
* The vector ProDOS calls to refresh the date, and
* the language-card switches a driver must be
* copied in behind.
DATETIME EQU $BF06
RWRAM1 EQU $C08B
ROMIN2 EQU $C082
* ---- the auxiliary language card (GATE.S) ----
* $C083 read TWICE: RAM bank 2 readable AND
* writable - the code in the card keeps its own
* variables beside it, so the gate needs both.
* $C081 read TWICE: ROM readable, RAM bank 2
* writable - how COBOL.AUX is copied in at boot.
* Which card they act on is ALTZP's choice.
LCRW2 EQU $C083
LCWR2 EQU $C081
AUXBASE EQU $D000
* the most COBOL.AUX may be: up to $FFFA, below the
* card's own interrupt vectors
AUXMAX EQU $2FFA
* ERRMSG's text, copied down out of the card where
* main code can read it.  $BD00-$BEFF was free.
ERRBUF EQU $BD00
PTRIG EQU $C070
BITMAP EQU $BF58

* ---- monitor ROM entries ----
* COUT and GETLN are 40-column, page-1 only.  They
* are for the SETUP phase before the driver takes
* over; afterwards use PUTS and GETLN80.
HOME EQU $FC58
COUT EQU $FDED
COUT1 EQU $FDF0
CROUT EQU $FD8E
RDKEY EQU $FD0C
GETLN EQU $FD6A
AUXMOVE EQU $C311
* The monitor delay, which the ProDOS beep is built
* on.  Calling the ROM beats carrying a copy.
MONWAIT EQU $FCA8
SPKR EQU $C030
