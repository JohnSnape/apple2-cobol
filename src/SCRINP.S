* SCRINP.S  full-screen field editor
* LIBRARY MODULE - slot 101, vector FRMACC.
* The ACCEPT verb's engine.  Moved into the library
* 2026-08-23 with SCRSHOW, for the reason given in
* RUNTIME.md 2: a PUT module's entry point moves
* with its host and compiled p-code cannot call a
* moving address.
* Needs SCRSHOW to have painted the form first.
* Set ZPDICT -> dict, ZPREC -> record buffer, then
* JSR FRMACC.  Returns the terminator in A - 1 ESC,
* 2 command chord - and does not use a shared
* variable to do it, because a compiled program is
* a separate assembly and cannot name TERM.
* TAB/RETURN = next field (DCT order, wraps),
* ESC = done, backspace = erase.
* Field types: 0 ALPHA 1 ALNUM 2 NUM 3 BOOL.
* Storage: ALPHA/ALNUM left-just space-pad;
* NUM and BOOL are NUM8 cells, eight bytes - the
* layout a COBOL record has, since a program's
* numeric items are cells (DICTIONARY.md 3).  A
* BOOL is the cell 1 for Y and 0 for N.
* The local FTYPE was renamed SIFTYP: EQUATES has
* FTYPE EQU $0CCB, the file-type parameter, and
* every program PUTs EQUATES first.

* zero page now in EQUATES.S - PUT it first

* ---- SCRINP: main entry ----
SCRINP LDY #8
 LDA (ZPDICT),Y
 STA NFLDS
 LDA #0
 STA CURFLD
SIIN LDA CURFLD
 CMP NFLDS
 BCS SIRUN
 JSR GETFLD
 LDA #0
 STA INLEN
 JSR PACK
 INC CURFLD
 JMP SIIN
SIRUN LDA #0
 STA CURFLD
SILP JSR GETFLD
 JSR UNPACK
 JSR EDITFLD
 JSR PACK
 LDA TERM
 BNE SIDN
 INC CURFLD
 LDA CURFLD
 CMP NFLDS
 BCC SILP
 LDA #0
 STA CURFLD
 JMP SILP
SIDN LDA TERM
 RTS

* ---- GETFLD: CURFLD -> FLDPTR, attrs, RECP ----
* CURFLD * 24 is a SIXTEEN-bit number.  A descriptor
* is 24 bytes, so field 11 sits at offset 264 and
* the eighth bit of the product is real.  This used
* to compute the product into a one-byte FOFF and
* then add it in with ADC #0 for the high half, so
* every field past the tenth indexed the wrong
* descriptor - silently, because 264 AND $FF is 8,
* which is a perfectly plausible offset.  SCRSHOW
* never had the bug: it walks the array with a
* running pointer and adds 24 each time round,
* which carries by itself.
GETFLD LDA #0
 STA FOFF+1
 LDA CURFLD
 ASL
 ROL FOFF+1
 CLC
 ADC CURFLD
 STA FOFF
 LDA FOFF+1
 ADC #0
 STA FOFF+1
 ASL FOFF
 ROL FOFF+1
 ASL FOFF
 ROL FOFF+1
 ASL FOFF
 ROL FOFF+1
 LDY #12
 LDA (ZPDICT),Y
 CLC
 ADC FOFF
 STA FLDPTR
 LDY #13
 LDA (ZPDICT),Y
 ADC FOFF+1
 STA FLDPTR+1
 CLC
 LDA FLDPTR
 ADC ZPDICT
 STA FLDPTR
 LDA FLDPTR+1
 ADC ZPDICT+1
 STA FLDPTR+1
 LDY #16
 LDA (FLDPTR),Y
 STA FROW
 LDY #17
 LDA (FLDPTR),Y
 STA FCOL
 LDY #11
 LDA (FLDPTR),Y
 STA FWID
 LDY #10
 LDA (FLDPTR),Y
 STA SIFTYP
 LDY #19
 LDA (FLDPTR),Y
 STA FFLAGS
 LDY #13
 LDA (FLDPTR),Y
 STA FROFF
 LDY #14
 LDA (FLDPTR),Y
 STA FROFF+1
 CLC
 LDA ZPREC
 ADC FROFF
 STA RECP
 LDA ZPREC+1
 ADC FROFF+1
 STA RECP+1
 RTS

* ---- PACK: INBUF/INLEN -> record at RECP ----
PACK LDA SIFTYP
 CMP #3
 BEQ PKBL
 CMP #2
 BEQ PKNM
 LDY #0
PKT1 CPY INLEN
 BCS PKT2
 LDA INBUF,Y
 STA (RECP),Y
 INY
 JMP PKT1
PKT2 CPY FWID
 BCS PKTD
 LDA #$20
 STA (RECP),Y
 INY
 JMP PKT2
PKTD RTS
* INLEN sits directly in front of INBUF, so the
* two together are the length-prefixed string
* PICDEED reads.  The field's decimals are the
* cell's scale.
PKNM LDA #<INLEN
 STA ZPT1
 LDA #>INLEN
 STA ZPT1+1
 LDA RECP
 STA ZPT2
 LDA RECP+1
 STA ZPT2+1
 LDY #12
 LDA (FLDPTR),Y
 STA PICSCL
 JMP PIDEED
PKBL LDA #0
 STA TMPB
 LDA INLEN
 BEQ PKB1
 LDA INBUF
 CMP #$59
 BNE PKB1
 LDA #1
 STA TMPB
PKB1 LDY #0
 TYA
PKB2 STA (RECP),Y
 INY
 CPY #NCELL-1
 BCC PKB2
 LDA TMPB
 STA (RECP),Y
 RTS

* ---- UNPACK: record at RECP -> INBUF/INLEN ----
UNPACK LDA SIFTYP
 CMP #3
 BEQ UNBL
 CMP #2
 BEQ UNNM
 LDY #0
UNT1 CPY FWID
 BCS UNT2
 LDA (RECP),Y
 STA INBUF,Y
 INY
 JMP UNT1
UNT2 LDX FWID
UNT3 CPX #0
 BEQ UNT4
 LDA INBUF-1,X
 CMP #$20
 BNE UNT4
 DEX
 JMP UNT3
UNT4 STX INLEN
 RTS
* the cell's fourteen digits, leading zeros
* dropped - which is what the operator typed
UNNM LDA RECP
 STA ZPT2
 LDA RECP+1
 STA ZPT2+1
 LDX #0
 STX INLEN
UNN1 JSR NGETD
 LDY INLEN
 BNE UNN2
 CMP #0
 BEQ UNN3
UNN2 ORA #$30
 STA INBUF,Y
 INC INLEN
UNN3 INX
 CPX #NDIG
 BCC UNN1
 RTS
UNBL LDY #NCELL-1
 LDA (RECP),Y
 BEQ UNB1
 LDA #$59
 JMP UNB2
UNB1 LDA #$4E
UNB2 STA INBUF
 LDA #1
 STA INLEN
 RTS

* ---- DRAWFLD: paint field from INBUF ----
DRAWFLD LDX FROW
 JSR SCRADDR
 LDA #1
 STA SCRATR
 LDA FCOL
 STA SCRCOL
 LDA #0
 STA DFI
DF1 LDA DFI
 CMP FWID
 BCS DFD
 CMP INLEN
 BCS DFBL
 LDX DFI
 LDA INBUF,X
 JSR CONV
 JSR PUTC
 JMP DFNX
DFBL LDA #$20
 JSR PUTC
DFNX INC DFI
 JMP DF1
DFD RTS

* ---- VALIDCH: A=char, SIFTYP -> C=1 accept ----
VALIDCH LDX SIFTYP
 CPX #1
 BEQ VCOK
 CPX #2
 BEQ VCNM
 CMP #$20
 BEQ VCOK
 CMP #$41
 BCC VCNO
 CMP #$5B
 BCC VCOK
 CMP #$61
 BCC VCNO
 CMP #$7B
 BCC VCOK
 JMP VCNO
VCNM CMP #$30
 BCC VCNO
 CMP #$3A
 BCC VCOK
VCNO CLC
 RTS
VCOK SEC
 RTS

* ---- EDITFLD: edit one field, sets TERM ----
EDITFLD JSR DRAWFLD
EF2 JSR GETKEYC
 JSR KEYCHRD
 BCC EF3
 JMP EFCM
EF3 AND #$7F
 CMP #$09
 BEQ EFNX
 CMP #$0D
 BEQ EFNX
 CMP #$1B
 BEQ EFDN
 CMP #$08
 BEQ EFBS
 CMP #$20
 BCC EF2
* The key is seven bits by now, so the only code
* left at $7F or above is $7F itself - DELETE.
* This line used to be BCS EF2, which threw
* it away; now it erases, the same as the left
* arrow, as it does in EDIT.  The //e's DELETE
* key is where a typist reaches to fix a slip.
* Same size, so nothing moves (user, 2026-11-24)
 CMP #$7F
 BEQ EFBS
 LDX SIFTYP
 CPX #3
 BEQ EFBO
 JSR VALIDCH
 BCC EF2
 LDX INLEN
 CPX FWID
 BCS EF2
 STA INBUF,X
 INC INLEN
 JMP EDITFLD
EFBS LDA INLEN
 BEQ EF2
 DEC INLEN
 JMP EDITFLD
EFBO CMP #$59
 BEQ EFBY
 CMP #$79
 BEQ EFBY
 CMP #$4E
 BEQ EFBN
 CMP #$6E
 BEQ EFBN
 JMP EF2
EFBY LDA #$59
 STA INBUF
 LDA #1
 STA INLEN
 JMP EDITFLD
EFBN LDA #$4E
 STA INBUF
 LDA #1
 STA INLEN
 JMP EDITFLD
EFNX LDA #0
 STA TERM
 LDA #$30
 JMP KEYDONE
EFDN LDA #1
 STA TERM
 LDA #$31
 JMP KEYDONE
* TERM 2 is new: the operator pressed a command
* chord.  SCRINP's caller loop tests TERM for
* non-zero to stop, so a chord stops the form the
* same way ESC does, and KEYTERM says which it was.
EFCM LDA #2
 STA TERM
 RTS

* ---- GETKEYC: blink cursor, return key in A ----
GETKEYC LDX FROW
 JSR SCRADDR
 LDA INLEN
 CMP FWID
 BCS GKNC
 CLC
 ADC FCOL
 STA CCOL
GKC2 LDA #$20
 JSR PUTAT
 JSR GKWAIT
 BCS GKCK
 LDA #$A0
 JSR PUTAT
 JSR GKWAIT
 BCC GKC2
GKCK PHA
 LDA #$20
 JSR PUTAT
 PLA
 RTS
GKNC JSR GKWAIT
 BCC GKNC
 RTS

* ---- GKWAIT: delay+poll; C=1 A=key or C=0 ----
* This is where the operator actually spends their
* time - sitting in a field with the cursor
* blinking - so this loop carries RNDSEED too.
* The counter costs about eight cycles an
* iteration, which would have halved the blink
* rate, so the outer count drops from $60 to $30
* to keep the blink where it was.
GKWAIT LDX #$30
GKW1 LDY #0
GKW2 LDA KBD
 BMI GKWK
 INC RNDSEED
 BNE GKW3
 INC RNDSEED+1
 BNE GKW3
 INC RNDSEED+2
 BNE GKW3
 INC RNDSEED+3
GKW3 DEY
 BNE GKW2
 DEX
 BNE GKW1
 CLC
 RTS
GKWK JSR READMOD
 BIT KBDSTRB
 SEC
 RTS

* ---- HEXCH: nibble in A -> ascii hex ----
HEXCH CMP #10
 BCC HXC1
 CLC
 ADC #$37
 RTS
HXC1 CLC
 ADC #$30
 RTS

* ---- HEXDUMP: HDLEN bytes at ZPREC as hex ----
HEXDUMP LDA #12
 STA HROW
 LDX HROW
 JSR SCRADDR
 LDA #0
 STA SCRCOL
 STA SCRATR
 STA HIDX
HD1 LDA HIDX
 CMP HDLEN
 BCS HDD
 LDY HIDX
 LDA (ZPREC),Y
 STA HBYTE
 LSR
 LSR
 LSR
 LSR
 JSR HEXCH
 JSR CONV
 JSR PUTC
 LDA HBYTE
 AND #$0F
 JSR HEXCH
 JSR CONV
 JSR PUTC
 LDA #$20
 JSR CONV
 JSR PUTC
 INC HIDX
 LDA SCRCOL
 CMP #75
 BCC HD1
 INC HROW
 LDX HROW
 JSR SCRADDR
 LDA #0
 STA SCRCOL
 JMP HD1
HDD RTS

* ---- variables ----
FROW DFB 0
FCOL DFB 0
FWID DFB 0
SIFTYP DFB 0
FFLAGS DFB 0
FROFF DS 2
CURFLD DFB 0
NFLDS DFB 0
FOFF DS 2
DFI DFB 0
NPAD DFB 0
NFILL DFB 0
TMPB DFB 0
TERM DFB 0
HROW DFB 0
HIDX DFB 0
HBYTE DFB 0
HDLEN DFB 0
* INLEN MUST STAY HERE, the byte before INBUF -
* PKNM hands the pair to PICDEED as one string
INLEN DFB 0
INBUF DS 40
