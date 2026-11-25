* SYSMENU.S  the menu and overlay dispatch
* PUT from COBOLSYS.S - no ORG, not assembled
* alone.  One symbol table spans every PUT.
*
* === MENU ===
* INIT80 already ran in COLD; redrawing the menu
* only needs the screen cleared.
*
* THE DATE IS DRAWN EVERY TIME, not once at startup.
* It costs nothing - the four bytes are already in
* ProDOS's global page - and it means that when a
* clock IS found the top line proves it on every
* return from every overlay, rather than in one
* message that scrolled away at boot.
* EVERYTHING IS CENTRED.  The title on row 0, and
* the menu as one block: its longest line, option 1,
* is centred and the others start where it starts,
* so the numbers stay in a column.  The block is
* thirteen rows, 6 to 18, which leaves five blank
* rows above it and five below.
MCOL EQU MENUCOL
MENU JSR CLRSCR
 STZ SCRROW
 LDA #31
 STA SCRCOL
 STZ SCRATR
 LDA #<L0
 STA STRPTR
 LDA #>L0
 STA STRPTR+1
 JSR PUTS
 JSR DTMDATE
 LDA #<DTBUF
 STA STRPTR
 LDA #>DTBUF
 STA STRPTR+1
 JSR NFPUTR
 STZ MI
ML1 LDX MI
 LDA MTAB,X
 CMP #$FF
 BEQ MLDN
 STA SCRROW
 LDA MTAB+1,X
 STA STRPTR
 LDA MTAB+2,X
 STA STRPTR+1
 LDA #MCOL
 STA SCRCOL
 STZ SCRATR
 JSR PUTS
 LDA MI
 CLC
 ADC #3
 STA MI
 JMP ML1
MLDN JSR GETK
 CMP #$31
 BEQ MO1
 CMP #$32
 BEQ MO2
 CMP #$33
 BEQ MO3
 CMP #$34
 BEQ MO4
 CMP #$35
 BEQ MO5
 CMP #$36
 BEQ MO6
 CMP #$37
 BEQ MO7
 CMP #$38
 BEQ MO8
 CMP #$39
 BEQ MO9
 CMP #$52
 BEQ MOR
 CMP #$72
 BEQ MOR
 JMP MLDN
* The order on the screen is the order of the work:
* write it (1-4), build it (5-6), look at what it
* made (7).  R still runs a program, as option 6
* does, because it was R for long enough that
* fingers know it.
MO1 JSR DOEDIT
 JMP MENU
MO2 JSR DOFMT
 JMP MENU
MO3 JSR DOQRY
 JMP MENU
MO4 JSR DORPT
 JMP MENU
MO5 JSR DOCMP
 JMP MENU
MO6 JSR DORUN
 JMP MENU
MO7 JSR DOVIEW
 JMP MENU
MO8 JSR DOUTIL
 JMP MENU
MO9 JMP DOQUIT
MOR JSR DORUN
 JMP MENU

* --- RUNOVL: A/X -> pathname; load it and run it -
* AN OVERLAY IS A SUBROUTINE.  It is entered with
* JSR and leaves with RTS, so the menu is still
* sitting at $2000 when it finishes and nothing has
* to be reloaded.  It may use every byte of the
* band, because only one is ever resident - the
* next BLOAD simply writes over it.
* ---- DOUTIL: the Utilities overlay -------------
* At UTLBASE ($A000), above the 16K COPY streams
* through - not at OVLBASE with the others.
DOUTIL LDA #<UTLNAM
 STA LDNAME
 LDA #>UTLNAM
 STA LDNAME+1
 STZ LDADDR
 LDA #>UTLBASE
 STA LDADDR+1
 STZ LDLEN
 LDA #$10
 STA LDLEN+1
 JSR LOADF
 BCS DFER
 JMP UTLBASE

RUNOVL STA LDNAME
 STX LDNAME+1
 JSR LOADOVL
 BCS DFER
 JSR OVLBASE
 RTS
* --- RUNLOW: the same, at LOWBASE ---------------
* A/X -> pathname, Y = the most pages to read.  The
* page limit is what keeps a low overlay off what
* lies above it: the object for the VM, the p-code
* buffer for the compiler.  JMP, not JSR - the
* overlay's RTS goes straight back to our caller.
RUNLOW JSR LDLOW
 BCS DFER
 JMP LOWBASE
* LDLOW: the load alone, C=1 on failure.  VIEW
* needs it apart: it enters EDIT at its second door
LDLOW STA LDNAME
 STX LDNAME+1
 STZ LDLEN
 STY LDLEN+1
 LDA #<LOWBASE
 STA LDADDR
 LDA #>LOWBASE
 STA LDADDR+1
 JMP LOADF
DFER LDA #<SLDER
 STA STRPTR
 LDA #>SLDER
 STA STRPTR+1
 JMP MSG

DOFMT LDA #<FMTNAME
 LDX #>FMTNAME
 JMP RUNOVL

DOEDIT LDA #<EDTNAME
 LDX #>EDTNAME
 LDY #EDPGS
 JMP RUNLOW

* --- DOVIEW: EDIT, entered at its second door ----
* VIEW is EDIT showing a data file read-only, so it
* is the same overlay entered at OVLBASE+3, where
* EDIT keeps a JMP EDVIEW beside its JMP EDIT.  The
* JMP here is a tail call: EDIT's RTS comes back to
* MO7's JSR.
DOVIEW LDA #<EDTNAME
 LDX #>EDTNAME
 LDY #EDPGS
 JSR LDLOW
 BCS DVER
 JMP LOWBASE+3
DVER JMP DFER

DOQRY LDA #<QRYNAME
 LDX #>QRYNAME
 JMP RUNOVL

* --- DOCMP: the compiler, which is TWO overlays --
* The only menu option that loads more than one, and
* the menu is the right place to sequence them: an
* overlay cannot load its successor, because the
* loader would be writing over the code that called
* it and the return address on the stack points into
* what is being replaced.
*
* CMPERR is tested between the two.  Compiling a
* PROCEDURE DIVISION against a symbol table that was
* never finished does not fail loudly - every data
* name is simply unknown - so pass two must not be
* reached after pass one has said no.
DOCMP LDA #<CMP1NAM
 LDX #>CMP1NAM
 LDY #CMPPGS
 JSR RUNLOW
 LDA CMPERR
 BNE DCX
 LDA #<CMP2NAM
 LDX #>CMP2NAM
 LDY #CMPPGS
 JMP RUNLOW
DCX RTS

DORPT LDA #<RPTNAME
 LDX #>RPTNAME
 LDY #RPPGS
 JMP RUNLOW

* --- DORUN: load an object and run it ------------
* THE EXECUTE PATH.  Until this existed a program
* could be edited and compiled and then only looked
* at: nothing loaded a .OBJ anywhere the interpreter
* would find it.  This is the piece that turns the
* tool chain into a system - it is the whole reason
* a beta tester can press keys and see something.
*
* Two loads and a JSR.  The object goes to OBJBASE
* FIRST, then the interpreter over the bottom of the
* band - the order matters only in that LOADOVL
* clobbers LDADDR/LDLEN, so the object's load has
* to be set up by hand and done first.
*
* The interpreter is an overlay like any other: JSR
* $8000, RTS back here when HALT is reached.  A
* fault inside it VMDIEs and RTSes too, so the menu
* comes back either way.
* The question goes under the menu, not over it:
* UPROMPT's row and column are variables, set here
* and put back for the Utilities screen.
DORUN LDA #<SRUN
 STA STRPTR
 LDA #>SRUN
 STA STRPTR+1
 LDA #20
 STA UPROW
 LDA #MCOL
 STA UPCOL
 JSR UNAME
 LDA #14
 STA UPROW
 LDA #1
 STA UPCOL
 BCS DRX
* DORUN2: the name is in FNBUF1 - typed, or the
* turnkey name (TKRUN)
* TEST, TEST.OBJ and even TEST.COB all run TEST.OBJ:
* SETSFX forces the OBJ suffix, which is part of the
* ProDOS name since 2026-11-07.  FLOAD is the
* library whole-file loader; LOADF here does not
* know the suffix table.
DORUN2 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 LDA #$4A
 LDX #1
 JSR SETSFX
 LDA #<RUNBASE
 STA FADDR
 LDA #>RUNBASE
 STA FADDR+1
 LDA #<RUNMAX
 STA FLEN
 LDA #>RUNMAX
 STA FLEN+1
 JSR FLOAD
 BCS DRERR
 LDA #<VMNAME
 LDX #>VMNAME
 LDY #VMPGS
 JMP RUNLOW
* $40 is the name that was typed: the prefix
* service makes every name that breaks ProDOS's
* rules into one (DECISIONS 8.10).  Anything else
* is the program that is not there, or a disk fault.
DRERR CMP #$40
 BEQ DRBAD
 JMP DFER
DRBAD LDA #<SBADN
 STA STRPTR
 LDA #>SBADN
 STA STRPTR+1
 JMP MSG
DRX RTS

* --- STUBM: 'not built yet' + wait a key ---
STUBM LDA #<SNOTB
 STA STRPTR
 LDA #>SNOTB
 STA STRPTR+1
 JMP MSG

* --- MSG: STRPTR line under the menu + key ---
* Row 20, two below Choice?, at the menu's column -
* row 14 is option 7 now.
* The rows are cleared first: the message lands on
* the row a name was typed on (RUN's), and a short
* message over a long name left its tail showing -
* "Bad file name (key)Y FILE!".  Row 21 too, for a
* name long enough to wrap.
MSG LDX #20
 JSR CLRROW
 LDX #21
 JSR CLRROW
 LDA #20
 STA SCRROW
 LDA #MCOL
 STA SCRCOL
 LDA #0
 STA SCRATR
 JSR PUTS
 JSR GETK
 RTS

* --- GETK: wait for a key -> A (ASCII) ---
* Was its own polling loop; now just the library's
* WAITKEY, which means it also feeds RNDSEED
* instead of idling.  One key-wait loop in the
* system is the right number.
GETK JSR WAITKEY
 AND #$7F
 RTS

* --- SETPFX: ensure a prefix is set ---
SETPFX JSR GETPFX
 LDA SYSPFX
 BNE SPXD
 JSR ONLINE
 LDA CATBLK
 AND #$0F
 STA VLEN
 BEQ SPXD
 CLC
 ADC #2
 STA SYSPFX
 LDA #$2F
 STA SYSPFX+1
 LDX #0
 LDY #2
SPX1 LDA CATBLK+1,X
 AND #$7F
 STA SYSPFX,Y
 INY
 INX
 CPX VLEN
 BCC SPX1
 LDA #$2F
 STA SYSPFX,Y
 JSR SETPRE
* SYSPFX is */ from here on - the prefix COBOL.SYSTEM
* was started in, or the one just made from the boot
* volume - and the aux card gets a copy (PXINIT)
SPXD JMP PXINIT

* --- DOQUIT: ProDOS QUIT (no return) ---
DOQUIT JSR MLI
 DFB $65
 DA QPARM
 RTS

* --- MLI wrappers ---
ONLINE JSR MLI
 DFB $C5
 DA OLPARM
 RTS
GETPFX JSR MLI
 DFB $C7
 DA GPPARM
 RTS
SETPRE JSR MLI
 DFB $C6
 DA SPPARM
 RTS
OPENF JSR MLI
 DFB $C8
 DA OPARM
 RTS
READF JSR MLI
 DFB $CA
 DA RWPARM
 RTS
CLOSEF JSR MLI
 DFB $CC
 DA CLPARM
 RTS

* --- MLI parameter blocks ---
* OPARM's pathname and RWPARM's address/length are
* filled in by LOADF at run time.
OLPARM DFB 2
 DFB 0
 DA CATBLK
GPPARM DFB 1
 DA SYSPFX
SPPARM DFB 1
 DA SYSPFX
OPARM DFB 3
 DA 0
 DA IOBUF
 DFB 0
RWPARM DFB 4
 DFB 0
 DA 0
 DA 0
 DA 0
CLPARM DFB 1
 DFB 0
QPARM DFB 4
 DFB 0
 DA 0
 DFB 0
 DA 0

* --- menu row/string table ---
* Every option at column MCOL, with a blank row
* between the groups.
MTAB DFB 6
 DA L1
 DFB 7
 DA L2
 DFB 8
 DA L3
 DFB 9
 DA L4
 DFB 11
 DA L5
 DFB 12
 DA L6
 DFB 14
 DA L7
 DFB 15
 DA L8
 DFB 16
 DA L9
 DFB 18
 DA LC
 DFB $FF

* --- strings (length-prefixed for PUTS) ---
L0 DFB 17
 ASC 'COBOL SYSTEM v1.0'
L1 DFB 45
 ASC '1) EDIT a New or Existing Program'
 ASC ' or Template'
* "or Menu" since FORMAT designs menus (OA-M,
* FMTMNU.S) - the user's wording, 2026-11-11
L2 DFB 41
 ASC '2) FORMAT a Screen for Data Entry'
 ASC ' or Menu'
L3 DFB 22
 ASC '3) Create a QUERY File'
L4 DFB 23
 ASC '4) Create a REPORT File'
L5 DFB 26
 ASC '5) COMPILE a COBOL Program'
L6 DFB 22
 ASC '6) RUN a COBOL Program'
L7 DFB 19
 ASC '7) VIEW a Data File'
L8 DFB 12
 ASC '8) Utilities'
L9 DFB 17
 ASC '9) Exit to ProDOS'
LC DFB 7
 ASC 'Choice?'
SNOTB DFB 21
 ASC 'Not built yet (a key)'
SLDER DFB 25
 ASC 'Overlay load failed (key)'
SBADN DFB 19
 ASC 'Bad file name (key)'
SRUN DFB 18
 ASC 'Program to run?   '

* --- ProDOS pathnames (length-prefixed) ---
* Spelled as explicit bytes rather than ASC: Merlin
* sets the high bit on ASC text and ProDOS wants it
* clear in a pathname.
FMTNAME DFB 6
 DFB $46,$4F,$52,$4D,$41,$54
EDTNAME DFB 4
 DFB $45,$44,$49,$54
RPTNAME DFB 6
 DFB $52,$45,$50,$4F,$52,$54
QRYNAME DFB 5
 DFB $51,$55,$45,$52,$59
VMNAME DFB 2
 DFB $56,$4D
CMP1NAM DFB 8
 DFB $43,$4F,$4D,$50,$49,$4C,$45,$31
CMP2NAM DFB 8
 DFB $43,$4F,$4D,$50,$49,$4C,$45,$32
* UTILITIES, not UTIL: that is a directory on the
* system disk already (Merlin's)
UTLNAM DFB 9
 DFB $55,$54,$49,$4C,$49
 DFB $54,$49,$45,$53
LIBNAM DFB 9
 DFB $43,$4F,$42,$4F,$4C,$2E
 DFB $4C,$49,$42
AUXNAM DFB 9
 DFB $43,$4F,$42,$4F,$4C,$2E
 DFB $41,$55,$58

* --- variables + buffers ---
VLEN DFB 0
MI DFB 0
LDNAME DS 2
LDADDR DS 2
LDLEN DS 2
