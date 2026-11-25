* SYSLOAD.S  library/overlay loading, prefix
* PUT from COBOLSYS.S - no ORG, not assembled
* alone.  One symbol table spans every PUT.
*
* === FILE LOADING ===
* --- LOADF: load a whole file.
* in:  LDNAME -> length-prefixed pathname
*      LDADDR = load address
*      LDLEN  = maximum bytes to read
* out: C=1 on any MLI error, code in A.
* One routine serves the library and every
* overlay; only the three inputs differ.
LOADF LDA LDNAME
 STA OPARM+1
 LDA LDNAME+1
 STA OPARM+2
* the system's files come from */ whatever 0/ is
* (TOSYS, SYSUTIL.S): the prefix is */ for the OPEN
* and back to 0/ straight after it
 JSR TOSYS
 JSR OPENF
 PHP
 PHA
 JSR TOWRK
 PLA
 PLP
 BCS LFDN
 LDA OPARM+5
 STA RWPARM+1
 STA CLPARM+1
 LDA LDADDR
 STA RWPARM+2
 LDA LDADDR+1
 STA RWPARM+3
 LDA LDLEN
 STA RWPARM+4
 LDA LDLEN+1
 STA RWPARM+5
 JSR READF
 PHP
 JSR CLOSEF
 PLP
LFDN RTS

* --- LOADLIB: COBOL.LIB -> LIBBASE ---
LOADLIB LDA #<LIBNAM
 STA LDNAME
 LDA #>LIBNAM
 STA LDNAME+1
 LDA #<LIBBASE
 STA LDADDR
 LDA #>LIBBASE
 STA LDADDR+1
 LDA #<LIBLEN
 STA LDLEN
 LDA #>LIBLEN
 STA LDLEN+1
 JMP LOADF

* --- LOADOVL: LDNAME -> the overlay band --------
* --- LOADAUX: COBOL.AUX -> the aux language card --
* Read into the overlay band, which is empty at
* boot, then copied up a page at a time with ALTZP
* on and the card's RAM bank 2 write-enabled -
* $C081 read twice is the switch.  The ROM stays
* readable throughout, and this loop runs from
* $2000, so nothing it executes moves under it.
* ZPT1/ZPT2 here are the AUXILIARY zero page's:
* they are set after the switch and used only
* before the switch back.  The stack is not touched
* in between, which is why the PHP and PLP are
* outside.  out: C=1 if the file could not be read
LOADAUX LDA #<AUXNAM
 STA LDNAME
 LDA #>AUXNAM
 STA LDNAME+1
 LDA #<OVLBASE
 STA LDADDR
 LDA #>OVLBASE
 STA LDADDR+1
 LDA #<AUXMAX
 STA LDLEN
 LDA #>AUXMAX
 STA LDLEN+1
 JSR LOADF
 BCS LAXX
* whole pages: the count read, rounded up
 LDX RWPARM+7
 LDA RWPARM+6
 BEQ LAX0
 INX
LAX0 PHP
 SEI
 STA ALTZPON
 BIT LCWR2
 BIT LCWR2
 LDA #<OVLBASE
 STA ZPT1
 LDA #>OVLBASE
 STA ZPT1+1
 LDA #<AUXBASE
 STA ZPT2
 LDA #>AUXBASE
 STA ZPT2+1
 LDY #0
LAX1 LDA (ZPT1),Y
 STA (ZPT2),Y
 INY
 BNE LAX1
 INC ZPT1+1
 INC ZPT2+1
 DEX
 BNE LAX1
 BIT ROMIN2
 STA ALTZPOFF
 PLP
 CLC
LAXX RTS

LOADOVL LDA #<OVLBASE
 STA LDADDR
 LDA #>OVLBASE
 STA LDADDR+1
 LDA #<OVLMAX
 STA LDLEN
 LDA #>OVLMAX
 STA LDLEN+1
 JMP LOADF

