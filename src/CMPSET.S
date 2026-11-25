* CMPSET.S  SET, DISPLAY ERASE, ACCEPT FROM MENU
* PUT from COMPILE2.S, after CMPARITH - no ORG, not
* assembled alone.  One symbol table spans every
* PUT.  Written 2026-11-11 for the user's four
* asks: a way to clear the screen, a report shown a
* page at a time, prefixes a program can set, and a
* menu designed in FORMAT.
*
*   DISPLAY ERASE [operands]          $8B ERASE 0
*   DISPLAY ERASE UPON PRINTER        $8B ERASE 1
*   SET PRINTER TO SCREEN | PAPER     $8C SETPR f
*   SET PREFIX n TO literal | item    $8D SETPX n k w
*   ACCEPT item FROM MENU "NAME"      $8E MENU ...
* (FROM KEY and FROM PREFIX n are $85 ACCF codes 2
* and 3, in PDAFR, CMPPROC4.S.)
*
* SET is not in VERBTAB, which is full: PDDISP finds
* it in ENDWT, the table that holds the END-xxx
* words for the same reason (CMPPROC.S, PDD9).
* Its words - PRINTER PREFIX SCREEN PAPER, and ERASE
* - are SETWT, beside the others in CMPPROC3.

* ---- PDERAS: DISPLAY's first word ERASE? ---------
* Called before DISPLAY reads its first operand.
* out: C=1 - there was no ERASE; the token is handed
*            back and DISPLAY goes on as it always
*            did
*      C=0 - ERASE, and its instruction emitted.
*            A=0: the statement is finished.  A=1:
*            operands follow, the first one handed
*            back, and DISPLAY goes on with them -
*            DISPLAY ERASE "MAIN MENU" AT LINE 1 ...
PDERAS JSR PDNEXT
 BCS PDER9
 LDA TOKTYP
 CMP #TKWORD
 BNE PDER9
 LDX #SETWT-RELWT
 JSR PFRW1
 BCS PDER9
 LDA PFRT
 CMP #SETWT-RELWT+28
 BNE PDER9
* ERASE.  UPON PRINTER after it is the report's
* page break, and the whole statement.
 JSR PDUPON
 LDA #OERASE
 JSR EMB
 BCS PDERX
 LDA PDDEV
 JSR EMB
 BCS PDERX
 LDA PDDEV
 BNE PDER0
* an operand next?  The same test DISPLAY makes
* between its operands (PDDS1A, CMPPROC.S)
 LDA PDHELD
 BEQ PDER0
 LDA TOKTYP
 CMP #TKSTR
 BEQ PDER1
 CMP #TKNUM
 BEQ PDER1
 CMP #TKWORD
 BNE PDER0
 JSR PDQKW
 BCC PDER0
 JSR SYMFIND
 BCC PDER1
 JSR PDISFG
 BCC PDER1
PDER0 LDA #0
 CLC
 RTS
PDER1 LDA #1
 CLC
 RTS
PDER9 LDA #1
 STA PDHELD
 SEC
 RTS
* an error is already in CMPERR; A=0 ends it
PDERX LDA #0
 CLC
 RTS

* ---- PDSET: SET PRINTER / SET PREFIX -------------
PDSET JSR PDNEXT
 BCS PDSTBD
 LDA TOKTYP
 CMP #TKWORD
 BNE PDSTBD
 LDX #SETWT-RELWT
 JSR PFRW1
 BCS PDSTBD
 LDA PFRT
 CMP #SETWT-RELWT
 BEQ PDSPR
 CMP #SETWT-RELWT+8
 BEQ PDSPX
PDSTBD LDA #41
 STA CMPERR
 RTS
* SET PRINTER TO SCREEN | PAPER
PDSPR JSR PDSTO
 BCS PDSTBD
 JSR PDNEXT
 BCS PDSTBD
 LDA TOKTYP
 CMP #TKWORD
 BNE PDSTBD
 LDX #SETWT-RELWT
 JSR PFRW1
 BCS PDSTBD
 LDX #1
 LDA PFRT
 CMP #SETWT-RELWT+15
 BEQ PDSP1
 DEX
 CMP #SETWT-RELWT+22
 BNE PDSTBD
PDSP1 STX PDSTF
 LDA #OSETPR
 JSR EMB
 BCS PDSX
 LDA PDSTF
 JMP EMB
* SET PREFIX n TO literal | item.  n is one digit,
* 0-9: */ is the boot prefix and cannot be set
* (PREFIX.S), and the compiler will not try.
PDSPX JSR PDNEXT
 BCS PDSTBD
 LDA TOKTYP
 CMP #TKNUM
 BNE PDSTBD
 LDA TOKLEN
 CMP #1
 BNE PDSTBD
 LDA TOKBUF
 SEC
 SBC #$30
 CMP #10
 BCS PDSTBD
 STA PDSTF
 JSR PDSTO
 BCS PDSTBD
 JSR PDOPND
 BCS PDSTBD
 LDA PDKIND
 CMP #2
 BCS PDSTBD
 JSR PDSAVE
 LDA #OSETPX
 JSR EMB
 BCS PDSX
 LDA PDSTF
 JSR EMB
 BCS PDSX
 LDA PDSKND
 JSR EMB
 BCS PDSX
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 JMP EMW
PDSX RTS
* PDSTO: the next word must be TO.  C=1 if not.
PDSTO JSR PDNEXT
 BCS PDSTN
 LDA TOKTYP
 CMP #TKWORD
 BNE PDSTN
 JSR PDCONW
 BCS PDSTN
 LDA PFRT
 CMP #CONWT-RELWT
 BNE PDSTN
 CLC
 RTS
PDSTN SEC
 RTS

* ---- PDAMN: ACCEPT item FROM MENU "NAME" ---------
* The FROM and the MENU are in hand, and PDSVAL is
* the item.  NAME.MNU is read NOW, at compile time,
* and its lines become part of the instruction:
*     $8E MENU  item  flags  count  lines...
* so the finished program needs no file to show its
* menu, and a turnkey disk carries nothing extra.
* The .MNU (FORMAT writes it) is laid out as the
* instruction's tail already, after a signature:
*     'MNU1'  flags  count  then per line:
*     row  column  length  the text
* IT IS STREAMED, NOT LOADED (2026-11-11).  It used
* to be loaded whole into a 2K buffer at $9C00, and
* that buffer was what held COMPILE2 below $9C00.
* Now the file is opened and read eighty bytes at a
* time through CPYBUF (COPY's line buffer, free by
* the time a statement is parsed - the book is in
* aux and closed), and each byte goes straight into
* the instruction.  COMPILE2 may now run up to
* OBCODE, $A500: 2.3K more for the PROCEDURE
* DIVISION.  The user's choice over a third pass.
* A name may carry a prefix - "1/MAIN" - like any
* other (FISPLT).  A missing file, or one that is
* not a menu, is error 40.
* its two errors, ahead of it so the branches reach
PDAMB LDA #12
 STA CMPERR
 RTS
PDAMF LDA #40
 STA CMPERR
 RTS
PDAMN JSR PDNEXT
 BCS PDAMB
 LDA TOKTYP
 CMP #TKSTR
 BNE PDAMB
 LDA TOKLEN
 BEQ PDAMB
 CMP #40
 BCS PDAMB
 STA MNNAME
 TAX
PDAM1 LDA TOKBUF-1,X
 STA MNNAME,X
 DEX
 BNE PDAM1
 LDA #<MNNAME
 STA FNAMP
 LDA #>MNNAME
 STA FNAMP+1
 LDA #$4E
 LDX #0
 JSR SETSFX
* open it through IOBUF, with COPY's parameter
* blocks (CMPLEX.S) - not NEWLINE: a menu is bytes,
* and a row of 13 is a Return
 JSR MLI
 DFB $C8
 DA CPOPP
 BCC PDAM1A
 JMP PDAMF
PDAM1A LDA CPOPP+5
 STA CPRDP+1
 STA CPCLP+1
 STZ MNRP
 STZ MNRN
 STZ MNKN
* the signature, 'MNU1'
 STZ MNPOS
PDAM2 JSR MNRB
 BCS PDAM2X
 LDX MNPOS
 CMP MNSIG,X
 BNE PDAM2X
 INC MNPOS
 LDA MNPOS
 CMP #4
 BCC PDAM2
 BRA PDAM2Y
* not a menu: the far end is out of branch reach
PDAM2X JMP PDAMC
PDAM2Y
* the instruction: opcode and item, then the rest
* of the file byte for byte - flags, count, lines
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDA #OMENU
 JSR EMOP1
 BCS PDAMXC
 JSR MNRE
 BCS PDAMXC
 JSR MNRB
 BCS PDAMC
 STA MNLEFT
 JSR EMB
 BCS PDAMXC
* each line: row and column, then its length, then
* the text
PDAM3 LDA MNLEFT
 BEQ PDAMXC
 JSR MNRE
 BCS PDAMXC
 JSR MNRE
 BCS PDAMXC
 JSR MNRB
 BCS PDAMC
 STA MNLEN
 JSR EMB
 BCS PDAMXC
 STZ MNPOS
PDAM4 LDA MNPOS
 CMP MNLEN
 BCS PDAM5
 JSR MNRB
 BCS PDAMC
* Every "x)" key once only, error 42.  FORMAT
* already refuses a second one (FMTMNU.S MNADD),
* but a .MNU can come from anywhere - an older
* FORMAT, another disk, a hand-made file - and the
* running program could not tell two lines with
* one key apart.  A key is the first character of
* a line whose second is ")", upper cased, the
* rule the VM draws by (VMSCRN.S).
 LDX MNPOS
 BNE PDAM4A
 STA MNCH
PDAM4A CPX #1
 BNE PDAM4B
 CMP #$29
 BNE PDAM4B
 JSR MNKEY
 BCS PDAMD
 LDA #$29
PDAM4B JSR EMB
 BCS PDAMXC
 INC MNPOS
 BRA PDAM4
PDAM5 DEC MNLEFT
 BRA PDAM3
* the ends: each closes the file first
PDAMD LDA #42
 STA CMPERR
 BRA PDAMXC
PDAMC JSR MLI
 DFB $CC
 DA CPCLP
 JMP PDAMF
PDAMXC PHP
 JSR MLI
 DFB $CC
 DA CPCLP
 PLP
 RTS

* ---- MNRB: the next byte of the .MNU -> A -------
* C=1 at the end of the file (or a read error)
MNRB LDX MNRP
 CPX MNRN
 BCC MNRB1
 JSR MLI
 DFB $CA
 DA CPRDP
 BCS MNRBX
 LDA CPRDP+6
 STA MNRN
 LDX #0
MNRB1 LDA CPYBUF,X
 INX
 STX MNRP
 CLC
MNRBX RTS
* MNRE: the next byte, emitted.  C=1 if the file
* ended (CMPERR 0) or the code is full (CMPERR set)
MNRE JSR MNRB
 BCC MNRE1
 LDA #40
 STA CMPERR
 SEC
 RTS
MNRE1 JMP EMB

* ---- MNKEY: has MNCH's key been seen?  C=1 if so --
* The keys seen so far are kept in MNKEYS, as many
* as the VM keeps (24).
MNKEY LDA MNCH
 CMP #$61
 BCC MK1
 CMP #$7B
 BCS MK1
 AND #$DF
MK1 LDX MNKN
MK2 DEX
 BMI MK3
 CMP MNKEYS,X
 BNE MK2
 SEC
 RTS
MK3 LDX MNKN
 CPX #24
 BCS MK4
 STA MNKEYS,X
 INC MNKN
MK4 CLC
 RTS

* 'MNU1', as bytes: high bit clear, as FORMAT
* writes it
MNSIG DFB $4D,$4E,$55,$31
MNNAME DS 41
MNLEFT DFB 0
MNLEN DFB 0
* the stream: MNRP the next byte in CPYBUF, MNRN how
* many the last READ gave; MNPOS the place in a
* line or the signature, MNCH a line's first byte
MNRP DFB 0
MNRN DFB 0
MNPOS DFB 0
MNCH DFB 0
* the keys PDAMN has seen, and how many
MNKN DFB 0
MNKEYS DS 24
PDSTF DFB 0
