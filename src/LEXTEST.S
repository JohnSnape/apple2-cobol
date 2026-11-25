* LEXTEST.S  the token dump - a harness for CMPLEX
* A STANDALONE program, not part of COMPILE.
* Built to the pattern QRYTEST set.
*
* HOW TO RUN IT
*   BLOAD COBOL.LIB,A$3000
*   BRUN LEXTEST
*
* WHAT IT PROVES
* A lexer is the one part of a compiler that can be
* tested completely on its own, because its output
* is readable.  This puts a twelve-line COBOL
* program into auxiliary memory - in the same
* eighty-byte records EDIT uses, so the lexer is
* reading exactly what it will read in earnest -
* and prints every token it gets back:
*
*   LINE COL TYPE TEXT
*
* Read the COL column against the source. A word in
* Area A shows a column of 2 to 5 and a word in
* Area B shows 6 or more, and that difference is
* the whole of fixed-form COBOL's grammar. If the
* columns are right the parser has what it needs;
* if they are not, nothing built on top of this can
* work and no amount of parser debugging will say
* why.
*
* Four things worth watching for in the output:
*   the '*' line does not appear at all
*   VALUE "HELLO, WORLD." is ONE token of type STR,
*     with the comma and the full stop inside it
*   123.45 is ONE token of type NUM, but the full
*     stop that ENDS the statement is its own PUNC
*   PIC S9(4)V99 comes back as one token, because
*     the harness asks for it with LEXPIC

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
 PUT CMPCON

 ORG $8000
 DSK /COBOL/OBJ/LEXTEST

TRSZ EQU 80
* NLINES counts the lines of THE SOURCE at the end of
* this file.  It is up here because the loop tests
* against it first - a small EQU met after its use
* is an ILLEGAL FORWARD REFERENCE to Merlin 8.
NLINES EQU 12

START JSR INIT80
 JSR CONINIT
 JSR CONCLR
 LDA #<MTITLE
 STA STRPTR
 LDA #>MTITLE
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 JSR FINDBNK
* EDIT's geometry: eighty-byte records, 512 to a
* bank, so the divide is a shift.
 LDA #9
 STA AXSHIFT
 LDA #TRSZ
 STA AXRSZ
 JSR TFILL
 JSR LEXINIT
 LDA #<MHEAD
 STA STRPTR
 LDA #>MHEAD
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR

TLOOP JSR LEXNEXT
 BCS TDONE
 LDA LEXERR
 BNE TERR
 JSR TDUMP
* PIC is the one word the parser must follow with a
* call of its own, because a picture string is not
* a COBOL word - S9(4)V99 would come back as five
* tokens with the meaning spread between them.
 JSR TISPIC
 BCC TLOOP
 JSR LEXPIC
 BCS TDONE
 JSR TDUMP
 JMP TLOOP

TDONE LDA #<MEND
 STA STRPTR
 LDA #>MEND
 STA STRPTR+1
 JSR CONPUTS
 JMP CONCR
TERR LDA #<MERR
 STA STRPTR
 LDA #>MERR
 STA STRPTR+1
 JSR CONPUTS
 LDA LEXERR
 CLC
 ADC #$30
 JSR CONPUTC
 JMP CONCR

* ---- TISPIC: C=1 if the token is PIC/PICTURE ----
TISPIC LDA TOKTYP
 CMP #TKWORD
 BNE TIPNO
 LDA TOKLEN
 CMP #3
 BEQ TIP1
 CMP #7
 BNE TIPNO
TIP1 LDX #0
TIP2 LDA TOKBUF,X
 CMP MPIC,X
 BNE TIPNO
 INX
 CPX #3
 BCC TIP2
 SEC
 RTS
TIPNO CLC
 RTS
MPIC ASC 'PIC'

* ---- TDUMP: one token, one line -----------------
TDUMP LDA TOKLIN
 JSR TDEC
 LDA #$20
 JSR CONPUTC
 LDA TOKCOL
 JSR TDEC
 LDA #$20
 JSR CONPUTC
 LDX TOKTYP
 LDA TNLO,X
 STA STRPTR
 LDA TNHI,X
 STA STRPTR+1
 JSR CONPUTS
 LDA #$20
 JSR CONPUTC
 LDX #0
TDU1 CPX TOKLEN
 BCS TDU2
 LDA TOKBUF,X
 JSR CONPUTC
 INX
 JMP TDU1
TDU2 JMP CONCR

* ---- TDEC: A as two digits, right justified -----
TDEC LDX #$30
TDE1 CMP #10
 BCC TDE2
 SEC
 SBC #10
 INX
 JMP TDE1
TDE2 PHA
 TXA
 CMP #$30
 BNE TDE3
 LDA #$20
TDE3 JSR CONPUTC
 PLA
 CLC
 ADC #$30
 JMP CONPUTC

* ---- TFILL: the source into auxiliary memory ----
* Each line is stored here length-prefixed and
* space-padded to eighty on the way out, which is
* the shape EDIT would have left it in.
TFILL LDA #<SRCTXT
 STA TSRC
 LDA #>SRCTXT
 STA TSRC+1
 LDA #0
 STA TN
TF1 LDA TN
 CMP #NLINES
 BCS TF9
 LDX #0
 LDA #$20
TF2 STA ROWBUF,X
 INX
 CPX #TRSZ
 BCC TF2
 LDA TSRC
 STA ZPT1
 LDA TSRC+1
 STA ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA TLEN
 BEQ TF4
 LDY #1
TF3 LDA (ZPT1),Y
 STA ROWBUF-1,Y
 CPY TLEN
 BCS TF4
 INY
 JMP TF3
TF4 LDA TN
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
 ADC TLEN
 STA TSRC
 LDA TSRC+1
 ADC #0
 STA TSRC+1
 INC TSRC
 BNE TF5
 INC TSRC+1
TF5 INC TN
 JMP TF1
TF9 LDA #NLINES
 STA NSRC
 LDA #0
 STA NSRC+1
 RTS

* ================= THE SOURCE =================
* Column 1 is the indicator, Area A starts at 2 and
* Area B at 6, so a division name is written with
* ONE leading space and a statement with five.
* (NLINES, the count of these, is at the top.)
SRCTXT DFB 25
 ASC ' IDENTIFICATION DIVISION.'
 DFB 19
 ASC ' PROGRAM-ID. HELLO.'
 DFB 16
 ASC '* a comment line'
 DFB 15
 ASC ' DATA DIVISION.'
 DFB 25
 ASC ' WORKING-STORAGE SECTION.'
 DFB 21
 ASC ' 01  MSG   PIC X(13).'
 DFB 31
 ASC ' 01  N     PIC S9(4)V99 COMP-3.'
 DFB 20
 ASC ' PROCEDURE DIVISION.'
 DFB 6
 ASC ' MAIN.'
 DFB 22
 ASC '     MOVE 123.45 TO N.'
 DFB 29
 ASC '     DISPLAY "HELLO, WORLD.".'
 DFB 14
 ASC '     STOP RUN.'

* ================== MESSAGES ==================
MTITLE DFB 24
 ASC 'LEXTEST - the token dump'
MHEAD DFB 15
 ASC 'LN CL TYPE TEXT'
MEND DFB 13
 ASC 'END OF SOURCE'
MERR DFB 10
 ASC 'LEX ERROR '
MTEOF DFB 4
 ASC 'EOF '
MTWORD DFB 4
 ASC 'WORD'
MTNUM DFB 4
 ASC 'NUM '
MTSTR DFB 4
 ASC 'STR '
MTPUNC DFB 4
 ASC 'PUNC'
TNLO DFB <MTEOF,<MTWORD,<MTNUM,<MTSTR,<MTPUNC
TNHI DFB >MTEOF,>MTWORD,>MTNUM,>MTSTR,>MTPUNC

* ================= VARIABLES ==================
TN DFB 0
TLEN DFB 0
TSRC DS 2

* ================= THE MODULES UNDER TEST ========
* PUT here, at the END, and not up with EQUATES.
* Code PUT before ORG and DSK is assembled but never
* written to the object - Merlin 8 left this file
* holding only its own tail (2026-11-07).  Only
* EQU-only files may come before ORG.  CMPVAR stays
* last, as in the compiler stubs.
 PUT CMPLEX
 PUT CMPVAR
