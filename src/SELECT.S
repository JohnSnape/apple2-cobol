* SELECT.S  choosing records: the cursor
* A library module (PUT it from LIB.S).
*
* The design is QUERY.md.  The one sentence of it
* that explains every decision below: a query
* result is a LIST OF RECORD NUMBERS, not a pile
* of records.  Nothing here ever copies a record,
* moves one, or writes one back.
*
* THE CURSOR
* One entry a hit, in auxiliary memory, at the top
* of bank QBANK:
*     0        .. QKEYL-1   the composite sort key
*     QKEYL    .. QKEYL+1   the record number, HIGH
*                           BYTE FIRST
* QESZ = QKEYL + 2.  With no sort keys QKEYL is 0
* and a hit costs two bytes.
*
* WHY THE KEY IS IN THE ENTRY
* Because the alternative is fetching the record
* again on every comparison, and a sort of a
* thousand records makes about eight thousand of
* them.  The key is built ONCE, here, during the
* single sequential pass the scan already makes -
* which is the only access pattern a floppy is any
* good at.  After that SORT.S never touches a
* record, a dictionary or a type code.
*
* WHY THE RECORD NUMBER IS BIG-ENDIAN
* It is the tail of the key, so a comparison that
* runs off the end of the key falls through into
* the record number and breaks the tie in FILE
* ORDER.  Shell sort is not stable; this makes the
* result stable anyway, for nothing.  It is the
* only big-endian value in the system and it is
* deliberate.
*
* WHAT THIS MODULE DOES NOT DO
* It does not allocate the bank.  QRYINIT checks
* that the cursor will not land on top of the
* records in use and refuses if it would; the real
* allocator is still owed - see STATUS.md.

* ---- limits ----
* QKMAX  the composite key.  Longer is an ERROR,
*        not a truncation: a truncated key sorts
*        almost right, which is the worst way for
*        a sort to be wrong.
* QPMAX  the predicate.  Small because the program
*        counter is a one-byte offset - zone S is
*        caller-saved and the evaluator calls
*        AXGET between every opcode, so a zero
*        page pointer could not have survived.
QFMAX EQU 40
QKMAX EQU 20
QPMAX EQU 96
QKEYS EQU 4
* one past the top of a bank.  MEMMAP: $BF00-$BFFF
* is not available to us.
QAUXT EQU $BF00
* the byte in front of QLBUF, where SLLCEL puts the
* literal's length for PICDEED
QLPFX EQU QLBUF-1

* =============== INITIALISE ===================
* ---- SLINIT: claim the area, settle the key ----
* in:  QBANK QMAX QKEYN QSPEC QDICT
*      NBANKS AXUSED AXRSZ AXSHIFT
* out: QKEYL QESZ QBASE, cursor emptied, QSTAT
SLINIT LDA #0
 STA QSTAT
 STA QCOUNT
 STA QCOUNT+1
 STA QIDX
 STA QIDX+1
 STA QKEYL
 LDA QSRC
 BEQ SLI00
 JSR SLFCHK
 LDA QSTAT
 BEQ SLI00
 RTS
SLI00 LDA QKEYN
 CMP #QKEYS+1
 BCC SLI0
 JMP SLIB4
* Each key's width comes from the DICTIONARY, never
* from the caller.  A caller that guessed could
* disagree with the descriptor, and then a saved
* query would sort correctly right up until someone
* widened the field in FORMAT.
SLI0 LDA #0
 STA QK
SLI1 LDA QK
 CMP QKEYN
 BCS SLI3
 LDA QK
 ASL
 CLC
 ADC QK
 TAY
 STY QSAV
 LDA QSPEC,Y
 STA QFNO
 JSR SLDESC
 LDA QSTAT
 BEQ SLI1A
 RTS
SLI1A LDY QSAV
 INY
 INY
 LDA QFLEN
 STA QSPEC,Y
 CLC
 LDA QKEYL
 ADC QFLEN
 STA QKEYL
 CMP #QKMAX+1
 BCC SLI2
 JMP SLIB4
SLI2 INC QK
 JMP SLI1
SLI3 CLC
 LDA QKEYL
 ADC #2
 STA QESZ
* ---- the area: QMAX entries of QESZ bytes -------
* Twenty-four bits, because a cursor can be bigger
* than sixteen bits of anything else here and a
* silent wrap would put QBASE somewhere pleasant
* and wrong.
 STZ QT
 STZ QT+1
 STZ QT2
 LDA QMAX
 STA QP
 LDA QMAX+1
 STA QP+1
 STZ QP+2
 LDA QESZ
 STA QMUL
SLI4 LDA QMUL
 BEQ SLI6
 LSR QMUL
 BCC SLI5
 CLC
 LDA QT
 ADC QP
 STA QT
 LDA QT+1
 ADC QP+1
 STA QT+1
 LDA QT2
 ADC QP+2
 STA QT2
SLI5 ASL QP
 ROL QP+1
 ROL QP+2
 JMP SLI4
SLI6 LDA QT2
 BEQ SLI7
 JMP SLIB3
* $B300 is a whole bank ($0C00 to $BEFF).  A cursor
* that size leaves nowhere for the records it is
* meant to be pointing at.
SLI7 LDA QT+1
 CMP #$B3
 BCC SLI8
 JMP SLIB3
SLI8 SEC
 LDA #0
 SBC QT
 STA QBASE
 LDA #$BF
 SBC QT+1
 STA QBASE+1
* ---- the bank must exist ------------------------
 LDA QBANK
 CMP NBANKS
 BCC SLI9
 JMP SLIB3
* ---- and be clear of the records in use ---------
* A courtesy check, and it depends on the caller
* keeping AXUSED honest - the same assumption
* AMFREE already makes.  On a plain 128K machine
* there is one bank and this is the check that
* stops a cursor being written over record 400.
SLI9 LDA AXUSED
 ORA AXUSED+1
 BEQ SLIX
 SEC
 LDA AXUSED
 SBC #1
 STA AXREC
 LDA AXUSED+1
 SBC #0
 STA AXREC+1
 JSR AXMAP
 LDA AXBANK
 CMP QBANK
 BCC SLIX
 BNE SLIB3
 CLC
 LDA AXADDR
 ADC AXRSZ
 STA QT
 LDA AXADDR+1
 ADC #0
 STA QT+1
 LDA QT
 CMP QBASE
 LDA QT+1
 SBC QBASE+1
 BCS SLIB3
SLIX RTS
SLIB3 LDA #3
 STA QSTAT
 RTS
SLIB4 LDA #4
 STA QSTAT
 RTS

* ================== THE SCAN ==================
* ---- SLSCAN: predicate over 0..QNREC-1 ---------
* out: QCOUNT, QSTAT
* One pass, in record order, which is what makes
* this affordable on a file as well as in memory.
SLSCAN LDA #0
 STA QSTAT
 STA QCOUNT
 STA QCOUNT+1
 STA QIDX
 STA QIDX+1
 STA QREC
 STA QREC+1
* A FILE HAS NO QNREC.  The scan reads records until
* RECMAN says there are no more, and a deleted
* record is stepped over exactly as READ NEXT steps
* over it - so a query and a READ NEXT loop agree
* about what is in the file.
SLS1 LDA QSRC
 BEQ SLS1A
 JSR SLRDREC
 BCC SLS1B
 CMP #$FF
 BEQ SLS3
 RTS
SLS1A LDA QREC
 CMP QNREC
 LDA QREC+1
 SBC QNREC+1
 BCS SLSD
* No predicate means everything passes.  A SORT is
* a SELECT that keeps everything, and that is not a
* special case in this code - it is an empty
* program.
SLS1B LDA QPLEN
 BEQ SLS2
 JSR SLEVAL
 LDA QSTAT
 BNE SLSD
 LDA QRES
 BEQ SLS3
SLS2 JSR SLBKEY
 LDA QSTAT
 BNE SLSD
 JSR SLAPND
 LDA QSTAT
 BNE SLSD
SLS3 INC QREC
 BNE SLS1
 INC QREC+1
 JMP SLS1
SLSD RTS

* ---- SLFILT: narrow the cursor, in place -------
* Re-runs QPROG over the entries already in the
* cursor and closes the gaps.  It can be done in
* place because the write index never overtakes the
* read index - a filter only ever removes.
SLFILT LDA #0
 STA QSTAT
 LDA QPLEN
 BNE SLF0
 RTS
SLF0 LDA #0
 STA QW1
 STA QW1+1
 STA QR1
 STA QR1+1
SLF1 LDA QR1
 CMP QCOUNT
 LDA QR1+1
 SBC QCOUNT+1
 BCS SLF5
 LDA QR1
 STA QI
 LDA QR1+1
 STA QI+1
 LDA #<QEBUF
 STA QBP
 LDA #>QEBUF
 STA QBP+1
 JSR SLRDIX
 LDY QKEYL
 LDA QEBUF,Y
 STA QREC+1
 INY
 LDA QEBUF,Y
 STA QREC
 JSR SLEVAL
 LDA QSTAT
 BNE SLF5
 LDA QRES
 BEQ SLF4
 LDA QW1
 STA QI
 LDA QW1+1
 STA QI+1
 LDA #<QEBUF
 STA QBP
 LDA #>QEBUF
 STA QBP+1
 JSR SLWRIX
 INC QW1
 BNE SLF4
 INC QW1+1
SLF4 INC QR1
 BNE SLF1
 INC QR1+1
 JMP SLF1
SLF5 LDA QW1
 STA QCOUNT
 LDA QW1+1
 STA QCOUNT+1
 LDA #0
 STA QIDX
 STA QIDX+1
 RTS

* ================= WALKING IT =================
* ---- SLGET: entry QIDX -> QREC, QEBUF ----------
* out: C=1 if QIDX is past the end
* The record cache is forgotten here.  Between one
* QUERY NEXT and the next the program may REWRITE
* the very record, or list a directory through
* CATBLK, and a QUERY FIELD answered from the cache
* would then be quietly out of date.
SLGET LDA #$FF
 STA QRCREC+1
 LDA QIDX
 CMP QCOUNT
 LDA QIDX+1
 SBC QCOUNT+1
 BCS SLGE1
 LDA QIDX
 STA QI
 LDA QIDX+1
 STA QI+1
 LDA #<QEBUF
 STA QBP
 LDA #>QEBUF
 STA QBP+1
 JSR SLRDIX
 LDY QKEYL
 LDA QEBUF,Y
 STA QREC+1
 INY
 LDA QEBUF,Y
 STA QREC
 CLC
 RTS
SLGE1 SEC
 RTS

* ---- SLNEXT: SLGET, then step ------------------
SLNEXT JSR SLGET
 BCS SLNX
 INC QIDX
 BNE SLNX2
 INC QIDX+1
SLNX2 CLC
SLNX RTS

* ================ READING A .QRY ==============
* ---- SLLOAD: FNAMP -> QSPEC, QKEYN, QPROG ------
* Staged through CATBLK, the directory buffer:
* nothing is cataloguing while a query loads, and
* 512 bytes is more than a query can be.
* The RESULT is never in the file.  A saved list of
* record numbers is stale the moment a record
* changes, and a stale answer is worse than none;
* the file holds the QUESTION.
SLLOAD LDA #0
 STA QSTAT
 LDA #<CATBLK
 STA FADDR
 LDA #>CATBLK
 STA FADDR+1
 STZ FLEN
 LDA #2
 STA FLEN+1
 JSR FLOAD
 BCC SLL1
 JMP SLLBAD
SLL1 LDX #0
SLL2 LDA CATBLK,X
 CMP QSIG,X
 BNE SLLBAD
 INX
 CPX #4
 BCC SLL2
 LDA CATBLK+4
 CMP #1
 BNE SLLBAD
 LDA CATBLK+9
 CMP #QKEYS+1
 BCS SLLBAD
 STA QKEYN
* the spec, at specoff - twelve bytes, always all
* four entries, so the block is a fixed size
 CLC
 LDA #<CATBLK
 ADC CATBLK+12
 STA ZPT1
 LDA #>CATBLK
 ADC CATBLK+13
 STA ZPT1+1
 LDY #0
SLL3 LDA (ZPT1),Y
 STA QSPEC,Y
 INY
 CPY #12
 BCC SLL3
* the predicate, at progoff
 LDA CATBLK+17
 BNE SLLBAD
 LDA CATBLK+16
 CMP #QPMAX+1
 BCS SLLBAD
 STA QPLEN
 BEQ SLLOK
 CLC
 LDA #<CATBLK
 ADC CATBLK+14
 STA ZPT1
 LDA #>CATBLK
 ADC CATBLK+15
 STA ZPT1+1
 LDY #0
SLL4 CPY QPLEN
 BCS SLLOK
 LDA (ZPT1),Y
 STA QPROG,Y
 INY
 JMP SLL4
SLLOK RTS
SLLBAD LDA #7
 STA QSTAT
 RTS
QSIG DFB $51,$52,$59,$31

* ================ READING A FIELD =============
* ---- SLFLD: field QFNO of record QREC ----------
* out: QFBUF, QFLEN, QFTYP, QSTAT
* Public, because it is the only routine in the
* system that turns "record 47, field 2" into bytes
* you can print, and REPORT needs exactly that.
SLFLD LDA #0
 STA QSTAT
 JSR SLDESC
 LDA QSTAT
 BNE SLFX
 JSR SLFETC
SLFX RTS

* ---- SLDESC: QFNO -> QFTYP, QFLEN, QROFF -------
* The descriptor is 24 bytes and there may be
* fifteen fields, so the offset is SIXTEEN BITS.
* Doing it in eight - which is the obvious way, and
* the way GETFLD does it - wraps at field 11.
SLDESC LDA QFNO
 STA QT
 LDA #0
 STA QT+1
 ASL QT
 ROL QT+1
 CLC
 LDA QT
 ADC QFNO
 STA QT
 LDA QT+1
 ADC #0
 STA QT+1
 ASL QT
 ROL QT+1
 ASL QT
 ROL QT+1
 ASL QT
 ROL QT+1
 LDA QDICT
 STA ZPDICT
 LDA QDICT+1
 STA ZPDICT+1
 LDY #8
 LDA (ZPDICT),Y
 CMP QFNO
 BCC SLDB8
 BEQ SLDB8
 LDY #12
 LDA (ZPDICT),Y
 CLC
 ADC QT
 STA ZPFLD
 INY
 LDA (ZPDICT),Y
 ADC QT+1
 STA ZPFLD+1
 CLC
 LDA ZPFLD
 ADC ZPDICT
 STA ZPFLD
 LDA ZPFLD+1
 ADC ZPDICT+1
 STA ZPFLD+1
 LDY #10
 LDA (ZPFLD),Y
 STA QFTYP
 LDY #12
 LDA (ZPFLD),Y
 STA QFDEC
 LDY #15
 LDA (ZPFLD),Y
 STA QFLEN
 LDY #13
 LDA (ZPFLD),Y
 STA QROFF
 INY
 LDA (ZPFLD),Y
 STA QROFF+1
 LDA QFLEN
 CMP #QFMAX+1
 BCC SLDX
 LDA #QFMAX
 STA QFLEN
SLDX RTS
SLDB8 LDA #8
 STA QSTAT
 RTS

* ---- SLFETC: the field's bytes -> QFBUF --------
* QSRC = 0  records in auxiliary memory
* QSRC = 1  the program's relative file 0, and
* QSRC = 2  file 1, through RECMAN.  The record is
*           read whole into CATBLK and the field is
*           cut out of it there.
SLFETC LDA QSRC
 BEQ SLFE1
 JMP SLFFIL
* A zero-length field would make AXEND compute an
* inclusive end one BELOW the start, and AUXMOVE
* would then move about 64K of the wrong thing.
SLFE1 LDA QFLEN
 BEQ SLFE2
 LDA QREC
 STA AXREC
 LDA QREC+1
 STA AXREC+1
 JSR AXMAP
 CLC
 LDA AXADDR
 ADC QROFF
 STA AXADDR
 LDA AXADDR+1
 ADC QROFF+1
 STA AXADDR+1
 LDA QFLEN
 STA AXLEN
 STZ AXLEN+1
 LDA #<QFBUF
 STA AXBUF
 LDA #>QFBUF
 STA AXBUF+1
 JMP AXGET
SLFE2 RTS

* ---- SLFFIL: the field, out of a file record ----
* A scan asks for several fields of one record, one
* after another, so the record is read ONCE and
* kept: QRCREC says which record CATBLK holds, and
* $FF in its high byte says none does.
SLFFIL LDA QREC
 CMP QRCREC
 BNE SLFF1
 LDA QREC+1
 CMP QRCREC+1
 BEQ SLFF2
SLFF1 JSR SLRDREC
 BCC SLFF2
* gone since the cursor was built - deleted, or the
* file was closed under it
 LDA #5
 STA QSTAT
 RTS
SLFF2 CLC
 LDA #<CATBLK
 ADC QROFF
 STA ZPT1
 LDA #>CATBLK
 ADC QROFF+1
 STA ZPT1+1
 LDY #0
SLFF3 CPY QFLEN
 BCS SLFF4
 LDA (ZPT1),Y
 STA QFBUF,Y
 INY
 BNE SLFF3
SLFF4 RTS

* ---- SLRDREC: record QREC -> CATBLK ------------
* out: C=0 read, and QRCREC = QREC
*      C=1, A=$FF   the record is deleted
*      C=1, A other past the end, or unreadable
*
* QREC counts from 0 like every record number in
* this module; RECMAN's key counts from 1 like
* COBOL's.  The +1 is here and nowhere else.
*
* DELETED IS TOLD APART FROM THE END BY CATBLK'S
* FIRST BYTE.  RMREAD reports both as status 23,
* but it has READ a deleted record before refusing
* it, and has read nothing at all past the end.  So
* the byte is cleared first: afterwards it is $FF
* only if a deleted record put it there.
*
* RMREAD steps the file's READ NEXT position, as
* any READ does.  A program that walks a file with
* READ NEXT and queries the same file in the middle
* of the walk will find its place moved.
SLRDREC LDX QSRC
 DEX
 STX RMFNO
 CLC
 LDA QREC
 ADC #1
 STA RMREC
 LDA QREC+1
 ADC #0
 STA RMREC+1
 LDA #<CATBLK
 STA RMBUF
 LDA #>CATBLK
 STA RMBUF+1
 LDA #$FF
 STA QRCREC+1
 STZ CATBLK
 JSR RMREAD
 LDA RMSTAT
 ORA RMSTAT+1
 CMP #$30
 BNE SLRR1
 LDA QREC
 STA QRCREC
 LDA QREC+1
 STA QRCREC+1
 CLC
 RTS
SLRR1 LDA CATBLK
 SEC
 RTS

* ---- SLFCHK: can file QSRC-1 be queried? -------
* out: QSTAT 5 if it is not open, 10 if its records
*      are longer than CATBLK or shorter than the
*      dictionary's
* The FCB offsets are written as numbers, not as
* RECMAN's RFREF and RFLEN: RECMAN is PUT after this
* module, and an EQU used before it is defined is
* the one forward reference Merlin 8 gets wrong.
*   +0 RFREF  the ProDOS ref, 0 = not open
*   +2 RFLEN  the record length
SLFCHK LDX #0
 LDA QSRC
 CMP #2
 BCC SLFC1
 LDX #16
SLFC1 LDA RMFCB0,X
 BNE SLFC2
 LDA #5
 STA QSTAT
 RTS
* more than 512 will not fit in CATBLK
SLFC2 LDA RMFCB0+3,X
 CMP #2
 BCC SLFC3
 BNE SLFCB
 LDA RMFCB0+2,X
 BNE SLFCB
* and the dictionary's fields must lie inside it
SLFC3 LDA QDICT
 STA ZPDICT
 LDA QDICT+1
 STA ZPDICT+1
 LDY #6
 LDA RMFCB0+2,X
 CMP (ZPDICT),Y
 INY
 LDA RMFCB0+3,X
 SBC (ZPDICT),Y
 BCC SLFCB
 LDA #$FF
 STA QRCREC+1
 RTS
SLFCB LDA #10
 STA QSTAT
 RTS

* ================ BUILDING A KEY ==============
* ---- SLBKEY: the key of QREC -> QKBUF ----------
SLBKEY LDA #0
 STA QKOFF
 STA QK
SLB1 LDA QK
 CMP QKEYN
 BCS SLB3
 LDA QK
 ASL
 CLC
 ADC QK
 TAY
 LDA QSPEC,Y
 STA QFNO
 INY
 LDA QSPEC,Y
 STA QDIR
 INY
 LDA QSPEC,Y
 STA QW
 JSR SLFLD
 LDA QSTAT
 BNE SLB4
 JSR SLKPUT
* A descending key is COMPLEMENTED as it is built.
* Reversed byte order is reversed sort order, so
* the comparison stays one unsigned compare with no
* direction flag anywhere in the inner loop, and
* mixed directions cost nothing.
 LDA QDIR
 BEQ SLB2
 JSR SLKNEG
SLB2 CLC
 LDA QKOFF
 ADC QW
 STA QKOFF
 INC QK
 JMP SLB1
* the record number, HIGH BYTE FIRST - see the
* header
SLB3 LDY QKEYL
 LDA QREC+1
 STA QKBUF,Y
 INY
 LDA QREC
 STA QKBUF,Y
SLB4 RTS

* ---- SLKPUT: QFBUF -> QKBUF at QKOFF, QW wide ---
SLKPUT LDA QFTYP
 CMP #2
 BCC SLKP1
 JMP SLKCEL
SLKP1 LDA #$20
 STA QFILL
 LDX #0
SLKP4 CPX QW
 BCS SLKP7
 TXA
 CMP QFLEN
 BCS SLKP5
 LDA QFBUF,X
 JMP SLKP6
SLKP5 LDA QFILL
SLKP6 STA QSAV
 TXA
 CLC
 ADC QKOFF
 TAY
 LDA QSAV
 STA QKBUF,Y
 INX
 JMP SLKP4
SLKP7 RTS

* ---- SLKCEL: a NUM8 cell as an ORDERED key -----
* A cell does not sort as bytes: its first byte is
* flags, and a negative number's digits run the
* wrong way.  So the key is rebuilt -
*   +0     $01 positive or zero, $00 negative
*   +1..7  the digits, COMPLEMENTED if negative
* - and then one unsigned compare orders it: every
* negative below every positive, and the bigger a
* negative magnitude the lower it sorts.  The width
* is the cell's, eight, which is what SLINIT took
* from the descriptor's storelen.
SLKCEL LDY QKOFF
 LDA QFBUF
 AND #$80
 STA QFILL
 BEQ SLKC1
 LDA #0
 BEQ SLKC2
SLKC1 LDA #1
SLKC2 STA QKBUF,Y
 LDX #1
SLKC3 CPX #NCELL
 BCS SLKC5
 INY
 LDA QFBUF,X
 BIT QFILL
 BPL SLKC4
 EOR #$FF
SLKC4 STA QKBUF,Y
 INX
 JMP SLKC3
SLKC5 RTS

* ---- SLKNEG: complement the slice at QKOFF ------
SLKNEG LDX #0
SLKN1 CPX QW
 BCS SLKN2
 TXA
 CLC
 ADC QKOFF
 TAY
 LDA QKBUF,Y
 EOR #$FF
 STA QKBUF,Y
 INX
 JMP SLKN1
SLKN2 RTS

* ================ THE CURSOR ITSELF ===========
* ---- SLAPND: QKBUF -> the end of the cursor -----
SLAPND LDA QCOUNT
 CMP QMAX
 LDA QCOUNT+1
 SBC QMAX+1
 BCC SLAP1
 LDA #1
 STA QSTAT
 RTS
SLAP1 LDA QCOUNT
 STA QI
 LDA QCOUNT+1
 STA QI+1
 LDA #<QKBUF
 STA QBP
 LDA #>QKBUF
 STA QBP+1
 JSR SLWRIX
 INC QCOUNT
 BNE SLAP2
 INC QCOUNT+1
SLAP2 RTS

* ---- SLADDR: entry QI -> aux address QAD --------
* QBASE + QI * QESZ, by shift and add - the same
* long multiplication AXMAP does, and it cannot
* overflow because SLINIT already proved
* QMAX * QESZ fits inside a bank.
SLADDR LDA #0
 STA QAD
 STA QAD+1
 LDA QI
 STA QAT
 LDA QI+1
 STA QAT+1
 LDA QESZ
 STA QAM
SLA1 LDA QAM
 BEQ SLA3
 LSR QAM
 BCC SLA2
 CLC
 LDA QAD
 ADC QAT
 STA QAD
 LDA QAD+1
 ADC QAT+1
 STA QAD+1
SLA2 ASL QAT
 ROL QAT+1
 JMP SLA1
SLA3 CLC
 LDA QAD
 ADC QBASE
 STA QAD
 LDA QAD+1
 ADC QBASE+1
 STA QAD+1
 RTS

* ---- SLRDIX / SLWRIX: entry QI <-> (QBP) --------
SLRDIX JSR SLADDR
 JMP SLRDE
SLWRIX JSR SLADDR
 JMP SLWRE

* ---- SLRDE: QESZ bytes, aux QAD -> main (QBP) ---
* AUXMOVE wants the INCLUSIVE end, not a length.
* CARRY CLEAR is auxiliary TO main, which reads
* backwards from the way it sounds and is the one
* mistake here that fails silently.
SLRDE LDA QBANK
 STA BANKSEL
 LDA QAD
 STA $3C
 LDA QAD+1
 STA $3D
 LDA QESZ
 SEC
 SBC #1
 CLC
 ADC QAD
 STA $3E
 LDA QAD+1
 ADC #0
 STA $3F
 LDA QBP
 STA $42
 LDA QBP+1
 STA $43
 STA CLR80S
 CLC
 JSR AUXMOVE
 LDA #0
 STA BANKSEL
 RTS

* ---- SLWRE: QESZ bytes, main (QBP) -> aux QAD ---
SLWRE LDA QBANK
 STA BANKSEL
 LDA QBP
 STA $3C
 LDA QBP+1
 STA $3D
 LDA QESZ
 SEC
 SBC #1
 CLC
 ADC QBP
 STA $3E
 LDA QBP+1
 ADC #0
 STA $3F
 LDA QAD
 STA $42
 LDA QAD+1
 STA $43
 STA CLR80S
 SEC
 JSR AUXMOVE
 LDA #0
 STA BANKSEL
 RTS

