* QRYIO.S  compile the predicate, read and write
* PUT from QUERY.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* THE COMPILER IS SIX INSTRUCTIONS LONG, which is
* the point of having specified the predicate as
* postfix in the first place.  QUERY.md 4 chose a
* stack machine over a tree because a stack machine
* is what a designer can emit in one pass with no
* parser: each condition becomes a CMPL, each
* connector becomes the AND or OR that follows it,
* and END finishes.
*
* CONDITIONS JOIN LEFT TO RIGHT, and AND does NOT
* bind tighter than OR.  A AND B OR C is (A AND B)
* OR C, and A OR B AND C is (A OR B) AND C.  That is
* not what a programming language would do and it is
* what a person reading a list of rules down a
* screen expects, which is the audience.  It is also
* the only rule that can be evaluated in one pass
* with no parentheses to type.

* ---- QCOMP: the conditions -> QDBUF+32+12 -------
* out: QPLENV = the program's length
QCOMP LDA #0
 STA QPLENV
 STZ QIX
QCM1 LDA QIX
 CMP QNCOND
 BCS QCM4
* CMPL: opcode, field, relation, length, the text
 LDA #$01
 JSR QEMIT
 LDX QIX
 LDA QCFLD,X
 JSR QEMIT
 LDX QIX
 LDA QCREL,X
 JSR QEMIT
 LDX QIX
 LDA QCLEN,X
 JSR QEMIT
 LDA QIX
 JSR QTXPTR
 LDX QIX
 LDA QCLEN,X
 STA QT
 STZ QT2
QCM2 LDA QT2
 CMP QT
 BCS QCM3
 LDY QT2
 LDA (ZPT2),Y
 JSR QEMIT
 INC QT2
 JMP QCM2
* the connector goes out AFTER the condition it
* joins, which is what postfix means
QCM3 LDA QIX
 BEQ QCM3A
 LDX QIX
 LDA QCCON,X
 BEQ QCM3B
 LDA #$05
 BNE QCM3C
QCM3B LDA #$04
QCM3C JSR QEMIT
QCM3A INC QIX
 JMP QCM1
* END - but only if there was anything.  A program
* of just END is an error, and no program at all is
* how QUERY.md says "everything passes".
QCM4 LDA QNCOND
 BEQ QCMX
 LDA #$00
 JSR QEMIT
QCMX RTS

* ---- QEMIT: append A to the program -------------
QEMIT PHA
 LDA QPLENV
 CMP #96
 BCS QEMX
 CLC
 ADC #44
 TAX
 PLA
 STA QDBUF,X
 INC QPLENV
 RTS
QEMX PLA
 RTS

* ================= WRITING =====================
* ---- QSAVEQ: build the file and write it --------
* Thirty-two of header, twelve of sort spec, at most
* ninety-six of predicate.  One buffer, one FSAVE,
* no streaming - a query is the smallest file the
* system writes and the only one that fits in a
* single MLI call without thinking about it.
QSAVEQ LDA QHASD
 BNE QSV0
 JMP QERRD
QSV0 LDA #<QPSAVE
 STA STRPTR
 LDA #>QPSAVE
 STA STRPTR+1
 JSR LINEIN
 BCC QSV1
 RTS
QSV1 JSR QSUFFIX
 JSR QCOMP
 JSR QHDR
 CLC
 LDA #44
 ADC QPLENV
 STA QDFLEN
 LDA #0
 ADC #0
 STA QDFLEN+1
 LDA QDFLEN
 STA QDBUF+18
 LDA QDFLEN+1
 STA QDBUF+19
 LDA #<NAMEBUF
 STA FNAMP
 LDA #>NAMEBUF
 STA FNAMP+1
 LDA #<QDBUF
 STA FADDR
 LDA #>QDBUF
 STA FADDR+1
 LDA QDFLEN
 STA FLEN
 LDA QDFLEN+1
 STA FLEN+1
 JSR FSAVE
 BCC QSVOK
 JMP QERRIO
QSVOK LDA #<QSSAVD
 STA STRPTR
 LDA #>QSSAVD
 STA STRPTR+1
 JMP SHOWERR

* ---- QHDR: the 32-byte header -------------------
* Deliberately the same shape as a .DCT - signature,
* version, a block of offsets, poolend, and a
* twelve-byte name at 20.  Two formats read by the
* same kind of code should not be laid out two
* different ways, and SELECT.S's loader was written
* against this before anything wrote one.
QHDR LDX #0
QHD1 LDA QSIGQ,X
 STA QDBUF,X
 INX
 CPX #4
 BCC QHD1
 LDA #1
 STA QDBUF+4
* flags: bit0 a predicate, bit1 a sort spec
 LDA #0
 LDX QNCOND
 BEQ QHD2
 ORA #1
QHD2 LDX QNKEY
 BEQ QHD3
 ORA #2
QHD3 STA QDBUF+5
* reclen and fieldcount, straight out of the
* dictionary: a sanity check for whoever loads this
* against a screen that has since been changed
 LDA #<DCTBUF
 STA ZPDICT
 LDA #>DCTBUF
 STA ZPDICT+1
 LDY #6
 LDA (ZPDICT),Y
 STA QDBUF+6
 INY
 LDA (ZPDICT),Y
 STA QDBUF+7
 LDY #8
 LDA (ZPDICT),Y
 STA QDBUF+8
 LDA QNKEY
 STA QDBUF+9
* keylen is filled in by QRYINIT at run time from
* the dictionary, so what goes here is a record of
* what was true when it was written and not an
* instruction.  QUERY.md 7 says so in as many words.
 LDA #0
 STA QDBUF+10
 STA QDBUF+11
 LDA #32
 STA QDBUF+12
 LDA #0
 STA QDBUF+13
 LDA #44
 STA QDBUF+14
 LDA #0
 STA QDBUF+15
 LDA QPLENV
 STA QDBUF+16
 LDA #0
 STA QDBUF+17
* the name, space padded
 LDX #0
QHD4 LDA #$20
 STA QDBUF+20,X
 INX
 CPX #12
 BCC QHD4
* ---- the sort spec, four entries of three -------
 LDX #0
QHD5 LDA #0
 STA QDBUF+32,X
 INX
 CPX #12
 BCC QHD5
 STZ QJX
QHD6 LDA QJX
 CMP QNKEY
 BCS QHD7
 LDA QJX
 ASL
 CLC
 ADC QJX
 TAX
 LDY QJX
 LDA QKFLD,Y
 STA QDBUF+32,X
 LDA QKDIR,Y
 STA QDBUF+33,X
 INC QJX
 JMP QHD6
QHD7 RTS
QSIGQ DFB $51,$52,$59,$31

* ================= READING =====================
* ---- QOPENQ: read a .QRY back in ----------------
* Decompiling the predicate is what makes Open worth
* having: a query you can load but not edit is a
* query you rewrite from scratch every time.  The
* walk expects exactly what QCOMP emits and rejects
* anything else - which is the right strictness,
* since nothing else writes these.
QOPENQ LDA #<QPOPEN
 STA STRPTR
 LDA #>QPOPEN
 STA STRPTR+1
 JSR LINEIN
 BCC QOP1
 RTS
QOP1 JSR QSUFFIX
 LDA #<NAMEBUF
 STA FNAMP
 LDA #>NAMEBUF
 STA FNAMP+1
 LDA #<QDBUF
 STA FADDR
 LDA #>QDBUF
 STA FADDR+1
 LDA #160
 STA FLEN
 LDA #0
 STA FLEN+1
 JSR FLOAD
 BCC QOP2
 JMP QERRIO
QOP2 LDX #0
QOP3 LDA QDBUF,X
 CMP QSIGQ,X
 BEQ QOP3A
 JMP QOPBAD
QOP3A INX
 CPX #4
 BCC QOP3
 JSR QNEWL
* the sort spec
 LDA QDBUF+9
 CMP #MAXKEY+1
 BCC QOP4A
 JMP QOPBAD
QOP4A STA QNKEY
 STZ QJX
QOP4 LDA QJX
 CMP QNKEY
 BCS QOP5
 LDA QJX
 ASL
 CLC
 ADC QJX
 TAX
 LDY QJX
 LDA QDBUF+32,X
 STA QKFLD,Y
 LDA QDBUF+33,X
 STA QKDIR,Y
 INC QJX
 JMP QOP4
* the predicate
QOP5 LDA QDBUF+16
 BNE QOP5A
 JMP QOPD
QOP5A STA QPLENV
 LDA #44
 STA QPC
QOP6 LDX QPC
 LDA QDBUF,X
 CMP #$00
 BNE QOP6A
 JMP QOPD
QOP6A CMP #$01
 BEQ QOP7
 CMP #$04
 BEQ QOPAND
 CMP #$05
 BEQ QOPOR
 JMP QOPBAD
QOPAND LDX QNCOND
 LDA #0
 STA QCCON,X
 INC QPC
 JMP QOP6
QOPOR LDX QNCOND
 LDA #1
 STA QCCON,X
 INC QPC
 JMP QOP6
* CMPL: put it back in the arrays
QOP7 LDA QNCOND
 CMP #MAXCOND
 BCC QOP7A
 JMP QOPBAD
QOP7A INC QPC
 LDX QPC
 LDA QDBUF,X
 LDY QNCOND
 STA QCFLD,Y
 INC QPC
 LDX QPC
 LDA QDBUF,X
 LDY QNCOND
 STA QCREL,Y
 INC QPC
 LDX QPC
 LDA QDBUF,X
 LDY QNCOND
 STA QCLEN,Y
 STA QT
 INC QPC
 LDA QNCOND
 JSR QTXPTR
 STZ QT2
QOP8 LDA QT2
 CMP QT
 BCS QOP9
 LDX QPC
 LDA QDBUF,X
 LDY QT2
 STA (ZPT2),Y
 INC QPC
 INC QT2
 JMP QOP8
QOP9 INC QNCOND
 JMP QOP6
QOPD STZ QSEL
 RTS
QOPBAD LDA #<QSEBAD
 STA STRPTR
 LDA #>QSEBAD
 STA STRPTR+1
 JSR SHOWERR
 JMP QNEWL

* ================= HOUSEKEEPING ================
* ---- QNEW: start again --------------------------
* Keeps the dictionary.  Somebody writing three
* queries against one screen should not have to open
* it three times, and OA-I is there for when they do
* want a different one.
QNEW JSR QNEWL
 RTS
QNEWL STZ QNCOND
 STZ QNKEY
 STZ QSEL
 STZ QPLENV
 RTS

* ---- QOPEND: open a dictionary ------------------
QOPEND LDA #<QPDICT
 STA STRPTR
 LDA #>QPDICT
 STA STRPTR+1
 JSR LINEIN
 BCC QOD1
 RTS
* Through FLOAD, as the QUERY verb does (VQDICT).
* DICTLOAD opens whatever PATHAD points at, and
* nothing in QUERY ever set PATHAD, so OA-I opened
* a stale pointer and said nothing (2026-11-07).
QOD1 JSR COPYNM
 LDA #$49
 JSR QSFX
 LDA #<NAMEBUF
 STA FNAMP
 LDA #>NAMEBUF
 STA FNAMP+1
 LDA #<DCTBUF
 STA FADDR
 LDA #>DCTBUF
 STA FADDR+1
 LDA #$00
 STA FLEN
 LDA #$04
 STA FLEN+1
 JSR FLOAD
 BCC QOD2
 JMP QERRIO
QOD2 LDA #<DCTBUF
 STA ZPDICT
 LDA #>DCTBUF
 STA ZPDICT+1
 LDY #8
 LDA (ZPDICT),Y
 STA QNFLD
 LDA #1
 STA QHASD
* the name for the top line, out of what was typed
 LDX #0
QOD3 LDA #$20
 STA QDNAME+1,X
 INX
 CPX #12
 BCC QOD3
 LDA LLEN
 CMP #13
 BCC QOD4
 LDA #12
QOD4 STA QDNAME
 STA QT
 STZ QT2
QOD5 LDA QT2
 CMP QT
 BCS QOD6
 LDX QT2
 LDA LBUF,X
 STA QDNAME+1,X
 INC QT2
 JMP QOD5
QOD6 JSR QNEWL
 RTS

* ---- QSUFFIX: LBUF + '.QRY' -> NAMEBUF ----------
* FILEIO's SPLITNM reads the suffix and sets the
* type from it, so the name the operator types is
* the name without one and this puts it back.  That
* is the whole of why the suffix convention exists:
* the type is never asked for and never wrong.
QSUFFIX JSR COPYNM
 LDA #$4D
* ---- QSFX: NAMEBUF gets the suffix of type A ----
* Through SETSFX, so BIGBAL becomes BIGBAL.QRY and
* BIGBAL.QRY is NOT made BIGBAL.QRY.QRY - which the
* hand-appended suffix that was here would have done.
QSFX PHA
 LDA #<NAMEBUF
 STA FNAMP
 LDA #>NAMEBUF
 STA FNAMP+1
 PLA
 LDX #0
 JSR SETSFX
 LDX FNBUF1
QSX1 LDA FNBUF1,X
 STA NAMEBUF,X
 DEX
 BPL QSX1
 RTS

* NAMBAD: the name just expanded broke ProDOS's
* rules (PREFIX.S, DECISIONS 8.10) - that, and not
* the disk, is why it failed.
QERRIO LDA NAMBAD
 BNE QERRBN
 LDA #<QSEIO
 STA STRPTR
 LDA #>QSEIO
 STA STRPTR+1
 JMP SHOWERR
QERRBN LDA #<QSEBN
 STA STRPTR
 LDA #>QSEBN
 STA STRPTR+1
 JMP SHOWERR

* ---- COPYNM: LBUF -> NAMEBUF -------------------
* FORMAT keeps COPYNAME in FORMATD because it writes
* DISKIO NAMEBUF.  QUERY PUTs neither, so it has its
* own - fourteen bytes rather than dragging in a
* module for one routine.
COPYNM LDA LLEN
 CMP #33
 BCC QCN1
 LDA #32
QCN1 STA NAMEBUF
 STA QT
 STZ QT2
QCN2 LDA QT2
 CMP QT
 BCS QCN3
 LDX QT2
 LDA LBUF,X
 AND #$7F
 STA NAMEBUF+1,X
 INC QT2
 JMP QCN2
QCN3 RTS

NAMEBUF DS 40
QPLENV DFB 0
QPC DFB 0
