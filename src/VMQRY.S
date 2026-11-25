* VMQRY.S  the QUERY verb - $D4 $D5 $D7 $D8
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= THE QUERY VERB ==============
* Four opcodes, and every one of them is the same
* shape: pull the operands out of the code stream,
* fill in the library's parameter block at $0C90,
* JSR one vector, record QSTAT, branch if the
* program asked to be told.
*
* NOTHING HERE KNOWS WHAT A PREDICATE IS.  The
* engine is SELECT.S and SORT.S and it was written
* months before there was a verb; this file is the
* door, and it is deliberately thin enough to see
* through.  QUERY.md 15.5 is the specification and
* this file is the whole of the implementation.

* how many cursor entries the interpreter claims
QMAXE EQU 1000
* the dictionary buffer: $1200 up to CSHADOW
DCTMAX EQU $0300
* VMTXT is 24 bytes and a numeric field arriving
* through PICDEED has to fit in it
VQTMAX EQU 24

* ---- $D4 QOPEN --------------------------------
* QUERY name USING dict {FOR n | OF file}
*      [GIVING c] [ON ERROR ...]
* operands: qryoff w, dictoff w, src b, srcarg w,
*           count w, status w, err w
*
* THE WHOLE PIPELINE IS ONE INSTRUCTION - load,
* init, scan, sort.  QUERY.md 10 says that order
* never varies, so there was no reason to make a
* compiler emit four instructions and every reason
* not to: separate opcodes would let a code
* generator emit a scan with no init, and that is
* the one order that writes a cursor over the top of
* the records it is scanning.
VQOPEN JSR VLIT
 LDA VMPT
 STA VQNAM
 LDA VMPT+1
 STA VQNAM+1
 JSR VLIT
 LDA VMPT
 STA VQDCT
 LDA VMPT+1
 STA VQDCT+1
 JSR VFETCH
 STA VQSRC
 JSR VFETW
 LDA VMW
 STA VQARG
 LDA VMW+1
 STA VQARG+1
 JSR VFETW
 LDA VMW
 STA VQCNT
 LDA VMW+1
 STA VQCNT+1
* The status item is recorded here and nowhere else.
* QUERY STATUS IS is one pointer for the life of the
* program, and QOPEN is necessarily the first query
* statement to run - nothing can walk a cursor that
* was never built - so this is the single store
* KEYWORDS.md promises, without spending a fifth
* opcode to make the point.
 JSR VFETW
 LDA VMW
 STA VQSTI
 LDA VMW+1
 STA VQSTI+1
* The error target is fetched LAST, so IP is past
* the whole instruction before anything can branch.
 JSR VFETW
 LDA VMW
 STA VQERR
 LDA VMW+1
 STA VQERR+1

 JSR VQDICT
 LDA QSTAT
 BEQ VQO1
 JMP VQODON
* the .QRY itself.  A text literal in the pool is
* length-prefixed, which is exactly what FNAMP
* wants, so the name needs no copying anywhere.
VQO1 LDA VQNAM
 STA FNAMP
 LDA VQNAM+1
 STA FNAMP+1
 LDA #$4D
 JSR VQSFX
 JSR QRYLOAD
 LDA QSTAT
 BEQ VQO2
 JMP VQODON
* src: 0 = FOR an item, 1 = OF a file, 2 = FOR a
* literal.  Two ways of saying FOR because FOR 500
* is the ordinary case and a constant in the source
* should be a constant in the code - the same
* argument DISPA makes for AT LINE n COLUMN n.  The
* alternative was to make the compiler invent a data
* item to hold a number it already knows.
VQO2 LDA VQSRC
 CMP #1
 BNE VQO2A
* OF file-name.  The operand is the file's number,
* 0 or 1, and QSRC is that plus one - 0 is taken,
* it means auxiliary memory.  There is no record
* count to give: the scan reads until RECMAN runs
* out, and QRYINIT checks the file is open.
 LDX VQARG
 INX
 STX QSRC
 JMP VQO4
* records 0..n-1 already in auxiliary memory, which
* is the case the system is built for.
VQO2A STZ QSRC
 CMP #2
 BEQ VQO2B
 LDA VQARG
 STA VMW
 LDA VQARG+1
 STA VMW+1
 JSR VQGETN
 JMP VQO3
VQO2B LDA VQARG
 STA VMW
 LDA VQARG+1
 STA VMW+1
VQO3 LDA VMW
 STA QNREC
 LDA VMW+1
 STA QNREC+1
* Where the cursor goes is the INTERPRETER'S policy
* and not the program's, which is why neither of
* these two numbers is in the source language.
* QUERY.md 8 refuses rather than collides, and when
* the bank allocator STATUS.md still owes arrives,
* this pair of stores is what it replaces.
VQO4 STZ QBANK
 LDA #<QMAXE
 STA QMAX
 LDA #>QMAXE
 STA QMAX+1
 JSR QRYINIT
 LDA QSTAT
 BNE VQODON
 JSR QRYSCAN
 LDA QSTAT
 BNE VQODON
* No sort keys is not a failure and not a special
* case: QUERY.md 4 says a sort is a selection that
* keeps everything, and a selection with no keys is
* simply not sorted.
 LDA QKEYN
 BEQ VQODON
 JSR QRYSORT
VQODON JSR VQGIVE
 JMP VQEND

* ---- VQSFX: FNAMP's name with suffix type A -----
* QUERY "BIGBAL" USING "CUST" finds BIGBAL.QRY and
* CUST.DCT, the names the designers gave them; a
* name written with its suffix is used as written.
* SETSFX answers in FNBUF1, and FLOAD may be handed
* FNBUF1 itself (FILEIO.S says so).
VQSFX LDX #0
 JSR SETSFX
 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 RTS

* ---- VQDICT: load the .DCT named by USING -------
* FORMAT and REPORT reach a dictionary through
* DICTLOAD, which lives in PRODOS.S - an OVERLAY
* file, not a library module - so the interpreter
* cannot call it and must not grow a copy.  FLOAD is
* in the library and does the same job: a dictionary
* is a few hundred bytes and is read in one shot.
*
* USING is required rather than optional because the
* .QRY header has no room to name its dictionary -
* QUERY.md 15.3.  A query's field numbers are
* meaningless without it, so somebody has to say
* which one, out loud.
VQDICT LDA VQDCT
 STA FNAMP
 LDA VQDCT+1
 STA FNAMP+1
 LDA #$49
 JSR VQSFX
 LDA #<DCTBUF
 STA FADDR
 LDA #>DCTBUF
 STA FADDR+1
 LDA #<DCTMAX
 STA FLEN
 LDA #>DCTMAX
 STA FLEN+1
 JSR FLOAD
 BCS VQDB
* Version 1 kept NUM fields as digit text; the
* engine now reads them as NUM8 cells, so an old
* dictionary is refused rather than misread.  Open
* it in FORMAT and save it again.
 LDA DCTBUF+4
 CMP #2
 BCS VQD1
VQDB LDA #9
 STA QSTAT
 RTS
VQD1 LDA #<DCTBUF
 STA QDICT
 LDA #>DCTBUF
 STA QDICT+1
 STZ QSTAT
 RTS

* ---- $D5 QNEXT --------------------------------
* QUERY NEXT [GIVING r] [AT END ...]
* operands: rec item w, at-end target w
*
* This one does NOT go through VQEND.  SLNEXT does
* not touch QSTAT - running off the end of a cursor
* is not an error, it is the ordinary way a walk
* finishes - so there is no status to record and
* AT END is the whole of the reporting.  A COBOL
* READ with no AT END carries on too.
VQNEXT JSR VFETW
 LDA VMW
 STA VQARG
 LDA VMW+1
 STA VQARG+1
 JSR VFETW
 LDA VMW
 STA VQT
 LDA VMW+1
 STA VQT+1
 JSR QRYNEXT
 BCC VQN1
 LDA VQT
 AND VQT+1
 CMP #$FF
 BEQ VQN2
 LDA VQT
 STA VMW
 LDA VQT+1
 STA VMW+1
 JMP VBRA2
VQN2 JMP VMLOOP
* a hit: QREC is the record number, and the program
* gets it if it asked.  This is what makes a cursor
* usable against a real file later - the answer is a
* list of record numbers and nothing else.
VQN1 LDA VQARG
 AND VQARG+1
 CMP #$FF
 BEQ VQN3
 LDA QREC
 STA BINVAL
 LDA QREC+1
 STA BINVAL+1
* From a FILE the answer is the RELATIVE KEY, which
* counts from 1, so the program can MOVE it to the
* key and READ the record it names.  Records in aux
* memory count from 0, as FOR n always has.
 LDA QSRC
 BEQ VQN4
 INC BINVAL
 BNE VQN4
 INC BINVAL+1
VQN4 LDA VQARG
 STA VMW
 LDA VQARG+1
 STA VMW+1
 JSR VQPUTN
VQN3 JMP VMLOOP

* ---- $D7 QSORT --------------------------------
* QUERY SORT [ON ERROR ...]
* operand: err target w
*
* Sorting a cursor you already hold is a different
* thing from running a query, which is why this is
* an opcode of its own: folding it into QOPEN would
* mean re-scanning the data to change the order of a
* list already sitting in memory.
* VQSTI IS NOT TOUCHED HERE.  QUERY STATUS IS is one
* pointer for the life of the program, set by QOPEN;
* clearing it would not mean "no status item", it
* would mean ITEM ZERO, and the status of every sort
* would be written over the program's first data
* item.  $0000 is a valid item number and only
* $FFFF means absent.
VQSORT JSR VFETW
 LDA VMW
 STA VQERR
 LDA VMW+1
 STA VQERR+1
 JSR QRYSORT
 JMP VQEND

* ---- $D8 QFLD ---------------------------------
* QUERY FIELD n INTO x
* operands: field b, dest item w
*
* The field number is an IMMEDIATE BYTE, following
* the precedent DISPA set for AT LINE n COLUMN n: it
* is constant in the source, so it is constant in
* the code.
VQFLD JSR VFETCH
 STA QFNO
 JSR VOPD
 JSR QRYFLD
 LDA QSTAT
 BEQ VQF1
 JSR VQPUTS
 JMP VMLOOP
VQF1 LDA QFTYP
 CMP #2
 BCS VQFC
 LDA VMD2+DTYPE
 CMP #TNUM
 BEQ VQF3
* Text into text.  QFBUF as it stands, space filled
* and truncated on the right, which is COBOL's own
* alphanumeric MOVE and the same library routine
* every other MOVE in the interpreter calls.
 LDA #<QFBUF
 STA ZPT1
 LDA #>QFBUF
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA QFLEN
 STA ALEN
 LDA VMD2+DLEN
 STA BLEN
 JSR MOVALP
 JMP VMLOOP
* A TEXT field into a numeric item - a ZIP code
* kept as X(5), say.  PICDEED is the converter, the
* same call ACCEPT makes: what is in the record is
* text that means a number.
*
* Truncated to VQTMAX because PICDEED reads a
* length-prefixed string and VMTXT is 24 bytes.  A
* NUM8 cell holds fourteen digits, so a field that
* loses anything here could not have been stored.
VQF3 LDA QFLEN
 CMP #VQTMAX+1
 BCC VQF4
 LDA #VQTMAX
VQF4 STA VMTLEN
 TAY
VQF5 DEY
 BMI VQF6
 LDA QFBUF,Y
 STA VMTXT,Y
 JMP VQF5
VQF6 LDA #<VMTLEN
 STA ZPT1
 LDA #>VMTLEN
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DDEC
 STA PICSCL
 JSR PICDEED
 JMP VMLOOP
* A NUM or BOOL field is a NUM8 cell already
* (DICTIONARY.md 3), at the field's scale, which
* FORMAT always writes as 0.  Into a numeric item
* it is MOVE: the cell, then VALIGN to the item's
* decimals.  Into a text item it is an edited MOVE
* with as many digits as the item is wide.
VQFC LDA #<QFBUF
 STA VMO1
 LDA #>QFBUF
 STA VMO1+1
 STZ VMD1+DDEC
 LDA VMD2+DTYPE
 CMP #TNUM
 BEQ VQFN
 LDA VMD2+DLEN
 CMP #NDIG+1
 BCC VQFW
 LDA #NDIG
VQFW ASL
 ASL
 ASL
 ASL
 STA VMD1+DFLG
 JSR VEDIT
 JMP VMLOOP
VQFN JSR VSETP
 JSR BCDMOV
 JSR VALIGN
 JMP VMLOOP

* ================= THE SHARED TAIL =============
* ---- VQEND: the status item, then the branch ----
* Two of the four opcodes end here, and it is the
* only reason the verb costs the space it does
* rather than half as much again.
VQEND JSR VQPUTS
 LDA QSTAT
 BEQ VQE1
 LDA VQERR
 AND VQERR+1
 CMP #$FF
 BEQ VQE1
 LDA VQERR
 STA VMW
 LDA VQERR+1
 STA VMW+1
 JMP VBRA2
VQE1 JMP VMLOOP

* ---- VQPUTS: QSTAT -> the QUERY STATUS item -----
* $FFFF means the clause was absent.  It is not a
* valid item number and not a valid code offset, so
* the same test serves for every optional operand in
* the verb and no form needs a flag byte.
VQPUTS LDA VQSTI
 AND VQSTI+1
 CMP #$FF
 BEQ VQPX
 LDA QSTAT
 STA BINVAL
 STZ BINVAL+1
 LDA VQSTI
 STA VMW
 LDA VQSTI+1
 STA VMW+1
 JMP VQPUTN
VQPX RTS

* ---- VQGIVE: QCOUNT -> the GIVING item ----------
VQGIVE LDA VQCNT
 AND VQCNT+1
 CMP #$FF
 BEQ VQGX
 LDA QCOUNT
 STA BINVAL
 LDA QCOUNT+1
 STA BINVAL+1
 LDA VQCNT
 STA VMW
 LDA VQCNT+1
 STA VMW+1
 JMP VQPUTN
VQGX RTS

* ---- VQPUTN: BINVAL -> the item numbered VMW ----
* Two kinds of destination and the DESCRIPTOR says
* which - a COMP item takes the two bytes as they
* stand, a numeric item is a NUM8 cell and needs
* BINBCD.  Reading that out of the descriptor rather
* than trusting what the programmer wrote is the
* rule every other move in the interpreter follows.
VQPUTN JSR VOPD2
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DTYPE
 CMP #TNUM
 BNE VQPN1
 JMP BINBCD
VQPN1 LDY #0
 LDA BINVAL
 STA (ZPT2),Y
 INY
 LDA BINVAL+1
 STA (ZPT2),Y
 RTS

* ---- VQGETN: the item numbered VMW -> VMW -------
VQGETN JSR VOPD2
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DTYPE
 CMP #TNUM
 BNE VQGN1
 JSR BCDBIN
 JMP VQGN2
VQGN1 LDY #0
 LDA (ZPT2),Y
 STA BINVAL
 INY
 LDA (ZPT2),Y
 STA BINVAL+1
VQGN2 LDA BINVAL
 STA VMW
 LDA BINVAL+1
 STA VMW+1
 RTS

* ================= VARIABLES ===================
* The five that hold an OPTIONAL operand start at
* $FFFF, not at zero, and are DFB rather than DS for
* exactly that reason: $0000 is item zero and would
* be written to, while $FFFF is the absent marker
* every test in this file already uses.  It matters
* if a QUERY SORT or a QUERY NEXT is ever reached
* before a QUERY has run - which the compiler will
* not emit, and which should still not corrupt the
* program's first data item.
VQNAM DS 2
VQDCT DS 2
VQSRC DFB 0
VQARG DFB $FF,$FF
VQCNT DFB $FF,$FF
VQSTI DFB $FF,$FF
VQERR DFB $FF,$FF
VQT DFB $FF,$FF
