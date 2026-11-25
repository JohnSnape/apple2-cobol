* EDITBAR.S  EDIT command bars and messages
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= THE COMMAND BARS =============
* row, string, column - and $FF at the end.
* The layout is the user's, 2026-11-08:
*  OA-N New     OA-O Open   SA-I Insert   OA-G Go to
*   SA-K Ins/Ovr   ESC Exit                 (row 22)
*  SA-P Place   OA-S Save   SA-D Delete   OA-P Print
*   TAB Area B                              (row 23)
* Columns 1, 13, 24, 37, 49 and 63.
* 2026-11-11: ^C Copy, ^X Cut and ^P Paste were on
* the bars for a morning and came off again at the
* user's word: the keys are the ones every editor
* uses and the manual has them, so the bar keeps
* only what an Apple user would not guess.
* OA-Up/Down select lines; SA-arrows page and go to
* the ends of a line.  The arrows are not on the
* bars either, for the same reason.
BARTAB DFB 22
 DA BARN
 DFB 1
 DFB 22
 DA BARO
 DFB 13
 DFB 22
 DA BARI
 DFB 24
 DFB 22
 DA BARG
 DFB 37
 DFB 22
 DA BARK
 DFB 49
 DFB 22
 DA BARE
 DFB 63
 DFB 23
 DA BARP
 DFB 1
 DFB 23
 DA BARS
 DFB 13
 DFB 23
 DA BARD
 DFB 24
 DFB 23
 DA BARR
 DFB 37
 DFB 23
 DA BART
 DFB 49
 DFB $FF
* the bars in a VIEW: only what still works
VBARTB DFB 22
 DA BARG
 DFB 37
 DFB 22
 DA BARE
 DFB 63
 DFB 23
 DA BARVW
 DFB 1
 DFB 23
 DA BARR
 DFB 37
 DFB $FF

* $00 says "the next byte is a raw screen code":
* $41 is the open apple, $40 the solid one.
BARN DFB 8
 DFB $00,$41
 ASC '-N New'
BARO DFB 9
 DFB $00,$41
 ASC '-O Open'
BARI DFB 11
 DFB $00,$40
 ASC '-I Insert'
BARG DFB 10
 DFB $00,$41
 ASC '-G Go to'
* Ins and Ovr: the one in force is drawn again in
* inverse over this by DMODE, at columns 53 and 57
BARK DFB 12
 DFB $00,$40
 ASC '-K Ins/Ovr'
BARE DFB 8
 ASC 'ESC Exit'
BARP DFB 10
 DFB $00,$40
 ASC '-P Place'
BARS DFB 9
 DFB $00,$41
 ASC '-S Save'
BARD DFB 11
 DFB $00,$40
 ASC '-D Delete'
BARR DFB 10
 DFB $00,$41
 ASC '-P Print'
BART DFB 10
 ASC 'TAB Area B'
BARVW DFB 31
 ASC 'VIEW - read only, nothing saved'
MINS DFB 3
 ASC 'Ins'
MOVR DFB 3
 ASC 'Ovr'

MNEW DFB 32
 ASC 'New program - are you sure?  Y/N'
MGOTO DFB 13
 ASC 'Go to line?  '
MSAVE DFB 10
 ASC 'Save as?  '
MOPEN DFB 7
 ASC 'Open?  '
MSAVED DFB 19
 ASC 'Saved - press a key'
MFULL DFB 27
 ASC 'Out of memory - press a key'
* The two dots are overwritten with the error code
* in hex before this is shown.
MERR DFB 28
 ASC 'Disk error $.. - press a key'
MBADN DFB 27
 ASC 'Bad file name - press a key'
FRTAIL ASC ' BYTES AVAILABLE'

EDNAME DFB 8
 ASC 'UNTITLED'
 DS 8

