* SYSBOOT.S  machine checks and cold start
* PUT from COBOLSYS.S - no ORG, not assembled
* alone.  One symbol table spans every PUT.
*
* === COLD: startup, once ===
* SYSPFX empty: TOSYS has no */ to switch to until
* SETPFX has read it, so LOADLIB and LOADAUX open by
* the prefix ProDOS started us in
*
* THIS BUILD REFUSES TO START UNDER COBOL.OS (the
* user, 2026-11-24: two builds, one for ProDOS and
* one for COBOL.OS, each guarding itself - DECISIONS
* 8.13).  Before anything is touched: the kernel's
* version byte, KVERSION at $BFFF, is small under
* ProDOS ($24 for 2.4.x) and $C0 or more under
* COBOL.OS.  This build keeps ERRBUF and the
* prefixes at $BD00, which is COBOL.OS's block
* buffer, so under COBOL.OS it would wreck the
* system it ran on.  It says so, waits for a key
* and QUITs.
COLD LDA KVERS
 CMP #$C0
 BCC COLD1
 LDA #<MNOTPD
 STA ZPT1
 LDA #>MNOTPD
 STA ZPT1+1
 JMP MERRQ
COLD1 STZ SYSPFX
 JSR CHK128
 BCS E128
 JSR CHK65
 BCS E65
 JSR RAMOFF
 JSR LOADLIB
 BCS ELIB
* the library's other half, into the auxiliary
* language card - GATE.S.  Nothing that does
* arithmetic works without it, so it is as fatal as
* a missing COBOL.LIB.
 JSR LOADAUX
 BCS EAUX
 JSR INIT80
* Count the auxiliary banks, then install the page
* mover in every one of them.  A plain 128K IIe
* reports one bank and everything below carries on
* exactly as before.
 JSR FINDBNK
 JSR BMINIT
 JSR SETPFX
* the printer and the prefixes, if they were saved
 JSR LDSET
* Nothing is in auxiliary memory yet, and the
* handover block has to say so.  RAM survives a
* reboot, so without this a cold start followed by
* menu option 5 would compile whatever the last
* session left behind - and produce an object file
* rather than a message, which is the worst way for
* it to be wrong.
 STZ SRCSIG
 STZ SRCSIG+1
 JSR CLOCKUP
* a turnkey disk runs its program, not the menu
 LDA TKNAME
 BEQ CLDMNU
 JMP TKRUN
CLDMNU JMP MENU

* --- CLOCKUP: get ProDOS a date, one way or the
* other ------------------------------------------
* Placed AFTER INIT80 because it may have to talk to
* the operator, and BEFORE the menu because every
* file the session creates is stamped from what it
* settles.
*
* MECHANISM IS IN CLOCK.S, POLICY IS HERE.  The
* library knows how to find a No-Slot Clock and how
* to ask; what to do about the answer is a decision
* the boot makes, and it is the kind of decision
* that changes.
* (RAMOFF is at the end of SYSUTIL.S: here it put
* the boot error branches out of range)
CLOCKUP LDA #0
 STA CLKSLOT
 JSR CLKFIND
 BCC CLKGOT
* Nothing found.  Say so and offer the keyboard -
* and take an empty line for an answer, because
* somebody rebooting six times while testing should
* not have to type the date six times.
 LDA #20
 STA SCRROW
 JSR CLKASK
 RTS
* Found, or ProDOS already had one.  Say which,
* because "for some reason it has no date" is
* exactly the mystery this line ends.
CLKGOT LDA #20
 STA SCRROW
 LDA #2
 STA SCRCOL
 STZ SCRATR
 LDA #<MCLKOK
 STA STRPTR
 LDA #>MCLKOK
 STA STRPTR+1
 JMP PUTS

* --- error exits: message + wait key + QUIT ---
* These can only happen before INIT80, so they are
* free to use the monitor.
E128 LDA #<M128
 STA ZPT1
 LDA #>M128
 STA ZPT1+1
 JMP MERRQ
E65 LDA #<M65
 STA ZPT1
 LDA #>M65
 STA ZPT1+1
 JMP MERRQ
ELIB LDA #<MLIB
 STA ZPT1
 LDA #>MLIB
 STA ZPT1+1
 JMP MERRQ
EAUX LDA #<MAUX
 STA ZPT1
 LDA #>MAUX
 STA ZPT1+1
 JMP MERRQ

* --- CLAIM: REMOVED 2026-08-16, and this is why ---
* It marked pages $08-$1F as ours in the ProDOS
* bitmap - "six bytes to be honest about what we
* hold", said the comment that used to be here,
* since text page 2, the data region and the foot
* of the library all look free to ProDOS otherwise.
*
* IT BREAKS ANY MLI CALL THAT WRITES INTO OUR DATA
* REGION.  ProDOS reads that map before it will
* write into a buffer handed to it, and a page
* marked in use comes back $56, BAD BUFFER ADDRESS.
* Found in WRITER, the word processor that shares
* this tree's modules: its GET_PREFIX buffer is at
* $1200 and the call failed every time until the
* claim went.  THE SAME TRAP IS SET HERE - CATALOG
* reads the prefix into CATPATH at $0E00, inside
* this range, so CTLIST would have failed $56 the
* first time anybody listed a directory - which has
* not happened yet, so it was waiting rather than
* known.  SYSMENU's own PFXBUF is a DS inside
* COBOL.SYSTEM at $2xxx and EDIT's is in the overlay
* band, so neither was ever in the claimed range;
* CATALOG was the one that would have found it.
*
* Nothing is lost by dropping it, and the old
* comment already said so: ProDOS never chooses
* memory for us, because the MLI OPEN call takes
* the file buffer as a PARAMETER and we pass IOBUF
* ourselves.  The bitmap matters only to something
* that does the choosing - BASIC.SYSTEM, a program
* selector, ALLOC_INTERRUPT - and none of those is
* resident while we own the machine.  ProDOS marks
* the four pages of an I/O buffer itself on OPEN
* and frees them on CLOSE, whether we claim
* anything or not.
*
* NOT A CONTRADICTION OF THE WORKING FILE I/O:
* EDIT's save streams through STAGE at $1C80, also
* inside the claimed range, and it was verified
* byte-perfect on the machine.  READ and WRITE
* evidently do not check the map; the calls that
* hand ProDOS a buffer to FILL - GET_PREFIX among
* them - do.

* --- CHK128: 128K present? (ProDOS 8 method) ---
* Runs the test from $0100, which stays put when
* aux is banked in.  Code at $2000 would bank
* itself out mid-test.  C=1 = no aux, C=0 = 128K.
* It scribbles on $0C00 and $7C00 in both banks -
* the foot of the data region and the top of the
* library - which is safe only because this runs
* before LOADLIB and before anything claims
* BANKTBL.  Do not move it later.
CHK128 LDX #C8END-C8ROUT
C8MOVE LDA C8ROUT,X
 STA $0100,X
 DEX
 BPL C8MOVE
 JMP $0100
C8ROUT LDA #$EE
 STA AUXREAD
 STA AUXWRITE
 STA $0C00
 STA $7C00
 LDA $0C00
 CMP #$EE
 BNE C8NO
 ASL $0C00
 ASL
 CMP $0C00
 BNE C8NO
 CMP $7C00
 BNE C8YES
C8NO SEC
 BCS C8R
C8YES CLC
C8R STA MAINREAD
 STA MAINWRITE
 RTS
C8END EQU *

* --- CHK65: 65C02 present? (decimal N flag) ---
* $99+1 in decimal: 65C02 sets N per the decimal
* result (0, N=0); NMOS 6502 sets N per binary
* ($9A, N=1).  C=1 = 6502 (fail), C=0 = 65C02.
CHK65 LDA #$99
 CLC
 SED
 ADC #1
 CLD
 BPL C65OK
 SEC
 RTS
C65OK CLC
 RTS

* --- MPRINT: ZPT1 -> $00-term string via COUT ---
* The one startup-phase message routine.  After
* INIT80, use PUTS instead.
MPRINT LDY #0
MPR1 LDA (ZPT1),Y
 BEQ MPRD
 ORA #$80
 JSR COUT
 INY
 BNE MPR1
MPRD RTS

* --- MERRQ: HOME + MPRINT + wait key + QUIT ---
MERRQ JSR HOME
 JSR MPRINT
 JSR RDKEY
* fall into SQUIT

* --- SQUIT: ProDOS QUIT (startup phase) ---
SQUIT JSR MLI
 DFB $65
 DA SQPARM
 RTS
SQPARM DFB 4
 DFB 0
 DA 0
 DFB 0
 DA 0

* --- startup message strings ---
M128 ASC 'Requires a 128K Apple - press a key'
 DFB 0
* two lines of 40 columns at most; $0D is RETURN
MNOTPD ASC 'This COBOL needs ProDOS, not COBOL.OS.'
 DFB $0D
 ASC 'Start it from ProDOS - press a key'
 DFB 0
M65 ASC 'Requires a 65C02 processor - press a key'
 DFB 0
MLIB ASC 'Cannot load COBOL.LIB - press a key'
 DFB 0
MAUX ASC 'Cannot load COBOL.AUX - press a key'
 DFB 0

* --- and one for after INIT80, so it is length
* prefixed and goes through PUTS, not MPRINT ---
MCLKOK DFB 23
 ASC 'Clock found - dates on.'

