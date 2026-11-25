* EDITCLP.S  EDIT selection, Copy, Cut and Paste
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* Added 2026-11-11, to the user's design:
*   OA-Up / OA-Down  select whole lines
*   Ctrl-C           Copy  the selection
*   Ctrl-X           Cut   the selection
*   Ctrl-P           Paste above the cursor
* With nothing selected, Copy and Cut take the line
* the cursor is on.
*
* THE CLIPBOARD IS A FILE.  CLIPBOARD.CLP, a TXT
* file in the current prefix, in the same form a
* program is saved in: low ASCII, one line to a
* carriage return, trailing spaces trimmed.  A file
* outlives the editor, so a piece cut from one
* program can be pasted into another after OA-O -
* or after a trip to the menu and back - and the
* clipboard costs no memory while nobody uses it.
* Being a TXT file it can be read, and written, by
* anything else on the disk as well.
*
* WHOLE LINES ONLY.  COBOL's columns mean something
* - 1 the indicator, 2 Area A, 6 Area B - and a
* paste that started in the middle of a line would
* push the rest of it out of its area or past
* column 80.  A pasted line goes in whole, above
* the cursor, and keeps every column it had.  So
* OA-Left and OA-Right select nothing; the moves
* they used to make - start and end of the line -
* went to SA-Left and SA-Right, with paging on
* SA-Up and SA-Down.
*
* THE SELECTION is the lines from the ANCHOR - the
* line the cursor was on at the first OA-arrow - to
* the cursor, whichever way round.  It is drawn in
* inverse (DRAWLN).  Any key but OA-Up, OA-Down,
* Ctrl-C and Ctrl-X ends it and then does what it
* always did; ESC ends it and does nothing else, so
* an ESC meant for the selection does not leave the
* editor.
*
* ONE PASS, NOT ONE A LINE.  INSLIN and DELLIN move
* every line below by one, and calling them once a
* line makes a paste of 100 lines into a 500-line
* program fifty thousand record moves.  INSN and
* DELN open or close the whole gap in one pass, so
* the cost is the length of the program, once.  A
* paste therefore reads the clipboard twice: once to
* count its lines, to know how big a gap to open,
* and once to fill it.

* ================= THE SELECTION ===============
* ---- SELCHK: does this key end the selection? ---
* Called by EDISP before any key is acted on.
* out: C=1 if the key is used up (ESC ending it).
SELCHK LDA SELON
 BEQ SCK0
 LDA CHMOD
 BPL SCK1
* Open-Apple: only Up and Down keep it
 LDA CHKEY
 CMP #$0B
 BEQ SCK0
 CMP #$0A
 BEQ SCK0
 BRA SCKOFF
* Solid-Apple ends it; so does a plain key, except
* Copy and Cut, which act on it
SCK1 AND #$40
 BNE SCKOFF
 LDA CHKEY
 CMP #$03
 BEQ SCK0
 CMP #$18
 BEQ SCK0
 CMP #$1B
 BNE SCKOFF
 JSR SELOFF
 SEC
 RTS
SCKOFF JSR SELOFF
SCK0 CLC
 RTS

* ---- SELOFF: no selection; repaint the window ---
SELOFF STZ SELON
 LDA RFLAG
 ORA #2
 STA RFLAG
 RTS

* ---- DSELU / DSELD: OA-Up and OA-Down ----------
* The first one drops the anchor where the cursor
* is; every one moves the cursor a line and the
* selection follows it.
DSELU JSR SELBEG
 JSR DUPL
 BRA SELUPD
DSELD JSR SELBEG
 JSR DDOWNL
SELUPD JSR SELRNG
 LDA RFLAG
 ORA #2
 STA RFLAG
 RTS
SELBEG LDA SELON
 BNE SBX
 LDA CURLIN
 STA SELANC
 LDA CURLIN+1
 STA SELANC+1
 LDA #1
 STA SELON
SBX RTS

* ---- SELRNG: anchor and cursor -> SELLO, SELHI --
SELRNG LDA SELANC
 STA C1
 LDA SELANC+1
 STA C1+1
 LDA CURLIN
 STA C2
 LDA CURLIN+1
 STA C2+1
 JSR CMP16
 BCC SRG1
* the anchor is at or below the cursor
 LDA CURLIN
 STA SELLO
 LDA CURLIN+1
 STA SELLO+1
 LDA SELANC
 STA SELHI
 LDA SELANC+1
 STA SELHI+1
 RTS
SRG1 LDA SELANC
 STA SELLO
 LDA SELANC+1
 STA SELLO+1
 LDA CURLIN
 STA SELHI
 LDA CURLIN+1
 STA SELHI+1
 RTS

* ---- DLSEL: is CLINE selected?  A = 1 if so -----
* For DRAWLN.  Uses C1 and C2, which DRAWWIN sets
* again for every row.
DLSEL LDA SELON
 BEQ DLSN
 LDA CLINE
 STA C1
 LDA CLINE+1
 STA C1+1
 LDA SELLO
 STA C2
 LDA SELLO+1
 STA C2+1
 JSR CMP16
 BCC DLSN
 LDA SELHI
 STA C1
 LDA SELHI+1
 STA C1+1
 LDA CLINE
 STA C2
 LDA CLINE+1
 STA C2+1
 JSR CMP16
 BCC DLSN
 LDA #1
 RTS
DLSN LDA #0
 RTS

* ---- CLPRNG: the lines Copy and Cut take --------
* out: CLPL1 the first, CLPLE one past the last,
*      CLPN how many
CLPRNG LDA SELON
 BEQ CRG1
 LDA SELLO
 STA CLPL1
 LDA SELLO+1
 STA CLPL1+1
 LDA SELHI
 STA CLPLE
 LDA SELHI+1
 STA CLPLE+1
 BRA CRG2
CRG1 LDA CURLIN
 STA CLPL1
 STA CLPLE
 LDA CURLIN+1
 STA CLPL1+1
 STA CLPLE+1
CRG2 INC CLPLE
 BNE CRG3
 INC CLPLE+1
CRG3 SEC
 LDA CLPLE
 SBC CLPL1
 STA CLPN
 LDA CLPLE+1
 SBC CLPL1+1
 STA CLPN+1
 RTS

* ================= THE COMMANDS ================
* ---- DCOPY: Ctrl-C ------------------------------
DCOPY JSR EDFLSH
 JSR CLPRNG
 JSR CLPWR
 JMP SELOFF

* ---- DCUT: Ctrl-X -------------------------------
* Copy, and only if the copy is safely on the disk,
* take the lines out.  Cutting every line leaves the
* one blank line a program never has fewer than.
DCUT JSR EDFLSH
 JSR CLPRNG
 JSR CLPWR
 BCC DCT1
 JMP SELOFF
DCT1 STZ LDIRTY
 LDA CLPN
 CMP NLINES
 LDA CLPN+1
 SBC NLINES+1
 BCC DCT2
* all of them
 LDA #1
 STA NLINES
 STZ NLINES+1
 JSR SHFBLK
 STZ CLINE
 STZ CLINE+1
 JSR SHFPUT
 JSR EDSTAL
 BRA DCT3
DCT2 LDA CLPL1
 STA INSP
 LDA CLPL1+1
 STA INSP+1
 JSR DELN
* the cursor goes where the first cut line was, or
* on the last line if the cut took the end
DCT3 LDA CLPL1
 STA CURLIN
 STA C1
 LDA CLPL1+1
 STA CURLIN+1
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCC DCT4
 SEC
 LDA NLINES
 SBC #1
 STA CURLIN
 LDA NLINES+1
 SBC #0
 STA CURLIN+1
DCT4 STZ CURCOL
 JSR SELOFF
 JMP EDMOVE

* ---- DPASTE: Ctrl-P -----------------------------
* PLACE's reader does the reading (EDITPLC): PLOPN,
* PLWALK and PLCLS on FNBUF1, with PLMODE 2 telling
* PLLDN to store every line - no "*" pieces - into
* the gap at PLAT instead of inserting it.  PLDONE
* puts the cursor back on the line it was on, now
* below what came in.
DPASTE JSR EDFLSH
 JSR SELOFF
 JSR CLPNAM
 JSR PLOPN
 BCC DPS1
 CMP #$46
 BEQ DPSMT
 JSR EDERR
 JMP EDFULL
DPS1 JSR CLPCNT
 LDA CLPN
 ORA CLPN+1
 BNE DPS2
 JSR PLCLS
DPSMT LDA #<MCLPE
 LDX #>MCLPE
 JSR EMSG
 JMP EDFULL
DPS2 LDA CURLIN
 STA INSP
 STA PLAT
 LDA CURLIN+1
 STA INSP+1
 STA PLAT+1
 JSR INSN
 BCC DPS3
 JSR PLCLS
 LDA #<MFULL
 LDX #>MFULL
 JSR EMSG
 JMP EDFULL
DPS3 LDA CLPN
 STA CLPR
 LDA CLPN+1
 STA CLPR+1
 LDA #2
 STA PLMODE
 JSR PLWALK
 STZ PLMODE
 JSR PLCLS
 JMP PLDONE

* ---- PLSTO: PLLINE -> the gap, line PLAT --------
* PLLDN's PLMODE 2.  C=1 stops the walk once the
* gap is full - it is as big as the count said, and
* a file that grew between the passes does not get
* to write past it.
PLSTO LDA CLPR
 ORA CLPR+1
 BNE PLSO1
 SEC
 RTS
PLSO1 LDY #RECSZ-1
PLSO2 LDA PLLINE,Y
 STA SHFBUF,Y
 DEY
 BPL PLSO2
 LDA PLAT
 STA CLINE
 LDA PLAT+1
 STA CLINE+1
 JSR SHFPUT
 INC PLAT
 BNE PLSO3
 INC PLAT+1
PLSO3 LDA CLPR
 BNE PLSO4
 DEC CLPR+1
PLSO4 DEC CLPR
 CLC
 RTS

* ---- CLPCNT: the lines in the open clipboard ----
* Counted the way PLWALK will read them: a carriage
* return ends one, and a last line with no carriage
* return counts if it has anything printable in it.
CLPCNT JSR MLI
 DFB $CE
 DA PLMKP
 STZ PLP
 STZ PLP+1
 STZ PLE
 STZ PLE+1
 STZ CLPN
 STZ CLPN+1
 STZ CLPPC
CCN1 JSR PLGET
 BEQ CCN9
 CMP #$0D
 BNE CCN2
 STZ CLPPC
 INC CLPN
 BNE CCN1
 INC CLPN+1
 BRA CCN1
CCN2 CMP #$20
 BCC CCN1
 STA CLPPC
 BRA CCN1
CCN9 LDA CLPPC
 BEQ CCNX
 INC CLPN
 BNE CCNX
 INC CLPN+1
CCNX RTS

* ---- CLPNAM: FNBUF1 <- CLIPBOARD.CLP ------------
* A bare name: ProDOS puts the prefix in front.
CLPNAM LDX CLPNM
CNM1 LDA CLPNM,X
 STA FNBUF1,X
 DEX
 BPL CNM1
 RTS

* ---- CLPWR: lines CLPL1 to CLPLE-1 -> the file --
* out: C=1 if it failed (the error has been shown)
* DSAVE's loop, over a range, into a file that is
* simply replaced: a clipboard lost to a power cut
* loses nothing that is not still in the program.
CLPWR JSR CLPNAM
 LDA #<FNBUF1
 STA EPDPRM+1
 LDA #>FNBUF1
 STA EPDPRM+2
* no clipboard yet ($46) is the usual answer
 JSR EPDEST
 LDA #<FNBUF1
 STA EPCPRM+1
 LDA #>FNBUF1
 STA EPCPRM+2
* TXT, so anything on the disk can read it
 LDA #$04
 STA EPCPRM+4
 STZ EPCPRM+5
 STZ EPCPRM+6
 JSR EPCREA
 BCS CLWER
 JSR EOPENF
 BCS CLWER
 JSR SGRST
 LDA CLPL1
 STA SLINE
 LDA CLPL1+1
 STA SLINE+1
CLW1 LDA SLINE
 CMP CLPLE
 LDA SLINE+1
 SBC CLPLE+1
 BCS CLW5
 LDA SLINE
 STA CLINE
 LDA SLINE+1
 STA CLINE+1
 JSR SHFGET
 JSR SGTRIM
* the same flush test as DSAVE: under 81 free
 LDA SGLEN+1
 CMP #STGFLH
 BCC CLW3
 BNE CLW2
 LDA SGLEN
 CMP #STGFLL
 BCC CLW3
CLW2 JSR SGFLSH
 BCS CLWCE
CLW3 JSR SGLINE
 INC SLINE
 BNE CLW1
 INC SLINE+1
 BRA CLW1
CLW5 JSR SGFLSH
 BCS CLWCE
 JSR EPCLOS
 BCS CLWER
 CLC
 RTS
* a write failed with the file open: close it
CLWCE PHA
 JSR EPCLOS
 PLA
CLWER JSR EDERR
 JSR EDFULL
 SEC
 RTS

* ================= THE GAPS ====================
* ---- INSN: CLPN blank lines at INSP -------------
* Lines INSP to the end move down CLPN places, the
* last first so nothing is overwritten before it is
* read.  C=1 if there is not room for them all.
INSN CLC
 LDA NLINES
 ADC CLPN
 STA C2
 LDA NLINES+1
 ADC CLPN+1
 STA C2+1
 BCS INNF
 LDA AXCAPV
 STA C1
 LDA AXCAPV+1
 STA C1+1
 JSR CMP16
 BCS INN0
INNF SEC
 RTS
INN0 SEC
 LDA NLINES
 SBC #1
 STA SRCL
 LDA NLINES+1
 SBC #0
 STA SRCL+1
INN1 LDA SRCL
 STA C1
 LDA SRCL+1
 STA C1+1
 LDA INSP
 STA C2
 LDA INSP+1
 STA C2+1
 JSR CMP16
 BCC INN3
 LDA SRCL
 STA CLINE
 LDA SRCL+1
 STA CLINE+1
 JSR SHFGET
 CLC
 LDA SRCL
 ADC CLPN
 STA CLINE
 LDA SRCL+1
 ADC CLPN+1
 STA CLINE+1
 JSR SHFPUT
 SEC
 LDA SRCL
 SBC #1
 STA SRCL
 LDA SRCL+1
 SBC #0
 STA SRCL+1
 BCS INN1
* the gap is blank until it is filled
INN3 JSR SHFBLK
 LDA INSP
 STA DSTL
 LDA INSP+1
 STA DSTL+1
 LDA CLPN
 STA CLPR
 LDA CLPN+1
 STA CLPR+1
INN4 LDA CLPR
 ORA CLPR+1
 BEQ INN5
 LDA DSTL
 STA CLINE
 LDA DSTL+1
 STA CLINE+1
 JSR SHFPUT
 INC DSTL
 BNE INN4A
 INC DSTL+1
INN4A LDA CLPR
 BNE INN4B
 DEC CLPR+1
INN4B DEC CLPR
 BRA INN4
INN5 CLC
 LDA NLINES
 ADC CLPN
 STA NLINES
 LDA NLINES+1
 ADC CLPN+1
 STA NLINES+1
 JSR EDSTAL
 CLC
 RTS

* ---- DELN: CLPN lines out, from INSP ------------
* Every line below moves up CLPN places, first
* first.  The caller has made sure some are left.
DELN CLC
 LDA INSP
 ADC CLPN
 STA SRCL
 LDA INSP+1
 ADC CLPN+1
 STA SRCL+1
 LDA INSP
 STA DSTL
 LDA INSP+1
 STA DSTL+1
DLN1 LDA SRCL
 CMP NLINES
 LDA SRCL+1
 SBC NLINES+1
 BCS DLN2
 LDA SRCL
 STA CLINE
 LDA SRCL+1
 STA CLINE+1
 JSR SHFGET
 LDA DSTL
 STA CLINE
 LDA DSTL+1
 STA CLINE+1
 JSR SHFPUT
 INC SRCL
 BNE DLN1A
 INC SRCL+1
DLN1A INC DSTL
 BNE DLN1
 INC DSTL+1
 BRA DLN1
DLN2 SEC
 LDA NLINES
 SBC CLPN
 STA NLINES
 LDA NLINES+1
 SBC CLPN+1
 STA NLINES+1
 JMP EDSTAL

* ================= STRINGS =====================
CLPNM DFB 13
 ASC 'CLIPBOARD.CLP'
MCLPE DFB 36
 ASC 'The clipboard is empty - press a key'

* ================= VARIABLES ===================
* SELON 1 while there is a selection; SELANC the
* line it started on; SELLO..SELHI the lines in it
SELON DFB 0
SELANC DS 2
SELLO DS 2
SELHI DS 2
* the range Copy and Cut work on, and its size;
* CLPR counts the gap down as it is filled; CLPPC
* is the last printable character CLPCNT saw
CLPL1 DS 2
CLPLE DS 2
CLPN DS 2
CLPR DS 2
CLPPC DFB 0
DSTL DS 2
