* RPTBAR.S  REPORT command bar and literals
* PUT from REPORT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* REPORT resolve against each other in pass two.
*
* ================= THE COMMAND BAR ==============
* row, string, column - and $FF at the end.
* Row 22 only.  Row 23 is the question line, and a
* bar that every prompt erases is worse than none.
BARTAB DFB 21
 DA BR1S
 DFB 1
 DFB 21
 DA BR2S
 DFB 13
 DFB 21
 DA BR3S
 DFB 27
 DFB 21
 DA BR4S
 DFB 40
 DFB 21
 DA BR5S
 DFB 52
 DFB 21
 DA BR6S
 DFB 70
 DFB 22
 DA BR7S
 DFB 1
 DFB 22
 DA BR8S
 DFB 13
 DFB 22
 DA BR9S
 DFB 27
 DFB 22
 DA BRAS
 DFB 40
 DFB 22
 DA BRBS
 DFB 52
 DFB $FF

* $00 says "the next byte is a raw screen code":
* $41 is the open apple, $40 the solid one.  The
* length counts BYTES, so a $00,$41 pair is two
* and draws one column.  Two rows since 2026-11-08,
* rows 21 and 22; row 23 stays the question line.
BR1S DFB 8
 DFB $00,$41
 ASC '-A Add'
BR2S DFB 11
 DFB $00,$41
 ASC '-D Delete'
BR3S DFB 10
 DFB $00,$41
 ASC '-G Go to'
BR4S DFB 9
 DFB $00,$41
 ASC '-B Band'
BR5S DFB 15
 DFB $00,$41
 ASC '-I Dictionary'
BR6S DFB 8
 ASC 'ESC Exit'
BR7S DFB 8
 DFB $00,$41
 ASC '-N New'
BR8S DFB 9
 DFB $00,$41
 ASC '-O Open'
BR9S DFB 9
 DFB $00,$41
 ASC '-S Save'
BRAS DFB 11
 DFB $00,$41
 ASC '-E Export'
BRBS DFB 9
 DFB $00,$40
 ASC '-C Code'

* ---- CMDLIST: the Open-Apple letters we take ---
* PROMPT's LINEIN walks this and swallows anything
* not on it, so a command that does not exist yet
* cannot reach a dispatcher that would not know
* what to do with it.  It grows a slice at a time:
* slice 4 adds B and P, slice 5 S N and O, slice 6
* E.  A add, D delete, G go to a line.
CMDLIST DFB $41,$44,$47,$42,$49,$4E,$4F,$53,$45,$00

* ================= THE RULE'S WORDS =============
MPAGE DFB 11
 ASC ' PAGE LINE '
MOF DFB 4
 ASC ' OF '
MBAND DFB 8
 ASC '   BAND '

* ---- band names, indexed by BANDOF's answer ----
BNTAB DA BNONE
 DA BHEAD
 DA BDET
 DA BFOOT
BNONE DFB 4
 ASC 'NONE'
BHEAD DFB 7
 ASC 'HEADING'
BDET DFB 6
 ASC 'DETAIL'
BFOOT DFB 7
 ASC 'FOOTING'

* ================= MESSAGES =================
MNODCT DFB 13
 ASC 'NO DICTIONARY'
MGOTO DFB 11
 ASC 'Page line? '

* ---- slice 2: placing and removing an entry ----
MLINEQ DFB 6
 ASC 'Line? '
MCOLQ DFB 8
 ASC 'Column? '
MKIND DFB 18
 ASC 'Kind L/R/P/D/F/T? '
MFLDQ DFB 12
 ASC 'Field name? '
MNOFLD DFB 31
 ASC 'No such field in the dictionary'
MNEEDD DFB 39
 ASC 'Open a dictionary first, OA-I (key)    '
MNUMF DFB 36
 ASC 'A total needs a number field (key)  '
MTEXTQ DFB 6
 ASC 'Text? '
MCHARQ DFB 11
 ASC 'Rule char? '
MWIDQ DFB 7
 ASC 'Width? '
MPICTQ DFB 9
 ASC 'Picture? '
* Every message ends '(key)' so the wait for a
* keypress is never a mystery.
MFULL DFB 17
 ASC 'Report full (key)'
MBAD DFB 27
 ASC 'Bad line/column/width (key)'
MOVL DFB 20
 ASC 'Entry overlaps (key)'
MNF DFB 21
 ASC 'Entry not found (key)'

* ---- the report's name, shown on row 0 ----
* Room after it for a longer one, the same way
* EDIT's EDNAME carries its own headroom.
RPNAME DFB 8
 ASC 'UNTITLED'
 DS 12
