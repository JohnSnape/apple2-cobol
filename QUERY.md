# SELECT and SORT — the query engine

The authority on the `.QRY` format, the **cursor**, and the two library
modules `src/SELECT.S` and `src/SORT.S`. Companion to `DICTIONARY.md`, which
this file defers to for everything about a field: a query names fields by
number and reads their type, width and record offset out of the dictionary,
and **may never assume a layout the dictionary does not state**.

ProDOS type `$4D`, mnemonic `QRY`. See `FILETYPES.md`.

---

## 1. The one idea

**A query result is a list of record numbers, not a pile of records.**

Everything else here follows from that. A selection walks the records once and
writes down the numbers of the ones that passed. A sort reorders those numbers.
A report walks them. No record is ever copied, moved, or written back, and the
data itself is never touched by either verb — which is what makes a sort of a
thousand records cost a few seconds instead of a few minutes, and what makes it
safe to sort a file that another part of the program is still holding open.

The list is called the **cursor**, which is the word the instruction-set chapter
already uses for it: `$D4 QUERY` produces `cur` and `$D5 QNEXT` walks it.

## 2. Two words that collide

`SELECT` is already a COBOL keyword — `SELECT ... ASSIGN TO`, the FILE-CONTROL
clause that names a file. It is compile-time only and has nothing to do with
this. `SORT` is a COBOL verb we do not implement and are not implementing here;
`KEYWORDS.md` still lists `SORT` / `MERGE` under *not in the subset*, and that
has not changed.

**These are runtime services, not language.** They are called by opcode from a
compiled program and by `JSR` from an overlay, exactly like `CATALOG` or the
PICTURE engine. Naming them after the two things an operator actually asks for
is worth the collision, but the collision is real and the manual has to say so
once.

## 3. The cursor

A cursor entry is one fixed-size record:

```
0            .. keylen-1    the composite sort key, MSB first
keylen       .. keylen+1    the record number, HIGH BYTE FIRST
```

`QESZ` = `keylen + 2` bytes. `keylen` is 0 when nothing is being sorted, so a
plain selection costs **two bytes a hit**.

The cursor lives in **auxiliary memory**, at the top of one bank, growing up
from `QBASE` = `$BF00 − QMAX × QESZ`. Records grow up from `$0C00`; the cursor
comes down from the ceiling; `QRYINIT` refuses to start if the two would meet
(§8).

### Why the key is in the entry

The obvious cursor is a bare list of record numbers, with the sort fetching
each record when it needs to compare. That design is wrong on this machine, and
expensively so: a sort of 1,000 records makes something like 8,000 comparisons,
and each one would be two `AXMAP`s and two aux reads — before the dictionary
walk, the type test and the compare. On a **file** it would be two disk seeks a
comparison, which is not slow, it is unusable.

So the key is extracted **once**, during the selection pass, and the sort never
looks at a record at all. The scan reads each record's key fields once,
sequentially, in record order, which is the only access pattern a floppy is
good at. After that the sort is a byte-string sort over a small array and has
no idea what a dictionary is.

### Three things fall out of it for free

**Multiple keys need no comparator.** The composite key is the key fields laid
end to end in order. `SORT ON BRANCH, DATE` is one byte string, compared once.

**Descending needs no comparator either.** A descending key's slice is
complemented (`EOR #$FF`) as it is built. Reversed byte order is reversed sort
order, so the inner loop stays one unsigned compare with no direction flag in
it. Mixed directions — ascending branch, descending date — cost nothing extra.

**The sort is stable, though the algorithm is not.** Shell sort is not stable,
but the comparison covers the *whole entry*, and the last two bytes of the
entry are the record number, high byte first. Two records with equal keys are
therefore ordered by record number, which is the order the scan visited them.
Ties come out in file order, every time, for nothing.

That last one is why the record number is stored big-endian in a machine that
is otherwise little-endian everywhere. It is the only place in the system where
that is true, and it is deliberate.

## 4. The predicate

A predicate is a short postfix program. It is evaluated against one record at a
time over a boolean stack eight deep, and it is the object a query-by-example
front end (`$D3 QBE`) would compile to.

| Byte | Mnemonic | Operands | Meaning |
|---|---|---|---|
| `$00` | `END` | — | stop; the answer is the one value left on the stack |
| `$01` | `CMPL` | f, r, n, *n* bytes | field *f* **rel** *r* the literal |
| `$02` | `CMPF` | f, r, g | field *f* **rel** *r* field *g* |
| `$03` | `HAS` | f, n, *n* bytes | field *f* contains the literal |
| `$04` | `AND` | — | pop two, push both |
| `$05` | `OR` | — | pop two, push either |
| `$06` | `NOT` | — | pop one, push its opposite |
| `$07` | `ALL` | — | push true |

Relations *r*: `0` EQ, `1` NE, `2` LT, `3` LE, `4` GT, `5` GE.

Field numbers are **0-based**, the same numbering `SCRINP` walks in.

`BALANCE > 0 AND STATE = "CA"` is eleven bytes:

```
01 03 04 01 30      CMPL field 3 GT "0"
01 05 00 02 43 41   CMPL field 5 EQ "CA"
04                  AND
00                  END
```

An empty program — `QPLEN` = 0 — passes everything. **A sort is a selection
that keeps everything**, and that is not a special case in the code: it is a
scan with no predicate.

A program of *just* `END` is a different thing and is rejected with status 6:
the stack has to hold exactly one value when `END` is reached, and a predicate
that computes nothing is a mistake rather than a way of saying "all". Say
"all" with `$07 $00`, or by not having a predicate at all.

### How a comparison is decided

The dictionary's type code for the field decides, and the storage rules in
`DICTIONARY.md` §3 are what make it cheap:

| Type | Compared as | What the engine does first |
|---|---|---|
| 0 ALPHA, 1 ALNUM | text | nothing — `CMPALP` pads the shorter operand with spaces, which is the COBOL rule |
| 2 NUM | text | leading **spaces become zeros**, then the literal is right-justified into the field's width and zero-filled |
| 3 BOOL | one byte | the literal `Y`, `y`, `1` or `$01` becomes `$01`; anything else `$00` |

A numeric field is right-justified and zero-padded digits in the record, so
**a text comparison of two of them is already a numeric comparison**. That is
the whole of the numeric case, and it is a consequence of a storage decision
`FORMAT` made for a different reason years earlier in the project's life.

Three limits, stated rather than discovered:

- A field is read up to **40 bytes** (`QFMAX`). Wider fields compare on their
  first 40 characters.
- Two **numeric fields of different storage widths** compare as text, which is
  not the same as comparing as numbers. Give two fields you mean to compare the
  same width in the dictionary.
- `HAS` is case-sensitive and does no folding. Fold the field with the
  dictionary's upper-case flag if that matters.

There is no sign and no decimal point in any of this, because a screen field
has neither — `DICTIONARY.md` §3 lists four types and `decimals` is always 0.
When edited fields arrive, this is the table that grows.

## 5. The sort

Shell sort over the cursor, with Knuth's `3h+1` gaps — 1, 4, 13, 40, 121, 364,
1093, 3280, 9841 — starting at the largest gap below the entry count.

The reasons are all about what the machine has and has not got:

- **No recursion and no stack.** Quicksort needs a partition stack; on a 6502
  that means either a hardware stack you must bound or a software one you must
  write. Shell sort needs three counters.
- **No second array.** A merge sort needs somewhere to merge *into*, which here
  means a second cursor and twice the auxiliary memory.
- **The inner loop is an insertion**, so a nearly-ordered cursor — the common
  case, because data tends to be entered in something close to an order —
  finishes in close to linear time.
- It is not stable, and §3 explains why that does not matter.

The held element is read out of the cursor once per outer step and stays in
main memory, so one comparison costs **one** aux read of `QESZ` bytes. On a
thousand records that is roughly eight thousand comparisons and about five
seconds. It is not instant and the manual should not pretend it is.

## 6. Where the records come from

`QSRC` says: `0` = records in auxiliary memory, reached through `AXMAP`/`AXGET`
exactly as `EDIT` reaches its source lines; `1` or `2` = the program's relative
file 0 or 1, through `RECMAN` — `QSRC` is the file number plus one.

**The file case works since 2026-11-08.** The file must already be open (`INPUT`
or `I-O`) — `QRYINIT` refuses with status 5 if it is not, and with status 10 if
its records are longer than 512 bytes or shorter than the dictionary's. Each
record is read whole with `RMREAD` into `CATBLK` and the fields are cut out of
it there; `QRCREC` remembers which record `CATBLK` holds, so a scan reads each
record once however many fields it looks at. There is no `QNREC`: the scan
reads until `RECMAN` runs out, and steps over deleted records exactly as
`READ NEXT` does. A deleted record is told from the end of the file by
`CATBLK`'s first byte, which is cleared before each read and is `$FF` afterwards
only if `RMREAD` read a deleted record before refusing it.

`RMREAD` moves the file's `READ NEXT` position, as any `READ` does — a program
walking a file with `READ NEXT` that queries the same file in the middle of the
walk will find its place moved.

The auxiliary case is not a placeholder for the file case. It is how the system
is meant to work: a data file is read into aux once and worked on there, which
is what `AUXMEM.S` is for and what the 5,242,880-byte free count in `EDIT`'s
status line is measuring. A query against aux records is a query at memory
speed.

## 7. The `.QRY` file — 32-byte header

Deliberately the same shape as a `.DCT`: signature, version, a block of
offsets, `poolend`, and a twelve-byte human name at offset 20. Two formats that
are read by the same kind of code should not be laid out two different ways.

| Off | Len | Field | Meaning |
|---|---|---|---|
| 0 | 4 | signature | `"QRY1"` — `$51 $52 $59 $31` |
| 4 | 1 | version | 1 |
| 5 | 1 | flags | bit0 predicate present, bit1 sort spec present |
| 6 | 2 | reclen | the record length this query was built for |
| 8 | 1 | fieldcount | the dictionary's field count, as a sanity check |
| 9 | 1 | keycount | sort keys, 0–4 |
| 10 | 1 | keylen | the composite key length the spec produces |
| 11 | 1 | — | reserved |
| 12 | 2 | specoff | offset to the sort spec. Always 32 |
| 14 | 2 | progoff | offset to the predicate program |
| 16 | 2 | proglen | its length, 0–96 |
| 18 | 2 | poolend | offset to end of file — the file's own length |
| 20 | 12 | qryname | human name, space-padded |

**Sort spec**, at `specoff`: four entries of three bytes, always all four
present so the block is a fixed twelve bytes.

```
byte  field number, 0-based
byte  direction   $00 ascending, $01 descending
byte  key width   FILLED IN BY QRYINIT from the dictionary
```

The width byte is an *output*, not an input. A caller that guessed a width
could disagree with the dictionary, and then a saved query would sort correctly
until somebody widened a field in `FORMAT`. `QRYINIT` overwrites it every time
from the descriptor, and the value in the file is a record of what was true
when it was written, not an instruction.

**What is not in the file: the result.** A cursor is stale the moment a record
changes, and a saved list of record numbers that no longer means what it says
is worse than no list. The file holds the *question*; the answer is built fresh
in a second.

Nothing writes a `.QRY` yet. `SELECT.S` reads one — `QRYLOAD` — and the tool
that writes them is the query-by-example front end behind `$D3`. That is the
same division of labour `FORMAT` and `.DCT` already have: one program writes
the format, everything else reads it.

## 8. Claiming the cursor area

`QRYINIT` is refused rather than allowed to collide. It checks, in order:

1. `QKEYN` ≤ 4.
2. Each key's field exists in the dictionary; its width comes from there; the
   widths total ≤ 20 bytes (`QKMAX`). A longer composite key is an error, not a
   truncation — a silently truncated key sorts *almost* right, which is the
   worst way for a sort to be wrong.
3. `QMAX × QESZ` is smaller than one bank.
4. `QBANK` < `NBANKS`.
5. The bank holding the last record in use (`AXUSED − 1`, through `AXMAP`) is
   below `QBANK`, or is `QBANK` and ends below `QBASE`.

Check 5 is a courtesy and depends on the caller keeping `AXUSED` honest, which
is the same assumption `AMFREE` already makes. **This is not a bank allocator**
— `STATUS.md` still owes one, and when it arrives this check is what it
replaces.

On a plain 128K IIe there is one bank and check 5 does real work: the cursor
and the records share bank 0, and a query over a large enough record set is
told it will not fit instead of quietly writing over record 400.

## 9. Status codes — `QSTAT`

| | |
|---|---|
| 0 | ok |
| 1 | the cursor is full — `QMAX` reached |
| 2 | the predicate holds an opcode we do not know |
| 3 | no room for the cursor in that bank |
| 4 | too many sort keys, or a composite key over 20 bytes |
| 5 | `OF file`: the file is not open, or a record in the cursor has gone since |
| 6 | the predicate is malformed — the stack did not balance |
| 7 | not a `.QRY` file, or too big for the staging buffer |
| 8 | a field number outside the dictionary |
| 9 | the `USING` dictionary could not be read, or is version 1 (`DICTIONARY.md` §3) |
| 10 | `OF file`: its records are over 512 bytes, or shorter than the dictionary's |

**Status 9 is set by the interpreter, not by `SELECT.S`** — it is the only one
that is. Codes 0–8 are the engine's, and the engine is handed a dictionary that
is already in memory; 9 belongs to `$D4`, which is the thing that has to go and
*get* one. Added 2026-08-15 with `VMQRY.S`. An overlay calling `QRYINIT` by
`JSR` will never see it, because an overlay loads its own dictionary.

## 10. The calls

Eight vectors, appended at slots 68–75. The table is append-only; nothing below
68 moved.

| Slot | Addr | Name | In | Out |
|---|---|---|---|---|
| 68 | `$30CC` | `QRYINIT` | `QBANK` `QMAX` `QKEYN` `QSPEC` `QDICT` | `QKEYL` `QESZ` `QBASE`, cursor emptied |
| 69 | `$30CF` | `QRYSCAN` | `QNREC`, `QPROG`/`QPLEN`, the spec | `QCOUNT` |
| 70 | `$30D2` | `QRYFILT` | an existing cursor, a new predicate | `QCOUNT`, compacted in place |
| 71 | `$30D5` | `QRYSORT` | a cursor | the same cursor, in key order |
| 72 | `$30D8` | `QRYGET` | `QIDX` | `QREC`, `QEBUF`; C=1 past the end |
| 73 | `$30DB` | `QRYNEXT` | — | `QREC`, then `QIDX` steps; C=1 at the end |
| 74 | `$30DE` | `QRYLOAD` | `FNAMP` | `QSPEC`, `QKEYN`, `QPROG`, `QPLEN` |
| 75 | `$30E1` | `QRYFLD` | `QREC`, `QFNO` | `QFBUF`, `QFLEN`, `QFTYP` |

`QRYFLD` is public on purpose. It is the only routine in the system that turns
"record 47, field 2" into bytes you can print, and `REPORT` needs exactly that
to put a `FIELD` entry on a page.

The pipeline is always the same three steps, and `QRYFILT` is the only one that
can be repeated:

```
QRYINIT   claim the area, settle the key
QRYSCAN   one pass over the data, building the cursor
QRYSORT   reorder the cursor            (skip if QKEYN = 0)
QRYNEXT   walk it
```

## 11. The opcodes

`PCODE.md` §3 lists `$D0–$D6` as the runtime services, all trapping. Four of
them are this engine, and the chapter's operand shapes are unchanged:

| Op | Mnem | Maps to | Reached from COBOL by |
|---|---|---|---|
| `$D3` | `QBE` | the front end that writes a `.QRY` | **nothing, on purpose** — that is the `QUERY` overlay, run by an operator |
| `$D4` | `QOPEN` | `QRYLOAD` + `QRYINIT` + `QRYSCAN` + `QRYSORT` | `QUERY name USING dict ...` |
| `$D5` | `QNEXT` | `QRYNEXT` | `QUERY NEXT` |
| `$D7` | `QSORT` | `QRYSORT` on an existing cursor | `QUERY SORT` |
| `$D8` | `QFLD` | `QRYFLD`, then a move | `QUERY FIELD n INTO x` |

`$D7` and `$D8` are new assignments inside the reserved `$D0–$DF` block, taken
from the free half above `$D6` rather than from anything already spoken for.
`$D7` exists because sorting a cursor you already have is a separate thing from
running a query, and folding it into `$D4` would mean re-scanning the data to
change the order of a list you are holding.

**`$D4` grew a `QRYLOAD` on the front when the verb was designed.** It used to
be init-scan-sort, which assumed something else had already read the file; a
COBOL program has no way to do that, so the load belongs inside the opcode. The
operand shapes are in §15.5, and none of them touches the four opcodes'
*numbers*, which the instruction-set chapter still owns.

None of the five is wired up. The handlers are about five instructions each,
plus one shared status-and-branch helper, and §15.5 gives the exact dispatch
table edit. There is still no reason to touch `VM.S` before `BCD` and `PICTURE`
have been on the machine.

## 12. Memory taken

Nothing was moved to make room. Every address below was free.

| Where | Size | What |
|---|---|---|
| `$0C90–$0CA9` | 26 | the public parameters |
| `$0DA0–$0DC7` | 40 | `QFBUF`, a fetched field |
| `$0DC8–$0DEF` | 40 | `QLBUF`, a normalised literal |
| `$0DF0–$0DFB` | 12 | `QSPEC`, the sort spec |
| `$0E80–$0EDF` | 96 | `QPROG`, the predicate |
| `$0F90–$0FA7` | 24 | `QKBUF`, an entry under construction |
| `$0FA8–$0FBF` | 24 | `QEBUF`, the held entry |
| `$0FC0–$0FD7` | 24 | `QEBF2`, the entry being compared |

`QRYLOAD` borrows `CATBLK` at `$1000` to stage the file. Nothing is
cataloguing while a query loads, and 512 bytes is more than a query can be.

**No zero page is held across a call.** The predicate's program counter is a
one-byte offset into `QPROG`, indexed absolutely, which is why `QPMAX` is 96
and not 4096. Zone S is caller-saved and the evaluator calls `AXGET` between
every opcode; a pointer in `ZPWORK` would have been destroyed by the first
comparison. `MEMMAP.txt` reserves `$16–$17` for a predicate pointer — that
reservation is now unnecessary and the note there says so.

## 13. What has not been done

- **Neither module has been assembled.** They are checked by script for line
  length, duplicate labels and unresolved symbols, and that is all.
- `QRYTEST.S` is the harness: it fills aux with twenty known records, runs a
  predicate over them, sorts two ways and prints the result. It is the first
  standalone test harness in the tree since the consolidation dropped the old
  ones, and it is meant to be kept.
- The opcodes are not wired into `VM.S` — §15.5 says exactly what the edit is.
- The `QUERY` **statement** is designed (§15) and not parsed: `CMPPROC` has no
  case for it, so a program that uses the verb does not compile yet.
- ~~Nothing writes a `.QRY`.~~ The `QUERY` overlay does, since 2026-08-15.
- ~~`RECMAN` is the file half of §6 and is still owed.~~ `QUERY ... OF
  file-name` works since 2026-11-08 (§6).
- **The `.QRY` header cannot say which dictionary it means** (§15.3). `USING` is
  required in the verb because of it, and a version 2 header is the real fix.

---

## 14. The designer — `QUERY`, the overlay that writes one

Written 2026-08-15. `QUERY.S` + `QRYENT` `QRYADD` `QRYIO` `QRYVAR`, plus
`PRODOS` and `PROMPT` shared with FORMAT and REPORT. 4,105 bytes of the 12K
band. Menu option 6.

**This is the front end opcode `$D3` reserves.** Until it existed, the format
was specified and `SELECT.S` could read one, but nothing produced one — which
made the whole query engine unreachable from a COBOL program.

### The model

Eight conditions and four sort keys, which is what fits on one screen without
scrolling. A condition is a field number, a relation, a literal and the
connector that joins it to the one above:

```
CONDITIONS
     BALANCE     >   000300
AND  STATE       =   CA
SORT KEYS
     BRANCH        ASCENDING
     BALANCE       DESCENDING
```

Field names come out of the loaded dictionary's ten-byte name field — the one
`DICTIONARY.md` §2 calls the format's piece of luck, reserved as ten zeros
before anybody knew what for.

### Conditions join left to right

**`AND` does not bind tighter than `OR`.** `A AND B OR C` is `(A AND B) OR C`,
and `A OR B AND C` is `(A OR B) AND C`.

That is not what a programming language would do, and it is what somebody
reading a list of rules down a screen expects — which is the audience. It is
also the only rule that can be emitted in one pass with no parentheses to type
and no parser to write.

### The compiler is six instructions

Which is the dividend from having specified the predicate as **postfix** in §4
rather than as a tree. Each condition becomes a `CMPL`; each connector becomes
the `AND` or `OR` that *follows* it; `END` finishes. No conditions at all emits
nothing, because §4 says an empty program passes everything and a program of
just `END` is an error.

### Open decompiles

A query you can load but not edit is a query you rewrite from scratch, so
`QOPENQ` walks the predicate back into the arrays. The walk expects exactly
what `QCOMP` emits and rejects anything else — the right strictness, since
nothing else writes these.

### What it does not do

**It does not run the query.** Building a cursor is `SELECT.S`'s job and needs
records in auxiliary memory, which needs `RECMAN`. The designer writes the
question; running it is the runtime's business — exactly as `FORMAT` writes a
screen it never displays.

---

## 15. The `QUERY` verb — how a program runs one

Added to the subset 2026-08-15. `KEYWORDS.md` carries the cost table; this is
the design.

Until now the engine had no door. The library routines were written, the
opcodes were reserved, the designer wrote the files — and there was no way to
say any of it in COBOL, which made `SELECT.S` the largest module in the tree
with no path to a program. One verb closes that.

### 15.1 The question a program asks, and the two files it takes

**A `.QRY` is not source and is never `COPY`d.** This is the first thing to
say, because `FORMAT` and `REPORT` have trained the reader to expect otherwise,
and the difference is not an inconsistency — it is the whole architecture.

| | `FORMAT` → `.DCT` | `REPORT` → `.RPT` | `QUERY` → `.QRY` |
|---|---|---|---|
| What the designer writes | a screen | a printed page | **a question** |
| What the program gets | generated `DISPLAY`/`ACCEPT` | generated group items and paragraphs | **nothing generated** |
| How it arrives | `COPY` at compile time | `COPY` at compile time | **`FLOAD` at run time** |
| When it can change | recompile | recompile | **any time; the program need not be rebuilt** |

The reason is not taste. A screen layout and a print layout are both *code* —
a sequence of moves and displays that COBOL can already express, so generating
COBOL is free and needs no runtime at all. **A query is not code.** Its
predicate is evaluated once per record by an interpreter that is not the VM
(§4), and its sort cannot be written in the subset at all, because `SORT` the
COBOL verb is excluded. Generating COBOL from a `.QRY` would mean generating an
`IF` chain that the compiler must then compile for every query, and a sort that
cannot be spelled. Loading the question at run time costs one `FLOAD` into
`CATBLK` — which `QRYLOAD` already does — and gives the thing `COPY` cannot:

**The question is late-bound.** Somebody can open `QUERY`, change *balance over
300* to *balance over 500*, save, and the report is different the next time it
runs, with no compiler on the disk. For a business tool that is the feature.
It is also the hazard, and the manual has to say so in the same breath: a
program's behaviour now depends on a file it does not contain, and there is
nothing in the object that records which version of the question it was tested
against. `qryname` at header offset 20 is the only human-readable trace.

### 15.2 So `COPY` is not out of it — it brings the vocabulary

A program still has to know what field 2 *is*, and it needs somewhere to put it.
Both come from `FORMAT`'s existing export, which already emits a record
description straight out of the dictionary:

```cobol
       WORKING-STORAGE SECTION.
       COPY CUSTOMER.
```

giving `01 CUSTOMER-REC.` with an `05` per field, in dictionary order. **Field
*n* of a query is the *n*th `05` in that copybook, counting from zero**, because
both come from the same `.DCT` and neither reorders. So the division of labour
is:

- **`COPY` supplies the vocabulary** — the names, the widths, the receiving
  items. Author-time, compiled in, changes only when the *screen* changes.
- **The `.QRY` supplies the question** — which records, in what order. Run-time,
  loaded by name, changes whenever somebody wants different records.

That is the honest answer to "do we do it like FORMAT and REPORT": **half of it
is exactly like FORMAT and REPORT, and the half that is not is the half that
should not be.**

> **One change to `SCREXP` this asks for.** The copybook should carry each
> field's number in a trailing comment — `05 CUST-NAME PIC X(20).` followed by
> `* field 2` — so a programmer writing `QUERY FIELD 2 INTO CUST-NAME` can read
> the number off the copybook instead of counting `05`s. It is one emitted
> comment per field in a routine that already walks the fields in order.

### 15.3 The four forms

```cobol
       QUERY query-name USING dictionary-name
                        { FOR record-count | OF file-name }
                        [ GIVING count-item ]
                        [ ON ERROR imperative ]

       QUERY NEXT [ GIVING record-number ] [ AT END imperative ]

       QUERY SORT [ ON ERROR imperative ]

       QUERY FIELD n INTO identifier
```

A whole report loop, with the record layout `COPY`d in and the question in a
file:

```cobol
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           QUERY STATUS IS WS-QSTAT.
      *
       WORKING-STORAGE SECTION.
       COPY CUSTOMER.
       01  WS-QSTAT            PIC 99.
       01  WS-HITS             PIC 9(4) COMP.
       01  WS-REC              PIC 9(4) COMP.
       01  WS-DONE             PIC X VALUE "N".
           88  ALL-DONE        VALUE "Y".
      *
       PROCEDURE DIVISION.
       MAIN-PARA.
           QUERY "ACTIVE" USING "CUSTOMER" FOR 500
               GIVING WS-HITS
               ON ERROR PERFORM QUERY-FAILED.
           DISPLAY WS-HITS " CUSTOMERS SELECTED".
           PERFORM SHOW-ONE UNTIL ALL-DONE.
           STOP RUN.
      *
       SHOW-ONE.
           QUERY NEXT GIVING WS-REC
               AT END MOVE "Y" TO WS-DONE.
           IF NOT ALL-DONE
               QUERY FIELD 0 INTO CUST-NAME
               QUERY FIELD 3 INTO CUST-BALANCE
               DISPLAY CUST-NAME " " CUST-BALANCE
           END-IF.
      *
       QUERY-FAILED.
           DISPLAY "QUERY FAILED, STATUS " WS-QSTAT.
           MOVE "Y" TO WS-DONE.
```

**Form 1 is the whole pipeline in one statement** — `QRYLOAD`, `QRYINIT`,
`QRYSCAN` and, when the file carries sort keys, `QRYSORT`. §10 says that
sequence is always the same three or four steps, so there was no reason to make
a programmer type them and every reason not to: three statements would let
somebody scan without initialising, which is the one order that silently writes
a cursor into the records.

**`USING` is required, and it is required because of a gap in the file.** The
`.QRY` header is a full 32 bytes (§7) and byte 11 is the only spare one, so
there is nowhere to record *which dictionary the field numbers mean*.
`fieldcount` at offset 8 is a sanity check and nothing more — it catches a query
run against a dictionary with a different number of fields, and not one with the
same number in a different order. So the program names the dictionary, out
loud, in the statement. **This is the one real defect the verb exposed in the
format**; a version 2 header that carries a twelve-byte `dictname` the way
`.RPT` does would let `USING` become optional, and until then stating it is
better than inferring it.

**`FOR` versus `OF` is `QSRC`.** `FOR n` means records 0..n−1 already in
auxiliary memory — `QSRC` = 0, the case `QRYTEST` exercises. `OF file-name`
means a relative file the program has `SELECT`ed and opened — `QSRC` = the
file's number plus one (§6). From a file, `QUERY NEXT GIVING r` gives the
**relative key**, counting from 1, so `MOVE r TO` the key and `READ` fetches
the record; from aux memory it counts from 0. One of them must be
present: a query with no stated source is a compile-time error, not a default,
because the two answers are a memory scan and a disk scan and guessing wrong is
not a small mistake.

**`QUERY SORT` re-orders a cursor you already hold**, which is why `$D7` exists
at all (§11): folding it into form 1 would mean re-scanning the data to change
the order of a list already in memory. It sorts on the spec the `.QRY` was
loaded with.

**`QUERY FIELD n INTO identifier`** is the only way to read anything. It is
`QRYFLD` — the one routine in the system that turns "record 47, field 2" into
printable bytes — followed by a move into the item, chosen from the two
descriptors the way every other move in the VM is chosen. The field number is a
**literal byte in the instruction**, not an item, the same decision `DISPA`
made for `AT LINE n COLUMN n`: it is constant in the source, so it is constant
in the code.

### 15.4 What is not in version 1

- **A whole-record fetch.** `QUERY RECORD INTO CUSTOMER-REC` is the obvious next
  form and it would be one aux read instead of *n* calls. It is not in version 1
  because the generated copybook and the stored record are not quite the same
  bytes: `DICTIONARY.md` §3 stores BOOL as one byte of `$01`/`$00` and `SCREXP`
  emits `9 COMP` for it, which is two. Fix that mismatch first, deliberately,
  rather than shipping a move that is right for three types out of four.
- **A variable field number.** Everything real is constant, and a loop over
  fields wants the whole-record form above rather than a computed `QUERY FIELD`.
- **`QUERY FILTER`** — narrowing a cursor with a second predicate. `QRYFILT`
  (slot 70) is built and this is the only one of the eight vectors the verb does
  not reach. It needs a second `.QRY` naming only a predicate, and no syntax has
  been chosen. Recorded rather than guessed at.

### 15.5 The opcodes, and what a handler does

Four handlers, all in the reserved `$D0–$DF` block. `$D8` is taken from the free
upper half, which is the precedent `$D7` set — nothing at or below `$D6` moves.

**Written into `src/VMQRY.S` on 2026-08-15**, and the file is the specification
made real: 719 bytes, `PUT` between `VMSCRN` and `VMTAIL`.

| Op | Mnem | Operands | Bytes | Calls |
|---|---|---|---|---|
| `$D4` | `QOPEN` | qryname litoff **w**, dictname litoff **w**, src **b**, srcarg **w**, count item **w**, status item **w**, error target **w** | 14 | `FLOAD` → `QRYLOAD` → `QRYINIT` → `QRYSCAN` → `QRYSORT` |
| `$D5` | `QNEXT` | rec item **w**, at-end target **w** | 5 | `QRYNEXT` |
| `$D7` | `QSORT` | error target **w** | 3 | `QRYSORT` |
| `$D8` | `QFLD` | field **b**, dest item **w** | 4 | `QRYFLD`, then the move |

**The status item is an operand of `QOPEN`, and that is how `QUERY STATUS IS`
avoids costing a fifth opcode.** The alternative was an instruction in the
`ENTER` prologue whose only job was to set a pointer. `QOPEN` is necessarily
the first query statement to run — nothing can walk a cursor that was never
built — so recording the pointer there is the same single store, in a slightly
later place, for three bytes instead of an opcode number. `$D5`, `$D7` and
`$D8` write through what it saved.

Conventions, all of them ones the interpreter already uses:

- **`$FFFF` in an item or target operand means the clause was absent.** No
  `GIVING`, no `AT END`, no `ON ERROR`. It is not a valid item number and not a
  valid code offset, so no test is ambiguous.
- **Targets are offsets from the code base, never relative** — `PCODE.md` §4.
  `AT END` and `ON ERROR` are ordinary forward branches on the fixup chain, the
  same as `IF`'s.
- `src` is `0` for `FOR` (aux, `srcarg` = the item holding the count) and `1`
  for `OF` (a file, `srcarg` = the FCB item).
- Every handler ends `JMP VMLOOP`, never `RTS`.
- Every handler stores `QSTAT` through the `QUERY STATUS IS` pointer if one was
  declared, then branches to the error target if `QSTAT` is non-zero and a
  target was given. That is four instructions, written once as `VQSTAT` and
  `JSR`ed by all four.

Wiring them cost one edit to `VMTAIL.S`, and it is worth writing down exactly,
because the dispatch table is 256 dense entries and its last line used to absorb
everything from `$A0` up:

```
 DS 96,<VBAD              became:

 DS 51,<VBAD              $A0-$D2
 DFB <VBAD,<VQOPEN,<VQNEXT   $D3 QBE (still trapping), $D4, $D5
 DFB <VBAD,<VQSORT,<VQFLD    $D6, $D7, $D8
 DS 39,<VBAD              $D9-$FF
```

51 + 6 + 39 = 96, and the same six lines again in `VTHI`. **Both halves must
still total exactly 256**, which is the one thing to check by hand after editing
either: a table one entry short shifts every opcode above the edit, and the
symptom is not a fault but the *wrong instruction* executing.

`$D3 QBE` stays `VBAD` on purpose: the front end that writes a `.QRY` is the
`QUERY` *overlay*, which an operator runs from the menu, and a running program
has no business building one.

### 15.6 What writing it actually cost

The design said the handlers would be "five instructions each". They are 719
bytes, and the difference is worth recording rather than quietly correcting,
because it is the same lesson every other module in this tree has taught:

**The engine calls are the small part.** `JSR QRYINIT` / `JSR QRYSCAN` /
`JSR QRYSORT` is nine bytes. What costs is everything around them — seven
operands pulled out of the code stream and stashed, an item number resolved to
an address and a descriptor, a 16-bit count read *out* of a COBOL item and a
16-bit count written *back into* one, and each of those two in both the `COMP`
and the NUM8 flavour because the descriptor decides and not the programmer.
Four shared helpers — `VQPUTN`, `VQGETN`, `VQGIVE`, `VQPUTS` — are a third of
the file and none of them is about querying anything.

**It also cost one line in `VMLOOP.S`.** `VOPD` fetches an item number *and*
resolves it; the query opcodes need those two halves apart, because they read
every operand out of the stream first, in order, and resolve afterwards. So
`VOPD` gained a second entry point, `VOPD2`, at the instruction after its
`VFETW`. One label, no duplicated code, and it is the only change this verb
made to code that already existed.

**And it moved the VM's ceiling from comfortable to watched.** `VM` was 3,136
bytes with about 960 spare below `$9000`; it is now **3,855 with 241 spare**.
That is still a fit, and it is no longer a fit with room to be careless in — the
`GIVING` forms and the counted `PERFORM`s that `PCODE.md` §3 still owes have to
come out of those 241 bytes. If they do not fit, the answer is the one `VM.S`
already writes down: in the standalone world there is no menu at `$2000`, so the
interpreter moves down there and the whole band becomes the program's.

### 15.6 What is in a `.QRY`, in one paragraph

Nothing executable by the VM, and no COBOL. A `.QRY` is a 32-byte header, a
twelve-byte sort spec of four `field, direction, width` triples, and a predicate
of at most 96 bytes in the **postfix byte code of §4** — `CMPL`, `CMPF`, `HAS`,
`AND`, `OR`, `NOT`, `ALL`, `END`, eight opcodes in all. Those bytes are run by
the predicate evaluator inside `SELECT.S`, once per record, over a boolean stack
eight deep. **There are two interpreters in this system and the `.QRY` drives
the smaller one** — which is worth saying plainly in the chapter, because it is
the clearest example in the book of the general point that an interpreter is a
technique and not a program: the same idea that gives us p-code from COBOL gives
us an eleven-byte answer to *balance over zero and state equals CA*.
