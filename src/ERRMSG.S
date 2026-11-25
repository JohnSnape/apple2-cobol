* ERRMSG.S  what a compiler error number means
* PUT from LIB.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Slot 105, vector CMPMSG.  A = the error number,
* out: STRPTR -> a length-prefixed explanation that
* CONPUTS prints as it is.  A, X and Y are used.
*
* WHY IT IS IN THE LIBRARY.  Both compiler passes
* print errors, and pass two has about four hundred
* bytes to spare - not the nine hundred the text
* takes.  The library is resident whenever either
* pass runs, and the menu can reach it too.
*
* The numbers are the ones the compiler has always
* raised; this file only names them.  22 and 26
* are not raised by anything and say so.  31 and 32
* are the lexer's two, which used to stop a compile
* in silence - the passes now report LEXERR as
* 30 + LEXERR.  Added 2026-11-07.
*
* Every entry is a count byte and then the text, in
* number order, so the walk is "skip A-1 strings".

ERMAX EQU 51

ERMSG CMP #ERMAX+1
 BCS ERM9
 TAX
 BEQ ERM9
 LDA #<ERTAB
 STA STRPTR
 LDA #>ERTAB
 STA STRPTR+1
ERM1 DEX
 BEQ ERM8
 LDY #0
 LDA (STRPTR),Y
 SEC
 ADC STRPTR
 STA STRPTR
 BCC ERM1
 INC STRPTR+1
 JMP ERM1
ERM9 LDA #<ERUNK
 STA STRPTR
 LDA #>ERUNK
 STA STRPTR+1
* THE TEXT IS COPIED DOWN.  This module runs from
* the auxiliary language card (GATE.S), and a
* pointer into it means nothing to the caller, who
* would read the ROM at the same address.  ERRBUF
* is in main memory; the longest text is 33.
ERM8 LDY #0
 LDA (STRPTR),Y
 TAY
ERM7 LDA (STRPTR),Y
 STA ERRBUF,Y
 DEY
 BPL ERM7
 LDA #<ERRBUF
 STA STRPTR
 LDA #>ERRBUF
 STA STRPTR+1
 RTS

ERUNK DFB 13
 ASC 'UNKNOWN ERROR'

ERTAB DFB 25
 ASC 'PROGRAM CODE AREA IS FULL'
 DFB 29
 ASC 'TOO MANY DATA ITEMS (128 MAX)'
 DFB 20
 ASC 'LITERAL POOL IS FULL'
* 4
 DFB 19
 ASC 'NAME ALREADY IN USE'
 DFB 24
 ASC 'TOO MANY NAMES (128 MAX)'
 DFB 27
 ASC 'NO PROCEDURE DIVISION FOUND'
 DFB 33
 ASC 'LEVEL NUMBER NOT FOLLOWED BY NAME'
* 8
 DFB 32
 ASC 'DATA ENTRY INCOMPLETE OR MISSING'
 DFB 22
 ASC 'INVALID PICTURE STRING'
 DFB 29
 ASC 'PARAGRAPH NAME ALREADY IN USE'
 DFB 26
 ASC 'PARAGRAPH NAME NOT DEFINED'
* 12
 DFB 32
 ASC 'UNKNOWN STATEMENT OR MISSING RUN'
 DFB 27
 ASC 'OPERAND CANNOT BE USED HERE'
 DFB 31
 ASC 'IF / ELSE / END-IF DO NOT MATCH'
 DFB 17
 ASC 'UNKNOWN DATA NAME'
* 16
 DFB 21
 ASC 'QUERY STATEMENT ERROR'
 DFB 26
 ASC 'TOO MANY FILES (2 MAXIMUM)'
 DFB 22
 ASC 'SELECT STATEMENT ERROR'
 DFB 30
 ASC 'FD NAME IS NOT A SELECTED FILE'
* 20
 DFB 33
 ASC 'FILE KEY OR STATUS NAME UNDEFINED'
 DFB 20
 ASC 'FILE NAME EXPECTED  '
 DFB 26
 ASC 'INTERNAL ERROR (CODE 22)  '
 DFB 29
 ASC 'INVALID EXPRESSION OR OPERAND'
* 24
 DFB 24
 ASC 'ROUNDED NEEDS = AFTER IT'
 DFB 23
 ASC 'EXPRESSION IS TOO DEEP '
 DFB 26
 ASC 'INTERNAL ERROR (CODE 26)  '
 DFB 26
 ASC 'EVALUATE NESTED TOO DEEPLY'
* 28
 DFB 33
 ASC 'WHEN OR END-EVALUATE OUT OF PLACE'
 DFB 32
 ASC 'DECIMAL LITERAL NOT ALLOWED HERE'
 DFB 30
 ASC 'END-PERFORM WITHOUT A PERFORM '
* 31, 32: the lexer
 DFB 27
 ASC 'QUOTED LITERAL NOT CLOSED  '
 DFB 29
 ASC 'WORD LONGER THAN 40 LETTERS  '
* 33: a length is one byte (2026-11-08)
 DFB 29
 ASC 'ITEM OR RECORD OVER 255 BYTES'
* 34: an 88 tests one value (2026-11-08)
 DFB 32
 ASC 'ONE VALUE ONLY - NO LIST OR THRU'
* 35: a data entry ran into the next (2026-11-08)
 DFB 28
 ASC 'FULL STOP MISSING ABOVE THIS'
* 36-39: tables and subscripts (2026-11-08)
 DFB 23
 ASC 'OCCURS NOT ALLOWED HERE'
 DFB 19
 ASC 'NO VALUE IN A TABLE'
 DFB 26
 ASC 'SUBSCRIPT MISSING OR WRONG'
 DFB 30
 ASC 'OVER 4 SUBSCRIPTS IN STATEMENT'
* 40, 41 (2026-11-11)
 DFB 31
 ASC 'MENU FILE MISSING OR NOT A MENU'
 DFB 32
 ASC 'SET PRINTER OR SET PREFIX 0-9 TO'
* 42: two menu lines with one key (CMPSET PDAMN)
 DFB 19
 ASC 'MENU KEY USED TWICE'
* 43-47: COPY (CMPLEX.S LXCOPY, 2026-11-11)
 DFB 19
 ASC 'COPY BOOK NOT FOUND'
 DFB 31
 ASC 'WRITE COPY, A NAME, A FULL STOP'
 DFB 23
 ASC 'COPY INSIDE A COPY BOOK'
 DFB 25
 ASC 'NO ROOM FOR THE COPY BOOK'
 DFB 31
 ASC 'PROCEDURE DIVISION IN COPY BOOK'
* 48: a name declared longer than thirty (SYMAUX)
 DFB 30
 ASC 'NAME LONGER THAN 30 CHARACTERS'
* 49: the object plus its WORKING-STORAGE would run
* into the file buffers at $B000 (COMPILE2 C2SIZE).
* 12,288 since 2026-11-22, when programs moved
* down to $8000 (it was 7,680)
 DFB 32
 ASC 'PROGRAM + DATA OVER 12,288 BYTES'
* 50: a clause, section or level this COBOL does not
* have - refused, not skipped (CMPENV.S, 2026-11-12)
 DFB 22
 ASC 'NOT PART OF THIS COBOL'
* 51: a seventeenth group open at once - the level
* stack holds sixteen (CMPDATA DDPUSH, 2026-11-22)
 DFB 27
 ASC 'OVER 16 GROUP LEVELS NESTED'
