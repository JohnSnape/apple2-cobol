* PRODOS.S  ProDOS MLI file I/O + DICTLOAD
* Part I - PUT it from FORMAT.S.  Needs a loaded
* COBOL.LIB for the screen vectors; PRHEXB is
* defined here, at the foot of the file.
* Wrappers: PCREATE PDESTROY PRENAME POPEN PREAD
*           PWRITE PCLOSE
* DICTLOAD: read a .DCT file into DCTBUF, set
*           ZPDICT.  WRDCT: write a file the safe
*           way - temporary, then destroy-and-
*           rename.
* Caller sets PATHAD -> length-prefixed pathname.
* All return C=1 + A=MLI error on failure.

* MLI IOBUF DCTBUF ZPDICT now in EQUATES.S

* ---- DICTLOAD: read .DCT into DCTBUF ----
DICTLOAD LDA PATHAD
 STA OPARM+1
 LDA PATHAD+1
 STA OPARM+2
 LDA #<IOBUF
 STA OPARM+3
 LDA #>IOBUF
 STA OPARM+4
 JSR POPEN
 BCS DLX
 LDA OPARM+5
 STA RWPARM+1
 LDA #<DCTBUF
 STA RWPARM+2
 LDA #>DCTBUF
 STA RWPARM+3
 STZ RWPARM+4
 LDA #$04
 STA RWPARM+5
 JSR PREAD
 PHP
 LDA RWPARM+1
 STA CLPARM+1
 JSR PCLOSE
 PLP
 BCS DLX
 LDA #<DCTBUF
 STA ZPDICT
 LDA #>DCTBUF
 STA ZPDICT+1
 CLC
 RTS
DLX SEC
 RTS

* ---- WRDCT: write WLEN bytes to a file ----
* src WSRC, path PATHAD, type WTYPE, aux WAUX.
* THE SAFE WAY (the SAVEFILE pattern from the
* subroutines book):
*   1. write the data to a TEMPORARY file beside
*      the target - the target's name plus .T
*   2. only when it is safely closed, DESTROY the
*      old file
*   3. RENAME the temporary onto the target's name
* At no instant does the disk lack a complete copy
* of the data.  The old DESTROY-then-CREATE left
* nothing on the disk from the DESTROY until the
* WRITE and CLOSE finished - power lost there lost
* the file.  Steps 2 and 3 are directory
* operations only, so the window is as small as
* ProDOS can make it.  (ProDOS has no truncate,
* which is what the DESTROY-first was for; a
* temporary created fresh sidesteps that too.)
* The final name needs TWO SPARE characters (13 of
* ProDOS's 15) for the .T; one too long fails the
* CREATE cleanly with $40, nothing touched.
* On a failure before step 2 the temporary is
* deleted and the old file is untouched.  If the
* old file refuses to DESTROY - locked, say - or
* the RENAME itself fails, the temporary is NOT
* deleted: it is the only copy of the new data,
* and the error says why the target is stale.
WRDCT JSR TMPBLD
* a stray temporary from an interrupted save is
* deleted without comment
 JSR WRTIDY
 LDA #<TMPPATH
 STA CPARM+1
 LDA #>TMPPATH
 STA CPARM+2
 LDA WTYPE
 STA CPARM+4
 LDA WAUX
 STA CPARM+5
 LDA WAUX+1
 STA CPARM+6
 JSR PCREATE
* WRX is a whole routine away now - too far for a
* relative branch - so invert the test and return
* here: on failure the MLI has already set the
* carry and A.
 BCC WRCR1
 SEC
 RTS
WRCR1 LDA #<TMPPATH
 STA OPARM+1
 LDA #>TMPPATH
 STA OPARM+2
 LDA #<IOBUF
 STA OPARM+3
 LDA #>IOBUF
 STA OPARM+4
 JSR POPEN
 BCS WRDROP
 LDA OPARM+5
 STA RWPARM+1
 LDA WSRC
 STA RWPARM+2
 LDA WSRC+1
 STA RWPARM+3
 LDA WLEN
 STA RWPARM+4
 LDA WLEN+1
 STA RWPARM+5
 JSR PWRITE
* the close must happen whatever the write said,
* and a write error outranks the close's own
 PHP
 PHA
 LDA RWPARM+1
 STA CLPARM+1
 JSR PCLOSE
 BCS WRCLE
 PLA
 PLP
 BCS WRDROP
* the data is safe under the temporary name; now
* the two directory steps.  A missing old file
* ($46) is the normal first save.
 LDA PATHAD
 STA DPARM+1
 LDA PATHAD+1
 STA DPARM+2
 JSR PDESTROY
 BCC WRREN
 CMP #$46
 BEQ WRREN
 SEC
 RTS
WRREN LDA #<TMPPATH
 STA RNPARM+1
 LDA #>TMPPATH
 STA RNPARM+2
 LDA PATHAD
 STA RNPARM+3
 LDA PATHAD+1
 STA RNPARM+4
 JMP PRENAME
* the close failed with the write clean: the
* temporary may be incomplete, so the close's
* error is the verdict.  A write error rides over
* it.
WRCLE STA WCERR
 PLA
 PLP
 BCS WRDROP
 LDA WCERR
* a failure while the old file still exists: tidy
* the temporary, report, and the disk is as it was
WRDROP PHA
 JSR WRTIDY
 PLA
WRX SEC
 RTS

* ---- WRTIDY: best-effort delete of the temp ----
WRTIDY LDA #<TMPPATH
 STA DPARM+1
 LDA #>TMPPATH
 STA DPARM+2
 JMP PDESTROY

* ---- TMPBLD: TMPPATH = name at PATHAD + .T ----
* ZPT1 is zone S - caller-saved - and nothing here
* calls anything while it is held.
TMPBLD LDA PATHAD
 STA ZPT1
 LDA PATHAD+1
 STA ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA SVTL
 LDA #1
 STA SVTI
TB1 LDA SVTL
 CMP SVTI
 BCC TB2
 LDY SVTI
 LDA (ZPT1),Y
 STA TMPPATH,Y
 INC SVTI
 JMP TB1
TB2 LDY SVTL
 INY
 LDA #$2E
 STA TMPPATH,Y
 INY
 LDA #$54
 STA TMPPATH,Y
 LDA SVTL
 CLC
 ADC #2
 STA TMPPATH
 RTS

* ---- MLI wrappers ----
PCREATE JSR MLI
 DFB $C0
 DA CPARM
 RTS
PDESTROY JSR MLI
 DFB $C1
 DA DPARM
 RTS
PRENAME JSR MLI
 DFB $C2
 DA RNPARM
 RTS
POPEN JSR MLI
 DFB $C8
 DA OPARM
 RTS
PREAD JSR MLI
 DFB $CA
 DA RWPARM
 RTS
PWRITE JSR MLI
 DFB $CB
 DA RWPARM
 RTS
PCLOSE JSR MLI
 DFB $CC
 DA CLPARM
 RTS
PGETPFX JSR MLI
 DFB $C7
 DA PFXPARM
 RTS
PONLINE JSR MLI
 DFB $C5
 DA OLPARM
 RTS

* ---- PRHEXB: print A as 2 hex digits ----
* caller sets SCRPTR (SCRADDR), SCRCOL, SCRATR=0
PRHEXB PHA
 LSR
 LSR
 LSR
 LSR
 JSR PRHN
 PLA
 AND #$0F
 JSR PRHN
 RTS
PRHN CMP #10
 BCC PRH1
 CLC
 ADC #$37
 JMP PRH2
PRH1 CLC
 ADC #$30
PRH2 JSR CONV
 JSR PUTC
 RTS

* ---- MLI parameter blocks ----
CPARM DFB 7
 DA 0
 DFB $C3
 DFB $49
 DA 0
 DFB 1
 DA 0
 DA 0
DPARM DFB 1
 DA 0
OPARM DFB 3
 DA 0
 DA 0
 DFB 0
RWPARM DFB 4
 DFB 0
 DA 0
 DA 0
 DA 0
CLPARM DFB 1
 DFB 0
RNPARM DFB 2
 DA 0
 DA 0
PFXPARM DFB 1
 DA PFXBUF
OLPARM DFB 2
 DFB 0
 DA OLBUF

* ---- variables ----
PATHAD DS 2
WSRC DS 2
WLEN DS 2
WTYPE DFB 0
WAUX DS 2
PFXBUF DS 80
OLBUF DS 256
* the safe save's private state.  TMPPATH holds
* FULLPATH's worst case (79 content bytes) plus
* the .T and the length byte.
SVTL DFB 0
SVTI DFB 0
WCERR DFB 0
TMPPATH DS 84
