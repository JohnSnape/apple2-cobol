* SYSUTIL.S  what COBOL.SYSTEM keeps of Utilities
* PUT from COBOLSYS.S - no ORG, not assembled
* alone.  One symbol table spans every PUT.
*
* UTILITIES IS AN OVERLAY NOW (UTIL, UTIL.S and
* UTILD.S, 2026-11-11).  It was resident because
* every utility was "a prompt and one MLI call";
* then COPY and the turnkey copier came, and it was
* 1,947 of COBOL.SYSTEM's 4,096 bytes, with ten to
* spare - and the prefixes wanted five hundred more.
* What stays here is what the menu and the boot
* need without loading anything:
*   UNAME, UPROMPT  the RUN prompt uses them
*   TKRUN           a turnkey disk starts here
*   RAMOFF          the boot takes /RAM away
*   TOSYS, TOWRK    the boot prefix in force for a
*                   moment, and back - LOADF, and
*                   the turnkey copier in UTIL
*   PXINIT, LDSET   the prefixes and COBOL.SETTINGS
*                   at boot
* UTILD.S has its own copies of UNAME and UPROMPT:
* an overlay assembled apart cannot reach these by
* name, and eighty bytes in the overlay is cheaper
* than a vector for each.

* ---- UNAME: prompt, read, build a pathname ------
* out: FNBUF1 = length-prefixed, HIGH BIT CLEAR
*      C=1 if ESC was pressed or nothing was typed
* ProDOS wants a pathname with the high bit off.
* GETLN80 already strips it on the way in - the mask
* here is belt and braces, and cheap enough to keep:
* a pathname with the top bit set is error $40 and
* nothing about the message says why.
UNAME JSR UPROMPT
* ESC cancels even after a name is typed.  GETLN80
* hands back C=1 with Y = the length, so testing Y
* alone took ESC for RETURN, and DELETE a file
* then destroyed the file named (user, 2026-11-25)
 BCS UNX
 CPY #0
 BEQ UNX
 STY FNBUF1
 LDX #0
UN1 CPX FNBUF1
 BCS UN2
 LDA UBUF,X
 AND #$7F
 STA FNBUF1+1,X
 INX
 JMP UN1
UN2 CLC
 RTS
UNX SEC
 RTS

* ---- UPROMPT: draw STRPTR, read a line ----------
* out: Y = length typed, C=1 if ESC
* row 14 at column 1 on the Utilities screen; the
* main menu moves it below itself for RUN
UPROMPT LDA UPROW
 STA SCRROW
 LDA UPCOL
 STA SCRCOL
 STZ SCRATR
 JSR PUTS
 LDA #<UBUF
 STA ZPT2
 LDA #>UBUF
 STA ZPT2+1
 LDA #40
 JMP GETLN80


* ---- TKRUN: the boot of a turnkey disk ----------
* COLD comes here when TKNAME is set.  The program
* runs exactly as menu option 6 runs it, and ProDOS
* QUIT follows - after STOP RUN, or after a message
* if it would not load.
TKRUN LDX #15
TKR1 LDA TKNAME,X
 STA FNBUF1,X
 DEX
 BPL TKR1
 JSR DORUN2
 JMP DOQUIT


* where UPROMPT asks - DORUN moves it
UPROW DFB 14
UPCOL DFB 1
UBUF DS 48

* ---- RAMOFF: disconnect /RAM --------------------
* ProDOS makes a RAM disk, /RAM, of the auxiliary
* 64K - which this system uses for itself: the
* editor's lines, the language card's COBOL.AUX.
* /RAM goes unnoticed until a pathname names some
* OTHER volume: ProDOS then searches every online
* volume for it, /RAM included, and its driver runs
* (out of page 2) over memory it no longer owns.
* The turnkey copier's /NEWDISK/PRODOS was the first
* such name, and crashed at $021E (2026-11-08).
* Apple's ProDOS Technical Note #8 is the cure:
* take slot 3 drive 2 out of the device list and
* point its vector at NODEV.
RDEV32 EQU $BF26
RNODEV EQU $BF10
RDVCNT EQU $BF31
RDVLST EQU $BF32
RAMOFF LDA RDEV32
 CMP RNODEV
 BNE RMO1
 LDA RDEV32+1
 CMP RNODEV+1
 BEQ RMOX
RMO1 LDX RDVCNT
RMO2 LDA RDVLST,X
 AND #$F0
 CMP #$B0
 BEQ RMO3
 DEX
 BPL RMO2
 BMI RMOV
* close the gap: entries X+1 .. DEVCNT move down one
RMO3 LDA RDVLST+1,X
 STA RDVLST,X
 CPX RDVCNT
 BEQ RMO4
 INX
 BNE RMO3
RMO4 DEC RDVCNT
RMOV LDA RNODEV
 STA RDEV32
 LDA RNODEV+1
 STA RDEV32+1
RMOX RTS


* ================= THE PREFIXES ==================
* PREFIX.S (in the aux card) has the scheme: */ the
* boot prefix, 0/ ProDOS's own prefix - the program
* directory - and 1/-9/ for data.

* ---- PXINIT: the table, at boot ------------------
* Every prefix empty, then */ = SYSPFX, which SETPFX
* has just read from ProDOS (or made from the boot
* volume's name when there was none).
PXINIT LDX #3
 JSR PXSVC
 LDA #<SYSPFX
 STA ZPT1
 LDA #>SYSPFX
 STA ZPT1+1
 LDY #0
 LDX #2
 JMP PXSVC

* ---- TOSYS / TOWRK: */ in force, and back --------
* The system's own files - the overlays, COBOL.LIB,
* the run-time a turnkey disk is made from - are
* opened by bare name, and a bare name is looked up
* in ProDOS's prefix, which is 0/ and may be a work
* directory on another disk.  So for the length of
* an OPEN the prefix is */, and then it is put back.
* Before the boot has read */ (SYSPFX is cleared at
* COLD) there is nothing to switch to, and nothing
* is switched: LOADLIB and LOADAUX run on the prefix
* ProDOS started us with, which is */ anyway.
TOSYS STZ TSON
 LDA SYSPFX
 BEQ TSX
 JSR MLI
 DFB $C7
 DA TSGP
 BCS TSX
 JSR MLI
 DFB $C6
 DA TSSP
 BCS TSX
 INC TSON
TSX RTS
TOWRK LDA TSON
 BEQ TWX
 STZ TSON
 JSR MLI
 DFB $C6
 DA TSGP
TWX RTS
TSGP DFB 1
 DA WRKPFX
TSSP DFB 1
 DA SYSPFX
TSON DFB 0

* ---- LDSET: */COBOL.SETTINGS, at boot ------------
* Missing, unreadable or not ours: the defaults
* stand - no printer, no prefixes, 0/ = */.  The
* layout is in EQUATES2 (SETBUF).  0/ is put in
* force with SET_PREFIX; if its disk is not in the
* drive that fails, and 0/ stays the boot prefix,
* which is the right answer for a missing disk.
LDSET LDA #<SETNAM
 STA FNAMP
 LDA #>SETNAM
 STA FNAMP+1
 LDA #<SETBUF
 STA FADDR
 LDA #>SETBUF
 STA FADDR+1
 LDA #<SETLEN
 STA FLEN
 LDA #>SETLEN
 STA FLEN+1
 JSR FLOAD
 BCS LSX
 LDA SETBUF
 CMP #$53
 BNE LSX
 LDA SETBUF+4
 STA PRSLOT
 LDA SETBUF+5
 STA PRMODE
* 1/ to 9/, 64 bytes apart from SETBUF+8
 LDA #<SETBUF+8
 STA ZPT1
 LDA #>SETBUF+8
 STA ZPT1+1
 LDA #1
 STA LSN
LS1 LDY LSN
 LDX #2
 JSR PXSVC
 CLC
 LDA ZPT1
 ADC #64
 STA ZPT1
 BCC LS2
 INC ZPT1+1
LS2 INC LSN
 LDA LSN
 CMP #10
 BCC LS1
* and 0/, where ZPT1 has arrived: SETBUF+584
 LDA (ZPT1)
 BEQ LSX
 LDA ZPT1
 STA LSSP+1
 LDA ZPT1+1
 STA LSSP+2
 JSR MLI
 DFB $C6
 DA LSSP
LSX RTS
LSSP DFB 1
 DA 0
LSN DFB 0
* */ in front: the file is the system's, wherever
* 0/ points - and at boot */ is all there is
SETNAM DFB 16
 ASC '*/COBOL.SETTINGS'
