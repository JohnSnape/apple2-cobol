* PROMPT.S  the row-23 question line, shared
* PUT from FORMAT.S and REPORT.S - no ORG, not
* assembled alone.  One symbol table spans every
* PUT, so this file and the overlay including it
* resolve against each other in pass two.
*
* Extracted from FORMATD.S 2026-08-15, when REPORT
* turned out to want every routine in it as it is.
* Row 23 is the question line in both overlays, so
* everything here draws there and nowhere else.
*
* ---- TWO SYMBOLS THE OVERLAY MUST DEFINE ----
* CMDLIST  a $00-terminated list of the Open-Apple
*   letters this overlay accepts.  LINEIN returns
*   LIRES=2 with the letter in CMDCH for any of
*   them and SWALLOWS the rest, so a command that
*   does not exist cannot reach the dispatcher.
*   This replaces the five hard CMPs FORMAT had:
*   REPORT accepts eight letters and FORMAT five,
*   and one table costs less than either list.
* DOPREV   the Solid-Apple C handler.  FORMAT
*   renders the COBOL its screen would export and
*   REPORT will do the same for a report; an
*   overlay with no preview yet defines it as an
*   RTS.
* This is the arrangement DISKIO already uses for
* the form arrays: the shared file names them, the
* including overlay owns them.

* ---- LINEIN: prompt=(STRPTR) -> LBUF/LLEN ----
* LIRES 0 = RETURN, 1 = ESC, 2 = an Open-Apple
* command, its letter in CMDCH.
LINEIN JSR CLRLINE
 LDA #23
 STA SCRROW
 LDA #0
 STA SCRCOL
 STA SCRATR
 JSR PUTS
 LDA #0
 STA LLEN
* Both Apple keys down is not Open-Apple - see the
* note at the head of EDITDSP.  Here the answer is
* to wait for another key rather than to return:
* this is a prompt, and abandoning the answer
* half-typed because two keys were held at once is
* not what anybody meant.
LII JSR SHOWCUR
 JSR GETCHORD
 JSR HIDECUR
 LDA CHMOD
 AND #$C0
 CMP #$C0
 BEQ LII
 LDA CHMOD
 BMI LICMD
 LDA CHMOD
 AND #$40
 BNE LISA
 LDA CHKEY
 CMP #$0D
 BEQ LIRET
 CMP #$1B
 BEQ LIESC
 CMP #$08
 BEQ LIBS
 CMP #$20
 BCC LII
* The key is seven bits by now, so the only code
* left at $7F or above is $7F itself - DELETE.
* This line used to be BCS LII, which threw
* it away; now it erases, the same as the left
* arrow, as it does in EDIT.  The //e's DELETE
* key is where a typist reaches to fix a slip.
* Same size, so nothing moves (user, 2026-11-24)
 CMP #$7F
 BEQ LIBS
 LDX LLEN
 CPX LIMAX
 BCS LII
 STA LBUF,X
 INC LLEN
 STZ SCRATR
 LDA CHKEY
 JSR CONV
 JSR PUTC
 JMP LII
LIBS LDA LLEN
 BEQ LII
 DEC LLEN
 DEC SCRCOL
 JMP LII
* The answer is in LIRES for FORMAT and REPORT, and
* in the CARRY for QUERY, which was written against
* carry: clear = an answer, set = ESC or a command.
* Nothing set it, and CMP #$0D leaves it SET on a
* Return, so every QUERY prompt - dictionary, open,
* save, add - gave up silently (2026-11-07).
LIRET LDA #0
 STA LIRES
 CLC
 RTS
LIESC LDA #1
 STA LIRES
 SEC
 RTS

* ---- the Open-Apple commands ----
* Walk CMDLIST rather than testing letters here.
* An unlisted letter falls back into LII, which is
* what keeps a half-typed answer alive when the
* operator reaches for a command this overlay does
* not have.
* The letter is folded to a capital first, into
* CMDCH, and the walk compares against that: with
* Caps Lock up, OA-s used to miss the S on the list
* and do nothing (user, 2026-11-24).  AND #$DF
* leaves the arrows alone - their codes have no
* bit 5 - and nothing that is not a letter folds
* onto one.  The overlays read CMDCH, so they see
* the capital whichever way it was typed.
LICMD LDA CHKEY
 AND #$DF
 STA CMDCH
 LDX #0
LICM1 LDA CMDLIST,X
 BEQ LICMN
 CMP CMDCH
 BEQ LICK
 INX
 JMP LICM1
LICMN JMP LII
LICK LDA #2
 STA LIRES
 SEC
 RTS

* ---- the Solid-Apple commands ----
* SA-D erases the answer and asks again, so it
* restarts LINEIN.  SA-C leaves the prompt alone
* entirely - the preview is on page 2 - so it gets
* back to LII with LBUF, LLEN and SCRCOL untouched
* and the half-typed answer still on row 23.
* folded, so SA-d and SA-c work with Caps Lock up
* (user, 2026-11-24)
LISA LDA CHKEY
 AND #$DF
 CMP #$44
 BNE LISC
 JMP LINEIN
LISC CMP #$43
 BNE LISX
 JSR DOPREV
 JMP LII
LISX JMP LII

* ---- GETCHORD: key -> CHKEY, CHMOD ----
* CHMOD bit7 = Open-Apple, bit6 = Solid-Apple.
* READMOD is called straight off the poll, before
* the key is even masked: the key is latched and
* will wait, but the Apple keys are paddle buttons
* and report only what is held at this instant.
* The fourteen instructions that used to be here
* were the same fourteen in EDITCUR, which is why
* they are in the library now.
GETCHORD LDA KBD
 BPL GETCHORD
 JSR READMOD
 AND #$7F
 STA CHKEY
 LDA KEYMOD
 STA CHMOD
 BIT KBDSTRB
 RTS

* ---- cursor helpers ----
* The cursor is a character, not hardware: an
* inverse space where the next letter will land,
* put back as a normal space when it moves.
SHOWCUR LDA SCRCOL
 STA CCOL
 LDA #$20
 JSR PUTAT
 RTS
HIDECUR LDA SCRCOL
 STA CCOL
 LDA #$A0
 JSR PUTAT
 RTS

* ---- CLRLINE: clear row 23 ----
CLRLINE LDX #23
 JMP CLRROW

* ---- SHOWERR: message on 23 + wait a key ----
* The caller points STRPTR at a length-prefixed
* string.  Every message ends '(key)' so the wait
* is never a mystery.
SHOWERR JSR CLRLINE
 LDA #23
 STA SCRROW
 LDA #0
 STA SCRCOL
 STA SCRATR
 JSR PUTS
SEW LDA KBD
 BPL SEW
 BIT KBDSTRB
 RTS

* ---- ATOI: LBUF/LLEN digits -> A ----
* Multiply by ten the only way this processor
* offers: shift for eight, shift for two, add.
ATOI LDA #0
 STA ATMP
 LDX #0
AT1 CPX LLEN
 BCS ATD
 LDA LBUF,X
 SEC
 SBC #$30
 STA ATDIG
 LDA ATMP
 ASL
 STA ATMP2
 ASL
 ASL
 CLC
 ADC ATMP2
 CLC
 ADC ATDIG
 STA ATMP
 INX
 JMP AT1
ATD LDA ATMP
 RTS

* ---- ISNUM: LBUF/LLEN all digits? -> NUMF ----
ISNUM LDA #1
 STA NUMF
 LDX #0
ISN1 CPX LLEN
 BCS ISND
 LDA LBUF,X
 CMP #$30
 BCC ISNNO
 CMP #$3A
 BCS ISNNO
 INX
 JMP ISN1
ISND RTS
ISNNO LDA #0
 STA NUMF
 RTS

* ---- variables ----
* LBUF is 40 and LINEIN caps typing at 38, which
* leaves the prompt room on an 80-column row.
LLEN DFB 0
CHKEY DFB 0
CHMOD DFB 0
CMDCH DFB 0
LIRES DFB 0
NUMF DFB 0
ATMP DFB 0
ATMP2 DFB 0
ATDIG DFB 0
* LIMAX: how long an answer may be.  38 for every
* prompt but FORMAT's menu text, which sets 72 for
* the one answer and puts 38 back (FMTMNU.S)
LIMAX DFB 38
LBUF DS 74
