* FILEIO.S  suffixed-name file load and save
* A library module (PUT it from LIB.S).  Lives in
* COBOL.LIB with the rest of the runtime, so a
* compiled p-code program gets the same file layer
* the tools use.
*
* THE SUFFIX CONVENTION
* A COBOL program says
*     SELECT LEAD-FILE ASSIGN TO "LEADS.DAT"
* and what lands on the disk is a file named LEADS
* with ProDOS type DAT.  The suffix is not part of
* the name - it IS the type.  ProDOS has carried a
* real type byte since 1983; spelling the type
* into the name as well would be saying the same
* thing twice, and the two could disagree.
*
* A suffix is recognised only when it is exactly
* three characters after a period, and only when
* it appears in FTTAB.  So COBOL.SYSTEM and
* COBOL.LIB keep their literal names - SYSTEM is
* not three characters, and LIB is deliberately
* absent from the table, because the library has
* to be loaded before the routine that reads the
* table exists.
*
* CHANGED 2026-11-07: THE SUFFIX STAYS IN THE NAME.
* The type is still set from it, but LEADS.COB is
* now a file called LEADS.COB.  Dropping it made the
* source, the object and the data file of one
* program all the same ProDOS name - and ProDOS will
* not hold two files of one name in a directory,
* whatever their types.  Running the MEDIA sample
* opened its own source as its data file and
* replaced it.  FISFX, below, supplies a suffix where
* a caller has a bare name and knows what it wants.
*
* No path building here.  ProDOS prepends the
* current prefix to any pathname that does not
* start with a slash, so passing the bare name is
* enough.

* ---- SPLITNM: split a suffixed name ----
* in:  FNAMP -> length-prefixed name
* out: FNBUF1 = length-prefixed base name, upper
*      cased;  FTYPE = ProDOS file type
*      C=0 a suffix was recognised and stripped
*      C=1 none; whole name kept, FTYPE = $06 BIN
* FNAMP is a public variable at $0CC5, not zero
* page, so it cannot be indexed through directly -
* (abs),Y does not exist on this processor.  Copy
* it into ZPT1 first.  Same trap CATALOG hits with
* CATFILT, and the assembler calls both of them
* "bad address mode".
FISPLT LDA FNAMP
 STA ZPT1
 LDA FNAMP+1
 STA ZPT1+1
* The copy into FNBUF1 and the fold to upper case
* are done in the aux card now, by the prefix
* service, which also turns */ 0/ and 1/-9/ into
* the directories they name (PREFIX.S, 2026-11-11).
* Every load, save and OPEN in the system comes
* through here, so that one call gives the whole
* system the prefixes - and it is shorter than the
* loop it replaced.
 LDX #0
 JSR PXGATE
 LDA FNBUF1
 STA SNLEN
 BEQ SNNO
* a suffix needs at least X.YYY - five characters
 LDA SNLEN
 CMP #5
 BCC SNNO
 SEC
 SBC #3
 STA SNDOT
 TAY
 LDA FNBUF1,Y
 CMP #$2E
 BNE SNNO
 LDY SNDOT
 INY
 LDA FNBUF1,Y
 STA SNS
 INY
 LDA FNBUF1,Y
 STA SNS+1
 INY
 LDA FNBUF1,Y
 STA SNS+2
* walk FTTAB: three characters then a type byte
 LDX #0
SNT LDA FTTAB,X
 BEQ SNNO
 CMP SNS
 BNE SNTN
 LDA FTTAB+1,X
 CMP SNS+1
 BNE SNTN
 LDA FTTAB+2,X
 CMP SNS+2
 BNE SNTN
 LDA FTTAB+3,X
 STA FTYPE
 CLC
 RTS
SNTN TXA
 CLC
 ADC #4
 TAX
 JMP SNT
SNNO LDA #$06
 STA FTYPE
 SEC
 RTS

* ---- FLOAD: read a whole file ----
* in:  FNAMP -> suffixed name
*      FADDR = where to put it
*      FLEN  = maximum bytes to read
* out: C=1 + A = MLI error on failure
FILOAD JSR FISPLT
 LDA #<FNBUF1
 STA FOPARM+1
 LDA #>FNBUF1
 STA FOPARM+2
 LDA #<IOBUF
 STA FOPARM+3
 LDA #>IOBUF
 STA FOPARM+4
 JSR FPOPEN
 BCS FLX
 LDA FOPARM+5
 STA FRWPRM+1
 STA FCLPRM+1
 LDA FADDR
 STA FRWPRM+2
 LDA FADDR+1
 STA FRWPRM+3
 LDA FLEN
 STA FRWPRM+4
 LDA FLEN+1
 STA FRWPRM+5
 JSR FPREAD
 PHP
 JSR FPCLOS
 PLP
FLX RTS

* ---- FSAVE: write a whole file ----
* in:  FNAMP -> suffixed name (gives the type)
*      FADDR = data to write
*      FLEN  = how many bytes
* out: C=1 + A = MLI error on failure
* DESTROY first, so a save over an existing file
* replaces it rather than failing.  A missing file
* makes DESTROY complain; we ignore that, because
* the CREATE that follows is the call that matters.
FISAVE JSR FISPLT
 LDA #<FNBUF1
 STA FDPARM+1
 LDA #>FNBUF1
 STA FDPARM+2
 JSR FPDEST
 LDA #<FNBUF1
 STA FCPARM+1
 LDA #>FNBUF1
 STA FCPARM+2
 LDA FTYPE
 STA FCPARM+4
 LDA FAUX
 STA FCPARM+5
 LDA FAUX+1
 STA FCPARM+6
 JSR FPCREA
 BCS FSX
 LDA #<FNBUF1
 STA FOPARM+1
 LDA #>FNBUF1
 STA FOPARM+2
 LDA #<IOBUF
 STA FOPARM+3
 LDA #>IOBUF
 STA FOPARM+4
 JSR FPOPEN
 BCS FSX
 LDA FOPARM+5
 STA FRWPRM+1
 STA FCLPRM+1
 LDA FADDR
 STA FRWPRM+2
 LDA FADDR+1
 STA FRWPRM+3
 LDA FLEN
 STA FRWPRM+4
 LDA FLEN+1
 STA FRWPRM+5
 JSR FPWRIT
 PHP
 JSR FPCLOS
 PLP
FSX RTS

* ---- the suffix table ----
* Three characters, then the ProDOS type byte.
* $47-$4D is our own contiguous block, in the
* order the system uses them.  See FILETYPES.md.
*
* DAT is NOT a type of its own: a data file is an
* ordinary TXT with its record length in the aux
* field.  That is exactly what BASIC.SYSTEM does
* for a random-access text file - OPEN name,L128
* leaves 128 in aux - so we are following the
* machine's own convention rather than inventing
* one beside it.  Set FAUX before calling FSAVE.
* ---- FISFX: give a name the suffix of type A ----
* Slot 106, vector SETSFX.  in: FNAMP -> the name,
* A = the ProDOS type wanted, X = 0 to ADD the
* suffix only if the name has none, X = 1 to FORCE
* it, replacing any suffix already there.
* out: FNBUF1 = the name with its suffix, upper
* cased; FTYPE = A.  FNAMP may point at FNBUF1.
*   EDIT saving TEST     -> TEST.COB      (A=$47 X=0)
*   COMPILE of TEST.COB  -> TEST.OBJ      (A=$4A X=1)
*   RUN TEST             -> TEST.OBJ      (A=$4A X=1)
* A base name over eleven letters is cut to eleven,
* so the whole thing fits ProDOS's fifteen.
FISFX STA SXTYP
 STX SXMOD
 JSR FISPLT
 BCS SXADD
 LDA SXMOD
 BEQ SXOK
 LDA SNDOT
 SEC
 SBC #1
 STA FNBUF1
SXADD LDX #0
SXF1 LDA FTTAB,X
 BEQ SXOK
 LDA FTTAB+3,X
 CMP SXTYP
 BEQ SXF2
 TXA
 CLC
 ADC #4
 TAX
 JMP SXF1
* The cut is to the LAST PART of the name, after its
* last slash.  It cut the whole name, which no name
* with a directory in it survived - /HD/DATA/LEADS
* became /HD/DATA/LE - and since the prefixes every
* name can have one (2026-11-11).
SXF2 LDY FNBUF1
 BEQ SXF5
SXF4 LDA FNBUF1,Y
 CMP #$2F
 BEQ SXF5
 DEY
 BNE SXF4
SXF5 STY SXSL
 LDA FNBUF1
 SEC
 SBC SXSL
 CMP #12
 BCC SXF6
 LDA SXSL
 CLC
 ADC #11
 STA FNBUF1
SXF6 LDA FNBUF1
SXF3 TAY
 LDA #$2E
 STA FNBUF1+1,Y
 LDA FTTAB,X
 STA FNBUF1+2,Y
 LDA FTTAB+1,X
 STA FNBUF1+3,Y
 LDA FTTAB+2,X
 STA FNBUF1+4,Y
 TYA
 CLC
 ADC #4
 STA FNBUF1
SXOK LDA SXTYP
 STA FTYPE
 CLC
 RTS
SXTYP DFB 0
SXMOD DFB 0
SXSL DFB 0

FTTAB ASC 'COB'
 DFB $47
 ASC 'SNP'
 DFB $48
 ASC 'DCT'
 DFB $49
 ASC 'OBJ'
 DFB $4A
 ASC 'SCR'
 DFB $4B
 ASC 'RPT'
 DFB $4C
 ASC 'QRY'
 DFB $4D
* a menu FORMAT designed (2026-11-11)
 ASC 'MNU'
 DFB $4E
 ASC 'DAT'
 DFB $04
 ASC 'TXT'
 DFB $04
 ASC 'BIN'
 DFB $06
 ASC 'SYS'
 DFB $FF
 DFB 0

* ---- MLI wrappers ----
* Named apart from PRODOS.S's so that both can be
* assembled into one program while FORMAT still
* carries its own copy.  When PRODOS.S and DISKIO.S
* move into the library, these replace them.
FPCREA JSR MLI
 DFB $C0
 DA FCPARM
 RTS
FPDEST JSR MLI
 DFB $C1
 DA FDPARM
 RTS
FPOPEN JSR MLI
 DFB $C8
 DA FOPARM
 RTS
FPREAD JSR MLI
 DFB $CA
 DA FRWPRM
 RTS
FPWRIT JSR MLI
 DFB $CB
 DA FRWPRM
 RTS
FPCLOS JSR MLI
 DFB $CC
 DA FCLPRM
 RTS

* ---- MLI parameter blocks ----
FCPARM DFB 7
 DA 0
 DFB $C3
 DFB $06
 DA 0
 DFB 1
 DA 0
 DA 0
FDPARM DFB 1
 DA 0
FOPARM DFB 3
 DA 0
 DA 0
 DFB 0
FRWPRM DFB 4
 DFB 0
 DA 0
 DA 0
 DA 0
FCLPRM DFB 1
 DFB 0

* ---- private variables ----
SNLEN DFB 0
SNDOT DFB 0
SNS DS 3
