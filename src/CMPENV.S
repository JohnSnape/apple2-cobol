* CMPENV.S  what pass one will and will not take
* PUT from COMPILE1.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= WHY THIS FILE ===============
* Until 2026-11-12 pass one SKIPPED any word it did
* not know.  That was kind to the three sample
* programs and unkind to everybody else: LINKAGE
* SECTION, ORGANIZATION INDEXED, COMP-1, JUSTIFIED
* RIGHT and BLANK WHEN ZERO all compiled, and the
* program then did something other than what it
* said.  An error is a nuisance; a program that
* quietly means something else is a lie.  So the
* rule turned round: a word is taken if it is on a
* list, and anything else is error 50, NOT PART OF
* THIS COBOL, at the line it is on.
*
* THE ONE EXCEPTION IS THE IDENTIFICATION DIVISION,
* which is free text - AUTHOR. JOHN SMITH, 11 NOV
* 2026 - and where everything is skipped, numbers
* too.  A number there used to be taken as a level:
* DATE-WRITTEN. 11 NOV 2026. made an item NOV at
* level 11.  DDSTA says which side of the line we
* are on: 0 until ENVIRONMENT DIVISION or DATA
* DIVISION, 1 after.
*
* The lists are length-prefixed words, $00 to end,
* and WDLOOK hands back the entry number - the same
* shape as CLWTAB always had, now read through a
* pointer so a list may be longer than 255 bytes.

* ---- WDLOOK: TOKBUF in the list at ZPT1? --------
* in:  ZPT1 -> the list (WDLKAX sets it from A/X)
* out: C=1 found, A = entry number from 0
*      C=0 not there
* ZPT1 is walked along the list and left wherever
* it stopped - it is scratch, zone S.
WDLKAX STA ZPT1
 STX ZPT1+1
WDLOOK STZ WDN
WDL1 LDY #0
 LDA (ZPT1),Y
 BEQ WDLNO
 CMP TOKLEN
 BNE WDL3
 TAX
WDL2 INY
 LDA (ZPT1),Y
 CMP TOKBUF-1,Y
 BNE WDL3
 DEX
 BNE WDL2
 LDA WDN
 SEC
 RTS
* past this entry: its count, plus one for the
* count byte itself (the SEC)
WDL3 LDY #0
 LDA (ZPT1),Y
 SEC
 ADC ZPT1
 STA ZPT1
 BCC WDL4
 INC ZPT1+1
WDL4 INC WDN
 BRA WDL1
WDLNO CLC
 RTS
WDN DFB 0

* ---- ENBAD: error 50 ----------------------------
ENBAD LDA #50
 STA CMPERR
 RTS

* ================= IDENTIFICATION ==============
* ---- ENIDN: a word in the free text -------------
* ENVIRONMENT or DATA followed by DIVISION ends the
* free text.  The next token is read to see - a
* REMARKS line that says "READS DATA FROM" stays
* free text, because FROM is not DIVISION.  The
* section headers further down can only be headers,
* so a program that leaves out both division lines
* and starts at WORKING-STORAGE SECTION still
* compiles, as it always did.
ENIDN LDA #<IDNTAB
 LDX #>IDNTAB
 JSR WDLKAX
 BCC ENIX
 CMP #2
 BCS ENIHD
 JSR LEXNEXT
 BCS ENIX
 LDA TOKTYP
 CMP #TKWORD
 BNE ENIX
 LDA #<DIVW
 LDX #>DIVW
 JSR WDLKAX
 BCC ENIX
 LDA #1
 STA DDSTA
ENIX RTS
* a section header: out of the free text, and the
* word is taken as it would be on the other side
ENIHD LDA #1
 STA DDSTA
 JMP ENWORD

IDNTAB DFB 11
 ASC 'ENVIRONMENT'
 DFB 4
 ASC 'DATA'
 DFB 13
 ASC 'CONFIGURATION'
 DFB 12
 ASC 'INPUT-OUTPUT'
 DFB 12
 ASC 'FILE-CONTROL'
 DFB 15
 ASC 'WORKING-STORAGE'
 DFB 13
 ASC 'SPECIAL-NAMES'
 DFB 0
DIVW DFB 8
 ASC 'DIVISION'
 DFB 0

* ================= ENVIRONMENT AND HEADERS ======
* ---- ENWORD: a word between the entries ---------
* Reached for a word that is not SELECT, FD, QUERY
* or PROCEDURE once the free text is over: a
* division or section header, a SPECIAL-NAMES
* clause, or something this COBOL does not have.
*
* WHAT IS REFUSED BY BEING LEFT OFF THE LIST:
* LINKAGE, SCREEN, REPORT, LOCAL-STORAGE and
* COMMUNICATION SECTION; I-O-CONTROL; CURRENCY SIGN,
* DECIMAL-POINT IS COMMA, CLASS, CRT STATUS and the
* mnemonic names (CONSOLE IS CRT).  CURRENCY SIGN
* and DECIMAL-POINT are wanted - FIXLIST B - but
* until they DO something, taking them would print
* dollars and points under a program that asked for
* pounds and commas.
ENWORD LDA #<ENWTAB
 LDX #>ENWTAB
 JSR WDLKAX
 BCS ENW0
 JMP ENBAD
ENW0 CMP #2
 BCS ENW1
* IDENTIFICATION or ID: free text again
 STZ DDSTA
 RTS
ENW1 CMP #16
 BCC ENWX
 CMP #18
 BCC ENSKIP
 BEQ ENUPC
* ANYCASE
 LDA #0
 JMP ENCASE
ENUPC LDA #$40
* ---- ENCASE: emit CASE with the flag in A -------
* UPPERCASE ONLY is what a program gets anyway -
* VMRUN starts with it - but saying so emits it
* too, so the object says what the source says.
ENCASE PHA
 LDA #OCASE
 JSR EMB
 PLA
 JMP EMB
ENWX RTS

* ---- ENSKIP: SOURCE-COMPUTER. APPLE-IIE. --------
* The computer's name is anybody's word, so the
* paragraph is passed over to its second full stop
* - the header's own, then the name's.
ENSKIP LDA #2
 STA ENDOT
ENS1 JSR LEXNEXT
 BCS ENSX
 LDA TOKTYP
 CMP #TKPUNC
 BNE ENS1
 LDA TOKBUF
 CMP #$2E
 BNE ENS1
 DEC ENDOT
 BNE ENS1
ENSX RTS
ENDOT DFB 0

* entries 0-1 free text; 2-15 headers and noise;
* 16-17 skipped paragraphs; 18 UPPERCASE; 19 ANYCASE
ENWTAB DFB 14
 ASC 'IDENTIFICATION'
 DFB 2
 ASC 'ID'
 DFB 11
 ASC 'ENVIRONMENT'
 DFB 4
 ASC 'DATA'
 DFB 8
 ASC 'DIVISION'
 DFB 7
 ASC 'SECTION'
 DFB 13
 ASC 'CONFIGURATION'
 DFB 12
 ASC 'INPUT-OUTPUT'
 DFB 12
 ASC 'FILE-CONTROL'
 DFB 4
 ASC 'FILE'
 DFB 15
 ASC 'WORKING-STORAGE'
 DFB 13
 ASC 'SPECIAL-NAMES'
 DFB 5
 ASC 'INPUT'
 DFB 4
 ASC 'CASE'
 DFB 2
 ASC 'IS'
 DFB 4
 ASC 'ONLY'
 DFB 15
 ASC 'SOURCE-COMPUTER'
 DFB 15
 ASC 'OBJECT-COMPUTER'
 DFB 9
 ASC 'UPPERCASE'
 DFB 7
 ASC 'ANYCASE'
 DFB 0

* ================= FD =========================
* ---- FDCLA: the FD's clauses, to its full stop --
* LABEL RECORDS ARE STANDARD, RECORD CONTAINS 40
* CHARACTERS, BLOCK CONTAINS, DATA RECORD IS: none
* of them changes anything here - the record is the
* 01 that follows - so they are read and passed
* over.  They used to fall back into the main loop,
* where the 40 of RECORD CONTAINS 40 CHARACTERS was
* a level number.
*
* A NUMBER THAT STARTS A LINE is the next entry's
* level: the FD's full stop is missing, error 35,
* as for a data entry (DDXVAL).  A number after a
* word on the same line is a count.
*
* Refused: LINAGE (page control this COBOL does not
* do), REPORT, CODE-SET, EXTERNAL, GLOBAL, and a
* record VARYING in size.
FDCLA LDA TOKLIN
 STA FDLN
 LDA TOKLIN+1
 STA FDLN+1
FDC1 JSR LEXNEXT
 BCS FDCX
 LDA TOKTYP
 CMP #TKPUNC
 BNE FDC2
 LDA TOKBUF
 CMP #$2E
 BEQ FDCX
 BRA FDCN
FDC2 CMP #TKNUM
 BNE FDC3
 LDA TOKLIN
 CMP FDLN
 BNE FDCDOT
 LDA TOKLIN+1
 CMP FDLN+1
 BNE FDCDOT
 BRA FDCN
FDC3 CMP #TKWORD
 BNE FDCN
 LDA #<FDXTAB
 LDX #>FDXTAB
 JSR WDLKAX
 BCC FDCN
 JMP ENBAD
* note this token's line: the next number starts a
* line only if it is on a later one
FDCN LDA TOKLIN
 STA FDLN
 LDA TOKLIN+1
 STA FDLN+1
 BRA FDC1
FDCDOT LDA #35
 STA CMPERR
FDCX RTS
FDLN DS 2

FDXTAB DFB 6
 ASC 'LINAGE'
 DFB 6
 ASC 'REPORT'
 DFB 7
 ASC 'REPORTS'
 DFB 8
 ASC 'CODE-SET'
 DFB 8
 ASC 'EXTERNAL'
 DFB 6
 ASC 'GLOBAL'
 DFB 7
 ASC 'VARYING'
 DFB 0

* ================= SELECT =====================
* ---- SELTAB: the words a SELECT may hold --------
* 0 ASSIGN, 1 KEY and 2 STATUS carry something
* (FCCLA); the rest only say what this system does
* anyway.  INDEXED, RECORD KEY, ALTERNATE, LINE
* SEQUENTIAL, RESERVE and LOCK are not here, and
* so are error 50.  They used to be skipped - and
* RECORD KEY IS X, being "KEY", quietly became the
* RELATIVE KEY.
SELTAB DFB 6
 ASC 'ASSIGN'
 DFB 3
 ASC 'KEY'
 DFB 6
 ASC 'STATUS'
 DFB 2
 ASC 'TO'
 DFB 12
 ASC 'ORGANIZATION'
 DFB 12
 ASC 'ORGANISATION'
 DFB 2
 ASC 'IS'
 DFB 10
 ASC 'SEQUENTIAL'
 DFB 8
 ASC 'RELATIVE'
 DFB 6
 ASC 'ACCESS'
 DFB 4
 ASC 'MODE'
 DFB 6
 ASC 'RANDOM'
 DFB 7
 ASC 'DYNAMIC'
 DFB 4
 ASC 'FILE'
 DFB 0
OPTW DFB 8
 ASC 'OPTIONAL'
 DFB 0

* ================= DATA ENTRIES ================
* ---- CLWTAB: the clause words of a data entry ---
* DDWHAT dispatches on the entry number:
*   0-1   PIC, PICTURE             DDPIC
*   2-3   VALUE, VALUES            DDVALC
*   4     OCCURS                   DDOCC
*   5     REDEFINES                DDREDF
*   6-7   THRU, THROUGH            DDXTHR (error 34)
*   8-16  the COMP family          DDCOMP
*   17-   taken and ignored
* THE COMP FAMILY: every one of them is a NUM8 cell
* here, as COMP-3 always was (KEYWORDS.md) - BINARY
* and COMP-4 hold the same numbers, just not in the
* same bytes, and no byte of a NUM8 is visible to a
* program except through a file this system wrote.
* TAKEN AND IGNORED: IS, ARE, TIMES, USAGE, DISPLAY,
* SIGN LEADING/TRAILING SEPARATE CHARACTER (where
* the sign is kept in storage - a NUM8 keeps it in
* its flag byte whatever is written), SYNC and
* SYNCHRONIZED LEFT/RIGHT (alignment: nothing here
* is aligned).
* REFUSED, by not being here: COMP-1 and COMP-2
* (floating point), INDEX, POINTER, JUSTIFIED,
* BLANK WHEN ZERO, INDEXED BY, DEPENDING ON,
* ASCENDING/DESCENDING KEY, EXTERNAL, GLOBAL,
* RENAMES.
CLWTAB DFB 3
 ASC 'PIC'
 DFB 7
 ASC 'PICTURE'
 DFB 5
 ASC 'VALUE'
 DFB 6
 ASC 'VALUES'
 DFB 6
 ASC 'OCCURS'
 DFB 9
 ASC 'REDEFINES'
 DFB 4
 ASC 'THRU'
 DFB 7
 ASC 'THROUGH'
 DFB 4
 ASC 'COMP'
 DFB 13
 ASC 'COMPUTATIONAL'
 DFB 6
 ASC 'COMP-3'
 DFB 15
 ASC 'COMPUTATIONAL-3'
 DFB 6
 ASC 'COMP-4'
 DFB 15
 ASC 'COMPUTATIONAL-4'
 DFB 6
 ASC 'COMP-5'
 DFB 6
 ASC 'BINARY'
 DFB 14
 ASC 'PACKED-DECIMAL'
 DFB 2
 ASC 'IS'
 DFB 3
 ASC 'ARE'
 DFB 5
 ASC 'TIMES'
 DFB 5
 ASC 'USAGE'
 DFB 7
 ASC 'DISPLAY'
 DFB 4
 ASC 'SIGN'
 DFB 7
 ASC 'LEADING'
 DFB 8
 ASC 'TRAILING'
 DFB 8
 ASC 'SEPARATE'
 DFB 9
 ASC 'CHARACTER'
 DFB 4
 ASC 'SYNC'
 DFB 12
 ASC 'SYNCHRONIZED'
 DFB 4
 ASC 'LEFT'
 DFB 5
 ASC 'RIGHT'
 DFB 0

DDSTA DFB 0
