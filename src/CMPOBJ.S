* CMPOBJ.S  the object header and the writer
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Twenty bytes of header, then three blocks in the
* order the header declares.  PCODE.md 2 is the
* authority on the layout and this is transcribed
* from it.
*
* THERE IS NO DATA-SEGMENT OFFSET FIELD.  The data
* segment starts at codeoff + codelen, and a third
* number could only ever disagree with the two we
* already have.  It is not in the file because it
* is not in the file: ENTER clears working storage
* and the VALUE clauses are instructions that
* follow, so an object carries no data image at all.

HDRLEN EQU 20

* ---- CMPHDR: build the header in OBHDR ----------
CMPHDR LDX #0
CMH1 LDA PCBSIG,X
 STA OBHDR,X
 INX
 CPX #4
 BCC CMH1
 LDA #1
 STA OBHDR+4
 LDA DSEG
 STA OBHDR+5
 LDA DSEG+1
 STA OBHDR+6
 LDA NITEMS
 STA OBHDR+7
 LDA NITEMS+1
 STA OBHDR+8
* descoff is always 20 - the header is fixed
 LDA #HDRLEN
 STA OBHDR+9
 STZ OBHDR+10
* litoff = 20 + itemcount * 8
 LDA NITEMS
 STA EMT
 LDA NITEMS+1
 STA EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 CLC
 LDA EMT
 ADC #HDRLEN
 STA OBHDR+11
 STA EMT2
 LDA EMT+1
 ADC #0
 STA OBHDR+12
 STA EMT2+1
* codeoff = litoff + litlen
 CLC
 LDA EMT2
 ADC LITLEN
 STA OBHDR+13
 LDA EMT2+1
 ADC LITLEN+1
 STA OBHDR+14
* entry is an offset from codeoff, and the prologue
* is always the first thing emitted, so it is zero
* until something wants it otherwise
 STZ OBHDR+15
 STZ OBHDR+16
 LDA CODLEN
 STA OBHDR+17
 LDA CODLEN+1
 STA OBHDR+18
* language 0 = COBOL.  With one front end this byte
* is always the same, and it costs nothing, and it
* is the thing you would wish you had if a second
* one ever appeared.  VMRUN checks it before it
* executes a single instruction.
 LDA #0
 STA OBHDR+19
 RTS

PCBSIG DFB $50,$43,$42,$31

* ---- CMPWRT: write the object to FNBUF1 ---------
* out: C=1 + A = the MLI error
* Four writes on one open file rather than one write
* of a buffer that would have to exist somewhere:
* the three areas are already laid out correctly in
* memory and there is nothing to be gained by
* copying them somewhere to be contiguous.
*
* DESTROY BEFORE CREATE, because ProDOS has no
* truncate and a shorter object written into a
* longer file would leave the old tail behind to be
* read back as p-code.  Same reason EDIT's save does
* it.
CMPWRT JSR CMPHDR
 JSR COCLOS
 JSR CODEST
 JSR COCREA
 BCC CMW1
 RTS
CMW1 JSR COOPEN
 BCC CMW2
 RTS
CMW2 LDA #<OBHDR
 LDX #>OBHDR
 LDY #HDRLEN
 JSR COWBLK
 BCS COWERR
 LDA NITEMS
 STA EMT
 LDA NITEMS+1
 STA EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 LDA #<OBDESC
 STA CORW+2
 LDA #>OBDESC
 STA CORW+3
 LDA EMT
 STA CORW+4
 LDA EMT+1
 STA CORW+5
 JSR COWRIT
 BCS COWERR
 LDA #<OBLIT
 STA CORW+2
 LDA #>OBLIT
 STA CORW+3
 LDA LITLEN
 STA CORW+4
 LDA LITLEN+1
 STA CORW+5
 JSR COWRIT
 BCS COWERR
 JSR COWCOD
 BCS COWERR
 JSR COCLOS
 CLC
 RTS
* An open file that is never closed loses the blocks
* it was holding, so the error path closes too.
COWERR PHA
 JSR COCLOS
 PLA
 SEC
COWX RTS

* ---- COWCOD: the code, out of aux ------------
* THE CODE IS IN AUX (CMPCON.S, 2026-11-22), and
* ProDOS writes only from main memory: it comes out
* through CODSTG, up to 2,816 bytes at a time.
* out: C=1 and A = the ProDOS error if a write fails
COWCOD STZ EMXO
 STZ EMXO+1
COW5 SEC
 LDA CODLEN
 SBC EMXO
 STA EMXN
 LDA CODLEN+1
 SBC EMXO+1
 STA EMXN+1
 ORA EMXN
 BEQ COW9
 LDA EMXN+1
 CMP #>CODSTN
 BCC COW6
 LDA #<CODSTN
 STA EMXN
 LDA #>CODSTN
 STA EMXN+1
COW6 LDA #<CODSTG
 STA EMXB
 STA CORW+2
 LDA #>CODSTG
 STA EMXB+1
 STA CORW+3
 CLC
 JSR EMXMOV
 LDA EMXN
 STA CORW+4
 LDA EMXN+1
 STA CORW+5
 JSR COWRIT
 BCS COW9X
 CLC
 LDA EMXO
 ADC EMXN
 STA EMXO
 LDA EMXO+1
 ADC EMXN+1
 STA EMXO+1
 JMP COW5
COW9 CLC
COW9X RTS


* ---- COWBLK: A/X = address, Y = length ----------
COWBLK STA CORW+2
 STX CORW+3
 STY CORW+4
 LDA #0
 STA CORW+5
* fall into COWRIT

* ---- the MLI calls ------------------------------
COWRIT JSR MLI
 DFB $CB
 DA CORW
 RTS
COOPEN JSR MLI
 DFB $C8
 DA COOP
 LDA COOP+5
 STA CORW+1
 STA COCL+1
 RTS
COCLOS LDA #0
 STA COCL+1
 JSR MLI
 DFB $CC
 DA COCL
 RTS
COCREA JSR MLI
 DFB $C0
 DA COCR
 RTS
* A missing file makes DESTROY complain, and we
* ignore it: the CREATE that follows is the call
* that matters.
CODEST JSR MLI
 DFB $C1
 DA CODS
 RTS

* ---- parameter blocks ---------------------------
COOP DFB 3
 DA FNBUF1
 DA IOBUF
 DFB 0
CORW DFB 4
 DFB 0
 DA 0
 DA 0
 DA 0
COCL DFB 1
 DFB 0
COCR DFB 7
 DA FNBUF1
 DFB $C3
 DFB $4A
 DA 0
 DFB 1
 DA 0
 DA 0
CODS DFB 1
 DA FNBUF1
