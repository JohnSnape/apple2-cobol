* SYMAUX.S  the compiler's symbol table, in the
* auxiliary language card
* PUT from AUXLC.S, after PREFIX - no ORG, not
* assembled alone.  Written 2026-11-11.
*
* WHY IT MOVED.  A name exists only while a program
* is compiled: the finished program reaches every
* item by its number, and no name is in the object.
* So the table is pure compile-time scratch, and the
* only question is where there is room for it.  It
* used to be 1K at $1000 - sixty-four names of ten
* characters, sixteen bytes an entry - because that
* was the one kilobyte free to both compiler passes.
* The user asked for longer names (2026-11-11), and
* the aux card has room that main memory does not.
*
* NAMES OF UP TO THIRTY CHARACTERS, the COBOL
* standard's limit, and 128 of them.  A longer name
* is refused when it is declared (error 48) rather
* than cut short, and a longer name in a statement
* is simply not found (error 15), so no two
* different names can ever meet in their first
* thirty characters and quietly become one.
*
* THE TABLE IS IN TWO PIECES.
* - The names, 128 of 30 bytes, space padded, in
*   the card's OTHER $D000 bank (bank 1), 3,840
*   bytes nothing else uses.  COBOL.AUX itself is in
*   bank 2, which is why this code has to sit above
*   $E000, in the part of the card that does not
*   switch: code at $D000-$DFFF would vanish the
*   moment bank 1 came in.  check.js holds SYMAUX
*   above $E000.
* - Everything else about a name, in five arrays of
*   128 bytes beside this code: the kind, the value
*   and the chain, low and high bytes apart, so the
*   index is just X with no multiply at all.
*
* THE CALL is LIB slot 108, SYMSVC, through the gate
* (GATE.S entry 25).  X says what to do:
*   0 INIT  empty the table
*   1 FIND  ZPT2 -> the name, Y = its length
*           out: C=0 found, A = its index
*                C=1 not, A = NSYMS
*   2 ADD   A = kind, ZPT2 -> name, Y = length
*           out: C=0, A = the new index (value 0,
*                chain $FFFF, the empty chain)
*                C=1, A = 4 duplicate, 5 full,
*                48 longer than thirty
*   3 GET   Y = index -> A = kind, ZPT2 = value
*   4 PUT   Y = index, ZPT2 = value
*   5 CHG   Y = index -> ZPT2 = chain
*   6 CHS   Y = index, ZPT2 = chain
* ZPT1 is never touched, so a caller's pointer there
* survives - the gate carries it both ways.  The
* name is read where it lies, in main memory: the
* card swaps zero page, the stack and $D000-$FFFF,
* and leaves $0200-$BFFF main for reading.  NSYMS,
* the count, stays in main too ($1F09, CMPXFR), so
* the passes can walk the table as before.
SYMAX EQU 128
SYNL EQU 30
SYNAME EQU $D000

SYAUX STA SYK
 TXA
 ASL
 TAX
 LDA SYK
 JMP (SYTAB,X)
SYTAB DA SYINI,SYFND,SYADD,SYGET,SYPUT
 DA SYCGT,SYCPT

SYINI STZ NSYMS
 CLC
 RTS

* ---- FIND ---------------------------------------
* Linear, as before: 128 names is still nothing,
* and each try costs a thirty-byte compare at most.
SYFND STY SYLEN
 LDA SYLEN
 CMP #SYNL+1
 BCS SYFNX
 JSR SYB1
 STZ SYI
SYF1 LDA SYI
 CMP NSYMS
 BCS SYFNO
 JSR SYNP
 JSR SYCMP
 BCC SYFOK
 INC SYI
 BRA SYF1
SYFOK JSR SYB2
 LDA SYI
 CLC
 RTS
SYFNO JSR SYB2
SYFNX LDA NSYMS
 SEC
 RTS

* ---- SYCMP: does (ZPWORK) hold the name? -------
* out: C=0 if it matches.  The stored name is space
* padded to thirty, so a shorter name matches only
* if the rest is spaces - which stops N matching
* NAME.
SYCMP LDY #0
SYC1 CPY #SYNL
 BCS SYCY
 CPY SYLEN
 BCS SYC2
 LDA (ZPT2),Y
 BRA SYC3
SYC2 LDA #$20
SYC3 CMP (ZPWORK),Y
 BNE SYCN
 INY
 BRA SYC1
SYCY CLC
 RTS
SYCN SEC
 RTS

* ---- ADD ----------------------------------------
SYADD STY SYLEN
 LDA SYLEN
 CMP #SYNL+1
 BCC SYA0
 LDA #48
 SEC
 RTS
SYA0 JSR SYFND
 BCS SYA1
 LDA #4
 SEC
 RTS
SYA1 LDA NSYMS
 CMP #SYMAX
 BCC SYA2
 LDA #5
 SEC
 RTS
SYA2 STA SYI
 JSR SYB1
 JSR SYNP
 LDY #0
SYA3 CPY #SYNL
 BCS SYA6
 CPY SYLEN
 BCS SYA4
 LDA (ZPT2),Y
 BRA SYA5
SYA4 LDA #$20
SYA5 STA (ZPWORK),Y
 INY
 BRA SYA3
SYA6 JSR SYB2
 LDX SYI
 LDA SYK
 STA SYKND,X
 STZ SYVLO,X
 STZ SYVHI,X
* $FFFF is the empty fixup chain (EMFIX)
 LDA #$FF
 STA SYCLO,X
 STA SYCHI,X
 INC NSYMS
 TXA
 CLC
 RTS

* ---- GET PUT CHG CHS: Y = the index ------------
SYGET LDA SYVLO,Y
 STA ZPT2
 LDA SYVHI,Y
 STA ZPT2+1
 LDA SYKND,Y
 CLC
 RTS
SYPUT LDA ZPT2
 STA SYVLO,Y
 LDA ZPT2+1
 STA SYVHI,Y
 CLC
 RTS
SYCGT LDA SYCLO,Y
 STA ZPT2
 LDA SYCHI,Y
 STA ZPT2+1
 CLC
 RTS
SYCPT LDA ZPT2
 STA SYCLO,Y
 LDA ZPT2+1
 STA SYCHI,Y
 CLC
 RTS

* ---- SYNP: ZPWORK = SYNAME + 30 * SYI ----------
* 30i is 32i - 2i: double it, keep that, four more
* doublings, take the kept one off.  ZPWORK is
* this card's own zero page, which the gate leaves
* alone, so it is free scratch here.
SYNP LDA SYI
 STA SYT
 STZ SYT+1
 ASL SYT
 ROL SYT+1
 LDA SYT
 STA ZPWORK
 LDA SYT+1
 STA ZPWORK+1
 LDX #4
SYN1 ASL ZPWORK
 ROL ZPWORK+1
 DEX
 BNE SYN1
 SEC
 LDA ZPWORK
 SBC SYT
 STA ZPWORK
 LDA ZPWORK+1
 SBC SYT+1
 CLC
 ADC #>SYNAME
 STA ZPWORK+1
 RTS

* ---- SYB1 / SYB2: the card's $D000 bank --------
* Two reads each, as the card wants for writing.
* The gate went in with bank 2 and puts the ROM
* back on the way out; these only swap the bank
* under $E000 while the names are being read.
SYB1 BIT RWRAM1
 BIT RWRAM1
 RTS
SYB2 BIT LCRW2
 BIT LCRW2
 RTS

* ---- variables, beside the code ----------------
SYK DFB 0
SYLEN DFB 0
SYI DFB 0
SYT DA 0
SYKND DS SYMAX
SYVLO DS SYMAX
SYVHI DS SYMAX
SYCLO DS SYMAX
SYCHI DS SYMAX
