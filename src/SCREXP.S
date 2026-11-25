* SCREXP.S  export the current form as COBOL
* Part of FORMAT (PUT it from FORMAT.S).  Needs
* the form arrays (FCOUNT, EROWS, ELCOLS, EFCOLS,
* ETYPES, EWIDS, ELTEXT, ENAMES), DISKIO (LINEIN,
* COPYNAME, MKPATH, NAMEBUF) and PRODOS (WRDCT).
*
* WHY THIS EXISTS
* Nevada COBOL made you hand-write the DISPLAY
* statements that paint a screen, with terminal
* escape codes buried in the string literals.
* Abacus COBOL 64 gave you even less.  Neither had
* a SCREEN SECTION - nor did the 1974 standard.
* So we do what they did, except the screen painter
* writes the statements for you.
*
* The payoff is what we DON'T have to build: no
* SCREEN SECTION grammar, no runtime dictionary
* loading, no new p-code.  The generated source
* uses only verbs the compiler already has, and
* the programmer can read and edit every line of
* it - which a SCREEN SECTION would have hidden.
*
* Output is a SNIPPET - type SNP ($48) - not a
* program.  A snippet and a program hold
* STRUCTURALLY IDENTICAL bytes: no sequence
* numbers in either, indicator at column 1, Area A
* at 2, Area B at 6.  The type byte is the only
* thing that says which is which, which is exactly
* what a type byte is for - and it is why EDIT
* inserts a snippet by copying it in rather than
* converting anything.  It also means anyone
* opening one in a viewer sees at a glance that it
* is a fragment.
*
* Not type SCR ($4B) - that is a GRAB/SHOW screen
* image, a picture of a screen, where this is the
* text that paints one.

* ---- the two pointers, in zone P ----
* (ptr),Y works only through zero page, and Merlin
* has to know that in pass 1 - so these are EQUs and
* they come before the first use.  They were DS 2
* variables at the end of the file: a forward
* reference, then a bad address mode.  An overlay
* owns zone P while it runs; nothing in the library
* touches it.  SCRPRV takes the next slot.
TPTR EQU ZPDRV
TSPTR EQU ZPDRV+2

* ---- DOEXP: OA-E, prompt for a name and write ---
DOEXP LDA #<PEXP
 STA STRPTR
 LDA #>PEXP
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE DXDN
 LDA LLEN
 BEQ DXDN
 JSR COPYNAME
 LDA #$48
 JSR NAMSFX
 JSR MKPATH
 JSR BLDCOB
 LDA #<EXPOUT
 STA WSRC
 LDA #>EXPOUT
 STA WSRC+1
 LDA EXLEN
 STA WLEN
 LDA EXLEN+1
 STA WLEN+1
 LDA #$48
 STA WTYPE
 LDA #0
 STA WAUX
 STA WAUX+1
 JSR WRDCT
 BCS DXER
 LDA #<MEXPD
 STA STRPTR
 LDA #>MEXPD
 STA STRPTR+1
 JSR SHOWERR
DXDN RTS
DXER LDA #<MEXPE
 LDX #>MEXPE
 JMP FESHOW

* ================= THE EMITTER =================
* Everything below appends bytes to EXPOUT through
* TPTR.  There is no seeking and no backing up:
* the file is written once, front to back, exactly
* as it will be read.

* ---- TEMIT: A -> (TPTR), bump.  Y is lost ----
TEMIT LDY #0
 STA (TPTR),Y
 INC TPTR
 BNE TEMD
 INC TPTR+1
TEMD RTS

* ---- TSAX: A=lo X=hi -> emit that string ----
* strings here are length-prefixed, as PUTS wants,
* so the same literals could be shown on screen.
TSAX STA TSPTR
 STX TSPTR+1
 LDY #0
 LDA (TSPTR),Y
 STA TSLEN
 BEQ TSD
 LDA #1
 STA TSIX
TSL LDY TSIX
 LDA (TSPTR),Y
 JSR TEMIT
 INC TSIX
 LDA TSLEN
 CMP TSIX
 BCS TSL
TSD RTS

* ---- TDEC: A = 0-255 -> decimal, no leading 0 ---
* Clobbers X.  Callers keep the field index in EXI,
* never in X, for exactly this reason.
TDEC LDX #0
 STX TDH
 STX TDT
 STX TDANY
TD1 CMP #100
 BCC TD2
 SBC #100
 INC TDH
 JMP TD1
TD2 CMP #10
 BCC TD3
 SBC #10
 INC TDT
 JMP TD2
TD3 STA TDU
 LDA TDH
 BEQ TDT1
 CLC
 ADC #$30
 JSR TEMIT
 LDA #1
 STA TDANY
TDT1 LDA TDT
 BNE TDTY
 LDA TDANY
 BEQ TDU1
TDTY LDA TDT
 CLC
 ADC #$30
 JSR TEMIT
TDU1 LDA TDU
 CLC
 ADC #$30
 JMP TEMIT

* ---- line starters ----
* A snippet line starts at the indicator column,
* so TLINE is a single space and the next
* character lands in what will become Area A once
* EDIT numbers the line.  TIND adds four more for
* Area B.  Getting these two wrong is the classic
* fixed-form COBOL bug, so they are routines
* rather than counted spaces.
TLINE LDA #$20
 JMP TEMIT
TCOM LDA #$2A
 JMP TEMIT
TIND LDX #4
TI1 LDA #$20
 JSR TEMIT
 DEX
 BNE TI1
 RTS
TEOL LDA #$0D
 JMP TEMIT

* ---- TPFX: emit the screen prefix ----
* Taken from the filename the user just typed.
* A ProDOS name is letters, digits and periods,
* and since 2026-11-07 the period starts the
* suffix - CUSTSCR.SNP - so the prefix stops there:
* CUSTSCR-REC, not CUSTSCR-SNP-REC.  Upper-cased,
* what is left is always a legal COBOL word.
TPFX LDA NAMEBUF
 BEQ TPFDF
 STA TPLEN
 LDX #1
TPF1 LDA NAMEBUF,X
 AND #$7F
 CMP #$2E
 BEQ TPFD
TPF2 CMP #$61
 BCC TPF3
 CMP #$7B
 BCS TPF3
 SEC
 SBC #$20
TPF3 STX TPX
 JSR TEMIT
 LDX TPX
 INX
 DEC TPLEN
 BNE TPF1
TPFD RTS
* No name yet.  The preview runs before the first
* save, and there is no filename to take a prefix
* from - but '01 -REC.' is not COBOL, so an empty
* name gets a stand-in rather than nothing.
TPFDF LDA #<SUNT
 LDX #>SUNT
 JMP TSAX

* ---- TFNAME: emit field EXI's data name ----
* Ten bytes, space padded, stop at the first space.
TFNAME LDA EXI
 ASL
 STA TFT
 ASL
 ASL
 CLC
 ADC TFT
 CLC
 ADC #<ENAMES
 STA TSPTR
 LDA #>ENAMES
 ADC #0
 STA TSPTR+1
 LDY #0
TFN1 CPY #10
 BCS TFND
 LDA (TSPTR),Y
 CMP #$20
 BEQ TFND
 STY TFY
 JSR TEMIT
 LDY TFY
 INY
 JMP TFN1
TFND RTS

* ---- TLBP: point TSPTR at field EXI's label -----
* A = its length, Z set if it has none.  Nothing is
* written: the paint loop asks this first, and it
* used to ask TLBL, which wrote the label while it
* was only being asked - every DISPLAY line came out
* as "NAME"     DISPLAY "NAME" (2026-11-07).
TLBP LDA EXI
 ASL
 ASL
 ASL
 ASL
 CLC
 ADC #<ELTEXT
 STA TSPTR
 LDA #>ELTEXT
 ADC #0
 STA TSPTR+1
 LDY #0
 LDA (TSPTR),Y
 RTS

* ---- TLBL: emit field EXI's label, in quotes ----
* Returns C=1 if the field has no label, in which
* case nothing was written.
TLBL JSR TLBP
 STA TLLEN
 BNE TLGO
 SEC
 RTS
TLGO LDA #$22
 JSR TEMIT
 LDA #1
 STA TLIX
TLL LDY TLIX
 LDA (TSPTR),Y
 JSR TEMIT
 INC TLIX
 LDA TLLEN
 CMP TLIX
 BCS TLL
 LDA #$22
 JSR TEMIT
 CLC
 RTS

* ---- TAT: emit " AT LINE r COLUMN c." ----
* in: TATR = row, TATC = column, both 0-based as
* the dictionary stores them.  COBOL counts from
* 1, so both get incremented here - one of the
* few places where an off-by-one is a feature.
TAT LDA #<SAT
 LDX #>SAT
 JSR TSAX
 LDA TATR
 CLC
 ADC #1
 JSR TDEC
 LDA #<SCOL
 LDX #>SCOL
 JSR TSAX
 LDA TATC
 CLC
 ADC #1
 JSR TDEC
 LDA #$2E
 JSR TEMIT
 JMP TEOL

* ---- TPIC: emit field EXI's PICTURE ----
TPIC LDX EXI
 LDA ETYPES,X
 CMP #3
 BEQ TPCB
 CMP #2
 BEQ TPCN
 CMP #0
 BEQ TPCA
 LDA #$58
 JMP TPCW
TPCA LDA #$41
 JMP TPCW
TPCN LDA #$39
TPCW JSR TEMIT
 LDA #$28
 JSR TEMIT
 LDX EXI
 LDA EWIDS,X
 JSR TDEC
 LDA #$29
 JMP TEMIT
* A boolean is the NUM8 cell 1 or 0 - not "Y"/"N"
* - because that is how SCRINP packs it and what
* the dictionary says.  PIC X would be wrong.
* 9 COMP is a cell too, and with an 88 it says
* exactly what is stored.
TPCB LDA #<SPCB
 LDX #>SPCB
 JMP TSAX

* ================= BLDCOB =================
* Build the whole file.  Three passes over the
* same array, because the generated program wants
* the data, the painting and the input in three
* separate places - which is itself the argument
* for generating it rather than typing it.
BLDCOB LDA #<EXPOUT
 STA TPTR
 LDA #>EXPOUT
 STA TPTR+1

* --- banner ---
 JSR TCOM
 LDA #$20
 JSR TEMIT
 JSR TPFX
 LDA #<SGEN
 LDX #>SGEN
 JSR TSAX
 JSR TEOL
 JSR TCOM
 JSR TEOL

* --- 01 record ---
 JSR TLINE
 LDA #<S01
 LDX #>S01
 JSR TSAX
 JSR TPFX
 LDA #<SREC
 LDX #>SREC
 JSR TSAX
 JSR TEOL
 LDA #0
 STA EXI
BC1 LDA EXI
 CMP FCOUNT
 BCS BC1D
 JSR TLINE
 JSR TIND
 LDA #<S05
 LDX #>S05
 JSR TSAX
 JSR TFNAME
 LDA #<SPIC
 LDX #>SPIC
 JSR TSAX
 JSR TPIC
 LDA #$2E
 JSR TEMIT
 JSR TEOL
* "* field n" under every 05: QUERY FIELD n names a
* field by its place in the dictionary, counting
* from zero, and this is where a programmer reads
* the number instead of counting 05s (QUERY.md
* 15.2).
 JSR TCOM
 LDA #<SFLD
 LDX #>SFLD
 JSR TSAX
 LDA EXI
 JSR TDEC
 JSR TEOL
 LDX EXI
 LDA ETYPES,X
 CMP #3
 BNE BC1N
 JSR TLINE
 JSR TIND
 LDA #<S88
 LDX #>S88
 JSR TSAX
 JSR TFNAME
 LDA #<SYES
 LDX #>SYES
 JSR TSAX
 JSR TEOL
BC1N INC EXI
 JMP BC1
BC1D JSR TCOM
 JSR TEOL

* --- the paint paragraph ---
 JSR TLINE
 JSR TPFX
 LDA #<SPAINT
 LDX #>SPAINT
 JSR TSAX
 JSR TEOL
 LDA #0
 STA EXI
BC2 LDA EXI
 CMP FCOUNT
 BCS BC2D
 JSR TLBP
 BEQ BC2N
 JSR TLINE
 JSR TIND
 LDA #<SDISP
 LDX #>SDISP
 JSR TSAX
 JSR TLBL
 LDX EXI
 LDA EROWS,X
 STA TATR
 LDX EXI
 LDA ELCOLS,X
 STA TATC
 JSR TAT
BC2N INC EXI
 JMP BC2
BC2D JSR TCOM
 JSR TEOL

* --- the accept paragraph ---
 JSR TLINE
 JSR TPFX
 LDA #<SACC
 LDX #>SACC
 JSR TSAX
 JSR TEOL
 LDA #0
 STA EXI
BC3 LDA EXI
 CMP FCOUNT
 BCS BC3D
 JSR TLINE
 JSR TIND
 LDA #<SACCV
 LDX #>SACCV
 JSR TSAX
 JSR TFNAME
 LDX EXI
 LDA EROWS,X
 STA TATR
 LDX EXI
 LDA EFCOLS,X
 STA TATC
 JSR TAT
 INC EXI
 JMP BC3

* --- length written ---
BC3D SEC
 LDA TPTR
 SBC #<EXPOUT
 STA EXLEN
 LDA TPTR+1
 SBC #>EXPOUT
 STA EXLEN+1
 RTS

* ================= LITERALS =================
* Length-prefixed, as TSAX expects.
PEXP DFB 11
 ASC 'Export as? '
MEXPD DFB 15
 ASC 'Snippet saved  '
MEXPE DFB 13
 ASC 'Export failed'
SGEN DFB 21
 ASC '  generated by FORMAT'
S01 DFB 4
 ASC '01  '
SREC DFB 5
 ASC '-REC.'
SFLD DFB 7
 ASC ' field '
S05 DFB 4
 ASC '05  '
SPIC DFB 6
 ASC '  PIC '
S88 DFB 8
 ASC '    88  '
SYES DFB 14
 ASC '-YES  VALUE 1.'
SPCB DFB 6
 ASC '9 COMP'
SUNT DFB 6
 ASC 'SCREEN'
SPAINT DFB 7
 ASC '-PAINT.'
SACC DFB 8
 ASC '-ACCEPT.'
SDISP DFB 8
 ASC 'DISPLAY '
SACCV DFB 7
 ASC 'ACCEPT '
SAT DFB 9
 ASC ' AT LINE '
SCOL DFB 8
 ASC ' COLUMN '

* ================= VARIABLES =================
TSLEN DFB 0
TSIX DFB 0
TDH DFB 0
TDT DFB 0
TDU DFB 0
TDANY DFB 0
TPLEN DFB 0
TPX DFB 0
TFT DFB 0
TFY DFB 0
TLLEN DFB 0
TLIX DFB 0
TATR DFB 0
TATC DFB 0
EXI DFB 0
EXLEN DS 2
* THE BUFFER IS BIG ENOUGH BY CONSTRUCTION, which
* is why TEMIT does not test.  ADDENT caps a form
* at fifteen fields.  The most expensive field is a
* boolean - a 05 line, an 88 line, a DISPLAY and an
* ACCEPT, about 169 bytes - and the banner and two
* paragraph headers add about 110.  So the worst
* form a person can draw generates about 2,645
* bytes.  If the field cap ever rises, this number
* has to rise with it, and PVHDR will show the
* headroom shrinking while you work.
EXMAX EQU 3000
EXPOUT DS EXMAX
