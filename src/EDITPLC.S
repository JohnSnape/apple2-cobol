* EDITPLC.S  SA-P, place a FORMAT or QUERY
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* Added 2026-11-08.  PLACE puts generated COBOL into
* the program ABOVE the line the cursor is on, and
* the cursor stays on that line.
*
*   F  a FORMAT: one piece of the .SNP the designer
*      exported - the 01 record, the paint paragraph
*      or the accept paragraph.  The pieces belong in
*      different divisions, so PLACE is run once for
*      each, with the cursor where it should go.
*      The .SNP separates them with a line that is
*      a lone "*", which is what is counted here.
*   Q  a QUERY: the statements that run it - QUERY,
*      QUERY NEXT, and a QUERY FIELD for every field
*      of its dictionary by name.  The .QRY does not
*      record its dictionary (QUERY.md 15.3), so
*      PLACE asks for both names.  FILE-NAME,
*      REC-NUMBER and END-FLAG are left for the
*      programmer to replace.
*   R  a REPORT: its .SNP, data and paragraphs.
*   P  a PROCEDURE from the library (2026-11-11):
*      the same two-piece .SNP as a REPORT's, read
*      from the PROCS folder - DATES, TEXT, SCREEN,
*      MONEY, WORDS.  A name that starts with "/" is
*      used as it is, so a programmer's own library
*      can live anywhere.

* The .SNP is read into the free space between the
* end of EDIT and the line ring.  The line being
* built is the last free part of the $AC00 page.
* (EDEND is named in the code, not EQUated here:
* an EQU of a label not yet seen gets a garbage
* value in Merlin 8, silently.)
PLLINE EQU EDHIGH+224

* ---- DPLACE: SA-P ------------------------------
DPLACE JSR EDFLSH
 LDA CURLIN
 STA PLAT
 LDA CURLIN+1
 STA PLAT+1
 LDA #<MPLC
 STA STRPTR
 LDA #>MPLC
 STA STRPTR+1
 JSR ASK
* PLRPT 0 a FORMAT's .SNP, 1 a REPORT's: the same
* walk, two pieces instead of three
 STZ PLRPT
 STZ PLPRC
 CMP #$46
 BEQ PLFMT
 CMP #$51
 BNE PLC1
 JMP PLQRY
PLC1 CMP #$52
 BEQ PLCR
* P: a procedure is a report-shaped .SNP
 CMP #$50
 BNE PLCX
 INC PLPRC
PLCR INC PLRPT
 JMP PLFMT
PLCX RTS

* ================= A FORMAT ====================
* The .SNP is read FIRST, then the piece is asked
* for - with the piece that fits where the cursor
* is offered as the default, which RETURN takes
* (the user's rule, 2026-11-08):
*   above PROCEDURE DIVISION      the record
*   below it                      the paint paragraph
*   below it, and the program
*     already has that paragraph  the accept one
* A REPORT's .SNP (RPTEXP.S) is the same shape with
* two pieces: 1 the data, 2 the paragraphs.  Its
* default is the data above PROCEDURE DIVISION and
* the paragraphs below it.
PLFMT LDA #<MPLSNP
 LDX #>MPLSNP
 LDY PLRPT
 BEQ PLFM1
 LDA #<MPLRS
 LDX #>MPLRS
 LDY PLPRC
 BEQ PLFM1
 LDA #<MPLPS
 LDX #>MPLPS
PLFM1 STA STRPTR
 STX STRPTR+1
 JSR EPROMP
 BCC PLF2
 RTS
* NAME.SNP, whatever suffix was typed
PLF2 JSR VWFNAM
 LDA #$48
 LDX #1
 JSR SETSFX
 LDA PLPRC
 BEQ PLF3
 JSR PLPFX
PLF3 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
* STREAMED, 512 bytes at a time, since 2026-11-08:
* it was loaded whole into the space between EDEND
* and the ring, and a REPORT's .SNP is bigger than
* that space - the paragraphs stopped at "MOVE 4 TO".
* The file stays open across both walks (the
* default and the placing) and PLWALK rewinds it.
 JSR PLOPN
 BCC PLF5
 JMP EDERR
PLF5 JSR PLDEF
 LDA PLWANT
 LDX PLRPT
 BEQ PLF5A
 CLC
 ADC #3
PLF5A ASL
 TAX
 LDA PLDTAB-2,X
 STA STRPTR
 LDA PLDTAB-1,X
 STA STRPTR+1
 JSR ASK
 CMP #$0D
 BEQ PLF5G
 LDX PLRPT
 BEQ PLF5F
* a report: D)ata or P)aragraphs
 LDX #1
 CMP #$44
 BEQ PLF5S
 INX
 CMP #$50
 BEQ PLF5S
 JMP PLCLS
PLF5F LDX #1
 CMP #$52
 BEQ PLF5S
 INX
 CMP #$50
 BEQ PLF5S
 INX
 CMP #$41
 BEQ PLF5S
 JMP PLCLS
PLF5S STX PLWANT
PLF5G STZ PLMODE
 JSR PLWALK
 JSR PLCLS
 JMP PLDONE

* ---- PLPFX: FNBUF1 <- "*/PROCS/" + FNBUF1 -------
* Unless it already starts with "/" - a full name,
* or one SETSFX has already given its prefix.
* FNBUF1 holds 127 characters; a typed name is at
* most 15 plus a suffix, so the eight more fit.
* */ since 2026-11-11: the library is the SYSTEM's,
* on the boot disk, and 0/ may be a work directory
* somewhere else.  The */ is expanded in place
* (PXSVC) because PLOPN hands FNBUF1 straight to
* ProDOS.
PLPFX LDA FNBUF1+1
 CMP #$2F
 BEQ PLPFXX
 LDX FNBUF1
PLPF1 LDA FNBUF1,X
 STA FNBUF1+8,X
 DEX
 BNE PLPF1
 LDX #7
PLPF2 LDA SPROCS,X
 STA FNBUF1+1,X
 DEX
 BPL PLPF2
 CLC
 LDA FNBUF1
 ADC #8
 STA FNBUF1
 LDA #<FNBUF1
 STA ZPT1
 LDA #>FNBUF1
 STA ZPT1+1
 LDX #0
 JSR PXSVC
PLPFXX RTS

* ---- PLDEF: the piece that fits here -> PLWANT --
PLDEF LDA #1
 STA PLWANT
 LDA #<SPROC
 LDX #>SPROC
 JSR PLSET
 LDA CURLIN
 STA PLEND
 LDA CURLIN+1
 STA PLEND+1
 JSR PLSRCH
 BCC PLDX
* a report: below PROCEDURE DIVISION, the paragraphs
 LDA PLRPT
 BEQ PLDF1
 LDA #2
 STA PLWANT
 RTS
PLDF1
* in the PROCEDURE DIVISION: the paint paragraph,
* unless its name - the first line of piece 2 - is
* in the program already
 LDA #2
 STA PLWANT
 STZ PLPAT
 LDA #1
 STA PLMODE
 JSR PLWALK
 STZ PLMODE
 LDA PLPAT
 BEQ PLDX
 LDA NLINES
 STA PLEND
 LDA NLINES+1
 STA PLEND+1
 JSR PLSRCH
 BCC PLDX
 LDA #3
 STA PLWANT
PLDX RTS

* ---- PLSET: A/X string -> PLPAT ------------------
PLSET STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 TAY
PLST1 LDA (ZPT1),Y
 STA PLPAT,Y
 DEY
 BPL PLST1
 RTS

* ---- PLSRCH: PLPAT in lines 0 to PLEND-1? C=1 --
PLSRCH STZ PLSNO
 STZ PLSNO+1
PLSR1 LDA PLSNO
 CMP PLEND
 LDA PLSNO+1
 SBC PLEND+1
 BCS PLSRN
 LDA PLSNO
 STA CLINE
 LDA PLSNO+1
 STA CLINE+1
 JSR SHFGET
 JSR PLMTCH
 BCS PLSRY
 INC PLSNO
 BNE PLSR1
 INC PLSNO+1
 JMP PLSR1
PLSRN CLC
PLSRY RTS

* ---- PLMTCH: PLPAT anywhere in SHFBUF? C=1 ------
PLMTCH LDX #0
PLM1 TXA
 CLC
 ADC PLPAT
 CMP #RECSZ+1
 BCS PLMN
 STX PLMS
 LDY #0
PLM2 LDA SHFBUF,X
 AND #$7F
 CMP PLPAT+1,Y
 BNE PLM3
 INX
 INY
 CPY PLPAT
 BCC PLM2
 SEC
 RTS
PLM3 LDX PLMS
 INX
 JMP PLM1
PLMN CLC
 RTS

* ---- PLWALK: the lines of the .SNP --------------
* A lone "*" starts the next piece.  PLMODE 0
* places every line of piece PLWANT; PLMODE 1 only
* copies its first line, trimmed, into PLPAT.
PLWALK STZ PLBLK
* back to the start of the file, and an empty
* buffer so the first PLGET reads
 JSR MLI
 DFB $CE
 DA PLMKP
 STZ PLP
 STZ PLP+1
 STZ PLE
 STZ PLE+1
PLW1 JSR PLCLR
PLW2 JSR PLGET
 BEQ PLW9
 CMP #$0D
 BEQ PLW3
 CMP #$0A
 BEQ PLW2
 CMP #$20
 BCC PLW2
 JSR PLCH
 JMP PLW2
PLW3 JSR PLLDN
 BCC PLW1
 RTS
* the end of the file: a last line with no CR
PLW9 LDA PLCOL
 BEQ PLWX
 JSR PLLDN
PLWX RTS
* PLLDN: a whole line is in PLLINE.  C=1: stop.
* PLMODE 2 is Paste (EDITCLP): every line, a lone
* "*" included - in a clipboard that is a comment
PLLDN LDA PLMODE
 CMP #2
 BNE PLLD1
 JMP PLSTO
PLLD1 JSR PLSEP
 BCC PLL1
 INC PLBLK
 CLC
 RTS
PLL1 LDA PLBLK
 CMP PLWANT
 BNE PLLN
 LDA PLMODE
 BNE PLLCP
 JMP PLEMIT
PLLN CLC
 RTS
* capture: from the first non-space to the end
PLLCP LDX #0
PLC2 CPX PLCOL
 BCS PLC3
 LDA PLLINE,X
 CMP #$20
 BNE PLC3
 INX
 BNE PLC2
PLC3 LDY #0
PLC4 CPX PLCOL
 BCS PLC5
 CPY #40
 BCS PLC5
 LDA PLLINE,X
 STA PLPAT+1,Y
 INX
 INY
 BNE PLC4
PLC5 STY PLPAT
 SEC
 RTS

* PLSEP: C=1 if PLLINE is a lone "*"
PLSEP LDA PLCOL
 CMP #1
 BNE PLSN
 LDA PLLINE
 CMP #$2A
 BNE PLSN
 SEC
 RTS
PLSN CLC
 RTS

* PLGET: the next byte of PLBUF, Z=1 at the end
PLGET LDA PLP
 CMP PLE
 BNE PLG1
 LDA PLP+1
 CMP PLE+1
 BNE PLG1
* the buffer is used up: the next 512 bytes
 JSR MLI
 DFB $CA
 DA PLRDP
 BCS PLGZ
 LDA PLRDP+6
 ORA PLRDP+7
 BEQ PLGZ
 LDA #<EDEND
 STA PLP
 CLC
 ADC PLRDP+6
 STA PLE
 LDA #>EDEND
 STA PLP+1
 ADC PLRDP+7
 STA PLE+1
PLG1 LDA PLP
 STA ZPT1
 LDA PLP+1
 STA ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 PHA
 INC PLP
 BNE PLG2
 INC PLP+1
PLG2 PLA
 RTS
PLGZ LDA #0
 RTS

* ---- PLOPN / PLCLS: the .SNP in FNBUF1 ---------
PLOPN JSR MLI
 DFB $C8
 DA PLOPP
 BCS PLOX
 LDA PLOPP+5
 STA PLRDP+1
 STA PLMKP+1
 STA PLCLP+1
PLOX RTS
PLCLS JSR MLI
 DFB $CC
 DA PLCLP
 RTS
PLOPP DFB 3
 DA FNBUF1
 DA IOBUF
 DFB 0
PLRDP DFB 4
 DFB 0
 DA EDEND
 DA 512
 DA 0
PLMKP DFB 2
 DFB 0
 DFB 0,0,0
PLCLP DFB 1
 DFB 0

* ================= A QUERY =====================
PLQRY LDA #<MPLQ
 STA STRPTR
 LDA #>MPLQ
 STA STRPTR+1
 JSR EPROMP
 BCC PLQ1
 RTS
* keep the query's name: NAMBUF is used again
PLQ1 LDX NAMBUF
PLQ2 LDA NAMBUF,X
 STA PLQNM,X
 DEX
 BPL PLQ2
 LDA #<MPLD
 STA STRPTR
 LDA #>MPLD
 STA STRPTR+1
 JSR EPROMP
 BCC PLQ3
 RTS
PLQ3 LDX NAMBUF
PLQ4 LDA NAMBUF,X
 STA PLDNM,X
 DEX
 BPL PLQ4
* the dictionary: VIEW's loader and field reader.
* A dictionary that will not load still gets the
* QUERY lines, without the fields.
 STZ VHASD
 JSR VWFNAM
 LDA #$49
 LDX #1
 JSR SETSFX
 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 LDA #<DCTBUF
 STA FADDR
 LDA #>DCTBUF
 STA FADDR+1
 STZ FLEN
 LDA #3
 STA FLEN+1
 JSR FLOAD
 BCS PLQ5
 INC VHASD
 LDA DCTBUF+4
 STA VVER
* *    query NAME on dictionary DICT
PLQ5 JSR PLCLR
 LDA #<SQC1
 LDX #>SQC1
 JSR PLSTR
 LDA #<PLQNM
 LDX #>PLQNM
 JSR PLSTR
 LDA #<SQC2
 LDX #>SQC2
 JSR PLSTR
 LDA #<PLDNM
 LDX #>PLDNM
 JSR PLSTR
 JSR PLEMIT
 BCC PLQ5B
 JMP PLDONE
PLQ5B
*     QUERY "NAME" USING "DICT" OF FILE-NAME
 JSR PLB
 LDA #<SQ1
 LDX #>SQ1
 JSR PLSTR
 LDA #<PLQNM
 LDX #>PLQNM
 JSR PLSTR
 LDA #<SQ2
 LDX #>SQ2
 JSR PLSTR
 LDA #<PLDNM
 LDX #>PLDNM
 JSR PLSTR
 LDA #<SQ3
 LDX #>SQ3
 JSR PLSTR
 JSR PLEMIT
 BCS PLQX
 LDA #<SQ4
 LDX #>SQ4
 JSR PLLIT
 BCS PLQX
 LDA #<SQ5
 LDX #>SQ5
 JSR PLLIT
 BCS PLQX
 LDA #<SQ6
 LDX #>SQ6
 JSR PLLIT
 BCS PLQX
* QUERY FIELD n INTO name, for every field
 LDA VHASD
 BEQ PLQX
 STZ VFI
PLQ6 LDA VFI
 CMP DCTBUF+8
 BCC PLQ6A
 JMP PLDONE
PLQ6A
 JSR VWDESC
 JSR PLB
 LDA #<SQ7
 LDX #>SQ7
 JSR PLSTR
 LDA VFI
 JSR PLDEC
 LDA #<SQ8
 LDX #>SQ8
 JSR PLSTR
 LDY #0
PLQ7 CPY VNLEN
 BCS PLQ8
 LDA (ZPT2),Y
 STY PLY
 JSR PLCH
 LDY PLY
 INY
 BNE PLQ7
PLQ8 JSR PLEMIT
 BCS PLQX
 INC VFI
 JMP PLQ6
PLQX JMP PLDONE

* ================= BUILDING LINES ==============
* PLCLR: PLLINE all spaces, the column at 0
PLCLR LDA #$20
 LDY #RECSZ-1
PLCL1 STA PLLINE,Y
 DEY
 BPL PLCL1
 STZ PLCOL
 RTS
* PLB: a clear line indented as the samples and the
* .SNP indent a statement: five spaces, column 6
PLB JSR PLCLR
 LDA #5
 STA PLCOL
 RTS
* PLCH: A onto the line; past column 80 is dropped
PLCH LDY PLCOL
 CPY #RECSZ
 BCS PLCH1
 STA PLLINE,Y
 INC PLCOL
PLCH1 RTS
* PLSTR: A/X -> a length-prefixed string onto it
PLSTR STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA PLN
 BEQ PLSX
 LDY #1
PLS1 LDA (ZPT1),Y
 STY PLY
 JSR PLCH
 LDY PLY
 CPY PLN
 INY
 BCC PLS1
PLSX RTS
* PLLIT: a whole Area B line from a string, emitted
PLLIT PHA
 JSR PLB
 PLA
 JSR PLSTR
 JMP PLEMIT
* PLDEC: A (0-99) in decimal onto the line
PLDEC LDX #0
PLD1 CMP #10
 BCC PLD2
 SBC #10
 INX
 BNE PLD1
PLD2 PHA
 TXA
 BEQ PLD3
 ORA #$30
 JSR PLCH
PLD3 PLA
 ORA #$30
 JMP PLCH

* ---- PLEMIT: PLLINE becomes a line at PLAT ------
* out: C=1 if memory is full (the message is shown)
PLEMIT LDA PLAT
 STA INSP
 LDA PLAT+1
 STA INSP+1
 JSR INSLIN
 BCC PLE1
 LDA #<MFULL
 LDX #>MFULL
 JSR EMSG
 SEC
 RTS
PLE1 LDY #RECSZ-1
PLE2 LDA PLLINE,Y
 STA SHFBUF,Y
 DEY
 BPL PLE2
 LDA PLAT
 STA CLINE
 LDA PLAT+1
 STA CLINE+1
 JSR SHFPUT
 INC PLAT
 BNE PLE3
 INC PLAT+1
PLE3 CLC
 RTS

* ---- PLDONE: back on the line we started on -----
* It has moved down by however many went in above.
PLDONE LDA PLAT
 STA CURLIN
 LDA PLAT+1
 STA CURLIN+1
 STZ CURCOL
 JSR EDMOVE
 LDA RFLAG
 ORA #2
 STA RFLAG
 RTS

* ================= STRINGS =====================
MPLC DFB 47
 ASC 'Place F)ormat, Q)uery, R)eport or P)rocedure?'
 ASC '  '
PLDTAB DA MPLR
 DA MPLP
 DA MPLA
 DA MPLRD
 DA MPLRP
MPLRS DFB 23
 ASC 'Report (.SNP) to place?'
MPLPS DFB 26
 ASC 'Procedure (.SNP) to place?'
SPROCS ASC '*/PROCS/'
MPLRD DFB 36
 ASC 'D)ata or P)aragraphs?  RETURN = Data'
MPLRP DFB 42
 ASC 'D)ata or P)aragraphs?  RETURN = Paragraphs'
MPLR DFB 44
 ASC 'R)ecord, P)aint or A)ccept?  RETURN = Record'
MPLP DFB 43
 ASC 'R)ecord, P)aint or A)ccept?  RETURN = Paint'
MPLA DFB 44
 ASC 'R)ecord, P)aint or A)ccept?  RETURN = Accept'
SPROC DFB 18
 ASC 'PROCEDURE DIVISION'
MPLSNP DFB 23
 ASC 'Format (.SNP) to place?'
MPLQ DFB 20
 ASC 'Query (.QRY) name?  '
MPLD DFB 25
 ASC 'Its dictionary (.DCT)?   '
SQC1 DFB 13
 ASC '*    QUERY   '
SQC2 DFB 15
 ASC ' ON DICTIONARY '
SQ1 DFB 7
 ASC 'QUERY "'
SQ2 DFB 9
 ASC '" USING "'
SQ3 DFB 14
 ASC '" OF FILE-NAME'
SQ4 DFB 36
 ASC '    ON ERROR DISPLAY "QUERY FAILED".'
SQ5 DFB 28
 ASC 'QUERY NEXT GIVING REC-NUMBER'
SQ6 DFB 32
 ASC '    AT END MOVE "Y" TO END-FLAG.'
SQ7 DFB 12
 ASC 'QUERY FIELD '
SQ8 DFB 6
 ASC ' INTO '

* ================= VARIABLES ===================
PLAT DS 2
PLP DS 2
PLWANT DFB 0
PLBLK DFB 0
PLCOL DFB 0
PLN DFB 0
PLY DFB 0
PLQNM DS 16
PLMODE DFB 0
PLE DS 2
PLRPT DFB 0
* 1 when the .SNP is a library procedure (PROCS/)
PLPRC DFB 0
PLMS DFB 0
PLEND DS 2
PLSNO DS 2
PLPAT DS 41
PLDNM DS 16
