* CATALOG.S  directory listing
* A library module (PUT it from LIB.S).  Any tool
* or compiled program can call it, which is the
* point: picking a file is something every part of
* the system needs to do.
*
* Two modes, chosen by CATFILT:
*   CATFILT = 0        list everything
*   CATFILT -> a list  list only those types.  The
*     list is type bytes, terminated by $00.
* So EDIT lists COB and SNP, FORMAT lists DCT, and
* a data-entry program lists TXT - each showing
* only what it can actually open.
*
* WHY WE HAVE OUR OWN
* BASIC.SYSTEM's CATALOG knows a handful of type
* abbreviations and prints everything else as raw
* hex, so our whole $47-$4D block would show up as
* numbers.  Ours reads the same table FILEIO uses
* to parse suffixes - one table, both directions -
* so a file that saves as LEADS.DCT lists as DCT.
*
* A directory is just a file.  OPEN it, READ it,
* and walk it: 512 bytes at a time, four bytes of
* block linkage, then thirteen 39-byte entries.

* CATP walks the directory entries, so it must be a
* zero-page pointer: (abs),Y is not an addressing
* mode this processor has.  It borrows ZPT2, which
* survives PUTS and PUTC - PUTS uses ZPT1 as
* STRPTR, and the paging call in the middle of the
* entry loop goes through PUTS.
CATP EQU ZPT2

* ---- CATALOG: list the current directory ----
* out: C=1 + A = MLI error
* CATX is 134 bytes away and the 6502 stops at 127,
* so this test cannot be a branch.  It was one, and
* the assembler would have caught it the moment the
* body between here and there grew past its limit -
* which is exactly what happened, quietly, some time
* after the module last assembled clean.
CTLIST JSR CATCPY
 JSR CATPFX
 BCC CTL0
 JMP CATX
* Close everything first.  If any file was left open
* on IOBUF, our OPEN would fail $56 (buffer in use).
* CLOSE ref 0 closes all files and frees the buffer;
* with none open it is a no-op.
CTL0 LDA #0
 STA CCLPRM+1
 JSR CPCLOS
 LDA #<CATPATH
 STA COPARM+1
 LDA #>CATPATH
 STA COPARM+2
 LDA #<IOBUF
 STA COPARM+3
 LDA #>IOBUF
 STA COPARM+4
 JSR CPOPEN
 BCS CATX
 LDA COPARM+5
 STA CRWPRM+1
 STA CCLPRM+1
 JSR CLRSCR
 JSR CATHDR
CATBL LDA #<CATBLK
 STA CRWPRM+2
 LDA #>CATBLK
 STA CRWPRM+3
 STZ CRWPRM+4
 LDA #2
 STA CRWPRM+5
 JSR CPREAD
 BCS CATDN
 LDA CRWPRM+6
 ORA CRWPRM+7
 BEQ CATDN
* four bytes of prev/next block pointers first
 LDA #<CATBLK
 CLC
 ADC #4
 STA CATP
 LDA #>CATBLK
 ADC #0
 STA CATP+1
 LDA #13
 STA CATN
CATE JSR CATONE
 CLC
 LDA CATP
 ADC #39
 STA CATP
 LDA CATP+1
 ADC #0
 STA CATP+1
 DEC CATN
 BNE CATE
 JMP CATBL
CATDN JSR CPCLOS
 JSR CATFTR
 JSR WAITKEY
 CLC
 RTS
CATX RTS

* ---- CATCPY: copy the filter list in ----
* CATFILT is a public variable, not zero page, so
* we cannot index through it directly.  Copy the
* list into CATFL once, up front, before anything
* touches ZPT2 - after this the filter is checked
* with absolute indexing and no pointer at all.
CATCPY LDA CATFILT
 ORA CATFILT+1
 BNE CC1
 LDA #0
 STA CATFL
 RTS
CC1 LDA CATFILT
 STA ZPT1
 LDA CATFILT+1
 STA ZPT1+1
 LDY #0
CC2 LDA (ZPT1),Y
 STA CATFL,Y
 BEQ CCD
 INY
 CPY #15
 BCC CC2
 LDA #0
 STA CATFL,Y
CCD RTS

* ---- CATPFX: current prefix -> CATPATH ----
* GET_PREFIX hands back a trailing slash - /COBOL/ -
* and OPEN will not accept one, so drop it before we
* try to open the directory it names.
CATPFX JSR CPGETP
 BCS CPXX
 LDA CATPATH
 BEQ CPXF
 TAY
 LDA CATPATH,Y
 CMP #$2F
 BNE CPXO
 DEC CATPATH
CPXO CLC
 RTS
CPXF SEC
CPXX RTS

* ---- CATONE: consider the entry at CATP ----
CATONE LDY #0
 LDA (CATP),Y
 BEQ CATOD
 AND #$F0
 CMP #$E0
 BCS CATOD
 LDY #16
 LDA (CATP),Y
 STA CATTYP
 JSR CATFLT
 BCS CATOD
 JSR CATSHOW
CATOD RTS

* ---- CATFLT: C=0 if CATTYP passes the filter ----
CATFLT LDA CATFL
 BEQ CFPASS
 LDX #0
CF1 LDA CATFL,X
 BEQ CFNO
 CMP CATTYP
 BEQ CFPASS
 INX
 CPX #15
 BCC CF1
CFNO SEC
 RTS
CFPASS CLC
 RTS

* ---- CATHDR / CATFTR ----
CATHDR LDA #0
 STA SCRROW
 LDA #2
 STA SCRCOL
 STA SCRATR
 LDA #<HDR
 STA STRPTR
 LDA #>HDR
 STA STRPTR+1
 JSR PUTS
 LDA #2
 STA CATROW
 RTS
CATFTR LDA #23
 STA SCRROW
 LDA #2
 STA SCRCOL
 STZ SCRATR
 LDA #<FTR
 STA STRPTR
 LDA #>FTR
 STA STRPTR+1
 JMP PUTS

* ---- CATPAGE: screen full, wait and start over --
CATPAGE JSR CATFTR
 JSR WAITKEY
 JSR CLRSCR
 JMP CATHDR

* ---- CATSHOW: display the entry at CATP ----
* name at column 2, type at 20, blocks at 26.
CATSHOW LDA CATROW
 CMP #22
 BCC CS0
 JSR CATPAGE
CS0 LDX CATROW
 JSR SCRADDR
 LDA #2
 STA SCRCOL
 LDA #0
 STA SCRATR
* --- name: length is the low nibble of byte 0 ---
 LDY #0
 LDA (CATP),Y
 AND #$0F
 STA CATNL
 LDA #1
 STA CATNI
CSN LDA CATNL
 CMP CATNI
 BCC CSND
 LDY CATNI
 LDA (CATP),Y
 JSR CONV
 JSR PUTC
 INC CATNI
 JMP CSN
CSND JSR CSPAD20
 JSR CATMNE
 JSR CSPAD26
 LDY #19
 LDA (CATP),Y
 STA CATNUM
 LDY #20
 LDA (CATP),Y
 STA CATNUM+1
 JSR CTDEC
 INC CATROW
 RTS

CSPAD20 LDA SCRCOL
 CMP #20
 BCS CSP2D
 LDA #$20
 JSR CONV
 JSR PUTC
 JMP CSPAD20
CSP2D RTS
CSPAD26 LDA SCRCOL
 CMP #26
 BCS CSP6D
 LDA #$20
 JSR CONV
 JSR PUTC
 JMP CSPAD26
CSP6D RTS

* ---- CATMNE: print the type mnemonic ----
* $04 is shown as DAT or TXT depending on the aux
* field: a non-zero aux is a record length, which
* is the only thing that distinguishes a data file
* from plain text.  That is not a fudge - it is
* precisely what the aux field means here.
CATMNE LDA CATTYP
 CMP #$04
 BNE CM1
 LDY #31
 LDA (CATP),Y
 INY
 ORA (CATP),Y
 BEQ CMTXT
 LDA #$44
 STA CATM
 LDA #$41
 STA CATM+1
 LDA #$54
 STA CATM+2
 JMP CMOUT
CMTXT LDA #$54
 STA CATM
 LDA #$58
 STA CATM+1
 LDA #$54
 STA CATM+2
 JMP CMOUT
* otherwise search FILEIO's suffix table backwards
CM1 LDX #0
CM2 LDA FTTAB,X
 BEQ CMHEX
 LDA FTTAB+3,X
 CMP CATTYP
 BEQ CMFND
 TXA
 CLC
 ADC #4
 TAX
 JMP CM2
CMFND LDA FTTAB,X
 STA CATM
 LDA FTTAB+1,X
 STA CATM+1
 LDA FTTAB+2,X
 STA CATM+2
CMOUT LDX #0
CMO1 STX CATXI
 LDA CATM,X
 JSR CONV
 JSR PUTC
 LDX CATXI
 INX
 CPX #3
 BCC CMO1
 RTS
* unknown: print it as $xx, the way ProDOS itself
* would leave it
CMHEX LDA #$24
 JSR CONV
 JSR PUTC
 LDA CATTYP
 LSR
 LSR
 LSR
 LSR
 JSR CMNIB
 LDA CATTYP
 AND #$0F
CMNIB CMP #10
 BCC CMN1
 CLC
 ADC #$37
 JMP CMN2
CMN1 CLC
 ADC #$30
CMN2 JSR CONV
 JMP PUTC

* ---- DEC16: CATNUM right-justified in 5 cols ----
* Repeated subtraction of the powers of ten.  No
* division anywhere on this machine, so this is
* how every number reaches a screen.
CTDEC LDX #0
 STX CATSUP
DC1 LDA #0
 STA CATDIG
DC2 SEC
 LDA CATNUM
 SBC POWL,X
 TAY
 LDA CATNUM+1
 SBC POWH,X
 BCC DC3
 STY CATNUM
 STA CATNUM+1
 INC CATDIG
 JMP DC2
DC3 CPX #4
 BEQ DCEM
 LDA CATDIG
 BNE DCEM
 LDA CATSUP
 BNE DCEM
 LDA #$20
 JMP DCP
DCEM LDA #1
 STA CATSUP
 LDA CATDIG
 CLC
 ADC #$30
DCP STX CATXI
 JSR CONV
 JSR PUTC
 LDX CATXI
 INX
 CPX #5
 BCC DC1
 RTS
POWL DFB $10,$E8,$64,$0A,$01
POWH DFB $27,$03,$00,$00,$00

* ---- MLI wrappers ----
CPOPEN JSR MLI
 DFB $C8
 DA COPARM
 RTS
CPREAD JSR MLI
 DFB $CA
 DA CRWPRM
 RTS
CPCLOS JSR MLI
 DFB $CC
 DA CCLPRM
 RTS
CPGETP JSR MLI
 DFB $C7
 DA CPFPRM
 RTS

* ---- MLI parameter blocks ----
COPARM DFB 3
 DA 0
 DA 0
 DFB 0
CRWPRM DFB 4
 DFB 0
 DA 0
 DA 0
 DA 0
CCLPRM DFB 1
 DFB 0
CPFPRM DFB 1
 DA CATPATH

* ---- literals ----
HDR DFB 28
 ASC 'NAME             TYPE BLOCKS'
FTR DFB 17
 ASC 'Press any key ...'

* ---- private data ----
* CATP is not here - it is ZPT2, declared above.
CATN DFB 0
CATNL DFB 0
CATNI DFB 0
CATROW DFB 0
CATTYP DFB 0
CATM DS 3
CATXI DFB 0
CATNUM DS 2
CATDIG DFB 0
CATSUP DFB 0
* CATFL, CATPATH and CATBLK are not here.  They are
* addresses in the data region - see EQUATES.  The
* 512-byte block buffer in particular has no
* business sitting inside a file that gets loaded
* from disk every time a program starts.
