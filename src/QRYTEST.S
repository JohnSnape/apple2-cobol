* QRYTEST.S  a harness for SELECT and SORT
* A STANDALONE program, not a library module.
*
* The consolidation dropped every test harness in
* the tree and STATUS.md records what that cost:
* there is now nothing to build a new one from.
* This is the replacement, and it is meant to be
* KEPT - the pattern here is what a BCD harness and
* a PICTURE harness should copy.
*
* HOW TO RUN IT
*   BLOAD COBOL.LIB,A$3000
*   BRUN QRYTEST
* It ORGs at $8000, in the overlay band, because
* $6000 - where the old harnesses lived - is inside
* COBOL.LIB now.  It ends with an RTS, so under
* BASIC.SYSTEM it comes back to the prompt.
*
* WHAT IT PROVES, IN ORDER
*   1  a hand-built dictionary is read correctly -
*      SLDESC's sixteen-bit descriptor offset
*   2  twenty records go into auxiliary memory and
*      come back - AXMAP, AXPUT, AXGET at a record
*      size nothing else in the system uses
*   3  a scan with no predicate keeps everything,
*      and builds a key
*   4  SORT puts the cursor in order, ascending
*   5  a DESCENDING key comes out reversed, which
*      is the complement trick working
*   6  a two-key sort breaks ties the right way
*   7  a predicate selects a subset
*   8  QRYFILT narrows that subset in place
* Each step prints what it got.  Nothing here is
* automatic: the operator reads the screen.  A test
* that reports PASS is a test that can lie.

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

 ORG $8000
 DSK /COBOL/OBJ/QRYTEST

* record layout, which the dictionary below states
* and this program must agree with:
*   0..9    NAME   alpha 10
*   10..17  CITY   alpha 8
*   18..23  AMOUNT num   6, right justified, zero
*                        filled
* reclen 24, and the aux record size is 32 so the
* geometry stays a power of two with room to spare.
TRECS EQU 20
TRSZ EQU 32
* the two hand-assembled predicates: four bytes of
* opcode and operands, six of literal, one of END
PR1LEN EQU 11
PR2LEN EQU 11

START JSR INIT80
 JSR CONINIT
 JSR CONCLR
 LDA #<MTITLE
 STA STRPTR
 LDA #>MTITLE
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR

* ---- the machine ------------------------------
 JSR FINDBNK
 JSR TSETUP
 JSR TDICT
 JSR TFILL

* ---- 3, 4: everything, sorted by CITY ---------
 LDA #<M1
 STA STRPTR
 LDA #>M1
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 STZ QPLEN
 LDA #1
 STA QKEYN
 LDA #1
 STA QSPEC
 LDA #0
 STA QSPEC+1
 JSR TRUN

* ---- 5: the same key, descending --------------
 LDA #<M2
 STA STRPTR
 LDA #>M2
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 LDA #1
 STA QSPEC+1
 JSR TRUN

* ---- 6: CITY then AMOUNT, both ascending ------
 LDA #<M3
 STA STRPTR
 LDA #>M3
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 LDA #2
 STA QKEYN
 LDA #1
 STA QSPEC
 STZ QSPEC+1
 LDA #2
 STA QSPEC+3
 LDA #0
 STA QSPEC+4
 JSR TRUN

* ---- 7: AMOUNT > 000300, sorted by AMOUNT -----
 LDA #<M4
 STA STRPTR
 LDA #>M4
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 LDA #1
 STA QKEYN
 LDA #2
 STA QSPEC
 LDA #0
 STA QSPEC+1
 JSR TPROG1
 JSR TRUN

* ---- 8: narrow it to CITY = LONDON ------------
 LDA #<M5
 STA STRPTR
 LDA #>M5
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 JSR TPROG2
 JSR QRYFILT
 JSR TSTAT
 JSR TSHOW
 RTS

* ---- TRUN: init, scan, sort, show -------------
TRUN JSR TPARM
 JSR QRYINIT
 JSR TSTAT
 LDA QSTAT
 BEQ TRUN1
 RTS
TRUN1 JSR QRYSCAN
 JSR TSTAT
 LDA QSTAT
 BEQ TRUN2
 RTS
TRUN2 JSR QRYSORT
 JMP TSHOW

* ---- TPARM: the parameters that never change ---
TPARM LDA #0
 STA QSRC
 LDA NBANKS
 SEC
 SBC #1
 STA QBANK
 LDA #64
 STA QMAX
 STZ QMAX+1
 LDA #TRECS
 STA QNREC
 STZ QNREC+1
 LDA #<DCTBUF
 STA QDICT
 LDA #>DCTBUF
 STA QDICT+1
 RTS

* ---- TSETUP: the auxiliary geometry ------------
* 32-byte records, 512 to a bank.  AXSHIFT is the
* log of the record count, which is what turns the
* division into a shift - see AUXMEM.
TSETUP LDA #9
 STA AXSHIFT
 LDA #TRSZ
 STA AXRSZ
 LDA #TRECS
 STA AXUSED
 LDA #0
 STA AXUSED+1
 JMP AXCAP

* ---- TDICT: build a dictionary in DCTBUF -------
* By hand, because FORMAT is not what is under
* test.  Three fields, and the header says where
* they are rather than anybody assuming.
TDICT LDX #0
TD1 LDA DHDR,X
 STA DCTBUF,X
 INX
 CPX #32
 BCC TD1
 LDX #0
TD2 LDA DFLDS,X
 STA DCTBUF+32,X
 INX
 CPX #72
 BCC TD2
 RTS

* ---- TFILL: twenty records into aux ------------
* Built in ROWBUF, which is free here: nothing has
* blitted a row since INIT80.
* The source walks with a POINTER, not an index.
* Twenty records of 32 bytes is 640, and TN*32
* stops fitting in a byte at record 8 - which is
* the sort of thing that would have shown up as
* nine good records and eleven strange ones.
TFILL LDA #0
 STA TN
 LDA #<TDATA
 STA TSRC
 LDA #>TDATA
 STA TSRC+1
TF1 LDA TN
 CMP #TRECS
 BCS TF9
* the whole record starts as spaces
 LDX #0
 LDA #$20
TF2 STA ROWBUF,X
 INX
 CPX #TRSZ
 BCC TF2
* name, city, amount, straight out of the table.
* ZPT1 is loaded here and used with no JSR in
* between, because zone S is caller-saved.
 LDA TSRC
 STA ZPT1
 LDA TSRC+1
 STA ZPT1+1
 LDY #0
TF3 LDA (ZPT1),Y
 STA ROWBUF,Y
 INY
 CPY #24
 BCC TF3
* and out to record TN
 LDA TN
 STA AXREC
 LDA #0
 STA AXREC+1
 JSR AXMAP
 LDA #TRSZ
 STA AXLEN
 STZ AXLEN+1
 LDA #<ROWBUF
 STA AXBUF
 LDA #>ROWBUF
 STA AXBUF+1
 JSR AXPUT
 CLC
 LDA TSRC
 ADC #TRSZ
 STA TSRC
 LDA TSRC+1
 ADC #0
 STA TSRC+1
 INC TN
 JMP TF1
TF9 RTS

* ---- TSHOW: walk the cursor and print it -------
TSHOW LDA #0
 STA QIDX
 STA QIDX+1
 LDA QCOUNT
 STA TCNT
 JSR TDEC
 LDA #<MFOUND
 STA STRPTR
 LDA #>MFOUND
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
TS1 JSR QRYNEXT
 BCS TS9
* field 0, the name, then field 2, the amount
 LDA #0
 STA QFNO
 JSR QRYFLD
 JSR TFOUT
 LDA #2
 STA QFNO
 JSR QRYFLD
 JSR TFOUT
 JSR CONCR
 JMP TS1
TS9 JMP CONCR

* ---- TFOUT: QFBUF, then a space ----------------
TFOUT LDX #0
TFO1 CPX QFLEN
 BCS TFO2
 LDA QFBUF,X
 JSR CONPUTC
 INX
 JMP TFO1
TFO2 LDA #$20
 JMP CONPUTC

* ---- TSTAT: print QSTAT if it is not zero ------
* A status of 3 here means the cursor and the
* records collided, which on a 128K machine is the
* interesting failure.
TSTAT LDA QSTAT
 BEQ TST9
 STA TCNT
 LDA #<MSTAT
 STA STRPTR
 LDA #>MSTAT
 STA STRPTR+1
 JSR CONPUTS
 JSR TDEC
 JSR CONCR
TST9 RTS

* ---- TDEC: TCNT, 0-99, to the console ----------
TDEC LDA #$30
 STA TD10
TDE1 LDA TCNT
 CMP #10
 BCC TDE2
 SEC
 SBC #10
 STA TCNT
 INC TD10
 JMP TDE1
TDE2 LDA TD10
 JSR CONPUTC
 LDA TCNT
 CLC
 ADC #$30
 JMP CONPUTC

* ---- TPROG1: AMOUNT > "000300" -----------------
* CMPL field 2, relation 4 (GT), six bytes.
TPROG1 LDX #0
TP1 LDA PROG1,X
 STA QPROG,X
 INX
 CPX #PR1LEN
 BCC TP1
 LDA #PR1LEN
 STA QPLEN
 RTS

* ---- TPROG2: CITY = "LONDON" -------------------
TPROG2 LDX #0
TP2 LDA PROG2,X
 STA QPROG,X
 INX
 CPX #PR2LEN
 BCC TP2
 LDA #PR2LEN
 STA QPLEN
 RTS

* =============== THE PREDICATES ===============
* Hand-assembled, which is the only way to test an
* interpreter before there is something to compile
* one - the same argument PCODE.md makes for the VM.
* CMPL, field 2 (AMOUNT), relation 4 (GT), six
* bytes of literal, then END.
PROG1 DFB $01,$02,$04,$06
 ASC '000300'
 DFB $00

* CMPL, field 1 (CITY), relation 0 (EQ), six bytes,
* then END.  CITY is eight wide and the literal is
* six: CMPALP pads the shorter operand with spaces,
* which is the COBOL rule and why this matches.
PROG2 DFB $01,$01,$00,$06
 ASC 'LONDON'
 DFB $00

* ================ THE DICTIONARY ==============
* Header, 32 bytes.  DICTIONARY.md 1 is the
* authority and this is transcribed from it.
DHDR DFB $41,$44,$42,$31
 DFB 1
 DFB 0
 DA 24
 DFB 3
 DFB 0
 DFB 0
 DFB 80
 DA 32
 DA 104
 DA 0
 DA 104
 DS 12,$20

* Three descriptors, 24 bytes each.  Only the
* fields the query engine reads are filled in:
* name, type, width, recoff, storelen.
DFLDS ASC 'NAME      '
 DFB 0
 DFB 10
 DFB 0
 DA 0
 DFB 10
 DFB 0
 DFB 0
 DFB $01
 DFB 0
 DFB 0
 DA 0
 DFB 0

 ASC 'CITY      '
 DFB 0
 DFB 8
 DFB 0
 DA 10
 DFB 8
 DFB 0
 DFB 0
 DFB $01
 DFB 0
 DFB 0
 DA 0
 DFB 0

 ASC 'AMOUNT    '
 DFB 2
 DFB 6
 DFB 0
 DA 18
 DFB 6
 DFB 0
 DFB 0
 DFB $01
 DFB 0
 DFB 0
 DA 0
 DFB 0

* ================== THE DATA ==================
* Twenty records of 32 bytes, of which 24 are used:
* ten of name, eight of city, six of amount.  Two
* pairs share a city AND an amount, so the tie
* break by record number is visible; several share
* a city alone, so the second key is visible too.
TDATA ASC 'ABBOTT    LONDON  000500'
 DS 8,$20
 ASC 'BAKER     PARIS   000250'
 DS 8,$20
 ASC 'CLARKE    LONDON  000100'
 DS 8,$20
 ASC 'DAVIES    OSLO    000750'
 DS 8,$20
 ASC 'EVANS     PARIS   000900'
 DS 8,$20
 ASC 'FISHER    LONDON  000500'
 DS 8,$20
 ASC 'GRANT     BERLIN  000050'
 DS 8,$20
 ASC 'HUGHES    OSLO    000325'
 DS 8,$20
 ASC 'IRVINE    PARIS   000250'
 DS 8,$20
 ASC 'JENKINS   LONDON  000875'
 DS 8,$20
 ASC 'KELLY     BERLIN  000400'
 DS 8,$20
 ASC 'LLOYD     OSLO    000150'
 DS 8,$20
 ASC 'MORGAN    PARIS   000600'
 DS 8,$20
 ASC 'NEWMAN    LONDON  000300'
 DS 8,$20
 ASC 'OWEN      BERLIN  000725'
 DS 8,$20
 ASC 'PRICE     OSLO    000475'
 DS 8,$20
 ASC 'QUINN     PARIS   000025'
 DS 8,$20
 ASC 'ROBERTS   LONDON  000650'
 DS 8,$20
 ASC 'SIMPSON   BERLIN  000200'
 DS 8,$20
 ASC 'TURNER    OSLO    000550'
 DS 8,$20

* ================== MESSAGES ==================
* LENGTH-PREFIXED, not $00-terminated.  CONPUTS
* reads the first byte as a count - hand it a C
* string and it prints the first character's ASCII
* value's worth of whatever follows.
MTITLE DFB 25
 ASC 'QRYTEST - SELECT AND SORT'
M1 DFB 15
 ASC '1. ALL, BY CITY'
M2 DFB 26
 ASC '2. ALL, BY CITY DESCENDING'
M3 DFB 27
 ASC '3. ALL, BY CITY THEN AMOUNT'
M4 DFB 27
 ASC '4. AMOUNT GT 300, BY AMOUNT'
M5 DFB 25
 ASC '5. AND NARROWED TO LONDON'
MFOUND DFB 6
 ASC ' FOUND'
MSTAT DFB 6
 ASC 'QSTAT '

* ================= VARIABLES ==================
TN DFB 0
TSRC DS 2
TCNT DFB 0
TD10 DFB 0
