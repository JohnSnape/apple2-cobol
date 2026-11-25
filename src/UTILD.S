* UTILD.S  the Utilities overlay, its body
* PUT from UTIL.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* UTILITIES LEFT COBOL.SYSTEM ON 2026-11-11.  It was
* resident when every utility was a prompt and one
* MLI call; COPY and the turnkey copier made it
* 1,947 of COBOL.SYSTEM's 4,096 bytes, and the
* prefixes (option 8) needed five hundred more than
* the ten that were left.  As an overlay it loads at
* UTLBASE, $A000 - above the band COPY streams
* through - each time option 8 of the menu is
* chosen, and RTS goes back to the menu.
*   Everything it used from the menu came with it
* (DOCAT, MHEXB, GETK, and copies of UNAME and
* UPROMPT, which the menu's RUN prompt still needs
* for itself).  The two things it calls in
* COBOL.SYSTEM go through fixed entries, XTOSYS and
* XTOWRK (EQUATES2), because a file assembled apart
* cannot name a label in another.
*
* DOUTIL IS THE FIRST BYTE: the menu enters at
* UTLBASE.

* ---- DOUTIL: draw it and dispatch ---------------
DOUTIL JSR CLRSCR
 STZ SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<U0
 STA STRPTR
 LDA #>U0
 STA STRPTR+1
 JSR PUTS
 JSR UHDR
 STZ UI
UL1 LDX UI
 LDA UTAB,X
 CMP #$FF
 BEQ ULDN
 STA SCRROW
 LDA UTAB+1,X
 STA STRPTR
 LDA UTAB+2,X
 STA STRPTR+1
 LDA #1
 STA SCRCOL
 STZ SCRATR
 JSR PUTS
 LDA UI
 CLC
 ADC #3
 STA UI
 JMP UL1
ULDN JSR GETK
 CMP #$1B
 BEQ UBACK
 CMP #$31
 BEQ UU1
 CMP #$32
 BEQ UU2
 CMP #$33
 BEQ UU3
 CMP #$34
 BEQ UU4
 CMP #$35
 BEQ UU5
 CMP #$36
 BEQ UU6
 CMP #$37
 BEQ UU7
 CMP #$38
 BEQ UU8
 JMP ULDN
UBACK RTS
UU1 JSR DOCAT
 JMP DOUTIL
UU2 JSR UCOPY
 JMP DOUTIL
UU3 JSR UDEL
 JMP DOUTIL
UU4 JSR UREN
 JMP DOUTIL
UU5 JSR UDATE
 JMP DOUTIL
UU6 JSR UPRSL
 JMP DOUTIL
UU7 JSR UTURN
 JMP DOUTIL
UU8 JSR UPFX
 JMP DOUTIL

* ---- UHDR: date, time and printer, top right ----
* The user's request, 2026-11-08: the three things
* options 5 and 6 set, shown where the user lands,
* right-justified on rows 0-2.  DOUTIL redraws after
* every option, so a change shows at once.
*   Date 11/8/2026        Date not set
*   Time 14:05            Time not set
*   Printer Slot 1        Printer Slot none
* A date of zero is ProDOS's "never set"; the time
* goes with it, since 00:00 is a real time.
UHDR STZ UHBUF
 LDA #<UHDT
 LDX #>UHDT
 JSR UHSTR
 LDA DATELO
 ORA DATELO+1
 BEQ UH1
 JSR DTMDATE
 LDA #<DTBUF
 LDX #>DTBUF
 JSR UHSTR
 JMP UH2
UH1 JSR UHNOT
UH2 STZ SCRROW
 JSR UHPUT
* the time: HH:MM out of DTTIME's eight digits
 STZ UHBUF
 LDA #<UHTM
 LDX #>UHTM
 JSR UHSTR
 LDA DATELO
 ORA DATELO+1
 BEQ UH3
 JSR DTTIME
 LDA DTBUF
 JSR UHCH
 LDA DTBUF+1
 JSR UHCH
 LDA #$3A
 JSR UHCH
 LDA DTBUF+2
 JSR UHCH
 LDA DTBUF+3
 JSR UHCH
 JMP UH4
UH3 JSR UHNOT
UH4 LDA #1
 STA SCRROW
 JSR UHPUT
* the printer
 STZ UHBUF
 LDA #<UHPR
 LDX #>UHPR
 JSR UHSTR
 LDA PRSLOT
 BEQ UH5
 ORA #$30
 JSR UHCH
 JMP UH6
UH5 LDA #<UHNONE
 LDX #>UHNONE
 JSR UHSTR
UH6 LDA #2
 STA SCRROW
* UHPUT: UHBUF, right-justified on SCRROW
UHPUT STZ SCRATR
 LDA #<UHBUF
 STA STRPTR
 LDA #>UHBUF
 STA STRPTR+1
 JMP NFPUTR
UHNOT LDA #<UHNS
 LDX #>UHNS
* UHSTR: A/X -> a length-prefixed string onto UHBUF
UHSTR STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA UHN
 BEQ UHSX
 LDY #1
UHS1 LDA (ZPT1),Y
 JSR UHCH
 CPY UHN
 INY
 BCC UHS1
UHSX RTS
* UHCH: A onto UHBUF.  Keeps Y.
UHCH LDX UHBUF
 STA UHBUF+1,X
 INC UHBUF
 RTS
UHDT DFB 5
 ASC 'Date '
UHTM DFB 5
 ASC 'Time '
UHPR DFB 13
 ASC 'Printer Slot '
UHNS DFB 7
 ASC 'not set'
UHNONE DFB 4
 ASC 'none'
UHN DFB 0
UHBUF DS 24

* ---- UDEL: delete a file ------------------------
* DESTROY, and nothing else.  ProDOS will refuse a
* locked file or an open one and hand back the code,
* which is more useful than us second-guessing it.
UDEL LDA #<UPDEL
 STA STRPTR
 LDA #>UPDEL
 STA STRPTR+1
 JSR UNAME
 BCS UDX
 LDA #<FNBUF1
 STA UDPARM+1
 LDA #>FNBUF1
 STA UDPARM+2
 JSR UDESTR
 JMP URESULT
UDX RTS

* ---- UREN: rename a file ------------------------
UREN LDA #<UPREN
 STA STRPTR
 LDA #>UPREN
 STA STRPTR+1
 JSR UNAME
 BCS URX
 JSR UCOPYN
 INC SCRROW
 LDA #<UPTO
 STA STRPTR
 LDA #>UPTO
 STA STRPTR+1
 JSR UNAME
 BCS URX
 LDA #<FNBUF2
 STA URPARM+1
 LDA #>FNBUF2
 STA URPARM+2
 LDA #<FNBUF1
 STA URPARM+3
 LDA #>FNBUF1
 STA URPARM+4
 JSR URENAM
 JMP URESULT
URX RTS

* ---- UCOPYN: FNBUF1 -> FNBUF2 -------------------
* RENAME wants both names at once and UNAME only
* builds one, so the first is parked before the
* second is asked for.
UCOPYN LDX #0
UCP1 LDA FNBUF1,X
 STA FNBUF2,X
 INX
 CPX #64
 BCC UCP1
 RTS

* ---- UDATE: set the date and time ---------------
* The same routine the boot uses when it finds no
* clock.  On a machine that HAS one this overwrites
* what the clock said - for about a second, until
* ProDOS calls the driver again on the next file
* operation and puts it back.  Worth knowing rather
* than worth preventing.
UDATE JSR CLRSCR
 LDA #6
 STA SCRROW
 JSR CLKASK
 RTS

* ---- UPRSL: which slot is the printer in? -------
UPRSL LDA #<UPPRS
 STA STRPTR
 LDA #>UPPRS
 STA STRPTR+1
 JSR UPROMPT
 LDA UBUF
 SEC
 SBC #$30
 CMP #8
 BCS UPRX
 STA PRSLOT
 STZ PRMODE
 JSR PRINIT
* kept for the next boot (COBOL.SETTINGS)
 JMP SVSET
UPRX RTS

* ---- UNAME: prompt, read, build a pathname ------
* out: FNBUF1 = length-prefixed, HIGH BIT CLEAR
*      C=1 if ESC was pressed or nothing was typed
* ProDOS wants a pathname with the high bit off.
* GETLN80 already strips it on the way in - the mask
* here is belt and braces, and cheap enough to keep:
* a pathname with the top bit set is error $40 and
* nothing about the message says why.
UNAME JSR UPROMPT
* C=1 is ESC, even with a name typed (2026-11-25)
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
* a name may start */ 0/ or 1/-9/ (PREFIX.S): it is
* expanded in place, and upper cased, before ProDOS
* sees it
UN2 LDA #<FNBUF1
 STA ZPT1
 LDA #>FNBUF1
 STA ZPT1+1
 LDX #0
 JSR PXSVC
 CLC
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
* 64: a pathname can be that long, and a prefix
* often is most of one
 LDA #64
 JMP GETLN80

* ---- URESULT: report what the MLI said ----------
URESULT BCC URDONE
 PHA
 LDA #16
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
* $40, bad pathname, is the name that was typed:
* the prefix service makes every name that breaks
* ProDOS's rules into one (DECISIONS 8.10).
 PLA
 CMP #$40
 BEQ URBAD
 PHA
 LDA #<UERR
 STA STRPTR
 LDA #>UERR
 STA STRPTR+1
 JSR PUTS
 PLA
 JSR MHEXB
 JSR GETK
 RTS
URBAD LDA #<UBADN
 STA STRPTR
 LDA #>UBADN
 STA STRPTR+1
 JSR PUTS
 JSR GETK
 RTS
URDONE LDA #16
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<UOK
 STA STRPTR
 LDA #>UOK
 STA STRPTR+1
 JSR PUTS
 JSR GETK
 RTS

* ---- the MLI calls ------------------------------
UDESTR JSR MLI
 DFB $C1
 DA UDPARM
 RTS
URENAM JSR MLI
 DFB $C2
 DA URPARM
 RTS
UDPARM DFB 1
 DA 0
URPARM DFB 2
 DA 0
 DA 0

* ================= COPY ========================
* ---- UCOPY: utility 2 ---------------------------
* Names as they are on the disk, like DELETE and
* RENAME; the second may be on another volume
* (/BACKUP/CUST.DAT).
UCOPY LDA #<UPCPY
 STA STRPTR
 LDA #>UPCPY
 STA STRPTR+1
 JSR UNAME
 BCS UCPX
 JSR UCOPYN
 INC UPROW
 LDA #<UPTO
 STA STRPTR
 LDA #>UPTO
 STA STRPTR+1
 JSR UNAME
 DEC UPROW
 BCS UCPX
 STZ UFPAT
 JSR UFCOPY
 JMP URESULT
UCPX RTS

* ---- UFCOPY: FNBUF2 -> FNBUF1 -------------------
* out: C=1 + A = the MLI error
* The type, aux type and access come across, so a
* SYS file is still a SYS file loading at $2000.
* The new file is made first: DESTROY (its error is
* ignored - the file need not exist), CREATE, then
* READ and WRITE through $6000-$9FFF, 16K a time -
* the band under this overlay, which loads at $A000
* (it was $7000-$AFFF while Utilities lived in
* COBOL.SYSTEM and the whole band was free).
* UFPAT <> 0 patches the first block with the
* turnkey name as it goes past: see UTURN.
UFBUF EQU $6000
UFMAX EQU $4000
UFCOPY LDA #<FNBUF2
 STA UGIPRM+1
 LDA #>FNBUF2
 STA UGIPRM+2
 JSR MLI
 DFB $C4
 DA UGIPRM
 BCC UFC0
 RTS
UFC0
 LDA #<FNBUF1
 STA UDPARM+1
 LDA #>FNBUF1
 STA UDPARM+2
 JSR UDESTR
 LDA #<FNBUF1
 STA UCRPRM+1
 LDA #>FNBUF1
 STA UCRPRM+2
* access, type, aux type: four bytes, in the same
* order in both blocks
 LDX #3
UFC1 LDA UGIPRM+3,X
 STA UCRPRM+3,X
 DEX
 BPL UFC1
 JSR MLI
 DFB $C0
 DA UCRPRM
 BCS UFX
* the source, then the copy
 LDA #<FNBUF2
 LDX #>FNBUF2
 LDY #>IOBUF2
 JSR UFOPEN
 BCS UFX
 STA UFSREF
 LDA #<FNBUF1
 LDX #>FNBUF1
 LDY #>IOBUF3
 JSR UFOPEN
 BCS UFCLS1
 STA UFDREF
UFC2 LDA UFSREF
 STA URWPRM+1
 LDA #<UFMAX
 STA URWPRM+4
 LDA #>UFMAX
 STA URWPRM+5
 JSR MLI
 DFB $CA
 DA URWPRM
 BCC UFC3
 CMP #$4C
 BEQ UFCEND
 SEC
 BCS UFCLS2
UFC3 JSR UFPCH
 LDA UFDREF
 STA URWPRM+1
 LDA URWPRM+6
 STA URWPRM+4
 LDA URWPRM+7
 STA URWPRM+5
 JSR MLI
 DFB $CB
 DA URWPRM
 BCC UFC2
 BCS UFCLS2
* end of file: close both, no error
UFCEND LDA #0
 CLC
UFCLS2 PHP
 PHA
 LDA UFDREF
 JSR UFCLOS
 PLA
 PLP
UFCLS1 PHP
 PHA
 LDA UFSREF
 JSR UFCLOS
 PLA
 PLP
UFX RTS
* UFOPEN: A/X path, Y = buffer page.  A = ref
UFOPEN STA UOPPRM+1
 STX UOPPRM+2
 STZ UOPPRM+3
 STY UOPPRM+4
 JSR MLI
 DFB $C8
 DA UOPPRM
 BCS UFOX
 LDA UOPPRM+5
UFOX RTS
UFCLOS STA UCLPRM+1
 JSR MLI
 DFB $CC
 DA UCLPRM
 RTS
* UFPCH: the turnkey name into byte 3 of the first
* block of COBOL.SYSTEM, once
UFPCH LDA UFPAT
 BEQ UFPX
 STZ UFPAT
 LDX #15
UFP1 LDA TKSET,X
 STA UFBUF+3,X
 DEX
 BPL UFP1
UFPX RTS

* ================= THE TURNKEY DISK ==============
* ---- UTURN: utility 7 ---------------------------
* A disk that boots straight into one program.  The
* user formats it first (any size ProDOS disk) and
* names its volume; this copies onto it
*   PRODOS  COBOL.SYSTEM  COBOL.LIB  COBOL.AUX  VM
*   and the program's .OBJ
* - the run-time and the program, nothing else: the
* program makes its own data files.  The copy of
* COBOL.SYSTEM carries the program's name at $2003
* (TKNAME), and that is the whole difference:
* COLD sees it and runs the program instead of
* showing the menu, and quits to ProDOS after
* STOP RUN.  It still asks the date if there is no
* clock, like the system disk.
UTURN LDA #<UPTKP
 STA STRPTR
 LDA #>UPTKP
 STA STRPTR+1
 JSR UNAME
 BCC UT0
 RTS
UT0 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 LDA #$4A
 LDX #1
 JSR SETSFX
* NAME.OBJ -> TKSET, the name the copy will carry
 LDX #15
UT1 LDA FNBUF1,X
 STA TKSET,X
 DEX
 BPL UT1
 INC UPROW
 LDA #<UPTKV
 STA STRPTR
 LDA #>UPTKV
 STA STRPTR+1
 JSR UPROMPT
 DEC UPROW
 BCS UTX
 CPY #0
 BEQ UTX
* the volume, with its leading slash, and no
* trailing one
 STY TKVLEN
 LDX #0
 LDY #0
 LDA UBUF
 AND #$7F
 CMP #$2F
 BEQ UT2
 LDA #$2F
 STA TKVOL
 INY
UT2 CPX TKVLEN
 BCS UT3
 LDA UBUF,X
 AND #$7F
 STA TKVOL,Y
 INX
 INY
 CPY #30
 BCC UT2
UT3 LDA TKVOL-1,Y
 CMP #$2F
 BNE UT4
 DEY
UT4 STY TKVLEN
* the files, in order
 STZ TKI
UT5 LDX TKI
 LDA TKFTAB,X
 STA ZPT1
 LDA TKFTAB+1,X
 STA ZPT1+1
 ORA ZPT1
 BNE UT6
* the program itself, last
 LDA #<TKSET
 STA ZPT1
 LDA #>TKSET
 STA ZPT1+1
 JSR UTONE
 JMP URESULT
* the run-time comes from */, the boot prefix - it
* is the system's - and the program from 0/
UT6 JSR XTOSYS
 JSR UTONE
 PHP
 PHA
 JSR XTOWRK
 PLA
 PLP
 BCS UTERR
 INC TKI
 INC TKI
 JMP UT5
UTERR JMP URESULT
UTX RTS

* ---- UTONE: copy the file named at ZPT1 ---------
* source: the bare name.  copy: TKVOL/name.  Shown
* on row 18 as it goes.
UTONE LDY #0
 LDA (ZPT1),Y
 TAY
UTO1 LDA (ZPT1),Y
 STA FNBUF2,Y
 DEY
 BPL UTO1
* TKVOL + "/" + name -> FNBUF1
 LDX #0
UTO2 CPX TKVLEN
 BCS UTO3
 LDA TKVOL,X
 STA FNBUF1+1,X
 INX
 BNE UTO2
UTO3 LDA #$2F
 STA FNBUF1+1,X
 INX
 LDY #1
UTO4 CPY FNBUF2
 BEQ UTO4A
 BCS UTO5
UTO4A LDA FNBUF2,Y
 STA FNBUF1+1,X
 INX
 INY
 BNE UTO4
UTO5 STX FNBUF1
* "Copying NAME"
 LDX #18
 JSR CLRROW
 LDA #18
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<UCPYG
 STA STRPTR
 LDA #>UCPYG
 STA STRPTR+1
 JSR PUTS
 LDA #<FNBUF1
 STA STRPTR
 LDA #>FNBUF1
 STA STRPTR+1
 JSR PUTS
* COBOL.SYSTEM is the one that is patched: it is
* entry 1 of the table
 STZ UFPAT
 LDA TKI
 CMP #2
 BNE UTO6
 INC UFPAT
UTO6 JMP UFCOPY

* the run-time, in copy order; 0 ends it and the
* program goes last
TKFTAB DA TKF1
 DA TKF2
 DA TKF3
 DA TKF4
 DA TKF5
 DA 0
TKF1 DFB 6
 ASC 'PRODOS'
TKF2 DFB 12
 ASC 'COBOL.SYSTEM'
TKF3 DFB 9
 ASC 'COBOL.LIB'
TKF4 DFB 9
 ASC 'COBOL.AUX'
TKF5 DFB 2
 ASC 'VM'

* ---- parameter blocks ----
* GET_FILE_INFO: count, path, access, type, aux,
* storage, blocks, dates
UGIPRM DFB 10
 DA 0
 DS 15
* CREATE: count, path, access, type, aux, storage,
* date, time - zero dates take today's
UCRPRM DFB 7
 DA 0
 DS 4
 DFB 1
 DA 0
 DA 0
UOPPRM DFB 3
 DA 0
 DA 0
 DFB 0
URWPRM DFB 4
 DFB 0
 DA UFBUF
 DA 0
 DA 0
UCLPRM DFB 1
 DFB 0
UFSREF DFB 0
UFDREF DFB 0
UFPAT DFB 0
TKI DFB 0
TKVLEN DFB 0
TKVOL DS 32
TKSET DS 16

* ---- the submenu table --------------------------
UTAB DFB 3
 DA U1
 DFB 4
 DA U2
 DFB 5
 DA U3
 DFB 6
 DA U4
 DFB 7
 DA U5
 DFB 8
 DA U6
 DFB 9
 DA U7
 DFB 10
 DA U9
 DFB 12
 DA U8
 DFB $FF

U0 DFB 9
 ASC 'UTILITIES'
U1 DFB 17
 ASC '1) CATALOG a disk'
U2 DFB 14
 ASC '2) COPY a file'
U3 DFB 16
 ASC '3) DELETE a file'
U4 DFB 16
 ASC '4) RENAME a file'
U5 DFB 24
 ASC '5) Set the DATE and TIME'
U6 DFB 23
 ASC '6) Set the PRINTER slot'
U7 DFB 24
 ASC '7) Create a TURNKEY disk'
U8 DFB 21
 ASC 'ESC) Back to the menu'
U9 DFB 19
 ASC '8) Set the PREFIXES'
UPCPY DFB 14
 ASC 'Copy which?   '
UPTKP DFB 31
 ASC 'Program for the turnkey disk?  '
UPTKV DFB 39
 ASC 'Volume of the blank disk (/MYDISK)?    '
UCPYG DFB 8
 ASC 'Copying '
UPDEL DFB 14
 ASC 'Delete which? '
UPREN DFB 14
 ASC 'Rename which? '
UPTO DFB 14
 ASC 'New name?     '
UPPRS DFB 21
 ASC 'Printer slot (1-7)?  '
UOK DFB 18
 ASC 'Done - press a key'
UERR DFB 14
 ASC 'ProDOS error $'
UBADN DFB 13
 ASC 'Bad file name'

* ---- variables ----------------------------------
UI DFB 0
* where UPROMPT asks - DORUN moves it
UPROW DFB 14
UPCOL DFB 1
UBUF DS 66

* ================= THE PREFIXES ================
* ---- UPFX: utility 8 ----------------------------
* The list, */ and 0/ to 9/ on rows 2-12, then
* which one to change and what to.  1/-9/ go into
* the aux card's table; 0/ is ProDOS's own prefix
* and is changed with SET_PREFIX.  */ is where the
* system booted and is not offered.  Every change
* is saved at once in */COBOL.SETTINGS.
UPFX JSR CLRSCR
 STZ SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<UPFT
 STA STRPTR
 LDA #>UPFT
 STA STRPTR+1
 JSR PUTS
* $FF is */, then 0 to 9
 LDA #$FF
 STA UPN
UPF1 LDA UPN
 CLC
 ADC #3
 STA SCRROW
* PUTC writes through the row pointer, which only
* SCRADDR sets - PUTS sets it for itself
 TAX
 JSR SCRADDR
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #$2A
 LDX UPN
 BMI UPF2
 TXA
 ORA #$30
UPF2 JSR CONV
 JSR PUTC
 LDA #$2F
 JSR CONV
 JSR PUTC
 LDA #5
 STA SCRCOL
 LDY #0
 LDX UPN
 BMI UPF4
 BNE UPF3
* 0/: what ProDOS has
 JSR MLI
 DFB $C7
 DA UPGP
 JMP UPF5
UPF3 TXA
 TAY
UPF4 LDA #<UPVAL
 STA ZPT2
 LDA #>UPVAL
 STA ZPT2+1
 LDX #1
 JSR PXSVC
UPF5 LDA #<UPVAL
 LDX #>UPVAL
 LDY UPVAL
 BNE UPF6
 LDA #<UPNS
 LDX #>UPNS
UPF6 STA STRPTR
 STX STRPTR+1
 JSR PUTS
 INC UPN
 LDA UPN
 CMP #10
 BCC UPF1
* what they are for
 LDA #18
 STA SCRROW
 LDA #<UPH1
 STA STRPTR
 LDA #>UPH1
 STA STRPTR+1
 JSR UPLINE
 LDA #19
 STA SCRROW
 LDA #<UPH2
 STA STRPTR
 LDA #>UPH2
 STA STRPTR+1
 JSR UPLINE
* which one
 LDA #14
 STA UPROW
 LDA #<UPPN
 STA STRPTR
 LDA #>UPPN
 STA STRPTR+1
 JSR UPROMPT
 BCS UPFX9
 CPY #0
 BEQ UPFX9
 LDA UBUF
 AND #$7F
 SEC
 SBC #$30
 CMP #10
 BCS UPFXR
 STA UPD
* what to
 INC UPROW
 LDA #<UPPV
 STA STRPTR
 LDA #>UPPV
 STA STRPTR+1
 JSR UPROMPT
 DEC UPROW
 BCS UPFXR
* UBUF, Y long -> FNBUF2, length first
 STY FNBUF2
 LDX #0
UPF8 CPX FNBUF2
 BCS UPF9
 LDA UBUF,X
 AND #$7F
 STA FNBUF2+1,X
 INX
 BNE UPF8
UPF9 LDA #<FNBUF2
 STA ZPT1
 LDA #>FNBUF2
 STA ZPT1+1
 LDY UPD
 BEQ UPF10
* 1/-9/: into the table.  An empty answer clears it.
* A bad directory name, or one over 64 expanded, is
* refused (C=1, PREFIX.S PXSET) and said as one.
 LDX #2
 JSR PXSVC
 BCC UPF11
 LDA #$40
 JSR URESULT
 JMP UPFX
* 0/: expanded first - it may be given as 1/SUB -
* then SET_PREFIX.  An empty answer leaves it be:
* ProDOS always has a prefix here.
UPF10 LDA FNBUF2
 BEQ UPFXR
 LDX #0
 JSR PXSVC
 JSR MLI
 DFB $C6
 DA UPSP
 BCC UPF11
 JSR URESULT
 JMP UPFX
UPF11 JSR SVSET
 BCC UPFXR
 JSR URESULT
UPFXR JMP UPFX
UPFX9 LDA #14
 STA UPROW
 RTS
* UPLINE: STRPTR at column 1 of SCRROW
UPLINE LDA #1
 STA SCRCOL
 STZ SCRATR
 JMP PUTS

* ---- SVSET: write */COBOL.SETTINGS --------------
* The layout is in EQUATES2 (SETBUF).  C=1 + A =
* the ProDOS error if it could not be written - a
* write-protected system disk, most likely.
SVSET LDX #7
SVS0 LDA SVHDR,X
 STA SETBUF,X
 DEX
 BPL SVS0
 LDA PRSLOT
 STA SETBUF+4
 LDA PRMODE
 STA SETBUF+5
 LDA #<SETBUF+8
 STA ZPT2
 LDA #>SETBUF+8
 STA ZPT2+1
 LDA #1
 STA UPN
SVS1 LDY UPN
 LDX #1
 JSR PXSVC
 CLC
 LDA ZPT2
 ADC #64
 STA ZPT2
 BCC SVS2
 INC ZPT2+1
SVS2 INC UPN
 LDA UPN
 CMP #10
 BCC SVS1
* 0/ at SETBUF+584, where ZPT2 has arrived
 LDA ZPT2
 STA SVGP+1
 LDA ZPT2+1
 STA SVGP+2
 JSR MLI
 DFB $C7
 DA SVGP
 LDA #<SVNAM
 STA FNAMP
 LDA #>SVNAM
 STA FNAMP+1
 LDA #<SETBUF
 STA FADDR
 LDA #>SETBUF
 STA FADDR+1
 LDA #<SETLEN
 STA FLEN
 LDA #>SETLEN
 STA FLEN+1
 STZ FAUX
 STZ FAUX+1
 JMP FSAVE
* 'SET1' and four bytes kept for later
SVHDR DFB $53,$45,$54,$31,0,0,0,0
SVNAM DFB 16
 ASC '*/COBOL.SETTINGS'
SVGP DFB 1
 DA 0
UPGP DFB 1
 DA UPVAL
UPSP DFB 1
 DA FNBUF1
UPN DFB 0
UPD DFB 0
UPVAL DS 66
UPFT DFB 8
 ASC 'PREFIXES'
UPNS DFB 9
 ASC '(not set)'
UPPN DFB 22
 ASC 'Which one (0 to 9)?   '
UPPV DFB 13
 ASC 'New prefix?  '
UPH1 DFB 45
 ASC '0/ is where programs are; 1/-9/ are for data.'
UPH2 DFB 39
 ASC '1/CUST.DAT means CUST.DAT in prefix 1/.'

* --- DOCAT: list the disk ------------------------
* CATFILT = 0 lists everything.  Options 2 and 3
* will point it at a type list instead, so the
* picker shows only the files EDIT can open - which
* is why CATALOG lives in the library and not in
* here.
DOCAT LDA #0
 STA CATFILT
 STA CATFILT+1
 JSR CATALOG
 BCC DCOK
* CATALOG returns C=1 + A = the ProDOS error.  Show
* it: a code we can look up beats a silent menu that
* looks like the key did nothing.
 PHA
 JSR CLRSCR
 LDA #14
 STA SCRROW
 LDA #2
 STA SCRCOL
 STZ SCRATR
 LDA #<SCATE
 STA STRPTR
 LDA #>SCATE
 STA STRPTR+1
 JSR PUTS
 PLA
 JSR MHEXB
 JSR GETK
DCOK RTS

* --- MHEXB: A as two hex digits at the cursor ---
* The message left SCRPTR on the row and SCRCOL past
* its text, so the digits land right after the '$'.
MHEXB PHA
 LSR
 LSR
 LSR
 LSR
 JSR MHNIB
 PLA
 AND #$0F
MHNIB CMP #10
 BCC MHN0
 CLC
 ADC #$37
 JMP MHN1
MHN0 CLC
 ADC #$30
MHN1 JSR CONV
 JMP PUTC


* --- GETK: wait for a key -> A (ASCII) ---
GETK JSR WAITKEY
 AND #$7F
 RTS
SCATE DFB 15
 ASC 'Catalog error $'

