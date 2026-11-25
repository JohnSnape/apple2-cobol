* EQUATES.S  shared equates for the suite.
* PUT this FIRST in every main, before anything
* else - LIB.S, an overlay, or a test.  One source
* of truth for zero page, soft switches, library
* vectors and system addresses.  Nothing here
* generates a byte of code.

* ===== ZERO PAGE ZONE MAP (whole system) =====
* Free for us: $02-$1F and $56-$FF.  Monitor owns
* $20-$4F/$50-$55; ProDOS owns $00-$01/$40-$4E;
* AUXMOVE scribbles $3C-$43.
*   $02-$05  G  dispatcher globals (persistent)
*   $06-$1F  S  shared scratch (caller-saved)
*   $60-$8F  P  active-driver registers (persist)
*   $90-$AF  D  service-private scratch
*   $B0-$FF     reserved for future services
* GOLDEN RULE: a service touches only zone S (and
* its own D slice) - NEVER zone P.  That lets the
* p-code VM keep IP/SP/FP live across the many
* service calls an opcode makes.
* Zone P = VM register file under RUNTIME, or the
* hot state of whatever overlay is running
* (EDIT/VIEW/COMPILE/FORMAT) - only one is ever
* live, so they reuse it.

* ---- zone G: dispatcher globals ($02-$05) ----
* Currently unused.  Its one tenant was RAMFLG,
* which went with the /RAM handling.  The zone
* stays reserved: it is the only zero page a
* program can count on surviving its own overlays.
ZPGLOB EQU $02

* ---- zone S: shared scratch (arch 3.4) ----
* caller-saved: assume destroyed across any JSR.
ZPT1 EQU $06
ZPT2 EQU $08
ZPREC EQU $0A
ZPDICT EQU $0C
ZPFLD EQU $0E
ZPSCR EQU $10
ZPNODE EQU $12
ZPCOLS EQU $14
ZPWORK EQU $16
* $15 was ZPPAGE, the text-page flag.  It moved to
* SCRPAGE in the text driver: zone S is caller-
* saved, so a flag that must survive every JSR in
* the system could never have lived here.
* $15, $18-$1F free for more caller-saved temps.

* ---- module names -> zone S slots ----
* (aliases so existing code needs no edits;
* new code should prefer the ZPxxx names)
STRPTR EQU ZPT1
DPTR EQU ZPT1
LPTR EQU ZPT2
FDPTR EQU ZPFLD
FLDPTR EQU ZPFLD
WPTR EQU ZPFLD
SCRPTR EQU ZPSCR
RECP EQU ZPNODE
LBPTR EQU ZPNODE

* ---- zone P: active-driver registers ----
* VM registers / overlay hot state.  Define the
* specific registers with the interpreter/editor.
ZPDRV EQU $60

* ---- zone D: service-private scratch ----
ZPSVC EQU $90

* ---- reserved for future services ----
* $B0-$EF and $F4-$FF are free.  $FE/$FF held the
* inline-string pointer for PRMESSAGE, which is
* gone: two message routines that worked in
* different ways was one too many.  MPRINT serves
* the startup phase, PUTS serves everything after
* INIT80, and neither plays games with the return
* address.
ZPRSVD EQU $B0

* ---- zone R: the entropy counter ($F0-$F3) ----
* A 32-bit counter that runs while the machine
* waits for a key, exactly as the Apple II monitor
* ran RNDL/RNDH at $4E/$4F inside KEYIN.  Applesoft
* never used those two bytes; we keep four, and we
* keep them because the only unpredictable thing
* about this machine is when a person presses a
* key.
*
* IT IS A SEED, NOT A GENERATOR.  It advances only
* while waiting for input, so two reads with no
* keypress between them return the same number.
* Anything wanting a sequence of random values
* must seed a PRNG from this ONCE and then step
* the PRNG.
*
* Owned by the key-wait loops.  Nothing else may
* write it; anyone may read it.
RNDSEED EQU $F0

* ---- soft switches ----
* $C000 reads as the keyboard and writes as
* 80STORE OFF.  Same address, two meanings,
* decided by whether you LDA it or STA it.
KBD EQU $C000
CLR80S EQU $C000
SET80S EQU $C001
MAINRD EQU $C002
AUXRD EQU $C003
MAINWR EQU $C004
AUXWR EQU $C005
ALTZPOFF EQU $C008
ALTZPON EQU $C009
SET80V EQU $C00D
ALTCHR EQU $C00F
KBDSTRB EQU $C010
* RamWorks-style bank select.  Harmless on a plain
* IIe, where it is only a paddle trigger.
BANKSEL EQU $C073
TXTSET EQU $C051
MIXCLR EQU $C052
* DISPLAY page select.  These are only the display
* page because the text driver keeps 80STORE OFF;
* with 80STORE ON they would instead be the
* main/aux bank select for $0400-$07FF, which is
* how the old SCREEN.S used them and why it could
* never reach page 2.
PG1SEL EQU $C054
PG2SEL EQU $C055
OPNAPPL EQU $C061
SLDAPPL EQU $C062

* older names kept for COBOLSYS's 128K test
STORE80 EQU SET80S
MAINREAD EQU MAINRD
AUXREAD EQU AUXRD
MAINWRITE EQU MAINWR
AUXWRITE EQU AUXWR
VID80 EQU SET80V
* MAINSW / AUXSW are deliberately NOT defined any
* more.  They meant "bank select" only while
* 80STORE was on.  Anything still using them must
* fail to assemble rather than quietly write to
* the wrong bank - or worse, flip the display page
* in the middle of a character.

* ===== RUNTIME LIBRARY (COBOL.LIB at $3000) =====
* Every program BLOADs COBOL.LIB to $3000 as its
* first act - the menu, each overlay, and any
* compiled p-code program running on its own.
* This table is the ABI.  A compiled object calls
* the runtime by address and will outlive any
* particular assembly of the library, so: APPEND
* new vectors at the end, never reorder, never
* reuse a retired slot.
* The library CODE lives at $3000-$7FFF and the
* table sits at its front, so COBOL.LIB is one
* contiguous file with one load address.  All of
* the library's variables and buffers live down in
* $0C00-$1FFF, which is never loaded - it is
* addresses, not a file.  Code and data separated,
* which is why the code got 12K.
LIBBASE EQU $3000
* --- slots 0-15: text driver ---
INIT80 EQU LIBBASE+$00
SETPAGE EQU LIBBASE+$03
GETPAGE EQU LIBBASE+$06
SWAPPAGE EQU LIBBASE+$09
SCRADDR EQU LIBBASE+$0C
CONV EQU LIBBASE+$0F
PUTC EQU LIBBASE+$12
PUTS EQU LIBBASE+$15
PUTSX EQU LIBBASE+$18
PUTAT EQU LIBBASE+$1B
CLRSCR EQU LIBBASE+$1E
CLRDATA EQU LIBBASE+$21
CLRROW EQU LIBBASE+$24
WAITKEY EQU LIBBASE+$27
GETLN80 EQU LIBBASE+$2A
HOME80 EQU LIBBASE+$2D
* --- slots 16-18: file I/O ---
SPLITNM EQU LIBBASE+$30
FLOAD EQU LIBBASE+$33
FSAVE EQU LIBBASE+$36
* --- slot 19: directory listing ---
CATALOG EQU LIBBASE+$39
* --- slots 20-31: decimal arithmetic ---
* B = B op A.  ZPT1 -> A, ZPT2 -> B.  No length:
* every numeric cell is the same 8 bytes.  Same
* scale, though - this pack does arithmetic, not
* alignment; the compiler emits BCDSHL/BCDSHR to
* line the decimal points up first.
BCDADD EQU LIBBASE+$3C
BCDSUB EQU LIBBASE+$3F
BCDMUL EQU LIBBASE+$42
BCDDIV EQU LIBBASE+$45
BCDCMP EQU LIBBASE+$48
BCDZRO EQU LIBBASE+$4B
BCDMOV EQU LIBBASE+$4E
BCDNEG EQU LIBBASE+$51
BCDSHR EQU LIBBASE+$54
BCDSHL EQU LIBBASE+$57
BCDRND EQU LIBBASE+$5A
BCDTST EQU LIBBASE+$5D
* --- slots 32-35: conversions ---
BCDPACK EQU LIBBASE+$60
BCDUNPK EQU LIBBASE+$63
BCDBIN EQU LIBBASE+$66
BINBCD EQU LIBBASE+$69
* --- slots 36-38: alphanumeric ---
MOVALP EQU LIBBASE+$6C
CMPALP EQU LIBBASE+$6F
FILLCH EQU LIBBASE+$72
* --- slot 39: decimal output ---
DEC16 EQU LIBBASE+$75
* --- slots 40-41: auxiliary banks ---
FINDBNK EQU LIBBASE+$78
BMINIT EQU LIBBASE+$7B
* --- slots 42-49: scrolling console (CONSOLE) ---
* Plain DISPLAY and ACCEPT: no coordinates, the
* cursor advances, the screen scrolls.
* CONGETLN sets KEYTERM/KEYCHAR - see KEYS.md.
CONINIT EQU LIBBASE+$7E
CONCLR EQU LIBBASE+$81
CONPUTC EQU LIBBASE+$84
CONPUTS EQU LIBBASE+$87
CONCR EQU LIBBASE+$8A
CONGETLN EQU LIBBASE+$8D
CONSCRU EQU LIBBASE+$90
* slot 49 ($3093) is RETIRED - it was CONSCRD,
* scroll down.  Kept as an RTS and never reused.
* The equate is deliberately NOT defined, so code
* that still calls it fails to assemble instead of
* silently doing nothing.
* --- slots 50-53: positioned screen (DSCREEN) ---
* DISPLAY/ACCEPT ... AT LINE n COLUMN n.  Nothing
* here scrolls or wraps.
DSAT EQU LIBBASE+$96
DSPUTS EQU LIBBASE+$99
DSPBUF EQU LIBBASE+$9C
DSACC EQU LIBBASE+$9F
* --- slots 54-57: auxiliary records (AUXMEM) ---
AXCAP EQU LIBBASE+$A2
AXMAP EQU LIBBASE+$A5
AXGET EQU LIBBASE+$A8
AXPUT EQU LIBBASE+$AB
* --- slots 58-60: readable numbers ---
NFCOMMA EQU LIBBASE+$AE
NFPUTR EQU LIBBASE+$B1
AMFREE EQU LIBBASE+$B4
* slots 61-63 ($30B7-$30BF) reserved for the
* record manager and the forms engine.  Currently
* RTS, so a call into an unbuilt service returns
* instead of running off into whatever is there.
* The PICTURE engine did NOT take these - it went
* on the end at 65-67, because by then the table
* had already grown past 64 and appending is
* always safe where reusing is not.
* --- slot 64: whole-row blit (TEXTDRV) ---
* X = row, ROWBUF = 80 screen codes.  The table
* grows at the end; slots 0-63 keep the addresses
* they were compiled against.
PUTROW EQU LIBBASE+$C0
* --- slots 65-67: the edit engine (PICTURE) ---
* PICEDIT: ZPT1 -> NUM8 cell, ZPT2 -> picture,
*   PICSCL = the cell's decimals -> PICBUF/PICLEN
* PICDEED: ZPT1 -> typed string, ZPT2 -> cell
* PICINIT: currency, point and separator to their
*   defaults.  SPECIAL-NAMES overwrites the bytes.
PICEDIT EQU LIBBASE+$C3
PICDEED EQU LIBBASE+$C6
PICINIT EQU LIBBASE+$C9
* --- slots 68-75: the query engine ---
* SELECT and SORT.  A query result is a LIST OF
* RECORD NUMBERS - the cursor - and neither verb
* ever moves a record.  QUERY.md is the design.
* The pipeline is always QRYINIT, QRYSCAN, then
* QRYSORT if there are keys, then QRYNEXT to walk
* it; only QRYFILT may be repeated.
QRYINIT EQU LIBBASE+$CC
QRYSCAN EQU LIBBASE+$CF
QRYFILT EQU LIBBASE+$D2
QRYSORT EQU LIBBASE+$D5
QRYGET EQU LIBBASE+$D8
QRYNEXT EQU LIBBASE+$DB
QRYLOAD EQU LIBBASE+$DE
QRYFLD EQU LIBBASE+$E1
* --- slots 76-78: the Apple command keys ---
* READMOD records the two switches and is called
* from inside every key wait in the system.
* KEYCHRD asks whether a keystroke was a command
* chord and, if it was, writes it down.
* KEYDONE records an ordinary terminator.
READMOD EQU LIBBASE+$E4
KEYCHRD EQU LIBBASE+$E7
KEYDONE EQU LIBBASE+$EA
* --- slots 79-82: the printer ---
* We never gave the screen to the firmware, so the
* printer cannot take it - see PRINTER.md.
PRINIT EQU LIBBASE+$ED
PRPUTC EQU LIBBASE+$F0
PRPUTS EQU LIBBASE+$F3
PRCR EQU LIBBASE+$F6
* --- slot 83: the ProDOS tone ---
* Not the monitor BELL at $FBDD, which is loud,
* high and long enough to make a room look up.
BELL EQU LIBBASE+$F9
* --- slots 84-87: the clock ---
DTHAS EQU LIBBASE+$FC
DTSET EQU LIBBASE+$FF
DTDATE EQU LIBBASE+$102
DTTIME EQU LIBBASE+$105
* --- slot 91: the date as M/D/YYYY ---
DTMDATE EQU LIBBASE+$111
* --- slot 88: choose among up to four printers ---
PRSEL EQU LIBBASE+$108
* --- slots 89-90: the clock ---
* CLKFIND installs a driver into ProDOS if it can
* find a clock; CLKASK is what to do when it cannot.
CLKFIND EQU LIBBASE+$10B
CLKASK EQU LIBBASE+$10E

* --- slots 92-99: relative files (RECMAN) ---
* The names the INTERPRETER calls.  RECMAN's own
* labels are RMOPEN, RMCLOS and so on, and the VM
* cannot use those: it is a separate assembly and
* the library is a separate file.  Everything
* crossing that line goes through the table, which
* is the whole reason the table exists.  Same
* arrangement as QRYINIT/SLINIT.
FILOPEN EQU LIBBASE+$114
FILCLOS EQU LIBBASE+$117
FILREAD EQU LIBBASE+$11A
FILNEXT EQU LIBBASE+$11D
FILWRIT EQU LIBBASE+$120
FILREWR EQU LIBBASE+$123
FILDEL EQU LIBBASE+$126
FILSTRT EQU LIBBASE+$129

* --- slots 100-101: the forms engine (SCRSHOW, SCRINP) ---
* The pair that makes ACCEPT a real verb.  A form
* lives in a .DCT and its field editor has to be
* reachable from compiled p-code, which can only
* call an address that does not move - so both are
* library modules with vectors, not PUT files that
* land wherever their host program put them.
* Set ZPDICT -> the dictionary and ZPREC -> the
* record buffer, then FRMSHOW to paint it and
* FRMACC to let the operator fill it in.  FRMACC
* RETURNS THE TERMINATOR IN A - 1 ESC, 2 command
* chord - because a compiled program is a separate
* assembly and cannot name a label inside the
* library.  KEYTERM/KEYCHAR say which chord it was.
* Module labels are SCRSHOW and SCRINP; the VM is a
* separate assembly and must use these names.
FRMSHOW EQU LIBBASE+$12C
FRMACC EQU LIBBASE+$12F

* --- slot 102: the class conditions (CLASS) ---
* IF X IS NUMERIC and its relatives, opcode $62.
* The module's own label is CLTEST; the interpreter
* is a separate assembly and must call CLASS.
* Set ZPT2 -> the item, CLCLS to the test, CLLEN to
* the item's length, and for a user class CLTAB to
* a 32-byte membership map.  Answers in A: 0 TRUE,
* 1 FALSE, which is the interpreter's condition
* register unchanged, so the branch after it is the
* same VBEQ every other comparison uses.
* CLASS.S lists the eleven test codes.
CLASS EQU LIBBASE+$132
CLCLS EQU $0D78
CLLEN EQU $0D79
CLTAB EQU $0D7A

* --- slots 103-104: the runtime error stop (ABORT) ---
* ABSET marks a recovery point and returns C=0; a
* later ABORT prints the fault, waits, and comes
* back to that same instruction with C=1.  setjmp
* and longjmp, and the only way out of a fault
* raised six JSRs deep inside an arithmetic
* statement that is being abandoned.
*
*   JSR ABSET
*   BCS FAULTED
*   ...the program...
*
* ABORT takes the code in A; ABCODE keeps it, so a
* program that wants to say which fault it was has
* somewhere to read it after the jump.  ABORT.S
* lists the nine codes.  Module labels are ABMARK
* and ABFAIL.
ABSET EQU LIBBASE+$135
ABORT EQU LIBBASE+$138
ABCODE EQU $0D7C

* --- slot 105: what a compiler error means ---
* A = the error number; STRPTR comes back pointing
* at a length-prefixed explanation for CONPUTS.
* Module label ERMSG, in ERRMSG.S.
CMPMSG EQU LIBBASE+$13B

* --- slot 106: a name with the suffix of a type ---
* A = the type, X = 0 add if missing / 1 replace.
* FNAMP -> the name; FNBUF1 and FTYPE come back.
SETSFX EQU LIBBASE+$13E

* --- slot 107: the prefixes, 2026-11-11 ---
* X=0 expand ZPT1's name into FNBUF1, X=1 get
* prefix Y into (ZPT2), X=2 set prefix Y from
* (ZPT1), X=3 clear them all.  PREFIX.S has the
* whole story; the code runs in the aux card.
PXSVC EQU LIBBASE+$141

* --- slot 108: the compiler's symbol table, ---
* 2026-11-11.  X = 0 init, 1 find, 2 add, 3 get,
* 4 put, 5 get chain, 6 put chain; SYMAUX.S has the
* registers.  Runs in the aux card; CMPSYM.S wraps it.
SYMSVC EQU LIBBASE+$144

* ---- the page mover, resident at $0300 ----
* Installed by BMINIT into main memory and every
* aux bank.  Called directly, not through a vector,
* because the whole point is that this address is
* identical in every bank.
*   A = page, X = bank ($FF = main),
*   C=1 write $0200 -> bank, C=0 read bank -> $0200
BMENTRY EQU $0300
BMBUF EQU $0200
* Largest bank count we will record.  The hardware
* allows 128 - eight megabytes - and a 16-bit
* record number at 512 records to a bank reaches
* exactly that many, so the two limits meet and
* neither wastes the other.
MAXBNK EQU 128

* ---- library public variables ($0CC0) ----
SCRROW EQU $0CC0
SCRCOL EQU $0CC1
SCRATR EQU $0CC2
CCOL EQU $0CC3
* read-only; call SETPAGE to change it
SCRPAGE EQU $0CC4
* --- file I/O parameters ---
FNAMP EQU $0CC5
FADDR EQU $0CC7
FLEN EQU $0CC9
FTYPE EQU $0CCB
* aux type.  For a DAT file this is the record
* length, following BASIC.SYSTEM's convention for
* random-access text files.  0 = sequential.
FAUX EQU $0CCC
* CATALOG: 0 lists everything, or point it at a
* $00-terminated list of file types to show.
CATFILT EQU $0CCE
* --- PICTURE parameters ---
* The three characters SPECIAL-NAMES may change.
* CURRENCY SIGN IS and DECIMAL-POINT IS COMMA are
* compile-time clauses that each set one byte here,
* which is the whole of their runtime cost.
PICCUR EQU $0CDD
PICDPT EQU $0CDE
PICCOM EQU $0CDF
* implied decimals of the cell being edited
PICSCL EQU $0CE8
* bit0 = BLANK WHEN ZERO
PICFLG EQU $0CE9
* length of the edited result in PICBUF
PICLEN EQU $0CEA
* de-edit found something it could not use
PICERR EQU $0CEB

* Continued in EQUATES2.  Merlin cannot load a PUT
* file over about 24K (MEMORY IN USE), so the
* equates are two files.  Every stub PUTs both,
* EQUATES first.
