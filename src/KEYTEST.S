* KEYTEST.S  a harness for the Apple command keys
* A STANDALONE program, not a library module.
* Built to the pattern QRYTEST set.
*
* HOW TO RUN IT
*   BLOAD COBOL.LIB,A$3000
*   BRUN KEYTEST
* ORGs at $8000 and ends with an RTS.
*
* WHAT IT PROVES, IN ORDER
*   1  READMOD sees both Apple keys, and sees them
*      AT THE KEYSTROKE - hold one down, type, let
*      go, and the reading is still right
*   2  with KEYCMD off, an ACCEPT behaves EXACTLY as
*      it did before any of this existed: OA-P types
*      a P and does not end the field.  This is the
*      stage that matters most, because it is the
*      promise made to every program already written
*   3  with KEYCMD on, a chord ends the ACCEPT and
*      KEYTERM/KEYCHAR say which one
*   4  the two bytes are printable, which is the
*      argument for them being ASCII: what is shown
*      on the screen is what a COBOL program would
*      see in its CRT STATUS item
*
* Nothing reports PASS.  The operator reads the
* screen - a test that reports PASS is a test that
* can lie.

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
 DSK /COBOL/OBJ/KEYTEST

BUFMAX EQU 39

START JSR INIT80
 JSR CONINIT
 JSR CONCLR
 LDA #<MTITLE
 STA STRPTR
 LDA #>MTITLE
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 JSR CONCR

* ---- 1: the raw modifier ----------------------
 JSR TMSG1
S1LP JSR WAITKEY
 STA TKEY
 AND #$7F
 CMP #$0D
 BEQ S1DN
 LDA #<MKEY
 STA STRPTR
 LDA #>MKEY
 STA STRPTR+1
 JSR CONPUTS
 LDA TKEY
 AND #$7F
 JSR CONPUTC
 LDA #<MMOD
 STA STRPTR
 LDA #>MMOD
 STA STRPTR+1
 JSR CONPUTS
 JSR TAPPLE
 JSR CONCR
 JMP S1LP
S1DN JSR CONCR

* ---- 2: KEYCMD off, the compatibility promise --
 LDA #0
 STA KEYCMD
 JSR TMSG2
 JSR TACC
 JSR TSHOW

* ---- 3: KEYCMD on, chords end the field --------
 LDA #1
 STA KEYCMD
 JSR TMSG3
S3LP JSR TACC
 JSR TSHOW
 LDA KEYTERM
 CMP #$33
 BNE S3LP
 LDA KEYCHAR
 CMP #$51
 BNE S3LP
* leave the switch as we found it, so a program
* run after this one is not surprised
 LDA #0
 STA KEYCMD
 RTS

* ---- TACC: one ACCEPT into TBUF ----------------
TACC LDA #<MPROMPT
 STA STRPTR
 LDA #>MPROMPT
 STA STRPTR+1
 JSR CONPUTS
 LDA #<TBUF
 STA ZPT2
 LDA #>TBUF
 STA ZPT2+1
 LDA #BUFMAX
 JSR CONGETLN
 STY TLEN
 RTS

* ---- TSHOW: the status, then what was typed ----
* KEYTERM and KEYCHAR go out as themselves.  They
* are ASCII precisely so that this is one CONPUTC
* each and not a conversion - and so that a COBOL
* program can DISPLAY its CRT STATUS item without
* doing anything to it first.
TSHOW LDA #<MTERM
 STA STRPTR
 LDA #>MTERM
 STA STRPTR+1
 JSR CONPUTS
 LDA KEYTERM
 JSR CONPUTC
 LDA KEYCHAR
 JSR CONPUTC
 LDA #<MGOT
 STA STRPTR
 LDA #>MGOT
 STA STRPTR+1
 JSR CONPUTS
 LDX #0
TSH1 CPX TLEN
 BCS TSH2
 LDA TBUF,X
 JSR CONPUTC
 INX
 JMP TSH1
TSH2 JMP CONCR

* ---- TAPPLE: KEYMOD as two letters -------------
* O and S if held, a dot if not.  Two characters
* rather than a hex byte, because the thing being
* checked is which key was down and a person reads
* letters faster than nibbles.
TAPPLE LDA KEYMOD
 AND #$80
 BEQ TAP1
 LDA #$4F
 BNE TAP2
TAP1 LDA #$2E
TAP2 JSR CONPUTC
 LDA KEYMOD
 AND #$40
 BEQ TAP3
 LDA #$53
 BNE TAP4
TAP3 LDA #$2E
TAP4 JMP CONPUTC

* ---- the three stage headings ------------------
TMSG1 LDA #<M1
 STA STRPTR
 LDA #>M1
 STA STRPTR+1
 JSR CONPUTS
 JMP CONCR
TMSG2 LDA #<M2
 STA STRPTR
 LDA #>M2
 STA STRPTR+1
 JSR CONPUTS
 JMP CONCR
TMSG3 LDA #<M3
 STA STRPTR
 LDA #>M3
 STA STRPTR+1
 JSR CONPUTS
 JMP CONCR

* ================== MESSAGES ==================
* Length-prefixed.  CONPUTS reads the first byte as
* a count.
MTITLE DFB 24
 ASC 'KEYTEST - THE APPLE KEYS'
MPROMPT DFB 2
 ASC '> '
MKEY DFB 4
 ASC 'KEY '
MMOD DFB 6
 ASC '  MOD '
MTERM DFB 7
 ASC 'STATUS '
MGOT DFB 6
 ASC '  GOT '
M1 DFB 43
 ASC '1. TYPE KEYS - OA/SA SHOW - RETURN TO GO ON'
M2 DFB 42
 ASC '2. KEYCMD OFF - OA-P SHOULD TYPE A PLAIN P'
M3 DFB 38
 ASC '3. KEYCMD ON - OA-Q TO FINISH THE TEST'

* ================= VARIABLES ==================
TKEY DFB 0
TLEN DFB 0
TBUF DS 40
