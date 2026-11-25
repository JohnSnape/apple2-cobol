* DATIME.S  the date and the clock
* A library module (PUT it from LIB.S).
*
* ProDOS stamps every file it creates from four
* bytes in its own global page:
*
*   $BF90-$BF91  date:  yyyyyyym mmmddddd
*   $BF92        minute (0-59)
*   $BF93        hour   (0-23)
*
* On every CREATE and every close of a written file
* it calls its CLOCK routine at $BF06 to refresh
* them, and then stamps the directory entry from
* what it finds.
*
* WHY FILES COME OUT WITH NO DATE
* MACHID bit 0 says whether ProDOS believes there is
* a clock.  With it clear, the CLOCK vector is a
* plain RTS - ProDOS calls it, nothing happens, and
* the four bytes keep whatever they held.  From a
* cold boot that is zero, and a zero date is what a
* catalog prints as <NO DATE>.
*
* AND WHY THAT IS EASY TO FIX
* The routine does nothing; it does not CLEAR them.
* So writing the four bytes ONCE, at startup, gives
* every file created afterwards a correct stamp -
* for as long as the machine stays up.  That is the
* whole trick, and it is what a good deal of
* ProDOS-era software did.
*
* IT DOES NOT TICK.  There is no time base here to
* advance it with, so every file made in a session
* carries the minute the operator typed.  Saying so
* is better than a clock that is wrong by hours and
* looks right.  A real clock card, when ProDOS knows
* about it, is refreshed by ProDOS on every call and
* this module then does nothing at all.

* ---- DTHASC: is there a clock? ------------------
* out: C=1 if ProDOS believes there is one
* MACHID bit 0.  This is what ProDOS itself tests
* before calling its clock routine, so it is the
* same question and the same answer.
DTHASC LDA MACHID
 AND #1
 BEQ DTHNO
 SEC
 RTS
DTHNO CLC
 RTS

* ---- DTSETC: DTY DTM DTD DTHH DTMM -> the globals
* in:  DTY  years since 1900 (77 = 1977)
*      DTM  1-12, DTD 1-31, DTHH 0-23, DTMM 0-59
*
* The date is packed and the packing is the awkward
* part: seven bits of year, four of month and five
* of day into sixteen bits, with the month split
* across the byte boundary.
*   high = yyyyyyym    low = mmmddddd
* So the high byte is the year shifted up one with
* the month's top bit underneath it, and the low
* byte is the month's bottom three bits shifted up
* five with the day beneath.
DTSETC LDA DTM
 LSR
 LSR
 LSR
 STA DTT
 LDA DTY
 ASL
 ORA DTT
 STA DATELO+1
 LDA DTM
 AND #7
 ASL
 ASL
 ASL
 ASL
 ASL
 ORA DTD
 STA DATELO
 LDA DTMM
 STA TIMELO
 LDA DTHH
 STA TIMELO+1
 RTS

* ---- DTDATC: COBOL ACCEPT ... FROM DATE ---------
* out: DTBUF = six digits, YYMMDD
* Unpacks what DTSETC packed, which is also what a
* real clock card leaves there - so this works the
* same whether the time came from hardware or from
* the operator.
* DTIX from 0: it was never set here, so the digits
* landed wherever the last call left it (found
* 2026-11-08 by ACCEPT FROM DATE)
DTDATC STZ DTIX
 LDA DATELO+1
 LSR
 STA DTT
 JSR DT2D
 LDA DATELO+1
 AND #1
 ASL
 ASL
 ASL
 STA DTT2
 LDA DATELO
 ROL
 ROL
 ROL
 ROL
 AND #7
 ORA DTT2
 STA DTT
 JSR DT2D
 LDA DATELO
 AND #$1F
 STA DTT
 JSR DT2D
 RTS

* ---- DTTIMC: COBOL ACCEPT ... FROM TIME ---------
* out: DTBUF = eight digits, HHMMSSss
* There are no seconds and no hundredths in the
* ProDOS globals, so both come back as zeros rather
* than as something invented.  A program that prints
* the time gets 14:32:00.00, which is honest.
DTTIMC LDA #0
 STA DTIX
 LDA TIMELO+1
 STA DTT
 JSR DT2D
 LDA TIMELO
 STA DTT
 JSR DT2D
 LDA #0
 STA DTT
 JSR DT2D
 LDA #0
 STA DTT
 JMP DT2D

* ---- DT2D: DTT (0-99) -> two digits in DTBUF ----
DT2D LDA #$30
 STA DTT2
DT2D1 LDA DTT
 CMP #10
 BCC DT2D2
 SEC
 SBC #10
 STA DTT
 INC DTT2
 JMP DT2D1
DT2D2 LDX DTIX
 LDA DTT2
 STA DTBUF,X
 INX
 LDA DTT
 CLC
 ADC #$30
 STA DTBUF,X
 INX
 STX DTIX
 RTS

* ================= VARIABLES ===================
DTT DFB 0
DTT2 DFB 0

* ---- DTMDY: the date as M/D/YYYY ---------------
* out: DTBUF = a length-prefixed string, ready for
*      PUTS or NFPUTR
* The form a person writes, not the form a file
* sorts: 8/15/2026 and not 260815.  DTDATC above is
* the other one and they are both wanted.
*
* THE MONTH IS FOUR BITS SPLIT ACROSS TWO BYTES, and
* this is the idiom every ProDOS clock driver uses
* for it: shift the high byte's bit 0 into carry,
* then let four ROLs of the low byte collect all
* four bits at once.  Doing it as two maskings and
* an ORA works too and takes twice the code.
*
* THE CENTURY IS A GUESS, AND ALWAYS WAS.  ProDOS
* gives seven bits of year and no century at all, so
* every program on the platform has to decide, and
* the convention they all settled on is 0-39 = 20xx
* and 40-99 = 19xx.  We follow it because a disk
* written by anything else follows it too.
DTMDY LDA #1
 STA DTIX
 LDA DATELO+1
 LSR
 LDA DATELO
 ROL
 ROL
 ROL
 ROL
 AND #$0F
 STA DTT
 JSR DTNUM
 LDA #$2F
 JSR DTPUT
 LDA DATELO
 AND #$1F
 STA DTT
 JSR DTNUM
 LDA #$2F
 JSR DTPUT
 LDA DATELO+1
 LSR
 STA DTT
 CMP #40
 BCS DTM19
 LDA #$32
 JSR DTPUT
 LDA #$30
 JSR DTPUT
 JMP DTM2
DTM19 LDA #$31
 JSR DTPUT
 LDA #$39
 JSR DTPUT
DTM2 JSR DT2DX
 LDA DTIX
 SEC
 SBC #1
 STA DTBUF
 RTS

* ---- DTPUT: append A to DTBUF ------------------
DTPUT LDX DTIX
 STA DTBUF,X
 INC DTIX
 RTS

* ---- DTNUM: DTT as 1 or 2 digits ---------------
* No leading zero, because 8/15 reads better than
* 08/15 on a line somebody looks at all day.
DTNUM LDA DTT
 CMP #10
 BCC DTN1
 JMP DT2DX
DTN1 CLC
 ADC #$30
 JMP DTPUT

* ---- DT2DX: DTT as exactly two digits ----------
DT2DX LDA #$30
 STA DTT2
DT2X1 LDA DTT
 CMP #10
 BCC DT2X2
 SEC
 SBC #10
 STA DTT
 INC DTT2
 JMP DT2X1
DT2X2 LDA DTT2
 JSR DTPUT
 LDA DTT
 CLC
 ADC #$30
 JMP DTPUT
