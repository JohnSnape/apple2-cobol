* CMPCON.S  the compiler's constants
* PUT by COMPILE1, COMPILE2, OBJTEST and LEXTEST,
* straight after EQUATES2 and before any code.
*
* These used to open CMPVAR.S, which is PUT LAST so
* CMPEND marks the end of the code.  But CMPEMIT,
* CMPPIC, CMPDATA and CMPPROC all use them first,
* and Merlin 8 calls a small EQU met after its use
* an ILLEGAL FORWARD REFERENCE - sixty-one of them
* across the two passes.  Constants take no bytes,
* so moving them changes nothing in either object.

* ---- the four build areas -----------------------
* Addresses, not storage: nothing here is in the
* object file, and the overlay does not carry 6K of
* DS across a floppy every time it is called.
*
* SYMTAB IS CARVED OUT OF THE CODE AREA, and the
* arithmetic behind that is worth writing down.  The
* interpreter gives an object and its data segment
* 8K TOGETHER, so descriptors + pool + code cannot
* usefully exceed about five of it whatever we do
* here; 512 + 512 + 3072 is 4,096, which leaves
* four kilobytes of working storage.  The symbol
* table is not in the object at all, so the 1K it
* takes is 1K the object was never going to be able
* to use.
* Slice 5 moved the boundary DOWN once: the
* PROCEDURE parser is the biggest piece of the
* compiler and 6,144 bytes did not hold it beside
* the rest.  Descriptors and pool halved to pay for
* it, which costs nothing real - SYMTAB holds 64
* names and there is no way to declare a 65th item
* to describe.  The two limits now agree, which
* they did not before.
* MOVED 2026-08-16, for COMPUTE and EVALUATE.  The
* PROCEDURE parser had 566 bytes left and the two of
* them are about a thousand.
*
* THE SYMBOL TABLE LEFT THE BAND ALTOGETHER.  It is
* 1,024 bytes that exist only while a compile is
* running, and $1000-$13FF is CATBLK plus the front
* of DCTBUF - the directory block and the loaded
* dictionary.  NOTHING IS CATALOGUING AND NO
* DICTIONARY IS LOADED WHILE THE COMPILER RUNS, so
* the borrow costs nothing; it is the same argument
* QRYLOAD already makes for staging a .QRY there,
* and it survives the pass swap for the same reason
* everything else does - the menu does not touch it.
*
* So the code band grew by a whole kilobyte and
* OBCODE did NOT have to shrink, which was the other
* way of finding the room and would have capped a
* compiled program at 2K of p-code.
* OBLIT went from 512 to 384 on 2026-08-16, for the
* inline PERFORM and the scope terminators.  It is
* not a squeeze: LITSMX caps the pool at 64 entries
* and LTAB is 64 entries of three bytes, so 512 was
* never reachable - the average literal in the three
* samples is under six bytes.  The code band takes
* the 128.
* MOVED AGAIN the same day: OBDESC and OBLIT
* followed SYMTAB out of the band, onto TEXT PAGE 2
* - 1,024 bytes of display memory nothing displays
* while a compile runs.  The menu draws on page 1
* and SCRPRV repaints page 2 from scratch on every
* entry, so the borrow costs what the SYMTAB borrow
* cost: nothing.  The band's code ceiling is OBCODE
* at $A400 now, and the pool keeps the 384-byte cap
* the LITSMX arithmetic above established.
* BACK TO 512 on 2026-11-11, and the arithmetic
* above was wrong twice.  LITSMX caps only the table
* that finds repeats (EMFADD stops recording, it
* does not refuse), so it never capped the pool;
* and a numeric literal is a NUM8 cell, nine bytes,
* not six.  The DATES library procedure and its test
* filled 384 bytes by line 113.  The 128 bytes come
* from the end of text page 2, $0B80-$0BFF, which
* nothing used: OBDESC 512 + OBLIT 512 is the page.
* AND THEN OFF THE PAGE, the same day: WORDS, the
* cheque-amount procedure, is 330 bytes of literals
* by itself, and 512 left a program using it almost
* nothing.  The pool is now IOBUF2 and IOBUF3,
* $B400-$BBFF - the two file buffers a RUNNING
* program's SELECTs use (RECMAN) and the Utilities
* copy uses.  Nothing opens a second file during a
* compile, and the menu loads COMPILE2 through
* IOBUF, so the pool survives the pass swap.  2,048
* bytes; $0A00-$0BFF on page 2 is free again.
* An object is header + descriptors + pool + code,
* loaded at $9200 under the file buffers at $B000:
* a bigger pool is taken from the room the data
* segment had, which is the right trade - a pool
* that is full stops the compile, room that is not
* used costs nothing.
OBDESC EQU $0800
OBLIT EQU $B400
* SYMTAB left for the aux card on 2026-11-11
* (SYMAUX.S); $1000-$13FF is not borrowed any more.
* THE P-CODE IS BUILT IN AUXILIARY MEMORY since
* 2026-11-22 (the user: "we need space for our
* users").  It was OBCODE, $A500-$AFFF in main -
* 2,816 bytes, between COMPILE2 and the file
* buffers - and a seven-item menu program (SALESDB)
* filled it four lines from the end.
*   Aux bank 0 holds the source as 512 records of 80
* bytes from $0C00, which ends at $AC00; QUERY's
* cursor uses the top of the bank only while a
* program RUNS.  So while compiling $AC00-$BEFF
* ($BF00 up is not ours) is free: 4,864 bytes.
*   It is DATA there, not code: the compiler writes
* and patches it through EMXMOV (CMPEMIT.S), and the
* object file is written from it a block at a time
* through CODSTG.  Nothing ever runs from aux, so
* MEMMAP's rule - aux holds data, never code - stands.
*   CODSTG is the old buffer's main-memory space,
* now a staging area: the object writer and the AT
* shift (PDDAT) copy through it.
CODAUX EQU $AC00
CODSTG EQU $A500
CODSTN EQU $0B00
* 128 since 2026-11-11: the descriptors have all of
* text page 2, $0800-$0BFF, which nothing else uses
* while compiling (the pool left it the same day)
DESCMX EQU 128
LITMAX EQU $0800
* 4,864: $AC00-$BEFF in aux (2,816 until 2026-11-22)
CODMAX EQU $1300

* ---- opcode numbers ----------------------------
* Transcribed from VMTAIL.S's dispatch table, which
* is the only thing that decides what these are.
* The gaps are real: every number not listed here
* points at VBAD, so a compiler bug that emits a
* wrong byte faults on that byte and names it
* rather than walking off into data.
ONOP EQU $00
OHALT EQU $01
OLINE EQU $02
OENTER EQU $03
OMOVA EQU $10
OMOVN EQU $11
OMOVE EQU $12
OMOVG EQU $13
OMOVL EQU $14
OMOVF EQU $15
OINIT EQU $16
* $17 MOVD: text -> number, de-edited (2026-11-08)
OMOVD EQU $17
* $18 SUBS: a table element into a slot (FIXLIST A2)
*   slot(b, bit 7 = the subscript is a number)
*   item(w) subscript(w) count(b) stride(b)
OSUBS EQU $18
OADDP EQU $30
OSUBP EQU $32
OMULP EQU $34
ODIVP EQU $36
OPUSHD EQU $50
OPUSHL EQU $51
OPOPD EQU $52
OEADD EQU $53
OESUB EQU $54
OEMUL EQU $55
OEDIV EQU $56
OENEG EQU $57
* $58 POPDR: POPD, ROUNDED (2026-11-08)
OPOPDR EQU $58
* $59 SZON, $5A SZCHK, $5B SZSKP target(w): size
* errors - SZON opens every ADD SUBTRACT MULTIPLY
* DIVIDE COMPUTE, SZCHK closes one with no ON SIZE
* ERROR, SZSKP jumps a REMAINDER (2026-11-11)
OSZON EQU $59
OSZCHK EQU $5A
OSZSKP EQU $5B
OCMPN EQU $60
OCMPA EQU $61
* $62 CLASS: item word, test byte, map word
OCLASS EQU $62
OBRA EQU $63
OBEQ EQU $64
OBNE EQU $65
OBLT EQU $66
OBGT EQU $67
OBLE EQU $68
OBGE EQU $69
OBSIZ EQU $6A
OBEXC EQU $6B
OPERF EQU $70
ORET EQU $74
OGOTO EQU $75
ODISP EQU $80
ODISPL EQU $81
* $82 AT: move the cursor - line byte, column byte
OAT EQU $82
OACC EQU $83
ONL EQU $86
ODISPN EQU $84
ODISPLN EQU $8A
ODISPP EQU $88
ODISPPL EQU $89
* $97 DISPPN and $98 DISPPLN: an item or a literal
* to the PRINTER without ending the line - every
* operand of DISPLAY a b c UPON PRINTER but the
* last.  The same three bytes as DISPN and DISPLN,
* so PDDPAT can patch them in place (2026-11-22,
* FIXLIST A22)
ODISPPN EQU $97
ODISPPLN EQU $98
* $99 FNAME: no operand - the ACCEPT after it is a
* file name (2026-11-22, DECISIONS 8.11, PDAFN)
OFNAME EQU $99
* $87 ACCA: line byte, column byte, dest word
OACCA EQU $87
* $85 ACCF: dest word, code byte (0 DATE, 1 TIME)
OACCF EQU $85
* $8B ERASE dev, $8C SETPR flag, $8D SETPX n kind
* operand, $8E MENU item flags count lines - DISPLAY
* ERASE, SET PRINTER, SET PREFIX and ACCEPT FROM MENU
* (2026-11-11, CMPSET.S)
OERASE EQU $8B
OSETPR EQU $8C
OSETPX EQU $8D
OMENU EQU $8E
* $8F CASE flag: $40 UPPERCASE ONLY, 0 ANYCASE -
* what ACCEPT does with a typed letter (CMPENV.S,
* 2026-11-12)
OCASE EQU $8F
* (MNBUF, the 2K the .MNU was loaded into at $9C00,
* went on 2026-11-11: ACCEPT FROM MENU streams the
* file now, CMPSET.S, and COMPILE2 may run to OBCODE)
* ---- the query verb ($D0-$DF services) ---------
* $D3 QBE is reserved and traps: what writes a .QRY
* is the QUERY overlay an operator runs, not
* anything a compiled program emits.
OQOPEN EQU $D4
OQNEXT EQU $D5
OQSORT EQU $D7
OQFLD EQU $D8

* ---- descriptor type codes ---------------------
* Six, not eight: NUM8 collapsed num-display,
* packed and signed into one eight-byte cell.
TALPHA EQU 0
TNUMB EQU 1
TBIN EQU 2
TBOOL EQU 3
TGROUP EQU 4
TEDIT EQU 5

* ---- the literal table size ----
* (moved here from CMPVAR's literal-table section)
LITSMX EQU 64

* ---- the lexer's token codes ----
* (moved from CMPLEX.S: LEXTEST compares against
* them before it PUTs the lexer)
TKEOF EQU 0
TKWORD EQU 1
TKNUM EQU 2
TKSTR EQU 3
TKPUNC EQU 4
TOKMAX EQU 40

