* CMPLEX.S  the lexer  -  COMPILE slice 2
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Source in, tokens out.  The design is COMPILE.md.
*
* IT READS FROM AUXILIARY MEMORY, NOT FROM DISK.
* One record a line, eighty bytes, exactly as EDIT
* holds it - so compiling needs no disk at all once
* the source is loaded, and a syntax error costs
* nothing to run again.  The caller sets AXRSZ and
* AXSHIFT to EDIT's geometry and NSRC to the line
* count; this file does the AXMAP and the AXGET.
*
* THE COLUMN IS PART OF THE TOKEN.
* Every other lexer hands back a type and some text.
* This one also hands back the COLUMN the token
* started in, because in fixed-form COBOL that is
* not decoration - it is grammar.  A word beginning
* in Area A is a division, a section, a paragraph or
* an 01; the same word beginning in Area B is a
* statement.  A parser that does not know where the
* token was cannot tell those apart, and would have
* to be told by a mode flag threaded through
* everything.
*
*   col 1     indicator: '*' comment, '-' continue
*   col 2-5   Area A
*   col 6-80  Area B
*
* THE PICTURE STRING IS NOT A COBOL WORD.
* S9(6)V99 has parentheses in it, and lexing it as
* a word would break it into five tokens with the
* meaning spread between them.  Every real COBOL
* compiler special-cases this and so do we: the
* parser sees PIC, and then calls LEXPIC, which
* takes the next run of non-blank characters
* whatever is in it.  Thirty bytes here that save a
* mess in the DATA DIVISION parser.

* The token codes (TKEOF TKWORD TKNUM TKSTR TKPUNC)
* and TOKMAX are in CMPCON.S, with the compiler's
* other constants: LEXTEST tests them before it PUTs
* this file, and Merlin 8 must meet a small EQU
* before its first use.

* ---- LEXINIT: start at line 0, column 1 ---------
* in: NSRC = how many source lines there are
LEXINIT LDA #0
 STA LEXLN
 STA LEXLN+1
 STA LEXERR
 STA LEXHDL
 LDA #81
 STA LEXCOL
 RTS

* ---- LEXLINE: read line LEXLN into LEXBUF -------
* out: C=1 if there are no more lines
* The buffer is space filled first, so a short
* record - or a record that was never written -
* lexes as blanks rather than as whatever was in
* auxiliary memory beforehand.
*
* INSIDE A COPY BOOK the line comes from the copy
* book's lines instead, which LXCOPY (below) put in
* aux after the source: record NSRC + CPYLN.
* LEXLN stays on the line after the COPY, so the
* program goes on from there when the book ends.
LEXLINE LDA CPYON
 BEQ LXLM
 LDA CPYLN
 CMP CPYEND
 LDA CPYLN+1
 SBC CPYEND+1
 BCS LXLCE
 CLC
 LDA NSRC
 ADC CPYLN
 STA AXREC
 LDA NSRC+1
 ADC CPYLN+1
 STA AXREC+1
 INC CPYLN
 BNE LXLRD
 INC CPYLN+1
 BRA LXLRD
* the book is done: back to the program
LXLCE STZ CPYON
LXLM LDA LEXLN
 CMP NSRC
 LDA LEXLN+1
 SBC NSRC+1
 BCC LXL1
 SEC
 RTS
LXL1 LDA LEXLN
 STA AXREC
 LDA LEXLN+1
 STA AXREC+1
 INC LEXLN
 BNE LXLRD
 INC LEXLN+1
LXLRD LDX #0
 LDA #$20
LXL2 STA LEXBUF,X
 INX
 CPX #80
 BCC LXL2
 JSR AXMAP
 LDA #80
 STA AXLEN
 STZ AXLEN+1
 LDA #<LEXBUF
 STA AXBUF
 LDA #>LEXBUF
 STA AXBUF+1
 JSR AXGET
 LDA #1
 STA LEXCOL
 CLC
 RTS

* ---- LEXNEXT: the next token --------------------
* out: TOKTYP TOKLEN TOKCOL TOKLIN, text in TOKBUF
*      C=1 at end of source
LEXNEXT LDA #0
 STA TOKLEN
 STA TOKTYP
* past the end of the line?  Get another.
LXN1 LDA LEXCOL
 CMP #81
 BCC LXN3
LXN2 JSR LEXLINE
 BCC LXN2A
 LDA #TKEOF
 STA TOKTYP
 SEC
 RTS
* Column 1 is the indicator and is never part of a
* token.  A comment is skipped whole; a
* continuation is noted and the line is then read
* from column 2 like any other.
LXN2A LDA LEXBUF
 CMP #$2A
 BEQ LXN2
 CMP #$2D
 BNE LXN2B
 LDA #1
 STA LEXHDL
LXN2B LDA #2
 STA LEXCOL
* skip blanks
LXN3 LDX LEXCOL
 CPX #81
 BCS LXN1
 LDA LEXBUF-1,X
 CMP #$20
 BNE LXN4
 INC LEXCOL
 JMP LXN3
* the token starts here: write down WHERE before
* anything else consumes it
* LEXLINE increments LEXLN after it reads, so LEXLN
* is already the 1-BASED number of the line the
* token is on - which is the number a person needs
* in an error message.  The record number, which is
* what positions EDIT's cursor, is one less.
LXN4 LDA LEXCOL
 STA TOKCOL
 LDA LEXLN
 STA TOKLIN
 LDA LEXLN+1
 STA TOKLIN+1
* in a copy book TOKLIN is the COPY's line, and
* TOKCPY the line in the book (from 1), so an error
* can name both; 0 in the program itself
 STZ TOKCPY
 STZ TOKCPY+1
 LDA CPYON
 BEQ LXN4A
 LDA CPYLN
 STA TOKCPY
 LDA CPYLN+1
 STA TOKCPY+1
LXN4A
 LDX LEXCOL
 LDA LEXBUF-1,X
 CMP #$22
 BEQ LXSTR
 CMP #$27
 BEQ LXSTR
 JSR LXDIG
 BCS LXNUM
 JSR LXALP
 BCS LXWORD
 JMP LXPUNC

* ---- a word: letters, digits and hyphens --------
* Folded to upper case here rather than at compare
* time, because a name is compared many times and
* read once.
LXWORD LDA #TKWORD
 STA TOKTYP
LXW1 LDX LEXCOL
 CPX #81
 BCS LXWD
 LDA LEXBUF-1,X
 JSR LXWCH
 BCC LXWD
 JSR LXFOLD
 JSR LXPUT
 INC LEXCOL
 JMP LXW1
* the word COPY is not handed to the parser: the
* lexer carries it out, and hands back the first
* token of the book instead (LXCOPY, below)
LXWD LDA TOKLEN
 CMP #4
 BNE LXWDX
 LDX #3
LXWD1 LDA TOKBUF,X
 CMP CPYW,X
 BNE LXWDX
 DEX
 BPL LXWD1
 JMP LXCOPY
LXWDX CLC
 RTS

* ---- a number ----------------------------------
* Digits, and one embedded point.  The sign is
* punctuation as far as this file is concerned -
* the parser knows whether a '-' in front of a
* number is a sign or an operator and the lexer
* does not.
LXNUM LDA #TKNUM
 STA TOKTYP
LXNM1 LDX LEXCOL
 CPX #81
 BCS LXNMD
 LDA LEXBUF-1,X
 JSR LXDIG
 BCS LXNM2
 CMP #$2E
 BNE LXNMD
* a point is part of the number only if a digit
* follows it.  Otherwise it is the full stop that
* ends the sentence, and eating it here would lose
* the end of every statement that finishes with a
* literal.
 LDX LEXCOL
 CPX #80
 BCS LXNMD
 LDA LEXBUF,X
 JSR LXDIG
 BCC LXNMD
 LDA #$2E
LXNM2 JSR LXPUT
 INC LEXCOL
 JMP LXNM1
LXNMD CLC
 RTS

* ---- a quoted literal --------------------------
* Either quote character opens one, and the same
* one closes it.  A doubled quote inside is one
* quote, which is how COBOL has always said it.
* NOT folded to upper case: what is between the
* quotes is data.
LXSTR LDA #TKSTR
 STA TOKTYP
 LDX LEXCOL
 LDA LEXBUF-1,X
 STA LEXQ
 INC LEXCOL
LXS1 LDX LEXCOL
 CPX #81
 BCS LXSBAD
 LDA LEXBUF-1,X
 CMP LEXQ
 BNE LXS2
 LDX LEXCOL
 CPX #80
 BCS LXSD
 LDA LEXBUF,X
 CMP LEXQ
 BNE LXSD
 INC LEXCOL
LXS2 LDA LEXBUF-1,X
 JSR LXPUT
 INC LEXCOL
 JMP LXS1
LXSD INC LEXCOL
 CLC
 RTS
* A literal that runs off the end of the line is an
* error, not a literal that happens to be short:
* the continuation rule is what joins two lines,
* and it has not been used.
LXSBAD LDA #1
 STA LEXERR
 CLC
 RTS

* ---- punctuation -------------------------------
* One character, its own token.  Which characters
* are legal is the parser's business; anything not
* a word, a number or a quote comes through here
* and is rejected where it is understood.
LXPUNC LDA #TKPUNC
 STA TOKTYP
 LDX LEXCOL
 LDA LEXBUF-1,X
 JSR LXPUT
 INC LEXCOL
 CLC
 RTS

* ---- LEXPIC: the next run of non-blanks ---------
* For PICTURE strings only.  Called by the parser
* the moment it has seen PIC or PICTURE, and never
* otherwise.
LEXPIC LDA #0
 STA TOKLEN
 LDA #TKWORD
 STA TOKTYP
LXP1 LDA LEXCOL
 CMP #81
 BCC LXP2
 JSR LEXLINE
 BCC LXP1
 SEC
 RTS
LXP2 LDX LEXCOL
 LDA LEXBUF-1,X
 CMP #$20
 BNE LXP3
 INC LEXCOL
 JMP LXP1
LXP3 LDA LEXCOL
 STA TOKCOL
LXP4 LDX LEXCOL
 CPX #81
 BCS LXPD
 LDA LEXBUF-1,X
 CMP #$20
 BEQ LXPD
* A full stop ends a picture only when a blank or
* the end of the line comes next: 9(4). ends at the
* stop, ZZ9.99 does not.  (It used to end at every
* stop after the first character, which cut ZZ9.99
* to ZZ9.)  X is LEXCOL, so LEXBUF,X is the
* character after this one.
 CMP #$2E
 BNE LXP5
 CPX #80
 BCS LXPD
 LDA LEXBUF,X
 CMP #$20
 BEQ LXPD
LXP5 LDX LEXCOL
 LDA LEXBUF-1,X
 JSR LXFOLD
 JSR LXPUT
 INC LEXCOL
 JMP LXP4
LXPD CLC
 RTS

* ================= CHARACTER TESTS =============
* ---- LXPUT: append A to TOKBUF ------------------
* A token longer than the buffer is an ERROR, not a
* truncation.  A silently shortened data name would
* match the wrong symbol, and that is a bug nobody
* would find by reading the source.
LXPUT LDX TOKLEN
 CPX #TOKMAX
 BCC LXPT1
 LDA #2
 STA LEXERR
 RTS
LXPT1 STA TOKBUF,X
 INC TOKLEN
 RTS

* ---- LXDIG: C=1 if A is a digit -----------------
LXDIG CMP #$30
 BCC LXDNO
 CMP #$3A
 BCS LXDNO
 SEC
 RTS
LXDNO CLC
 RTS

* ---- LXALP: C=1 if A is a letter ----------------
LXALP CMP #$41
 BCC LXANO
 CMP #$5B
 BCC LXAYES
 CMP #$61
 BCC LXANO
 CMP #$7B
 BCS LXANO
LXAYES SEC
 RTS
LXANO CLC
 RTS

* ---- LXWCH: C=1 if A may continue a word --------
* Letters, digits and the hyphen.  A COBOL word may
* not END in a hyphen either, which the parser can
* see for itself from the token it is handed.
LXWCH CMP #$2D
 BEQ LXWCY
 JSR LXALP
 BCS LXWCY
 JSR LXDIG
 BCS LXWCY
 CLC
 RTS
LXWCY SEC
 RTS

* ---- LXFOLD: A to upper case --------------------
LXFOLD CMP #$61
 BCC LXFD
 CMP #$7B
 BCS LXFD
 SEC
 SBC #$20
LXFD RTS

* ================ COPY (2026-11-11) ===============
*     COPY CUSTSCR.        COPY "1/LEDGER".
* The lexer carries out COPY itself, so neither pass
* knows it exists: it reads the book and goes on
* lexing from the book's first line, then from the
* line after the COPY.  KEYWORDS.md has the why.
*
* THE BOOK IS PUT IN AUX, AFTER THE SOURCE.  It is
* read once, a line at a time (ProDOS's NEWLINE
* mode stops each READ at a Return), and every line
* becomes an 80-byte record at NSRC, NSRC+1 ... -
* the same records the source is in, so LEXLINE
* reads a book line exactly as it reads a program
* line.  The file is closed again at once, so
* nothing stays open while the parser works: a
* .MNU read for ACCEPT FROM MENU inside a book
* still has IOBUF.  EDIT keeps nothing past the
* last line, so the space is free.
*
* A .SNP HAS PIECES.  FORMAT, REPORT and the PROCS
* library write the data and the paragraphs into
* one .SNP, parted by lines that are a lone "*" -
* the same pieces EDIT's PLACE counts (EDITPLC.S):
*     notes  *  the data  *  the paragraphs
* (FORMAT's paragraphs are two pieces, the paint
* and the accept, and a lone "*" is a comment.)
* COPY takes the piece that belongs where it is
* (the user's rule, 2026-11-11): in the DATA
* DIVISION the lines between the first lone "*"
* and the second, in the PROCEDURE DIVISION all
* the lines after the second.  Pass one is the
* DATA DIVISION and pass two the PROCEDURE
* DIVISION, so CMPPHS tells which.  A book with no
* lone "*" is copied whole either way.
*
* A BARE NAME gets .SNP, and is looked for in 0/,
* then in */PROCS/, so COPY DATES finds the library
* (the user's rule).  A name with a "/" in it - a
* prefix, "1/LEDGER", or a full path - is used as
* it is written.
*
* ONE DEEP.  A book may not COPY: error 45.  And
* COPY ends its line - the rest after the full stop
* is not read, as with PROCEDURE DIVISION.
CPYBUF EQU $BE80

* the errors, ahead of the code so its branches reach
LXCSYN LDA #44
* an error stops the pass the way a lexer error
* does - LEXERR - with its own number in CMPERR,
* which both passes report ahead of LEXERR
LXCERR STA CMPERR
 LDA #3
 STA LEXERR
LXCX CLC
 RTS
LXCOPY LDA CPYON
 BEQ LXC1
 LDA #45
 JMP LXCERR
* the name, a word or a quoted string
LXC1 JSR LEXNEXT
 BCS LXCSYN
 LDA LEXERR
 BNE LXCX
 LDA TOKTYP
 CMP #TKWORD
 BEQ LXC2
 CMP #TKSTR
 BNE LXCSYN
LXC2 LDX TOKLEN
 BEQ LXCSYN
 STX CPYNM
LXC3 LDA TOKBUF-1,X
 STA CPYNM,X
 DEX
 BNE LXC3
* then the full stop, and nothing else: OF and
* REPLACING are not in the subset
 JSR LEXNEXT
 BCS LXCSYN
 LDA TOKTYP
 CMP #TKPUNC
 BNE LXCSYN
 LDA TOKBUF
 CMP #$2E
 BNE LXCSYN
 JSR CPOPEN
 BCC LXC4
 LDA #43
 JMP LXCERR
LXC4 JSR CPSTG
 BCC LXC5
 JMP LXCERR
* the piece: CPYLN up to CPYEND, the whole book
* unless it has a lone "*"
LXC5 STZ CPYLN
 STZ CPYLN+1
 LDA CPYN
 STA CPYEND
 LDA CPYN+1
 STA CPYEND+1
 LDA CPYSF
 BEQ LXC8
* the DATA DIVISION starts after the first, the
* PROCEDURE DIVISION after the second - and with
* no second it takes nothing (CPYLN = CPYEND)
 LDX #0
 LDA CMPPHS
 BEQ LXC6
 LDX #2
 LDA CPYSF
 CMP #2
 BCS LXC6
 LDA CPYN
 STA CPYLN
 LDA CPYN+1
 STA CPYLN+1
 BRA LXC8
LXC6 CLC
 LDA CPYSI,X
 ADC #1
 STA CPYLN
 LDA CPYSI+1,X
 ADC #0
 STA CPYLN+1
* the data ends at the second, if there is one
 LDA CMPPHS
 BNE LXC8
 LDA CPYSF
 CMP #2
 BCC LXC8
 LDA CPYSI+2
 STA CPYEND
 LDA CPYSI+3
 STA CPYEND+1
* and on from the book's first line
LXC8 LDA #81
 STA LEXCOL
 LDA #1
 STA CPYON
 JMP LEXNEXT

* ---- CPOPEN: open the book, NEWLINE on Return ----
* out: C=1 if it is in neither place
CPOPEN LDA #<CPYNM
 STA FNAMP
 LDA #>CPYNM
 STA FNAMP+1
 JSR CPOP1
 BCC CPOX
* not in 0/: a bare name is tried in */PROCS/
 LDX CPYNM
CPO1 LDA CPYNM,X
 CMP #$2F
 BEQ CPOF
 DEX
 BNE CPO1
 LDX #0
CPO2 LDA CPPRC,X
 STA CPYPN+1,X
 INX
 CPX #8
 BNE CPO2
 LDY #0
CPO3 LDA CPYNM+1,Y
 STA CPYPN+9,Y
 INY
 CPY CPYNM
 BNE CPO3
 TYA
 CLC
 ADC #8
 STA CPYPN
 LDA #<CPYPN
 STA FNAMP
 LDA #>CPYPN
 STA FNAMP+1
* SETSFX adds .SNP to a name with no suffix and
* expands a prefix name, into FNBUF1 (FILEIO.S)
CPOP1 LDA #$48
 LDX #0
 JSR SETSFX
 JSR MLI
 DFB $C8
 DA CPOPP
 BCS CPOX
 LDA CPOPP+5
 STA CPNLP+1
 STA CPRDP+1
 STA CPCLP+1
 JSR MLI
 DFB $C9
 DA CPNLP
CPOX RTS
CPOF SEC
 RTS

* ---- CPSTG: every line of the book into aux -----
* out: CPYN lines, CPYSF/CPYSI the first lone "*";
*      C=1 and A = the error (43 unreadable, 46 no
*      room), the file closed either way
* the ends, ahead of the loop so its branches reach
CPS9 JSR CPCLS
 CLC
 RTS
CPSER PHA
 JSR CPCLS
 PLA
 SEC
 RTS
CPCLS JSR MLI
 DFB $CC
 DA CPCLP
 RTS
CPSTG STZ CPYN
 STZ CPYN+1
 STZ CPYSF
* spaces first: a short line is blank to column 80
CPS1 LDX #80
 LDA #$20
CPS2 STA CPYBUF,X
 DEX
 BPL CPS2
 JSR MLI
 DFB $CA
 DA CPRDP
 BCC CPS3
 CMP #$4C
 BEQ CPS9
 LDA #43
 BRA CPSER
* the Return becomes a space, and any high bits go
* (a file written by another program may have
* them); CPL is the line's length without it
CPS3 LDA CPRDP+6
 STA CPL
 LDX #0
CPS4 CPX CPRDP+6
 BCS CPS6
 LDA CPYBUF,X
 AND #$7F
 CMP #$0D
 BNE CPS5
 STX CPL
 LDA #$20
CPS5 STA CPYBUF,X
 INX
 BRA CPS4
* the first two lone "*"s part the pieces: where
* each is goes in CPYSI, two bytes apiece
CPS6 LDA CPL
 CMP #1
 BNE CPS7
 LDA CPYBUF
 CMP #$2A
 BNE CPS7
 LDA CPYSF
 CMP #2
 BCS CPS7
 ASL
 TAX
 LDA CPYN
 STA CPYSI,X
 LDA CPYN+1
 STA CPYSI+1,X
 INC CPYSF
* record NSRC + CPYN, if aux has it
CPS7 CLC
 LDA NSRC
 ADC CPYN
 STA AXREC
 LDA NSRC+1
 ADC CPYN+1
 STA AXREC+1
 LDA AXREC
 CMP AXCAPV
 LDA AXREC+1
 SBC AXCAPV+1
 BCC CPS8
 LDA #46
 JMP CPSER
CPS8 JSR AXMAP
 LDA #80
 STA AXLEN
 STZ AXLEN+1
 LDA #<CPYBUF
 STA AXBUF
 LDA #>CPYBUF
 STA AXBUF+1
 JSR AXPUT
 INC CPYN
 BNE CPS8A
 INC CPYN+1
CPS8A JMP CPS1

* ---- LXSHCP: ", COPY book line n" ---------------
* Both passes call this after "at line n" when they
* report an error, so an error in a book names the
* COPY's line and the line in the book.
LXSHCP LDA TOKCPY
 ORA TOKCPY+1
 BEQ LXSC9
 LDA #<MCPYL
 STA STRPTR
 LDA #>MCPYL
 STA STRPTR+1
 JSR CONPUTS
 LDA TOKCPY
 STA NFVAL
 LDA TOKCPY+1
 STA NFVAL+1
 STZ NFVAL+2
 JSR NFCOMMA
 LDA #<NFBUF
 STA STRPTR
 LDA #>NFBUF
 STA STRPTR+1
 JSR CONPUTS
LXSC9 RTS

* ---- the MLI calls' parameters, and the state ---
CPOPP DFB 3
 DA FNBUF1
 DA IOBUF
 DFB 0
CPNLP DFB 3
 DFB 0
 DFB $7F
 DFB $0D
CPRDP DFB 4
 DFB 0
 DA CPYBUF
 DA 81
 DA 0
CPCLP DFB 1
 DFB 0
MCPYL DFB 17
 ASC ', COPY book line '
* 'COPY' and '*/PROCS/', as bytes
CPYW DFB $43,$4F,$50,$59
CPPRC DFB $2A,$2F,$50,$52,$4F,$43,$53,$2F
* in a book: CPYON 1, CPYLN the next line of it,
* CPYEND one past its last; CPYN lines read, CPYSF
* (0, 1 or 2) the lone "*"s and CPYSI where
CPYON DFB 0
CPYLN DA 0
CPYEND DA 0
CPYN DA 0
CPYSF DFB 0
CPYSI DS 4
CPL DFB 0
TOKCPY DA 0
CPYNM DS 41
CPYPN DS 50
