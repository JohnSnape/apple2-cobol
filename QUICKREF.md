# COBOL quick reference

Every keyword this system accepts, division by division, on one page each.
Print it and keep it by the machine.

`KEYWORDS.md` is the same list with **what each word costs us** — compile-time,
codegen, an opcode, a library routine. This one is for somebody *writing a
program*, so it says what the word does and whether it works yet.

| Mark | |
|---|---|
| ✔ | works — the runtime behind it is built |
| ◑ | compiles, but the runtime traps or is unwritten |
| ✘ | reserved: recognised and rejected with a clear message |

✔ means *built end to end* — compiler, interpreter and library — and run in
AppleWin by the test suite (`tools/emu/suite.ps1`). Merlin32 assembles it;
the Merlin 8 builds for the book wait until the system is complete
(DECISIONS §8.1). The four ◑ marks this table used to carry were checked
2026-11-20 against `fchk`, `fchk2`, `notat`, `exc` and `qfile`.

---

## The shape of a source line

No sequence numbers and no identification field. Eighty columns, all of them
text.

```
col 1     indicator     * = comment,  - = continuation
col 2-5   Area A        division, section, paragraph and FD names,
                        level 01 and 77
col 6-80  Area B        everything else
```

TAB moves **4 columns**, which is exactly the Area A → Area B step. `EDIT`
shows no line number, because screen column *n* is source column *n*.

A word is up to 30 characters of `A-Z 0-9 -`, not starting or ending with a
hyphen. Case is not significant. A literal is `"..."` or `'...'`; a figurative
constant is a word. A statement ends at a full stop, and a full stop is
required at the end of a paragraph.

---

## IDENTIFICATION DIVISION

```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEADS.
```

| Keyword | | |
|---|---|---|
| `IDENTIFICATION DIVISION` | ✔ | required |
| `PROGRAM-ID` | ✔ | goes in the object header |

`AUTHOR`, `DATE-WRITTEN`, `INSTALLATION`, `SECURITY`, `REMARKS` — taken and
ignored. Everything up to `ENVIRONMENT DIVISION` or `DATA DIVISION` is free
text: words, numbers and punctuation are all skipped.

---

## ENVIRONMENT DIVISION

```cobol
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. APPLE-IIE.
       OBJECT-COMPUTER. APPLE-IIE.
       SPECIAL-NAMES.
           INPUT CASE IS ANYCASE.
           QUERY STATUS IS QUERY-CODE.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LEAD-FILE ASSIGN TO "LEADS.DAT"
               ORGANIZATION IS RELATIVE
               ACCESS MODE IS DYNAMIC
               RELATIVE KEY IS LEAD-NUMBER
               FILE STATUS IS LEAD-STATUS.
```

| Keyword | | |
|---|---|---|
| `ENVIRONMENT DIVISION` | ✔ | |
| `CONFIGURATION SECTION` | ✔ | |
| `SOURCE-COMPUTER` / `OBJECT-COMPUTER` | ✔ | the paragraph is read and ignored |
| `SPECIAL-NAMES` | ✔ | |
| `UPPERCASE ONLY` | ✔ | **the default.** Letters typed into any `ACCEPT` become capitals as they are typed |
| `ANYCASE` | ✔ | `ACCEPT` keeps letters as typed. `INPUT`, `CASE` and `IS` may go in front of either |
| `QUERY STATUS IS` | ✔ | a two-digit code after every `QUERY` |
| `CURRENCY SIGN IS` | ✘ | error 50 — wanted (FIXLIST B) |
| `DECIMAL-POINT IS COMMA` | ✘ | error 50 — wanted |
| `CLASS`, `CRT STATUS`, `CONSOLE IS` | ✘ | error 50 |
| `INPUT-OUTPUT SECTION` | ✔ | |
| `FILE-CONTROL` | ✔ | |
| `SELECT [OPTIONAL] ... ASSIGN TO "path"` | ✔ | two files at most. `TO` may be left out |
| `ASSIGN TO` *data-name* | ✔ | **the name is read at every `OPEN`**: one `SELECT` can open `EAST.DAT`, close it, and open `WEST.DAT`. Trailing spaces are dropped and letters upper-cased; a prefix such as `1/` works. Error 15 if the name is not declared; a `SELECT` with no `ASSIGN` is error 18 (2026-11-22) |
| `ORGANIZATION SEQUENTIAL / RELATIVE` | ✔ | taken; every file is relative |
| `ACCESS SEQUENTIAL / RANDOM / DYNAMIC` | ✔ | taken; access is always dynamic |
| `RELATIVE KEY IS` | ✔ | |
| `FILE STATUS IS` | ✔ | two characters, as the standard says |

The case setting is the one clause here that makes code: a program that says
`ANYCASE` gets a one-instruction `CASE` at its start. The case of the
*source* is never significant — keywords and names may be written in either,
and text in quotes is kept as written.

**Anything else is error 50, NOT PART OF THIS COBOL**, at its line —
`ORGANIZATION INDEXED`, `RECORD KEY`, `ALTERNATE`, `LINE SEQUENTIAL`,
`I-O-CONTROL`, `SAME AREA`. Until 2026-11-12 such words were skipped, and
the program ran as something other than what it said.

---

## DATA DIVISION

```cobol
       DATA DIVISION.
       FILE SECTION.
       FD  LEAD-FILE.
       01  LEAD-RECORD.
           05  LEAD-NAME      PIC X(20).
           05  LEAD-BALANCE   PIC S9(6)V99 COMP-3.
           05  LEAD-ACTIVE    PIC X.
               88  IS-ACTIVE  VALUE "Y".
       WORKING-STORAGE SECTION.
       77  LINE-COUNT         PIC 9(3) VALUE ZERO.
       01  TOTALS.
           05  GRAND-TOTAL    PIC S9(9)V99 VALUE ZERO.
           05  SHOWN-TOTAL    PIC $$$,$$9.99CR.
```

| Keyword | | |
|---|---|---|
| `DATA DIVISION` / `FILE SECTION` / `WORKING-STORAGE SECTION` | ✔ | |
| `FD` | ✔ | `LABEL RECORDS`, `RECORD CONTAINS`, `BLOCK CONTAINS` and `DATA RECORD` are read and passed over: the record is the `01` that follows. `LINAGE`, `REPORT`, `CODE-SET`, `EXTERNAL`, `GLOBAL` and a record `VARYING` in size are error 50 |
| Levels `01`–`49`, `77` | ✔ | groups nest sixteen deep; a 17th group open at once is error 51 |
| `88` condition-name | ✔ | `IF IS-ACTIVE`, `IF NOT STAT-OK`, `PERFORM UNTIL ALL-DONE` |
| `PICTURE` / `PIC` | ✔ | the edit happens at MOVE time |
| `USAGE DISPLAY` | ✔ | |
| `USAGE COMP` | ✔ | 2-byte binary, for subscripts and keys |
| `USAGE COMP-3` | ✔ | **accepted, and it means NUM8** — see below |
| `VALUE` | ✔ | initialised in the `ENTER` prologue |
| `OCCURS` | ✔ | one dimension, on an item or a group; `X(2)`, `X(I)`; `SUBS` checks the range at run time. Not at 01/77, not nested, no `VALUE` in a table, eight tables, four subscripts a statement |
| `REDEFINES` | ✔ | two names, one address |
| `SIGN ... SEPARATE` | ✔ | taken; a NUM8 keeps its sign in its flag byte whatever is written |
| `JUSTIFIED RIGHT` | ✘ | error 50 until a move honours it |
| `BLANK WHEN ZERO` | ✘ | error 50 until the edit honours it |

> **Every numeric variable is the same eight bytes**, whatever its PICTURE says
> and whether you write `COMP-3` or not: a NUM8 cell, sign in a flag byte,
> fourteen digits. `COMP-3` is a hint about intent, not a layout request — it
> changes nothing about the storage. One size means one `ADD`, one `COMPARE`,
> one `MULTIPLY`, and no length parameter anywhere in the runtime.

### PICTURE characters

| | |
|---|---|
| `9` | a digit |
| `X` | any character |
| `A` | a letter or space |
| `S` | signed — the sign is in the flag byte, not in the digits |
| `V` | assumed decimal point, takes no room |
| `P` | scaling position |
| `Z` | digit, leading zeros to spaces |
| `*` | digit, leading zeros to asterisks (cheque protection) |
| `$` | currency, fixed or floating |
| `+` `-` | sign, fixed or floating |
| `,` `.` | separator and point |
| `/` `B` `0` | insert a slash, a space, a zero |
| `CR` `DB` | credit / debit, printed only when negative |

`(n)` repeats: `PIC X(20)`, `PIC S9(6)V99`. All of the above are built —
`PICTURE.S` does both directions, edit and de-edit.

`COMP-1`, `COMP-2` (no floating point anywhere in this system), `66 RENAMES`,
`OCCURS DEPENDING ON`, `INDEXED BY`, `INDEX`, `POINTER`, `EXTERNAL`, `GLOBAL`,
`LINKAGE SECTION`, `REPORT SECTION`, `SCREEN SECTION` — ✘, error 50 at the
line. `SYNC` / `SYNCHRONIZED`, `USAGE DISPLAY`, `BINARY`, `PACKED-DECIMAL` and
every `COMP-n` but 1 and 2 are taken: a number is a NUM8 cell whatever its
usage says.

> **`SCREEN SECTION` is dropped on purpose.** `FORMAT` paints the screen and
> generates ordinary `DISPLAY`/`ACCEPT ... AT LINE n COLUMN n` you can read and
> edit. No new grammar, no new p-code, and nothing hidden.

---

## PROCEDURE DIVISION — data movement

| Statement | | |
|---|---|---|
| `MOVE` numeric → numeric | ✔ | the VM aligns the decimal points itself |
| `MOVE` numeric → edited | ✔ | through the PICTURE engine |
| `MOVE` alphanumeric | ✔ | left justified, space filled, truncated right |
| `MOVE` `SPACE` / `ZERO` | ✔ | |
| `MOVE ALL "x"` | ✘ | not built yet — FIXLIST list B |
| `INITIALIZE` | ✘ | not built yet — FIXLIST list B |
| `SET ... TO TRUE` | ✘ | not built yet — FIXLIST list B |

## PROCEDURE DIVISION — arithmetic

| Statement | | |
|---|---|---|
| `ADD` `SUBTRACT` `MULTIPLY` `DIVIDE` | ✔ | two-operand form |
| ... `GIVING` | ✔ | through the expression stack, so no operand is cut short before the arithmetic |
| `DIVIDE ... GIVING q REMAINDER r` | ✔ | r = dividend − q × divisor, with q as stored (cut to its decimals), COBOL's rule. With `ROUNDED`, q is stored rounded after r is worked out |
| `COMPUTE` | ✔ | reverse-Polish onto the expression stack |
| `ROUNDED` | ✔ | half away from zero, on all five verbs; stored by `POPDR` |
| `[ON] SIZE ERROR` statement | ✔ | on all five verbs. A result with more integer digits than the receiver's PICTURE, over 14 digits, or a zero divisor leaves the receiver **unchanged** and runs the statement (or an `IF`/`EVALUATE`/inline `PERFORM` to its end). `NOT ON SIZE ERROR` is not built |
| no `SIZE ERROR` clause | ✔ | the same three cases **stop the run**: "Size error at line n" ("Divide by zero at line n") — a program never goes on with a wrong number |
| `END-ADD` `END-SUBTRACT` `END-MULTIPLY` `END-DIVIDE` `END-COMPUTE` | ✔ | accepted and ignored, like `END-READ`: the clause is one statement |

All of it is exact decimal. There is no floating point and none is coming.

## PROCEDURE DIVISION — logic and flow

| Statement | | |
|---|---|---|
| `IF` / `ELSE` / `END-IF` | ✔ | `THEN` after the condition is optional and ignored |
| `=` `>` `<` `>=` `<=` `NOT` | ✔ | |
| `AND` `OR` `NOT` | ✔ | |
| `IS [NOT] NUMERIC` `ALPHABETIC` `-UPPER` `-LOWER` `POSITIVE` `NEGATIVE` `ZERO` | ✔ | `$62 CLASS` |
| `GREATER THAN OR EQUAL TO` … `( )`, `A = 1 OR 2`, `A > 1 AND < 10` | ✔ | AND binds tighter than OR |
| `EVALUATE` / `WHEN` / `END-EVALUATE` | ✔ | lowers to compares and branches. Nests 4 deep |
| `EVALUATE TRUE` / `WHEN` condition-name | ✔ | |
| `PERFORM` (inline) | ✔ | |
| `PERFORM ... THRU` / `THROUGH` | ✔ | |
| `PERFORM ... TIMES` | ✔ | both forms; a hidden counter per statement |
| `PERFORM ... UNTIL` | ✔ | both forms — a paragraph, or inline to `END-PERFORM` |
| `PERFORM ... VARYING` | ✔ | both forms; one variable (no `AFTER`), not subscripted |
| `GO TO` | ✔ | |
| `EXIT` / `CONTINUE` | ✔ | |
| `STOP RUN` / `GOBACK` | ✔ | |

`ALTER`, `GO TO ... DEPENDING ON`, DEBUG declaratives, segmentation — ✘.

## PROCEDURE DIVISION — screen

| Statement | | |
|---|---|---|
| `DISPLAY` literal / field | ✔ | scrolling console |
| `DISPLAY ERASE` | ✔ | clears the screen and puts the cursor home. Operands may follow: `DISPLAY ERASE "MAIN MENU" AT LINE 1 COLUMN 30`. `$8B` (2026-11-11) |
| `DISPLAY ERASE UPON PRINTER` | ✔ | a new page: nothing on paper; under `SET PRINTER TO SCREEN` it waits for a key and clears. REPORT's page headings start with it |
| `DISPLAY ... AT LINE n COLUMN n` | ✔ | positioned, never scrolls |
| `DISPLAY ... UPON CONSOLE` | ✔ | the screen — the same as no `UPON` |
| `DISPLAY ... UPON PRINTER` | ✔ | `$88`/`$89`; one printer, the slot set in Utilities. Any other word after `UPON` also means the printer. Every operand goes to the printer, sixteen at most before the last (more is error 13) — until 2026-11-22 only the **last** did, and the rest went to the screen (FIXLIST A22) |
| `ACCEPT` field | ✔ | Into a file name (an item a `SELECT` names in `ASSIGN TO`): 64 characters at most, with a beep on each of the last seven (2026-11-25) |
| `ACCEPT ... AT LINE n COLUMN n` | ✔ | Into a file name: 64 characters at most, no beep |
| `ACCEPT ... FROM DATE / TIME` | ✔ | `$85` |
| `ACCEPT ... FROM DAY` | ✘ | not built yet |
| `ACCEPT ... FROM KEY` | ✔ | one keystroke, not shown, as typed. A digit into a number is its value (2026-11-11) |
| `ACCEPT ... FROM MENU "NAME"` | ✔ | clears the screen, draws `NAME.MNU` (centred if it was saved so), waits for one of its keys. The compiler reads the `.MNU` and builds it into the program. `$8E` |
| `ACCEPT ... FROM PREFIX n` | ✔ | the prefix `n/` (0-9) as text, `/HD/DATA/` |
| `SET PRINTER TO SCREEN` / `TO PAPER` | ✔ | where `DISPLAY ... UPON PRINTER` goes. On the screen, a page at a time — see below. `$8C` |
| `SET PREFIX n TO "path"` / item | ✔ | `n` is 0-9; `*/` cannot be set. `$8D` |
| `ACCEPT ... ON EXCEPTION` | ✘ | not built yet: error 12 at the `ON`. `ACCEPT ... FROM KEY` reads command keys instead |

> **The screen is two halves and a program picks one.** The console scrolls,
> wraps, and has a cursor that advances. `AT LINE n COLUMN n` has coordinates
> and never scrolls. Mixing them gives a screen that half-scrolls.

## PROCEDURE DIVISION — files

**All of these work** — `RECMAN.S` in the library, the opcodes in the
interpreter, and the verbs in the compiler — except where a row says not.

| Statement | | |
|---|---|---|
| `OPEN INPUT / OUTPUT / I-O / EXTEND` | ✔ | one file per statement |
| `CLOSE` | ✔ | |
| `READ` / `READ ... NEXT RECORD` | ✔ | |
| `WRITE` / `REWRITE` / `DELETE` | ✔ | `WRITE` names the RECORD, not the file |
| `START ... KEY IS` | ✔ | |
| `AT END` / `INVALID KEY` | ✔ | tests `FILE STATUS`, branches. On `READ`, `READ NEXT`, `WRITE`, `REWRITE`, `DELETE`. A `REWRITE` or `DELETE` of a deleted record, or past the end, is `"23"` (FIXLIST A20, fixed 2026-11-20) |
| `NOT AT END` / `NOT INVALID KEY` | ✘ | not built yet: error 12. Test the flag after `END-READ` instead |

**A relative file is arithmetic, not a structure.** Record *n* lives at byte
(*n*−1) × record-length and nowhere else — no index, no free list, nothing
inside the file but records. Three things follow that a programmer should know:

- **Keys are 1-based.** `RELATIVE KEY` 1 is the first record, as the standard
  says.
- **The record length lives in the file**, in its ProDOS aux field — the same
  place `BASIC.SYSTEM` puts it for `OPEN name,L128`. A `.DAT` is an ordinary
  TXT file with its record length in aux. Only `OPEN OUTPUT` needs you to say
  what the length is, because a file that does not exist yet cannot be asked.
- **Two files open at once.** There are three ProDOS buffers and the catalog
  keeps one, so a program with two `SELECT`s can still let the operator pick a
  file.

### `FILE STATUS` values

Two characters, as the standard says, and the same shape as `CRT STATUS`.

| | |
|---|---|
| `"00"` | it worked |
| `"10"` | end of file — this is what `AT END` tests |
| `"23"` | no such record: past the end, key 0, or deleted - for `READ`, `REWRITE` and `DELETE` alike |
| `"24"` | write outside the file's boundary |
| `"30"` | a ProDOS error that has no better name |
| `"31"` | `OPEN` and the name breaks ProDOS's rules: each part 1-15 characters, a letter first, then letters, digits and periods; 64 in all. Refused, never changed - `MY FILE!.DAT` is not opened as anything else |
| `"34"` | reserved for "no room"; nothing raises it. Rewriting a record past the end is `"23"` |
| `"35"` | `OPEN` and the file is not on the disk |
| `"37"` | wrong mode — writing to an `INPUT` file, say |
| `"41"` | already open |
| `"42"` | not open |

**`DELETE` writes one byte.** A deleted record is one whose first byte is
`$FF`; the rest keeps whatever it held. The space cannot be returned to ProDOS
in any case — record *n* has to stay at byte (*n*−1) × reclen whatever happens
to its neighbours — and `READ NEXT` skips deleted records rather than returning
them.

> **One thing version 1 does not do.** Writing record 500 to a file that holds
> 10 extends it, and the 490 records in between read back as all zeros rather
> than as deleted. Write records in order — which is what `ADD 1 TO WS-LAST`
> then `WRITE` does, and what all three sample programs do — and the gap never
> exists.

## PROCEDURE DIVISION — `QUERY`

One verb, four forms. It runs a `.QRY` file built in the **QUERY designer**
(menu option 6) against records in auxiliary memory, and hands back the ones
that match, in the order the query asked for.

```cobol
       QUERY "ACTIVE" USING "CUSTOMER" FOR 500
           GIVING HOW-MANY
           ON ERROR PERFORM QUERY-FAILED.
       PERFORM SHOW-ONE UNTIL ALL-DONE.
      *
       SHOW-ONE.
           QUERY NEXT GIVING REC-NUMBER
               AT END MOVE "Y" TO WS-DONE.
           IF NOT ALL-DONE
               QUERY FIELD 0 INTO CUST-NAME
               QUERY FIELD 3 INTO CUST-BALANCE
               DISPLAY CUST-NAME " " CUST-BALANCE
           END-IF.
```

| Statement | | |
|---|---|---|
| `QUERY q USING d FOR n` | ✔ | run it over records 0..n−1 in aux memory |
| `QUERY q USING d OF file` | ✔ | over a relative file; deleted records are skipped. Status 5 if the file is not there |
| `... GIVING count` | ✔ | how many records matched |
| `... ON ERROR` | ✔ | taken when the status is not zero |
| `QUERY NEXT` | ✔ | step to the next hit |
| `... GIVING rec` | ✔ | the record number of this hit |
| `... AT END` | ✔ | taken when the hits run out |
| `QUERY SORT` | ✔ | re-sort the hits you already have |
| `QUERY FIELD n INTO x` | ✔ | field *n* of the current record |

**`USING` is not optional.** A query names its fields by number, and a number
means nothing without the dictionary it was built against — which the `.QRY`
file has no room to record. Name the same `.DCT` the designer used.

**Field numbers start at zero** and run in dictionary order — which is the
order the `COPY` copybook `FORMAT` writes declares them, so field *n* is the
*n*th `05`.

### Where the two files come from

This is the one place in the system where a designer's output does **not** come
in through `COPY`, and it is worth understanding once:

| | |
|---|---|
| the **record** — names, widths, the items you read into | `COPY CUSTOMER.` — compiled in, from `FORMAT` |
| the **question** — which records, in what order | `"ACTIVE"`, read off the disk when the statement runs |

So changing the question needs no compiler: somebody opens the QUERY designer,
changes *balance over 300* to *balance over 500*, saves, and the next run
selects differently. That is the point of it — and the thing to be careful
about, because the program no longer contains its own answer.

### `QUERY STATUS` codes

| | |
|---|---|
| 0 | ok |
| 1 | more hits than the cursor can hold |
| 2 | the query file holds something we do not understand |
| 3 | no room for the cursor in that bank |
| 4 | too many sort keys, or a composite key over 20 bytes |
| 5 | `OF file-name`, and `RECMAN.S` is not built |
| 6 | the query's conditions do not make sense together |
| 7 | not a `.QRY` file, or too big |
| 8 | a field number the dictionary does not have |
| 9 | the `USING` dictionary could not be read |

`SORT` and `SELECT` are **not** verbs — see the exclusions below. The engine
behind `QUERY` is `SELECT.S` and `SORT.S` in the library, and it never moves a
record: a result is a list of record numbers.

---

## Source text — `COPY`

```cobol
       WORKING-STORAGE SECTION.
           COPY CUSTSCR.
           COPY "1/LEDGER".
       PROCEDURE DIVISION.
           ...
           COPY CUSTSCR.
           COPY DATES.
```

| | | |
|---|---|---|
| `COPY name.` / `COPY "name".` | ✔ | the compiler reads the file and compiles its lines in place of the statement (2026-11-11) |
| `COPY ... OF / IN library-name` | ✘ | error 44 — write a prefix or a path instead: `COPY "*/PROCS/DATES".` |
| `COPY ... REPLACING` | ✘ | error 44 |
| `REPLACE` | ✘ | |

Not a verb — a compiler directive, with no runtime existence whatsoever. It is
how a generated screen or report gets into a program: `FORMAT` re-exports, you
recompile, and the program has the new layout with no editing. A placed
snippet is a snapshot; `COPY` is a live reference.

**A `.SNP` is copied by division.** `FORMAT`, `REPORT` and the procedure
library write one `.SNP` in pieces parted by lines that are a lone `*` — the
notes, then the data, then the paragraphs, the same pieces `SA-P` places.
`COPY` takes the piece that fits where it is written: in the DATA DIVISION the
data (between the first lone `*` and the second), in the PROCEDURE DIVISION
the paragraphs (everything after the second). So the same `COPY CUSTSCR.` is
written twice, once in WORKING-STORAGE and once among the paragraphs. A file
with no lone `*` is copied whole, wherever it is.

**Where it looks.** A name with no suffix gets `.SNP`. A bare name is looked
for in `0/` and then in `*/PROCS/`, so `COPY DATES.` finds the library. A name
with a `/` in it — a prefix name like `"1/LEDGER"` or a full path — is used as
written, and has to be quoted.

**The rules.** `COPY` nests one deep: a copybook may not contain a `COPY`
(error 45). `COPY` ends its line — anything after its full stop is not read. A
`PROCEDURE DIVISION` header may not come out of a copybook (error 47). A
copybook's lines go into auxiliary memory after the program's; if there is no
room, error 46. An error inside a copybook is reported at the `COPY`'s line,
with the line in the book: `at line 10, COPY book line 2`.

| Error | |
|---|---|
| 43 | `COPY BOOK NOT FOUND` |
| 44 | `WRITE COPY, A NAME, A FULL STOP` |
| 45 | `COPY INSIDE A COPY BOOK` |
| 46 | `NO ROOM FOR THE COPY BOOK` |
| 47 | `PROCEDURE DIVISION IN COPY BOOK` |

Two more errors, not COPY's: **49** `PROGRAM AND DATA OVER 7,680 BYTES` —
the object and its WORKING-STORAGE must fit between `$9200` and the file
buffers at `$B000`; and **50** `NOT PART OF THIS COBOL` — a clause, section or
level this compiler does not have.

---

## The Apple command keys

**Not written yet** — `CRT STATUS IS` is error 50 until it is (FIXLIST B).
The runtime keeps the two bytes below; the clause that names a field for them
is what is missing. As designed, `SPECIAL-NAMES. CRT STATUS IS ws-item.`
gives you a two-character field that says how the last `ACCEPT` ended:

| First character | |
|---|---|
| `"0"` | RETURN |
| `"1"` | ESC |
| `"2"` | TAB |
| `"3"` | Open-Apple + the key in the second character |
| `"4"` | Solid-Apple |
| `"5"` | both |

```cobol
       01  KEY-STATUS.
           05  KEY-HOW    PIC X.
               88  ENTERED   VALUE "0".
               88  CANCELLED VALUE "1".
           05  KEY-CHAR   PIC X.

           ACCEPT CUST-NAME AT LINE 5 COLUMN 20.
           EVALUATE KEY-STATUS
               WHEN "3P"  PERFORM PRINT-THE-LIST
               WHEN "3Q"  PERFORM FINISH
           END-EVALUATE.
```

**Acting on a command key needs no new keyword** — `EVALUATE` already does it.
A program that never declares a `CRT STATUS` never sees a command key, and
`OA-P` simply types a `P`.

`OA-Ctrl-Reset` reboots the machine and nothing can intercept it. `KEYS.md` is
the full contract.

---

## The editor's clipboard

| Keys | |
|---|---|
| Open-Apple + Up / Down | select whole lines, from the line the cursor was on; drawn in inverse |
| Ctrl-C | Copy the selection — or the cursor line, if nothing is selected |
| Ctrl-X | Cut the same |
| Ctrl-P | Paste above the cursor line |
| ESC | with a selection: drop it (and stay in the editor) |
| Solid-Apple + Up / Down | page up / down (Open-Apple's until 2026-11-11) |
| Solid-Apple + Left / Right | start / end of the line |

The clipboard is the file `CLIPBOARD.CLP` in the current prefix — plain text,
one line to a carriage return — so it outlives the editor: cut from one
program, open another with OA-O, paste. Whole lines only, because COBOL's
columns mean something. A VIEW allows selecting and Copy, not Cut or Paste.

## The procedure library

`SA-P`, `P`, then a name: `DATES`, `TEXT`, `SCREEN`, `MONEY` or `WORDS`,
from the `PROCS` folder (a name starting with `/` is used as it is). Place it
twice — `D`ata in WORKING-STORAGE, `P`aragraphs at the end of the PROCEDURE
DIVISION; the default answer is the one that fits where the cursor is. Or
write `COPY DATES.` in both places instead, and the compiler reads it from the
library every time (see `COPY`, above). The notes at the top of each `.SNP` say
what each paragraph does and what it costs.

| File | Prefix | Paragraphs |
|---|---|---|
| `DATES` | `DT-` | check a date, leap year, day number and back (1 March 1900 – 28 February 2100), day of the week, add days, today |
| `TEXT` | `TX-` | length, trim, upper and lower case, centre, right-justify |
| `SCREEN` | `SC-` | Y/N, press RETURN, a menu choice, a number in a range — each asks again until the answer is usable |
| `MONEY` | `BM-` | percent, simple interest, monthly compounding, loan payment, amortization schedule — to the cent |
| `WORDS` | `NW-` | an amount in words for a cheque: ONE THOUSAND TWO HUNDRED THIRTY-FOUR AND 56/100 |

## A report on the screen, a page at a time

```cobol
           DISPLAY "P)rint or S)creen?" ACCEPT ANS FROM KEY.
           IF ANS = "S" SET PRINTER TO SCREEN.
           PERFORM RPT-BEGIN.
           ...
           PERFORM RPT-END.
           SET PRINTER TO PAPER.
```

The same REPORT paragraphs print or show. On the screen every report page
starts on a clear screen, a page longer than the screen stops when it is full,
and every stop says *Press a key to go on*. The blank lines REPORT pads a page
with on paper never reach the screen.

## Menus

`FORMAT`, `OA-M`: each line is a row, a column and up to 72 characters of
text. A line written `1) Add a contact` or `A) Add` answers to the key before
the `)`; any other line is a title. Each key may be used once: a second `Q)`
(or `q)`, since keys are upper cased) is refused with `Key already used`,
and the compiler stops a `.MNU` made elsewhere that has one key twice
(error 42, `MENU KEY USED TWICE`).
`OA-S` saves `NAME.MNU` (type `$4E MNU`)
and asks whether to centre it; `OA-O NAME.MNU` opens it again; `OA-D` takes out
the lines on a row. In a program:

```cobol
           ACCEPT CHOICE FROM MENU "MAIN".
           EVALUATE CHOICE
               WHEN "1" PERFORM ADD-CONTACT
               WHEN "Q" GO TO FINISH
           END-EVALUATE.
```

Letters come back upper case; any key that is not on the menu rings the bell.
The menu is read when the program is **compiled** — change the `.MNU`,
compile again.

## Prefixes

ProDOS 16's idea: a name may start with a prefix name.

| | |
|---|---|
| `*/` | the boot prefix — where `COBOL.SYSTEM` is. Set at boot; nothing can change it |
| `0/` | the program prefix — ProDOS's current prefix, where programs and objects live |
| `1/` to `9/` | for data and anything else: `1/CUST.DAT` |

Anywhere a file is named — `ASSIGN TO "1/CUST.DAT"` (or a data name holding
`1/CUST.DAT`), EDIT's open and save,
FORMAT, QUERY, RUN, Utilities — the prefix name is replaced by the directory
it holds. Utilities 8 sets them and saves them with the printer slot in
`*/COBOL.SETTINGS`, read at boot; a program can set them for the session with
`SET PREFIX`. The system's own files always come from `*/`.

---

## Not in the subset, and why

| | |
|---|---|
| `CALL` / `CANCEL` / `LINKAGE` | one program at a time |
| `SORT` / `MERGE` the verbs | with their `SD`, `RELEASE` and `RETURN`. **Use `QUERY SORT`** — the engine is in the library and the query verb is the door to it |
| `SELECT` as "pick records" | `SELECT` means the FILE-CONTROL clause and nothing else. The record-picking is `QUERY` |
| `STRING` / `UNSTRING` / `INSPECT` | phase 2 |
| Report Writer | `REPORT` the tool generates ordinary COBOL instead |
| `SCREEN SECTION` | `FORMAT` generates `DISPLAY`/`ACCEPT` instead |
| Communications, `ENTER`, `EXAMINE`, `TRANSFORM` | dead in the standard too |
| `COMP-1` / `COMP-2` | no floating point |
| `ORGANIZATION INDEXED` | relative files only |

---

## The one-page summary

**Most of COBOL is free.** Two entire divisions and nearly all of the DATA
DIVISION are compile-time only; the runtime cost of the whole language is
concentrated in about fifteen verbs.

**What is still missing** is FIXLIST.md's list B, and each row above marked ✘
says so. (This section used to list GIVING, the PERFORM forms, the class tests,
FROM DATE / TIME, UPON PRINTER and QUERY ... OF as traps; all of them have
been built and tested since.)

**The limits a program meets first** (2026-11-11): 128 names (data names,
88-levels, file names and paragraph names together), each up to **30
characters, all of them significant** — a longer one is refused (error 48),
never cut short; 128 data items (error 2); and 2,048 bytes of literals — a
quoted literal costs its length, **every numeric literal 9 bytes** (a NUM8
cell), and a repeated one is stored once. Names exist only while compiling:
the finished program has item numbers, so a long name costs it nothing.
