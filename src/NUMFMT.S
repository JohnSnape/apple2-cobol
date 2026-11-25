* NUMFMT.S  numbers a person can read
* A library module (PUT it from LIB.S).
*
* Turns a 24-bit binary count into digits with
* thousands separators - 5,242,880 rather than
* 5242880 - and puts it on the right-hand end of a
* line.  EDIT uses it for the space remaining,
* CATALOG could use it for a volume total, and
* REPORT will want it for page counts.
*
* This is NOT the PICTURE engine.  PICTURE edits
* packed decimal according to a COBOL clause and
* has currency, sign and zero suppression to think
* about.  This one formats a plain binary byte
* count for a human reading a status line, and the
* two have no code in common.
*
* 24 bits reaches 16,777,215 - comfortably past the
* 5,865,472 bytes that 128 auxiliary banks hold, so
* the counter cannot overflow on any machine this
* system can run on.

* ---- NFCOMMA: NFVAL -> NFBUF, length-prefixed ---
* Repeated subtraction of the powers of ten, which
* is how every number gets out of this machine.
* NFVAL is copied first, so the caller's value
* survives.
*
* A separator goes after the digit at index 1 and
* index 4, but ONLY once a digit has actually been
* printed - otherwise 999 would come out as ,999.
* The leading-zero suppression and the comma rule
* are the same test, which is why they share a
* flag.
NMCOMA LDA NFVAL
 STA NFV
 LDA NFVAL+1
 STA NFV+1
 LDA NFVAL+2
 STA NFV+2
 LDA #0
 STA NFLEN
 STA NFANY
 LDX #0
NFC1 LDA #0
 STA NFDIG
NFC2 SEC
 LDA NFV
 SBC PWLO,X
 STA NFT
 LDA NFV+1
 SBC PWMD,X
 STA NFT+1
 LDA NFV+2
 SBC PWHI,X
 STA NFT+2
 BCC NFC3
 LDA NFT
 STA NFV
 LDA NFT+1
 STA NFV+1
 LDA NFT+2
 STA NFV+2
 INC NFDIG
 JMP NFC2
* This digit is printed if it is not zero, or if
* something has been printed already, or if it is
* the last one - a value of zero still has to show
* a nought.
NFC3 LDA NFDIG
 BNE NFC4
 LDA NFANY
 BNE NFC4
 CPX #7
 BNE NFC6
NFC4 LDA NFDIG
 CLC
 ADC #$30
 JSR NFEMIT
 LDA #1
 STA NFANY
 CPX #1
 BEQ NFC5
 CPX #4
 BNE NFC6
NFC5 LDA #$2C
 JSR NFEMIT
NFC6 INX
 CPX #8
 BCC NFC1
 LDA NFLEN
 STA NFBUF
 RTS

NFEMIT LDY NFLEN
 STA NFBUF+1,Y
 INC NFLEN
 RTS

* the powers of ten, 24 bits each, most significant
* first: 10,000,000 down to 1
PWLO DFB $80,$40,$A0,$10,$E8,$64,$0A,$01
PWMD DFB $96,$42,$86,$27,$03,$00,$00,$00
PWHI DFB $98,$0F,$01,$00,$00,$00,$00,$00

* ---- NFPUTR: STRPTR string, right-justified -----
* in: STRPTR -> length-prefixed string, SCRROW,
*     SCRATR
* Puts the last character in column 80.  A count
* that changes length as it grows would otherwise
* wander across the line every time it crossed a
* power of ten.
NMPUTR LDY #0
 LDA (STRPTR),Y
 STA NFT
 SEC
 LDA #80
 SBC NFT
 BCS NFR1
 LDA #0
NFR1 STA SCRCOL
 JMP PUTS

* ================= VARIABLES ===================
NFV DS 3
NFT DS 3
NFDIG DFB 0
NFANY DFB 0
NFLEN DFB 0
