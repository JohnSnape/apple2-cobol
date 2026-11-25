* AUXMEM.S  records in auxiliary memory, any bank
* A library module (PUT it from LIB.S).
*
* BKFIND counts the banks; this is what makes them
* useful.  It turns a record number into a bank and
* an address, and moves records in and out.
*
* THE GEOMETRY IS CHOSEN SO THE ARITHMETIC IS
* SHIFTS
* Auxiliary memory is not one flat space - it is N
* separate 64K banks, and only one is visible at a
* time.  Turning a record number into a bank means
* dividing, and there is no divide on this machine.
* So we do not divide: the caller declares how many
* records live in a bank as a POWER OF TWO, and the
* division becomes a shift.
*     bank  = record >> AXSHIFT
*     index = record - (bank << AXSHIFT)
* Pick 512 records of 80 bytes and a bank holds
* 40,960 of its 45,824 usable bytes - eleven per
* cent wasted to turn a division into three
* instructions.  That is a bargain, and it is the
* same trade the screen makes with its row table.
*
* EVERY BANK LOOKS THE SAME
* Bank 0 has the two text pages in it, so its
* usable space starts at $0C00.  Banks 1 and up
* have nothing in them at all and could start at
* $0200.  We start every bank at $0C00 anyway.
* Uniformity is worth more than the 2,560 bytes a
* bank: one mapping, no special case for bank 0,
* and no routine that has to ask which bank it is
* working in before it can compute an address.
*
* HOW THE BYTES MOVE
* Through the firmware's AUXMOVE at $C311, with the
* bank selected first.  AUXMOVE lives in ROM, so it
* is immune to the RAMRD instruction-fetch hazard
* that forced the page mover in BANKS.S to be
* copied into every bank; and it moves any length
* between any two addresses, where the page mover
* moves exactly 256 bytes through $0200.
*   Selection and AUXMOVE do compose, which was not
* obvious.  Harvey Brown's 1986 article says
* AUXMOVE "does not work with the extra banks of
* RAM available in cards such as the RAMWORKS", and
* he wrote a whole replacement on the strength of
* it.  What he meant is that AUXMOVE has no bank
* parameter of its own - not that a bank already
* selected at $C073 fails to stay selected across
* the call.  AXTEST wrote and read back all 128
* banks of an eight-megabyte card and every one
* came back distinct.
*   The moral is not that Brown was wrong.  It is
* that a warning about a routine's limits is not
* the same as a statement about what it cannot be
* combined with, and twenty lines of test told us
* which one this was.

* ---- AXCAP: how many records will fit? ---------
* out: AXCAPV = NBANKS << AXSHIFT, saturating
*
* IT SATURATES BECAUSE THE COUNT CAN OVERFLOW
* 128 banks of 512 records is 65,536 - one more
* than a sixteen-bit record number can name.  A
* plain shift would return zero on exactly the
* machine with the most memory in it, and every
* caller would then believe it had no room at all.
* $FFFF is the true answer: the record NUMBER is
* what runs out first, not the memory.
AMCAP LDA NBANKS
 STA AXCAPV
 LDA #0
 STA AXCAPV+1
 LDX AXSHIFT
 BEQ AXCD
AXC1 ASL AXCAPV
 ROL AXCAPV+1
 BCS AXCS
 DEX
 BNE AXC1
AXCD RTS
AXCS LDA #$FF
 STA AXCAPV
 STA AXCAPV+1
 RTS

* ---- AXMAP: AXREC -> AXBANK and AXADDR ---------
* in:  AXREC   record number
*      AXSHIFT log2 of records per bank
*      AXRSZ   record size in bytes
* out: AXBANK, AXADDR
AMMAP LDA AXREC
 STA AXT
 LDA AXREC+1
 STA AXT+1
* bank = record >> AXSHIFT
 LDX AXSHIFT
 BEQ AXM2
AXM1 LSR AXT+1
 ROR AXT
 DEX
 BNE AXM1
AXM2 LDA AXT
 STA AXBANK
* index = record - (bank << AXSHIFT).  Shifting the
* bank back and subtracting costs less than
* building a mask.
 LDA AXBANK
 STA AXT
 LDA #0
 STA AXT+1
 LDX AXSHIFT
 BEQ AXM4
AXM3 ASL AXT
 ROL AXT+1
 DEX
 BNE AXM3
AXM4 SEC
 LDA AXREC
 SBC AXT
 STA AXIDX
 LDA AXREC+1
 SBC AXT+1
 STA AXIDX+1
* address = AXBASE + index * AXRSZ, by shift and
* add - the same long multiplication the decimal
* pack does, in binary and only eight steps deep.
 STZ AXADDR
 STZ AXADDR+1
 LDA AXRSZ
 STA AXM
 LDA AXIDX
 STA AXT
 LDA AXIDX+1
 STA AXT+1
AXM5 LDA AXM
 BEQ AXM7
 LSR AXM
 BCC AXM6
 CLC
 LDA AXADDR
 ADC AXT
 STA AXADDR
 LDA AXADDR+1
 ADC AXT+1
 STA AXADDR+1
AXM6 ASL AXT
 ROL AXT+1
 JMP AXM5
AXM7 CLC
 LDA AXADDR
 ADC #<AXBASE
 STA AXADDR
 LDA AXADDR+1
 ADC #>AXBASE
 STA AXADDR+1
 RTS

* ---- AXSEL / AXSEL0: choose a bank -------------
* Bank 0 goes back on the moment we are done with
* anything else: it is the bank the 80-column
* firmware paints the screen from.
AXSEL LDA AXBANK
 STA BANKSEL
 RTS
AXSEL0 LDA #0
 STA BANKSEL
 RTS

* ---- AXEND: $3E/$3F = last byte of the record ---
* AUXMOVE wants the INCLUSIVE end address, not a
* length.  Getting that wrong moves one byte too
* few and is invisible until a record's last
* character goes missing.
AXEND SEC
 LDA AXLEN
 SBC #1
 STA AXT
 LDA AXLEN+1
 SBC #0
 STA AXT+1
 CLC
 LDA AXADDR
 ADC AXT
 STA $3E
 LDA AXADDR+1
 ADC AXT+1
 STA $3F
 RTS

* ---- AXGET: aux record -> main buffer ----------
* in: AXBANK, AXADDR, AXBUF, AXLEN
AMGET JSR AXSEL
 LDA AXADDR
 STA $3C
 LDA AXADDR+1
 STA $3D
 JSR AXEND
 LDA AXBUF
 STA $42
 LDA AXBUF+1
 STA $43
* AUXMOVE requires 80STORE off, which it always is
* here - the text driver turns it off at startup
* and never turns it back on.  Stated anyway, so
* the routine is correct read on its own.
 STA CLR80S
* CARRY CLEAR = AUXILIARY TO MAIN.
* The carry runs the other way from the way it
* reads: SET moves main to aux, CLEAR moves aux to
* main.  Getting it backwards does not fail loudly
* - it moves the right number of bytes in the wrong
* direction, so a read silently leaves the buffer
* untouched and a write silently destroys whatever
* was at the destination.
 CLC
 JSR AUXMOVE
 JMP AXSEL0

* ---- AXPUT: main buffer -> aux record ----------
AMPUT JSR AXSEL
 LDA AXBUF
 STA $3C
 LDA AXBUF+1
 STA $3D
 SEC
 LDA AXLEN
 SBC #1
 STA AXT
 LDA AXLEN+1
 SBC #0
 STA AXT+1
 CLC
 LDA AXBUF
 ADC AXT
 STA $3E
 LDA AXBUF+1
 ADC AXT+1
 STA $3F
 LDA AXADDR
 STA $42
 LDA AXADDR+1
 STA $43
 STA CLR80S
* carry SET = main to auxiliary
 SEC
 JSR AUXMOVE
 JMP AXSEL0

* ---- AMFREE: how many bytes are left? ----------
* in:  AXCAPV total records (from AMCAP)
*      AXUSED records in use
*      AXRSZ  bytes a record
* out: AXFREE, 24 bits
*
* Multiplying a 16-bit record count by a byte gives
* 24 bits, which is why the counter is three bytes
* wide: 128 banks of 512 records at 80 bytes is
* 5,242,880, and sixteen bits would have run out
* somewhere around the second bank.
AMFRE SEC
 LDA AXCAPV
 SBC AXUSED
 STA AXP
 LDA AXCAPV+1
 SBC AXUSED+1
 STA AXP+1
 BCS AMF1
* more used than exist: report nothing left rather
* than an enormous number
 LDA #0
 STA AXP
 STA AXP+1
AMF1 LDA #0
 STA AXP+2
 STA AXFREE
 STA AXFREE+1
 STA AXFREE+2
 LDA AXRSZ
 STA AXM
AMF2 LDA AXM
 BEQ AMF4
 LSR AXM
 BCC AMF3
 CLC
 LDA AXFREE
 ADC AXP
 STA AXFREE
 LDA AXFREE+1
 ADC AXP+1
 STA AXFREE+1
 LDA AXFREE+2
 ADC AXP+2
 STA AXFREE+2
AMF3 ASL AXP
 ROL AXP+1
 ROL AXP+2
 JMP AMF2
AMF4 RTS

* ================= VARIABLES ===================
AXT DS 2
AXM DFB 0
AXIDX DS 2
AXP DS 3
