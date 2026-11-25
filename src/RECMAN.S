* RECMAN.S  the relative-record file manager
* PUT from LIB.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= WHAT THIS IS ================
* COBOL's file verbs, over ProDOS 8.  OPEN, CLOSE,
* READ, READ NEXT, WRITE, REWRITE, DELETE and START
* for ORGANIZATION RELATIVE - which is the only
* organization in the subset, because an indexed
* file is a B-tree and a B-tree is a book of its
* own.
*
* It is the last big unwritten piece of the library
* and the most referenced: every file statement in
* the language traps without it, opcodes $90-$96 in
* PCODE.md 3 are all waiting on it, and QUERY.md 6's
* QSRC=1 - query a FILE rather than records already
* in auxiliary memory - returns status 5 for the
* same reason.
*
* ================= THE ONE IDEA ================
* A RELATIVE FILE IS ARITHMETIC, NOT A STRUCTURE.
* Record N lives at byte (N-1) * reclen and nowhere
* else; there is no index, no free list and no
* directory inside the file.  So the whole module is
* a multiply, a SET_MARK and a READ - and that is
* why it is 700 bytes and not the 6K an indexed
* manager would be.
*
* Three consequences worth stating before the code:
*
* 1. THE KEY IS 1-BASED.  COBOL says RELATIVE KEY 1
*    is the first record.  The subtraction is done
*    once, in RMPOS, and nowhere else.
*
* 2. THE RECORD LENGTH COMES FROM THE FILE, not from
*    the program.  It is in the ProDOS aux_type -
*    which is exactly what BASIC.SYSTEM does for a
*    random-access text file, OPEN name,L128 leaving
*    128 in aux.  FILEIO.S's suffix table already
*    says so: DAT is not a type of its own, it is
*    TXT ($04) with its record length in aux.  We
*    are following the machine's convention rather
*    than inventing one beside it.
*
* 3. TWO FILES AT ONCE.  IOBUF2 and IOBUF3 are
*    theirs; IOBUF stays with CATALOG and FLOAD, so
*    a program with two SELECTs can still list a
*    directory to pick a file.  That is what
*    EQUATES.S said the third buffer was for.

* ---- the FCB, 16 bytes, two of them -------------
RFREF EQU 0
RFMODE EQU 1
RFLEN EQU 2
RFEOF EQU 4
RFCUR EQU 7
RFLAST EQU 9

* ---- open modes ---------------------------------
RMINP EQU 1
RMOUT EQU 2
RMIO EQU 3
RMEXT EQU 4

* ---- FILE STATUS indices into RMSTAB ------------
SOK EQU 0
SEOF EQU 1
SNOREC EQU 2
SBOUND EQU 3
SPERM EQU 4
SNOFIL EQU 5
SMODE EQU 6
SISOPN EQU 7
SNOTOP EQU 8
* (SNOMEM 9 is below.)  SBADNM 10, "31": the name
* breaks ProDOS's rules - GnuCOBOL's code for an
* inconsistent file name.  DECISIONS 8.10.
SBADNM EQU 10
SNOMEM EQU 9

* ================= OPEN =========================
* ---- RMOPEN: RMFNO RMMODE RMNAMP [RMLEN] --------
* out: RMSTAT, RMLEN = the record length in force
*
* RMLEN is an INPUT for OPEN OUTPUT - a file that
* does not exist yet has no aux field to be asked -
* and an OUTPUT for every other mode.  That
* asymmetry is real and is the one thing about this
* call worth remembering.
RMOPEN JSR RMSEL
 LDA RMFCB0+RFREF,X
 BEQ RMO1
 LDA #SISOPN
 JMP RMSBAD
RMO1 LDA RMNAMP
 STA FNAMP
 LDA RMNAMP+1
 STA FNAMP+1
 JSR FISPLT
 LDA RMMODE
 CMP #RMOUT
 BNE RMO3
* OPEN OUTPUT means a NEW file: the old one goes.
* DESTROY's error is ignored on purpose - "it was
* not there" is the outcome we wanted anyway.
 JSR RMDEST
 LDA RMLEN
 STA RMCAUX
 LDA RMLEN+1
 STA RMCAUX+1
 JSR RMCREA
 BCC RMO3
 JMP RMOPRM
* Everything else opens what is there, and takes the
* record length from it.
RMO3 JSR RMINFO
 BCC RMO4
 LDX #SNOFIL
 BRA RMOBAD
RMO4 LDA RMMODE
 CMP #RMOUT
 BEQ RMO5
 LDA RMIAUX
 STA RMLEN
 LDA RMIAUX+1
 STA RMLEN+1
* A record length of zero is a file that was never a
* relative file - a plain TXT, most likely - and
* dividing by it later would be the first anyone
* heard of it.
 ORA RMLEN
 BNE RMO5
 LDA #SMODE
 JMP RMSBAD
* LDX RMIX, and it is not belt and braces: every
* MLI call above may have used X for its own
* purposes, and GET_FILE_INFO is one of them.  Any
* FCB access AFTER an MLI call reloads the index.
* Getting this wrong writes the record length into
* the other file's control block, which is a fault
* that shows up two statements later in a different
* file.
RMO5 LDX RMIX
 LDA RMLEN
 STA RMFCB0+RFLEN,X
 LDA RMLEN+1
 STA RMFCB0+RFLEN+1,X
* the buffer: file 0 gets IOBUF2, file 1 IOBUF3
 LDA #<IOBUF2
 STA RMOBUF
 LDA #>IOBUF2
 STA RMOBUF+1
 LDA RMFNO
 BEQ RMO6
 LDA #<IOBUF3
 STA RMOBUF
 LDA #>IOBUF3
 STA RMOBUF+1
RMO6 JSR RMOPN
 BCC RMO7
 JMP RMOPRM
RMO7 LDX RMIX
 LDA RMOREF
 STA RMFCB0+RFREF,X
 LDA RMMODE
 STA RMFCB0+RFMODE,X
 JSR RMGEOF
 LDA #1
 STA RMFCB0+RFCUR,X
 LDA #0
 STA RMFCB0+RFCUR+1,X
 STA RMFCB0+RFLAST,X
 STA RMFCB0+RFLAST+1,X
 LDA #SOK
 JMP RMSET
* A failed OPEN: X = the status it would be, A =
* the MLI's error.  $40 is a bad pathname, and the
* prefix service makes every name that breaks
* ProDOS's rules into one (PREFIX.S): "31", not the
* "30" or "35" that would send the programmer
* looking for a disk fault or a missing file.
RMOPRM LDX #SPERM
RMOBAD CMP #$40
 BNE RMOB1
 LDX #SBADNM
RMOB1 TXA
 JMP RMSBAD

* ================= CLOSE ========================
* ---- RMCLOS: RMFNO ------------------------------
* Closing a file that is not open is status 42 and
* not a crash: a program that hits an error path
* twice should not take the machine with it.
RMCLOS JSR RMSEL
 LDA RMFCB0+RFREF,X
 BNE RMC1
 LDA #SNOTOP
 JMP RMSBAD
RMC1 STA RMCREF
 JSR RMCLS
 LDX RMIX
 LDA #0
 STA RMFCB0+RFREF,X
 LDA #SOK
 JMP RMSET

* ================= READ =========================
* ---- RMREAD: RMFNO RMREC RMBUF ------------------
* out: RMSTAT, the record in RMBUF
RMREAD JSR RMSEL
 JSR RMOPEND
 BCC RMR1
 RTS
RMR1 JSR RMPOS
 BCC RMR2
 LDA #SNOREC
 JMP RMSBAD
RMR2 JSR RMINF
 BCC RMR3
 LDA #SNOREC
 JMP RMSBAD
RMR3 JSR RMSEEK
 BCS RMRPRM
 JSR RMRD
 BCS RMRPRM
* A DELETED RECORD IS ONE WHOSE FIRST BYTE IS $FF.
* DELETE writes that one byte and nothing else,
* which is why this test is a byte and not a scan.
* A record starts with text or a NUM8 cell, and a
* cell's flag byte never has all eight bits set -
* so the marker cannot collide with data the
* system itself wrote.
 JSR RMDELQ
 BNE RMR4
 LDA #SNOREC
 JMP RMSBAD
RMR4 LDX RMIX
 LDA RMREC
 STA RMFCB0+RFLAST,X
 LDA RMREC+1
 STA RMFCB0+RFLAST+1,X
 JSR RMSTEP
 LDA #SOK
 JMP RMSET
RMRPRM LDA #SPERM
 JMP RMSBAD

* ---- RMNEXT: READ NEXT --------------------------
* out: RMSTAT = 10 at end of file, RMREC = the
*      record actually read
* Deleted records are SKIPPED, not returned - which
* is the whole reason a sequential read of a
* relative file is a loop and not one seek.
RMNEXT JSR RMSEL
 JSR RMOPEND
 BCC RMN1
 RTS
RMN1 LDX RMIX
 LDA RMFCB0+RFCUR,X
 STA RMREC
 LDA RMFCB0+RFCUR+1,X
 STA RMREC+1
 JSR RMPOS
 BCS RMNEND
 JSR RMINF
 BCS RMNEND
 JSR RMSEEK
 BCS RMNPRM
 JSR RMRD
 BCS RMNPRM
 JSR RMDELQ
 BNE RMN2
* deleted: step over it and go round again
 JSR RMSTEP
 JMP RMN1
RMN2 LDX RMIX
 LDA RMREC
 STA RMFCB0+RFLAST,X
 LDA RMREC+1
 STA RMFCB0+RFLAST+1,X
 JSR RMSTEP
 LDA #SOK
 JMP RMSET
RMNEND LDA #SEOF
 JMP RMSBAD
RMNPRM LDA #SPERM
 JMP RMSBAD

* ================= WRITE ========================
* ---- RMWRIT: RMFNO RMREC RMBUF ------------------
* Writing past the end EXTENDS the file.  ProDOS
* will not SET_MARK beyond EOF, so the file is grown
* with SET_EOF first and the mark set inside it
* afterwards - which is also how the gap gets there.
* See "what version one does not do", below.
RMWRIT JSR RMSEL
 JSR RMOPEND
 BCC RMW1
 RTS
RMW1 LDA RMFCB0+RFMODE,X
 CMP #RMINP
 BNE RMW2
 LDA #SMODE
 JMP RMSBAD
RMW2 JSR RMPOS
 BCC RMW3
 LDA #SNOREC
 JMP RMSBAD
RMW3 JSR RMINF
 BCC RMW5
* past the end: grow the file to hold this record
 JSR RMGROW
 BCS RMWPRM
RMW5 JSR RMSEEK
 BCS RMWPRM
 JSR RMWR
 BCS RMWPRM
 JSR RMSTEP
 LDA #SOK
 JMP RMSET
RMWPRM LDA #SPERM
 JMP RMSBAD

* ---- RMREWR: REWRITE ----------------------------
* The key names the record, as it does for WRITE.
* The difference is that REWRITE will not create
* one: rewriting a record that is not there is
* status 23 and not a silent extend.
*
* A DELETED RECORD IS NOT THERE EITHER (2026-11-20,
* FIXLIST A20).  It used to be written over, $FF
* and all, so the REWRITE said 00, took no INVALID
* KEY, and brought the record back to life.  RMGONE
* reads its first byte before anything is written.
RMREWR JSR RMSEL
 JSR RMOPEND
 BCC RMRW1
 RTS
RMRW1 LDA RMFCB0+RFMODE,X
 CMP #RMIO
 BEQ RMRW2
 LDA #SMODE
 JMP RMSBAD
RMRW2 JSR RMPOS
 BCS RMRWNO
 JSR RMINF
 BCS RMRWNO
 JSR RMGONE
 BCS RMRWPR
 BEQ RMRWNO
 JSR RMSEEK
 BCS RMRWPR
 JSR RMWR
 BCS RMRWPR
 LDA #SOK
 JMP RMSET
RMRWNO LDA #SNOREC
 JMP RMSBAD
RMRWPR LDA #SPERM
 JMP RMSBAD

* ================= DELETE =======================
* ---- RMDEL: RMFNO RMREC -------------------------
* ONE BYTE IS WRITTEN, not a whole record.  The rest
* of the record keeps whatever it held, which costs
* nothing and matters not at all: a deleted record
* is not readable, and the space cannot be given
* back to ProDOS anyway - a relative file's record N
* has to stay at byte (N-1)*reclen whatever happens
* to its neighbours.
*
* It needs no record area, which is why RMBUF is not
* an input here.  A DELETE that demanded somewhere
* to put the record it was about to destroy would be
* a strange thing to have to explain.
*
* DELETING A DELETED RECORD IS STATUS 23 (2026-11-20,
* FIXLIST A20), as the standard says: the record is
* not there to delete.  It used to say 00 and skip
* the INVALID KEY.  RMGONE looks first; the byte it
* reads lands in RMDBYT, which is then set to $FF
* for the write anyway.
RMDEL JSR RMSEL
 JSR RMOPEND
 BCC RMD1
 RTS
RMD1 LDA RMFCB0+RFMODE,X
 CMP #RMIO
 BEQ RMD2
 LDA #SMODE
 JMP RMSBAD
RMD2 JSR RMPOS
 BCS RMDNO
 JSR RMINF
 BCS RMDNO
 JSR RMGONE
 BCS RMDPRM
 BEQ RMDNO
 JSR RMSEEK
 BCS RMDPRM
 LDA #$FF
 STA RMDBYT
 JSR RM1BYT
 JSR RMWRT
 BCS RMDPRM
 LDA #SOK
 JMP RMSET
RMDNO LDA #SNOREC
 JMP RMSBAD
RMDPRM LDA #SPERM
 JMP RMSBAD

* ================= START ========================
* ---- RMSTRT: RMFNO RMREC ------------------------
* Position for the READ NEXTs that follow.  It reads
* nothing itself, so it costs one multiply and a
* bounds test - which is the whole of what START IS
* NOT LESS THAN means on a file with no index.
RMSTRT JSR RMSEL
 JSR RMOPEND
 BCC RMT1
 RTS
RMT1 JSR RMPOS
 BCS RMTNO
 JSR RMINF
 BCS RMTNO
 LDX RMIX
 LDA RMREC
 STA RMFCB0+RFCUR,X
 LDA RMREC+1
 STA RMFCB0+RFCUR+1,X
 LDA #SOK
 JMP RMSET
RMTNO LDA #SNOREC
 JMP RMSBAD

* ================= THE ARITHMETIC ===============
* ---- RMSEL: X = RMIX = this file's FCB offset ---
RMSEL LDX #0
 LDA RMFNO
 BEQ RMSL1
 LDX #16
RMSL1 STX RMIX
 RTS

* ---- RMOPEND: is it open? -----------------------
* out: C=1 and RMSTAT set if it is not
RMOPEND LDA RMFCB0+RFREF,X
 BNE RMOPD1
 LDA #SNOTOP
 JSR RMSET
 SEC
 RTS
RMOPD1 CLC
 RTS

* ---- RMPOS: (RMREC-1) * reclen -> RMMK ----------
* out: C=1 if RMREC is 0, which is not a key
*
* Sixteen bits by sixteen, into TWENTY-FOUR, because
* a ProDOS mark is three bytes and 1,000 records of
* 80 is 80,000 - past what two bytes hold, and the
* first place a relative file stops being arithmetic
* you can do in your head.
RMPOS LDA RMREC
 ORA RMREC+1
 BNE RMP0
 SEC
 RTS
RMP0 SEC
 LDA RMREC
 SBC #1
 STA RMML
 LDA RMREC+1
 SBC #0
 STA RMML+1
 LDX RMIX
 LDA RMFCB0+RFLEN,X
 STA RMMD
 LDA RMFCB0+RFLEN+1,X
 STA RMMD+1
 LDA #0
 STA RMMD+2
 STA RMMK
 STA RMMK+1
 STA RMMK+2
 LDY #16
RMP1 LDA RMML
 AND #1
 BEQ RMP2
 CLC
 LDA RMMK
 ADC RMMD
 STA RMMK
 LDA RMMK+1
 ADC RMMD+1
 STA RMMK+1
 LDA RMMK+2
 ADC RMMD+2
 STA RMMK+2
RMP2 ASL RMMD
 ROL RMMD+1
 ROL RMMD+2
 LSR RMML+1
 ROR RMML
 DEY
 BNE RMP1
 CLC
 RTS

* ---- RMINF: is the record inside the file? ------
* in: RMMK, RMIX;  out: C=1 if it is past the end
* RMMK + reclen must be no greater than EOF.  Done
* as a comparison and not as a division, which is
* the reason this module never needs to know how
* many records the file holds.
RMINF LDX RMIX
 CLC
 LDA RMMK
 ADC RMFCB0+RFLEN,X
 STA RMT
 LDA RMMK+1
 ADC RMFCB0+RFLEN+1,X
 STA RMT+1
 LDA RMMK+2
 ADC #0
 STA RMT+2
 LDA RMFCB0+RFEOF,X
 CMP RMT
 LDA RMFCB0+RFEOF+1,X
 SBC RMT+1
 LDA RMFCB0+RFEOF+2,X
 SBC RMT+2
 BCC RMIF1
 CLC
 RTS
RMIF1 SEC
 RTS

* ---- RMGROW: extend the file to hold RMMK -------
* ProDOS refuses SET_MARK past EOF, so the file is
* grown first.  SET_EOF on a file makes the new
* space part of it; ProDOS reads it back as zeros.
RMGROW LDX RMIX
 CLC
 LDA RMMK
 ADC RMFCB0+RFLEN,X
 STA RMEPOS
 LDA RMMK+1
 ADC RMFCB0+RFLEN+1,X
 STA RMEPOS+1
 LDA RMMK+2
 ADC #0
 STA RMEPOS+2
 LDA RMFCB0+RFREF,X
 STA RMEREF
 JSR RMSEOF
 BCS RMGR1
 LDX RMIX
 LDA RMEPOS
 STA RMFCB0+RFEOF,X
 LDA RMEPOS+1
 STA RMFCB0+RFEOF+1,X
 LDA RMEPOS+2
 STA RMFCB0+RFEOF+2,X
 CLC
RMGR1 RTS

* ---- RMSEEK: SET_MARK to RMMK -------------------
RMSEEK LDX RMIX
 LDA RMFCB0+RFREF,X
 STA RMMREF
 LDA RMMK
 STA RMMPOS
 LDA RMMK+1
 STA RMMPOS+1
 LDA RMMK+2
 STA RMMPOS+2
 JMP RMSMRK

* ---- RMRD / RMWR: one record ---------------------
RMRD JSR RMXSET
 JMP RMREAD1
RMWR JSR RMXSET
 JMP RMWRT
RMXSET LDX RMIX
 LDA RMFCB0+RFREF,X
 STA RMRWRF
 LDA RMBUF
 STA RMRWAD
 LDA RMBUF+1
 STA RMRWAD+1
 LDA RMFCB0+RFLEN,X
 STA RMRWCT
 LDA RMFCB0+RFLEN+1,X
 STA RMRWCT+1
 RTS

* ---- RMDELQ: is the record just read deleted? ---
* out: Z=1 if it is
* THE POINTER IS BUILT HERE AND NOT KEPT.  Indirect
* indexed addressing needs a ZERO PAGE pointer, and
* the only ones available are ZPT1/ZPT2 in Zone S -
* which every library routine, and the MLI, is free
* to destroy.  Setting it before the READ and using
* it after would be a pointer through whatever
* ProDOS left behind.  Two loads and a store, after
* the call, cost less than finding that out.
RMDELQ LDA RMBUF
 STA ZPT1
 LDA RMBUF+1
 STA ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 CMP #$FF
 RTS

* ---- RMGONE: is the record at RMMK deleted? -----
* in: RMMK, RMIX (RMPOS and RMINF have run)
* out: C=1 if ProDOS failed; else C=0 and Z=1 if
*      the record is deleted
* For REWRITE and DELETE, which must not touch a
* deleted record (FIXLIST A20).  RMDELQ cannot do
* it: it looks at RMBUF, and REWRITE's RMBUF holds
* the NEW record, not what is on the disk.  So one
* byte is read into RMDBYT instead.  The read moves
* the mark on by one, so the caller seeks again
* before it writes.
* The CLC after the CMP is deliberate: CMP #$FF
* sets carry exactly when the byte IS $FF, which
* would read as a ProDOS error.  CLC leaves Z be.
RMGONE JSR RMSEEK
 BCS RMGN9
 JSR RM1BYT
 JSR RMREAD1
 BCS RMGN9
 LDA RMDBYT
 CMP #$FF
 CLC
RMGN9 RTS

* ---- RM1BYT: the MLI block -> RMDBYT, one byte --
* RMGONE reads the deletion mark through it and
* RMDEL writes one.  Shared because COBOL.LIB has
* to end by $5FFF and had 58 bytes left: DELETE's
* own copy of these lines paid for most of RMGONE.
RM1BYT LDX RMIX
 LDA RMFCB0+RFREF,X
 STA RMRWRF
 LDA #<RMDBYT
 STA RMRWAD
 LDA #>RMDBYT
 STA RMRWAD+1
 LDA #1
 STA RMRWCT
 STZ RMRWCT+1
 RTS

* ---- RMSTEP: RFCUR = RMREC + 1 ------------------
RMSTEP LDX RMIX
 CLC
 LDA RMREC
 ADC #1
 STA RMFCB0+RFCUR,X
 LDA RMREC+1
 ADC #0
 STA RMFCB0+RFCUR+1,X
 RTS

* ---- RMGEOF: EOF into the FCB -------------------
RMGEOF LDX RMIX
 LDA RMFCB0+RFREF,X
 STA RMEREF
 JSR RMGTEOF
 LDX RMIX
 LDA RMEPOS
 STA RMFCB0+RFEOF,X
 LDA RMEPOS+1
 STA RMFCB0+RFEOF+1,X
 LDA RMEPOS+2
 STA RMFCB0+RFEOF+2,X
 RTS

* ================= FILE STATUS ==================
* ---- RMSET: A = an index into RMSTAB ------------
* out: C=0 always - the CALLER's carry says whether
*      the statement worked; RMSTAT says why
* Two ASCII characters, exactly as COBOL specifies
* and exactly as CRT STATUS already is.  LOW ASCII,
* spelled as bytes: Merlin's ASC sets the high bit
* and a compiled program compares this against a
* literal out of the pool, which is low.
RMSET ASL
 TAY
 LDA RMSTAB,Y
 STA RMSTAT
 LDA RMSTAB+1,Y
 STA RMSTAT+1
 CLC
 RTS

* ---- RMSBAD: the same, with C=1 -----------------
RMSBAD JSR RMSET
 SEC
 RTS

RMSTAB DFB $30,$30
 DFB $31,$30
 DFB $32,$33
 DFB $32,$34
 DFB $33,$30
 DFB $33,$35
 DFB $33,$37
 DFB $34,$31
 DFB $34,$32
 DFB $33,$34
 DFB $33,$31

* ================= MLI ==========================
* Named apart from FILEIO's and PRODOS's, so all
* three can be in one program while FORMAT still
* carries its own copy.
RMOPN JSR MLI
 DFB $C8
 DA RMOPRA
 RTS
RMCLS JSR MLI
 DFB $CC
 DA RMCLPA
 RTS
RMREAD1 JSR MLI
 DFB $CA
 DA RMRWPA
 RTS
RMWRT JSR MLI
 DFB $CB
 DA RMRWPA
 RTS
RMSMRK JSR MLI
 DFB $CE
 DA RMMKPA
 RTS
RMGTEOF JSR MLI
 DFB $D1
 DA RMEFPA
 RTS
RMSEOF JSR MLI
 DFB $D0
 DA RMEFPA
 RTS
RMINFO JSR MLI
 DFB $C4
 DA RMIFPA
 RTS
RMCREA JSR MLI
 DFB $C0
 DA RMCRPA
 RTS
RMDEST JSR MLI
 DFB $C1
 DA RMDSPA
 RTS

* ---- MLI parameter blocks -----------------------
* Every pathname is FNBUF1, which FISPLT built.
RMOPRA DFB 3
 DA FNBUF1
RMOBUF DA 0
RMOREF DFB 0
RMCLPA DFB 1
RMCREF DFB 0
RMRWPA DFB 4
RMRWRF DFB 0
RMRWAD DA 0
RMRWCT DA 0
 DA 0
RMMKPA DFB 2
RMMREF DFB 0
RMMPOS DFB 0,0,0
RMEFPA DFB 2
RMEREF DFB 0
RMEPOS DFB 0,0,0
* GET_FILE_INFO: aux_type is at offset 5 of the
* result, which is RMIAUX below.
* Ten parameters and SEVENTEEN bytes after the
* count: pathname, access, type, aux, storage,
* blocks, mod date, mod time, create date, create
* time.  A block one entry short does not fail - the
* MLI writes the missing field over whatever comes
* next, which here would have been the CREATE block.
RMIFPA DFB $0A
 DA FNBUF1
RMIACC DFB 0
RMITYP DFB 0
RMIAUX DA 0
 DFB 0
 DA 0
 DA 0
 DA 0
 DA 0
 DA 0
* CREATE: type $04 TXT, and the record length in
* aux - which is what makes it a relative file and
* not just a text file.  Storage type 1, a seedling;
* ProDOS grows it as it is written.
RMCRPA DFB 7
 DA FNBUF1
 DFB $C3
 DFB $04
RMCAUX DA 0
 DFB 1
 DA 0
 DA 0
RMDSPA DFB 1
 DA FNBUF1

* ================= VARIABLES ====================
RMIX DFB 0
RMMK DFB 0,0,0
RMMD DFB 0,0,0
RMML DFB 0,0
RMT DFB 0,0,0
RMDBYT DFB $FF
