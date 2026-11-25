* QRYADD.S  adding and removing
* PUT from QUERY.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Every prompt goes through PROMPT.S's LINEIN, the
* same row-23 question line FORMAT and REPORT use.
* A field is named by NUMBER rather than picked from
* a list, which is the same choice FORMAT made and
* is recorded in REPORT.md 10 as a question worth
* revisiting once somebody has used it in anger.

* QDSRC is read through (QDSRC),Y, so it has to be
* zero page and defined before its first use.  It
* was a DS 2 at the end of this file.  Zone P is the
* overlay's while QUERY runs.
QDSRC EQU ZPDRV

* ---- QADDC: add a condition --------------------
QADDC LDA QHASD
 BNE QAC0
 JMP QERRD
QAC0 LDA QNCOND
 CMP #MAXCOND
 BCC QAC1
 JMP QERRF
QAC1 LDA #<QPFLD
 STA STRPTR
 LDA #>QPFLD
 STA STRPTR+1
 JSR LINEIN
 BCS QACX
 JSR ATOI
 CMP QNFLD
 BCC QAC2
 JMP QERRN
QAC2 LDX QNCOND
 STA QCFLD,X
* the relation
 LDA #<QPREL
 STA STRPTR
 LDA #>QPREL
 STA STRPTR+1
 JSR LINEIN
 BCS QACX
 JSR QRELOF
 BCS QACX
 LDX QNCOND
 STA QCREL,X
* what to compare with
 LDA #<QPVAL
 STA STRPTR
 LDA #>QPVAL
 STA STRPTR+1
 JSR LINEIN
 BCS QACX
 JSR QSTASH
* and, for every condition after the first, how it
* joins the one above it
 LDA QNCOND
 BEQ QAC4
 LDA #<QPCON
 STA STRPTR
 LDA #>QPCON
 STA STRPTR+1
 JSR LINEIN
 BCS QACX
 LDA LBUF
 AND #$DF
 CMP #$4F
 BNE QAC3
 LDA #1
 BNE QAC3A
QAC3 LDA #0
QAC3A LDX QNCOND
 STA QCCON,X
QAC4 INC QNCOND
QACX RTS

* ---- QSTASH: LBUF -> condition QNCOND's text ----
QSTASH LDA LLEN
 CMP #MAXLIT+1
 BCC QST1
 LDA #MAXLIT
QST1 LDX QNCOND
 STA QCLEN,X
 STA QT
 LDA QNCOND
 JSR QTXPTR
 STZ QT2
QST2 LDA QT2
 CMP QT
 BCS QST3
 LDX QT2
 LDA LBUF,X
 LDY QT2
 STA (ZPT2),Y
 INC QT2
 JMP QST2
QST3 RTS

* ---- QDELC: remove the selected condition -------
* Four parallel arrays and the text block all shift
* down by one.  FORMAT shifts nine arrays to delete
* a field and this is the same idea with fewer of
* them - which is the argument for parallel arrays
* at this size and against them at REPORT's.
QDELC LDA QNCOND
 BNE QDC0
 RTS
QDC0 LDA QSEL
 CMP QNCOND
 BCC QDC1
 RTS
QDC1 LDA QSEL
 STA QIX
QDC2 LDA QIX
 CLC
 ADC #1
 CMP QNCOND
 BCS QDC4
 TAX
 LDA QCFLD,X
 LDY QIX
 STA QCFLD,Y
 LDA QCREL,X
 STA QCREL,Y
 LDA QCCON,X
 STA QCCON,Y
 LDA QCLEN,X
 STA QCLEN,Y
 JSR QSHTX
 INC QIX
 JMP QDC2
QDC4 DEC QNCOND
 LDA QSEL
 CMP QNCOND
 BCC QDC5
 LDA QNCOND
 BEQ QDC5
 DEC QSEL
QDC5 RTS

* ---- QSHTX: copy text QIX+1 down to QIX ---------
QSHTX LDA QIX
 CLC
 ADC #1
 JSR QTXPTR
 LDA ZPT2
 STA QDSRC
 LDA ZPT2+1
 STA QDSRC+1
 LDA QIX
 JSR QTXPTR
 LDY #0
QSH1 LDA (QDSRC),Y
 STA (ZPT2),Y
 INY
 CPY #MAXLIT
 BCC QSH1
 RTS

* ---- QADDK: add a sort key ---------------------
QADDK LDA QHASD
 BNE QAK0
 JMP QERRD
QAK0 LDA QNKEY
 CMP #MAXKEY
 BCC QAK1
 JMP QERRF
QAK1 LDA #<QPKEY
 STA STRPTR
 LDA #>QPKEY
 STA STRPTR+1
 JSR LINEIN
 BCS QAKX
 JSR ATOI
 CMP QNFLD
 BCS QERRN
 LDX QNKEY
 STA QKFLD,X
 LDA #<QPDIR
 STA STRPTR
 LDA #>QPDIR
 STA STRPTR+1
 JSR LINEIN
 BCS QAKX
 LDA LBUF
 AND #$DF
 CMP #$44
 BNE QAK2
 LDA #1
 BNE QAK3
QAK2 LDA #0
QAK3 LDX QNKEY
 STA QKDIR,X
 INC QNKEY
QAKX RTS

* ---- QDELK: remove the last sort key ------------
* The last and not the selected one, because a sort
* key's POSITION is its meaning - key 1 beats key 2 -
* so removing one from the middle silently promotes
* every key under it.  Taking them off the end is
* the only removal that cannot surprise anybody.
QDELK LDA QNKEY
 BEQ QDKX
 DEC QNKEY
QDKX RTS

* ---- QRELOF: LBUF -> a relation number ----------
* out: A = 0 EQ 1 NE 2 LT 3 LE 4 GT 5 GE, C=1 if it
*      is not one of them
QRELOF LDA LLEN
 BEQ QROX
 LDX #0
QRO1 LDA QRELIN,X
 BEQ QROX
 CMP LBUF
 BNE QRO2
 TXA
 CLC
 RTS
QRO2 INX
 JMP QRO1
QROX SEC
 RTS
* = # < ( > )  - the six, in the order the
* interpreter numbers them.  '#' is not-equal and
* '(' and ')' are the two "or equal" forms, because
* a IIe keyboard has no other single characters for
* them and a two-character answer at a prompt is
* worse than an odd one.
QRELIN DFB $3D,$23,$3C,$28,$3E,$29,$00

* ---- the error messages ------------------------
QERRD LDA #<QSEND
 STA STRPTR
 LDA #>QSEND
 STA STRPTR+1
 JMP SHOWERR
QERRF LDA #<QSEFL
 STA STRPTR
 LDA #>QSEFL
 STA STRPTR+1
 JMP SHOWERR
QERRN LDA #<QSEFN
 STA STRPTR
 LDA #>QSEFN
 STA STRPTR+1
 JMP SHOWERR
