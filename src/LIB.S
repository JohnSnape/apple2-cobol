* LIB.S  the runtime library.
* Assembles to COBOL.LIB, a BIN file that EVERY
* program in the system BLOADs to $3000 before it
* does anything else - the menu, each overlay, and
* any compiled p-code program running on its own.
*
* WHY A FILE AND NOT A RESIDENT BLOCK
* Not because anything needs to survive a QUIT -
* once we QUIT we are on our way out.  It is a
* file because that is what makes a compiled
* program self-sufficient: it loads COBOL.LIB to
* $3000 exactly as the menu did, and gets exactly
* the runtime the menu had, with no relinking and
* no copy of the library inside it.
*
* THE JUMP TABLE IS THE ABI
* $3000-$30BF is frozen: 64 slots, and the BASE is
* what is frozen, not the count - growth goes on
* the end.  A compiled p-code object calls the
* runtime by address and will outlive any
* particular assembly of this library.  APPEND new
* vectors.  Never reorder.  Never reuse a retired
* slot.
*
* Layout:
*   $0C00-$1FFF  DATA - variables and buffers.  NOT
*                part of this file: never loaded,
*                only addressed.  See EQUATES.
*   $3000-$30BF  jump table (64 slots)
*   $30C0-$7FFF  code
*
* The table sits at the front of the code, so this
* assembles to one contiguous file with one load
* address.  Keeping the table down at $0C00 with
* the data would have meant either two files or one
* file with a 20K hole straight through the menu.
*
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

 ORG $3000
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/COBOL.LIB

* ================= JUMP TABLE =================

* --- 0-15: text driver (TEXTDRV) ---
 JMP TDINIT
 JMP TDSETPG
 JMP TDGETPG
 JMP TDSWAP
 JMP TDSCRAD
 JMP TDCONV
 JMP TDPUTC
 JMP TDPUTS
 JMP TDPUTSX
 JMP TDPUTAT
 JMP TDCLRS
 JMP TDCLRD
 JMP TDCLRRW
 JMP TDWAITK
 JMP TDGETLN
 JMP TDHOME

* --- 16-18: file I/O (FILEIO) ---
 JMP FISPLT
 JMP FILOAD
 JMP FISAVE

* --- 19: directory listing (CATALOG) ---
 JMP CTLIST

* --- 20-31: decimal arithmetic (BCD) ---
 JMP BADD
 JMP BSUB
 JMP BMUL
 JMP BDIV
 JMP BCMP
 JMP BZERO
 JMP BMOVE
 JMP BNEG
 JMP BSHR
 JMP BSHL
 JMP BROUND
 JMP BTEST

* --- 32-35: conversions (BCD) ---
 JMP BPACK
 JMP BUNPK
 JMP BTOBIN
 JMP BFRBIN

* --- 36-38: alphanumeric (BCD) ---
 JMP BMOVA
 JMP BCMPA
 JMP BFILL

* --- 39: decimal output (CATALOG) ---
 JMP CTDEC

* --- 40-41: auxiliary banks (BANKS) ---
 JMP BKFIND
 JMP BKINIT

* --- 42-49: scrolling console (CONSOLE) ---
 JMP CNINIT
 JMP CNCLR
 JMP CNPUTC
 JMP CNPUTS
 JMP CNCR
 JMP CNGETLN
 JMP CNSCRU
* --- 49: RETIRED (was CNSCRD, scroll down) ---
* Removed, not repurposed.  The table is append-
* only: a retired slot keeps its three bytes and
* becomes an RTS, so an object compiled against the
* old library returns instead of landing in
* whatever moved up into the gap.
 DS 3,$60

* --- 50-53: positioned screen (DSCREEN) ---
 JMP DZAT
 JMP DZPUTS
 JMP DZPBUF
 JMP DZACC

* --- 54-57: auxiliary records (AUXMEM) ---
 JMP AMCAP
 JMP AMMAP
 JMP AMGET
 JMP AMPUT

* --- 58-60: readable numbers (NUMFMT, AUXMEM) ---
 JMP NMCOMA
 JMP NMPUTR
 JMP AMFRE

* --- 61-63: reserved ---
* Three slots left over from the original sixty-
* four.  Everything they were being held for went
* on the END of the table instead, where an
* already-compiled object cannot notice it: the
* PICTURE engine took 65-67, the record manager
* 92-99, the forms engine 100-101.  These three
* stay RTS, so a call into an unbuilt service
* returns instead of running off into whatever
* happens to be there.
 DS $30C0-*,$60

* --- 64: whole-row blit (TEXTDRV) ---
* The table was never fixed at 64 entries - only its
* BASE is frozen.  Growth goes on the end, where an
* already-compiled object cannot notice it.
 JMP TDPUTRW

* --- 65-67: the edit engine (PICTURE) ---
 JMP PIEDIT
 JMP PIDEED
 JMP PIINIT

* --- 68-75: the query engine (SELECT, SORT) ---
 JMP SLINIT
 JMP SLSCAN
 JMP SLFILT
 JMP SRSORT
 JMP SLGET
 JMP SLNEXT
 JMP SLLOAD
 JMP SLFLD

* --- 76-78: the Apple command keys (TEXTDRV) ---
 JMP TDKMOD
 JMP TDKCHD
 JMP TDKDNE

* --- 79-82: the printer (PRINTER) ---
 JMP PRTINI
 JMP PRTPUT
 JMP PRTSTR
 JMP PRTCR

* --- 83: the ProDOS tone (TEXTDRV) ---
 JMP TDBELL

* --- 84-87: the clock (DATIME) ---
 JMP DTHASC
 JMP DTSETC
 JMP DTDATC
 JMP DTTIMC

* --- 88: choose a printer (PRINTER) ---
 JMP PRTSEL

* --- 89-90: the clock (CLOCK) ---
 JMP CLKFIN
 JMP CLKASKX

* --- 91: the date, for a person (DATIME) ---
 JMP DTMDY

* --- 92-99: relative files (RECMAN) ---
* The eight COBOL file verbs.  Every one takes its
* parameters in the block at $0E70 and answers in
* RMSTAT, which IS the FILE STATUS item - two ASCII
* characters, not a code to be translated.
 JMP RMOPEN
 JMP RMCLOS
 JMP RMREAD
 JMP RMNEXT
 JMP RMWRIT
 JMP RMREWR
 JMP RMDEL
 JMP RMSTRT

* --- 100-101: the forms engine (SCRSHOW, SCRINP) ---
* The pair RUNTIME.md 2 calls blocking.  Until they
* were here they were PUT-included modules whose
* entry points moved with whatever host included
* them, and compiled p-code can only call an
* address that does not move - so ACCEPT could not
* be compiled at all.  SCRSHOW paints the form,
* SCRINP runs the field editor and returns the
* terminator in A.
 JMP SCRSHOW
 JMP SCRINP

* --- 102: the class conditions (CLASS) ---
 JMP CLTEST

* --- 103-104: the runtime error stop (ABORT) ---
 JMP ABMARK
 JMP ABFAIL

* --- 105: what a compiler error means (ERRMSG) ---
 JMP ERMSG

* --- 106: name + suffix for a type (FILEIO) ---
 JMP FISFX

* --- 107: the prefixes */ 0/ 1/-9/ (PREFIX.S,
* in the aux card, through the gate) ---
 JMP PXGATE

* --- 108: the compiler's symbol table (SYMAUX.S,
* in the aux card, through the gate) 2026-11-11 ---
 JMP SYGATE

* ================= LIBRARY CODE =================
* $30C0 upward.  Order does not matter; only the
* jump table is frozen.
 PUT TEXTDRV
 PUT FILEIO
 PUT CATALOG
* BCD, PICTURE and ERRMSG run from the auxiliary
* language card since 2026-11-08 - COBOL.AUX,
* AUXLC.S.  GATE.S keeps their names here.
 PUT GATE
 PUT BANKS
 PUT CONSOLE
 PUT DSCREEN
 PUT AUXMEM
 PUT NUMFMT
* SELECT before SORT: SORT calls SLRDIX/SLWRIX and
* shares QI/QAD/QBP with it.  Order does not matter
* to the assembler - one symbol table spans every
* PUT - but it matters to anyone reading.
 PUT SELECT
 PUT SELECT2
 PUT SORT
 PUT PRINTER
 PUT DATIME
 PUT CLOCK
 PUT RECMAN
* SCRSHOW before SCRINP: SCRINP calls GETFLD's view
* of the descriptor array and SCRSHOW paints the
* same array.  Order does not matter to Merlin -
* one symbol table spans every PUT - but a reader
* meets the drawing half first.
 PUT SCRSHOW
 PUT SCRINP
* CLASS after BCD: CLTEST calls BTEST directly,
* which it may - one symbol table spans every PUT -
* and a sign class condition is BTEST's answer
* with a different name on it.
 PUT CLASS

* ABORT last: it is the one module every other one
* may end up calling, and nothing calls it that is
* not already assembled by the time Merlin gets
* here.
 PUT ABORT

LIBEND EQU *
* If LIBEND ever passes $8000 the library has
* outgrown its region and is colliding with the
* overlay band.  Check it after every assembly.
