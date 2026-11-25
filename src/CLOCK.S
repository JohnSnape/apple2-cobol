* CLOCK.S  find a clock, or ask for the time
* A library module (PUT it from LIB.S).
*
* Ported from the a2stuff No-Slot Clock driver by
* "CAP", 1991, and its set.datetime companion.  The
* originals are ca65; this is Merlin 8 and it drops
* what we do not need.
*
* THE PROBLEM, STATED PROPERLY
* ProDOS stamps a file from four bytes in its global
* page, and it refreshes them by calling whatever is
* at DATETIME ($BF06) - but ONLY if MACHID bit 0
* says a clock exists.  With that bit clear the
* vector is a plain RTS, nothing refreshes, and
* every file is created <NO DATE>.
*
* So there are exactly two ways to get dated files,
* and this module does both:
*   1  find a real clock, install a driver at
*      DATETIME, and set MACHID bit 0.  ProDOS then
*      stamps every file for the rest of the
*      session, and keeps doing it after a QUIT.
*   2  failing that, ask the operator once and write
*      the four bytes.  ProDOS's null routine does
*      not CLEAR them, so every file made afterwards
*      carries that stamp.  It does not tick.
*
* A PROBE TABLE, NOT A DRIVER
* CLKFIN walks CLKTAB, and each entry is a detect
* routine.  The first that validates wins.  That is
* the same shape a2stuff's own "jumbo" build has -
* the JUMBO_CLOCK_DRIVER conditional in the source
* this was ported from is exactly that - and it is
* why adding a second make of clock is a table entry
* and forty bytes, not a rewrite.  Today the table
* has one entry.
*
* WHAT WAS LEFT OUT, AND THE RISK
* The original probes every slot and, before poking
* each one, checks for a Z80 SoftCard - because
* writing to a Z80 card's ROM space hands the
* machine to the Z80 and it does not come back.
* That detection is sixty lines of swapping code in
* and out of $0FFD and it is omitted here.
*   The consequence is real and narrow: ON A MACHINE
* WITH A Z80 CARD, DO NOT LET THE SCAN RUN.  CLKSLOT
* is the way out - set it to the slot the clock is
* in and only that slot is probed; set it to zero
* and the scan is skipped entirely and the operator
* is asked instead.

* ---- CLKFIN: is there a clock? ----------------
* out: C=0 if ProDOS now has one
CLKFIN LDA MACHID
 AND #1
 BEQ CLKF1
* ProDOS already believes in a clock - either a card
* it knows or a driver somebody else installed.
* Nothing to do, and nothing to second-guess.
 CLC
 RTS
CLKF1 JSR NSCDET
 BCS CLKFNO
 JMP NSCINS
CLKFNO SEC
 RTS

* ================= THE NO-SLOT CLOCK ===========
* A DS1216 sits UNDER a ROM and answers only after a
* 64-bit unlock pattern has been clocked into it one
* bit at a time, using the low address bit of a read
* as the data line.  That is why the driver is all
* self-modified addresses: the slot is not known
* until it is found.
*
* ---- NSCDET: probe for it ----------------------
* out: C=0 and the driver patched for where it is
*
* CLKSLOT decides how hard to look:
*   0      scan slots 1-7, then under the main ROM
*   1-7    that slot only
*   $FF    do not probe at all - the Z80 escape
*          hatch, and the only safe setting on a
*          machine with a SoftCard in it
*
* The main-ROM phase is not an afterthought.  A
* DS1216 is a socket that a ROM sits IN, so on a IIe
* it is as often under the machine's own $C800 ROM
* as it is under a card's - and finding it there
* needs INTCXROM rather than a slot address, which
* is why the two phases patch different things.
NSCDET LDY #3
NSCD1 LDA DATELO,Y
 STA NSCSAV,Y
 DEY
 BPL NSCD1
 LDA CLKSLOT
 CMP #$FF
 BEQ NSCDNO
* $CFFF turns the slot ROMs back off afterwards
 LDA #$CF
 LDY #$FF
 STA NSLD4+2
 STY NSLD4+1
 STA NSST4+2
 STY NSST4+1
 LDA CLKSLOT
 BEQ NSCSCAN
 CMP #8
 BCS NSCDNO
 JSR NSCONE
 BCC NSCDYES
 BCS NSCDNO
* ---- phase one: every slot -----------------------
NSCSCAN LDA #1
 STA NSCSLT
NSCS1 LDA NSCSLT
 JSR NSCONE
 BCC NSCDYES
 INC NSCSLT
 LDA NSCSLT
 CMP #8
 BCC NSCS1
* ---- phase two: under the main ROM ---------------
* $C015 reads which ROM is switched in, $C007 selects
* the internal one and $C006 puts the slot ROMs back.
 LDA #$C0
 LDY #$15
 STA NSLD4+2
 STY NSLD4+1
 LDY #$07
 STA NSST1+2
 STY NSST1+1
 LDY #$06
 STA NSST4+2
 STY NSST4+1
 LDA #$C8
 JSR NSCPAT
 JSR NSCTRY
 BCC NSCDYES
NSCDNO LDY #3
NSCD2 LDA NSCSAV,Y
 STA DATELO,Y
 DEY
 BPL NSCD2
 SEC
 RTS
NSCDYES CLC
 RTS

* ---- NSCONE: probe slot A ------------------------
NSCONE ORA #$C0
 STA NSST1+2
 LDY #0
 STY NSST1+1
 JSR NSCPAT
 JMP NSCTRY

* ---- NSCPAT: point the three reads at $Cn --------
* NSST1 is patched separately, because the main-ROM
* phase needs it aimed at INTCXROM and not at a slot.
NSCPAT STA NSLD1+2
 STA NSLD2+2
 STA NSST2+2
 RTS

* ---- NSCTRY: three good reads wins -------------
* The addresses have already been patched by NSCPAT;
* this only decides whether what comes back is a
* date.
* One plausible reading can be luck; three in a row
* from a slot with no clock in it cannot be.  Every
* field is range checked, because a slot ROM read as
* if it were a clock returns whatever bytes the ROM
* happens to hold and those are usually not a date.
NSCTRY LDA #3
 STA NSCTRI
NSCT1 JSR NSCDRV
 LDA DATELO+1
 ROR
 LDA DATELO
 ROL
 ROL
 ROL
 ROL
 AND #$0F
 BEQ NSCTNO
 CMP #13
 BCS NSCTNO
 LDA DATELO
 AND #$1F
 BEQ NSCTNO
 CMP #32
 BCS NSCTNO
 LDA TIMELO+1
 CMP #24
 BCS NSCTNO
 LDA TIMELO
 CMP #60
 BCS NSCTNO
 DEC NSCTRI
 BNE NSCT1
 CLC
 RTS
NSCTNO SEC
 RTS

* ---- NSCINS: install the driver into ProDOS -----
* The driver is copied to wherever DATETIME points,
* which is inside the language card - so RWRAM1 has
* to be read twice to bank it in for writing, and
* ROMIN2 puts the ROM back afterwards.  Then MACHID
* bit 0 goes on and the vector becomes a JMP.
* The copy goes through ZPT1: STA (ptr),Y needs its
* pointer in zero page.  (It was CLKP, a variable
* out in the code, which no 6502 can do - Merlin
* calls it a bad address mode.)  Nothing between
* here and NSCI1 makes a call, so the caller-saved
* scratch pointer is safe.
NSCINS LDA DATETIME+1
 STA ZPT1
 CLC
 ADC #NSCULK-NSCDRV-1
 STA NSCU1+1
 LDA DATETIME+2
 STA ZPT1+1
 ADC #0
 STA NSCU1+2
 LDA RWRAM1
 LDA RWRAM1
 LDY #NSCEND-NSCDRV-1
NSCI1 LDA NSCDRV,Y
 STA (ZPT1),Y
 DEY
 BPL NSCI1
 LDA MACHID
 ORA #1
 STA MACHID
 LDA #$4C
 STA DATETIME
 JSR DATETIME
 LDA ROMIN2
 CLC
 RTS

* ================= THE DRIVER ==================
* This block is COPIED into ProDOS and runs there,
* so it may not refer to anything of ours - every
* address in it is either absolute or self-modified.
* ProDOS allows 125 bytes and no more.
NSCDRV PHP
 SEI
 LDA PTRIG
 LDA $C00B
NSLD4 LDA $CFFF
 PHA
NSST1 STA $C300
NSLD1 LDA $C304
 LDX #8
* unlock: sixty-four bits, one read each, the bit
* carried in the low address line
NSCU1 LDA NSCULK-1,X
 SEC
 ROR
NSCU2 PHA
 LDA #0
 ROL
 TAY
NSLD2 LDA $C300,Y
 PLA
 LSR
 BNE NSCU2
 DEX
 BNE NSCU1
* Eight bytes of eight bits, BCD, pushed as binary.
* $200 IS THE SCRATCH BYTE, and it is worth knowing
* where that is: page 2 is ProDOS own GETLN buffer
* and our page-mover buffer.  Neither is live when
* ProDOS calls a clock driver - BMINIT finishes at
* startup and we never use ProDOS GETLN - but this
* driver runs on every file CREATE, so anything that
* later wants $200 to survive a disk write has to
* know.
 LDX #8
NSCB1 LDY #8
NSST2 LDA $C304
 ROR
 ROR $200
 DEY
 BNE NSST2
 LDA $200
 LDY #$FF
 SEC
 SED
NSCB2 INY
 SBC #1
 BCS NSCB2
 CLD
 TYA
 PHA
 DEX
 BNE NSCB1
* the stack now holds y/m/d/w/H/M/S/F
 PLA
 STA DATELO+1
 PLA
 ASL
 ASL
 ASL
 ASL
 ASL
 STA DATELO
 ROL DATELO+1
 PLA
 ORA DATELO
 STA DATELO
 PLA
 PLA
 STA TIMELO+1
 PLA
 STA TIMELO
 PLA
 PLA
 PLA
 BMI NSCDN
NSST4 STA $CFFF
NSCDN PLP
 RTS
* The two bytes after NSCU1's LDA opcode are the
* ones the installer rewrites (NSCU1+1 and +2),
* because the unlock table moves with the driver
* when it is copied into ProDOS.
*
* No EQUs here.  NSCUAD EQU NSCU1+1 and NSCLEN EQU
* *-NSCDRV were both used by NSCINS above before
* they were defined - Merlin 8's ILLEGAL FORWARD
* REFERENCE.  NSCINS now writes NSCU1+1 directly,
* and the length is NSCEND-NSCDRV, two plain labels,
* the same way NSCULK-NSCDRV is worked out.
NSCULK DFB $5C,$A3,$3A,$C5
 DFB $5C,$A3,$3A,$C5
NSCEND

* ================= TYPING IT IN ================
* ---- CLKASKX: no clock, so ask ------------------
* in:  INIT80 has run; SCRROW is where to prompt
* out: DATELO/TIMELO set, C=1 if the operator
*      declined
*
* THE POSITIONED DRIVER, NOT THE CONSOLE.
* CONINIT has not run at this point in the boot and
* the menu that follows is positioned text, so this
* uses PUTS and GETLN80 like everything else in the
* startup phase.  Reaching for CONPUTS here would
* mean initialising a scrolling console for two
* lines and then never using it again.
*
* AN EMPTY LINE MEANS "LEAVE IT".  Somebody who
* reboots six times while testing should not have to
* type the date six times, and a wrong date entered
* impatiently is worse than no date at all.
CLKASKX LDA #<MCKD
 STA STRPTR
 LDA #>MCKD
 STA STRPTR+1
 JSR CLKPRM
 BCS CLKAX
 CPY #8
 BCC CLKAX
 LDA #0
 JSR CLK2
 STA DTM
 LDA #3
 JSR CLK2
 STA DTD
 LDA #6
 JSR CLK2
 STA DTY
 INC SCRROW
 LDA #<MCKT
 STA STRPTR
 LDA #>MCKT
 STA STRPTR+1
 JSR CLKPRM
 BCS CLKAX
 CPY #5
 BCC CLKAX
 LDA #0
 JSR CLK2
 STA DTHH
 LDA #3
 JSR CLK2
 STA DTMM
 JSR DTSETC
 CLC
 RTS
CLKAX SEC
 RTS

* ---- CLKPRM: draw STRPTR, read a line -----------
* out: Y = length typed, C=1 if ESC
CLKPRM LDA #2
 STA SCRCOL
 STZ SCRATR
 JSR PUTS
 LDA #24
 STA SCRCOL
 LDA #<CLKB
 STA ZPT2
 LDA #>CLKB
 STA ZPT2+1
 LDA #10
 JMP GETLN80

* ---- CLK2: two ASCII digits at CLKB+A -> A ------
CLK2 TAX
 LDA CLKB,X
 AND #$0F
 STA CLKT
 ASL
 ASL
 ASL
 STA CLKT2
 LDA CLKT
 ASL
 CLC
 ADC CLKT2
 STA CLKT
 INX
 LDA CLKB,X
 AND #$0F
 CLC
 ADC CLKT
 RTS

MCKD DFB 21
 ASC 'No clock.  MM/DD/YY? '
MCKT DFB 21
 ASC 'Time      HH:MM?     '
MCKF DFB 21
 ASC 'Clock found in slot  '

* ================= VARIABLES ===================
NSCSAV DS 4
NSCTRI DFB 0
NSCSLT DFB 0
CLKT DFB 0
CLKT2 DFB 0
CLKB DS 16
