* RPTENT.S  REPORT entry, main loop, scrolling
* PUT from REPORT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* REPORT resolve against each other in pass two.
*
* ================= ENTRY =================
* JMP START in REPORT.S lands here, after PROMPT.
START JSR RPINIT
 JSR RPFULL
RPMAIN JSR GETCHORD
 JSR RPKEY
 LDA QUIT
 BEQ RPMAIN
 RTS

* ---- RPINIT: an empty 66-line page -------------
* NOTE WHAT IS MISSING.  There is no FINDBNK, no
* AXCAP, no AXSHIFT and no ring, because REPORT
* uses no auxiliary memory at all - the whole
* report is main-memory entries.  The absence is
* the design, not an oversight; see REPORT.S.
RPINIT JSR INIT80
 JSR CLRSCR
 LDA #$41
 STA HSIG
 LDA #$44
 STA HSIG+1
 LDA #$52
 STA HSIG+2
 LDA #$31
 STA HSIG+3
 LDA #1
 STA HVER
 STZ HORG
 STZ HECNT
 STZ HDSPC
 STZ HEOFF+1
 STZ HFEND+1
 STZ PTOP
 STZ QUIT
 LDA #DEFPLEN
 STA HPLEN
 LDA #DEFPWID
 STA HPWID
 LDA #32
 STA HEOFF
 STA HFEND
* An unset band mark is $FF.  No page line can
* reach $FF, so "no such band" needs no special
* case anywhere downstream - BANDOF simply never
* matches it.
 LDA #$FF
 LDX #0
RPI1 STA HHTOP,X
 INX
 CPX #6
 BCC RPI1
 LDA #$20
 LDX #0
RPI2 STA HDNAME,X
 INX
 CPX #12
 BCC RPI2
 RTS

* ---- RPFULL: draw the whole screen -------------
RPFULL JSR RPHDR
 JSR RPBARS
* fall into RPDRAW

* ---- RPDRAW: what a scroll changes -------------
* The header and the bar do not move, so they are
* drawn once by RPFULL and never from here.
RPDRAW JSR RPRULE
 JMP RPWIN

* ================= KEYS =================
* ---- RPKEY: one keystroke ----------------------
* The main loop reads keys DIRECTLY rather than
* sitting inside LINEIN the way FORMAT does.  It
* has to: LINEIN swallows the arrow keys, and in a
* designer whose page outgrows its window the
* arrows are the most important keys on the board.
* A prompt is entered only when a command needs an
* answer, and left again immediately.
* Both Apple keys down is not Open-Apple - see the
* note at the head of EDITDSP.  REPORT defines no
* OA+SA chord either, so it does nothing.
RPKEY LDA CHMOD
 AND #$C0
 CMP #$C0
 BNE RPK0
 RTS
RPK0 LDA CHMOD
 BMI RPKOA
 AND #$40
 BNE RPKSA
 LDA CHKEY
 CMP #$1B
 BEQ RPQUIT
 CMP #$0B
 BEQ RPUP
 CMP #$0A
 BEQ RPDN
 RTS
RPQUIT LDA #1
 STA QUIT
 RTS

* ---- Solid-Apple: the code preview -------------
* Wired now, an RTS until slice 7, so the key does
* nothing rather than doing something wrong.
RPKSA LDA CHKEY
 AND #$DF
 CMP #$43
 BNE RPKSZ
 JMP DOPREV
RPKSZ RTS

* ---- Open-Apple: paging and the commands -------
* Folded here, once, before any letter is tested.
* G, A and D used to be tested before the fold at
* RPKO3, so with Caps Lock up OA-g, OA-a and OA-d
* did nothing while OA-i and the rest worked (user,
* 2026-11-24).  The arrows have no bit 5 and pass.
RPKOA LDA CHKEY
 AND #$DF
 CMP #$0B
 BEQ RPPGU
 CMP #$0A
 BEQ RPPGD
 CMP #$47
 BNE RPKO1
 JMP RPGOTO
RPKO1 CMP #$41
 BNE RPKO2
 JMP RPADD
RPKO2 CMP #$44
 BNE RPKO3
 JMP RPDEL
* the slices 3-7 commands, 2026-11-08
RPKO3 CMP #$49
 BNE RPKO4
 JMP RPDICT
RPKO4 CMP #$42
 BNE RPKO5
 JMP RPBAND
RPKO5 CMP #$4E
 BNE RPKO6
 JMP RPNEW
RPKO6 CMP #$4F
 BNE RPKO7
 JMP RPOPEN
RPKO7 CMP #$53
 BNE RPKO8
 JMP RPSAVE
RPKO8 CMP #$45
 BNE RPKOZ
 JMP RPEXP
RPKOZ RTS

* ================= SCROLLING =================
* PTOP is the page line shown on the first window
* row.  RPMAX pins it, so a page shorter than the
* window cannot be scrolled off the bottom and a
* page exactly as tall as the window cannot scroll
* at all.
RPUP LDA PTOP
 BEQ RPRED
 DEC PTOP
RPRED JMP RPDRAW
RPDN JSR RPMAX
 CMP PTOP
 BEQ RPRED
 BCC RPRED
 INC PTOP
 JMP RPRED
RPPGU LDA PTOP
 SEC
 SBC #NPAGE
 BCS RPPU1
 LDA #0
RPPU1 STA PTOP
 JMP RPRED
RPPGD JSR RPMAX
 STA PMX
 LDA PTOP
 CLC
 ADC #NPAGE
 CMP PMX
 BCC RPPD1
 LDA PMX
RPPD1 STA PTOP
 JMP RPRED

* ---- RPMAX: the largest legal PTOP -> A --------
* Never negative: a page no taller than the window
* pins the top line at zero.
RPMAX SEC
 LDA HPLEN
 SBC #NPAGE
 BCS RPMXD
 LDA #0
RPMXD RTS

* ---- RPGOTO: OA-G, a page line to the top ------
* The prompt is 1-based, as printed pages are, and
* PTOP is 0-based, as an index is.  One DEC is the
* whole of the conversion, and it happens here
* rather than in five places downstream.
RPGOTO LDA #<MGOTO
 STA STRPTR
 LDA #>MGOTO
 STA STRPTR+1
 JSR LINEIN
 JSR CLRLINE
 LDA LIRES
 BNE RPGD
 LDA LLEN
 BEQ RPGD
 JSR ATOI
 STA GTMP
 BEQ RPGD
 DEC GTMP
 JSR RPMAX
 CMP GTMP
 BCS RPG1
 STA GTMP
RPG1 LDA GTMP
 STA PTOP
 JMP RPDRAW
RPGD RTS

* (DOPREV, SA-C, is in RPTEXP.S since 2026-11-08)
