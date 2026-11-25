# The REPORT overlay and the `.RPT` format

The print-layout designer. Sibling to `FORMAT`: where `FORMAT` paints a screen
and exports the `DISPLAY`/`ACCEPT` statements that draw it, `REPORT` paints a
**printed page** and exports the `MOVE`/`DISPLAY UPON PRINTER` statements that
print it.

> **BUILT AND RUNNING, 2026-11-08.** All seven slices work in AppleWin
> (`tools/emu/rpttest.ps1`, `rptrt.ps1`): a report is designed, saved, reopened
> byte for byte, exported, PLACEd into a program, compiled, run and printed
> with page breaks, a footing and a running total. Where the build differs
> from what follows, the build wins:
>
> - **Loads at $7000** (RUNLOW, `RPPGS`), not $8000; nineteen page rows, and
>   two command bars on rows 21-22: `OA-A Add, OA-D Delete, OA-G Go to, OA-B
>   Band, OA-I Dictionary, ESC` / `OA-N New, OA-O Open, OA-S Save, OA-E Export,
>   SA-C Code`. Files: `RPTIO.S` (dictionary, bands, new/open/save) and
>   `RPTEXP.S` (the emitter, the disk sink and the screen sink).
> - **One `.SNP`, not a pair, and PLACE, not COPY** (COPY is still not in the
>   compiler): data and paragraphs are separated by a lone `*` line, and the
>   editor's SA-P R places each.
> - **Names fit the compiler's ten significant characters**: `RPT-Lnn` per page
>   line, `R<line>-<col>` per named item, `RT-nn` per total (nn = entry index),
>   `RPT-PAGE`, `RPT-LINES`, `RPT-DATE` / `RPT-DATEP` (MM/DD/YY).
> - **Paragraphs** `RPT-BEGIN`, `RPT-HEAD` (every line above the detail band),
>   `RPT-DETAIL`, `RPT-FOOT`, `RPT-SKIP`, `RPT-END`. The page test is `IF
>   RPT-LINES > n` (`NOT LESS THAN` is not in the compiler), rules are FILLERs of
>   at most 30 (`ALL` is not either), and a total is a running total.
> - **The run time it needed was built with it**: `DISPLAY ... UPON PRINTER`
>   ($88/$89) and `ACCEPT ... FROM DATE/TIME` ($85). Printer cards without
>   Pascal firmware are now driven at their data register, because their
>   firmware echoed to the screen.

Written 2026-08-15. Nothing in here is built yet. This file is the authority on
the `.RPT` format and on what the overlay does; where it disagrees with a
source comment later, the code is right and this file gets corrected.

ProDOS type `$4C`, mnemonic `RPT` — the slot `FILETYPES.md` reserved for it.

---

## 1. The three decisions

**It generates COBOL; it does not interpret anything at run time.** The same
argument as `SCREXP`, and for the same reasons: no new grammar, no new p-code,
no runtime `.RPT` loading, and the programmer can read and edit every line that
comes out. It also means REPORT is an *author-time* tool that adds nothing to
the library — the only runtime it needs is `PRINTER.S`, which the verb list
already owed us.

**The page is a canvas with band marks.** One canvas of `pagelen` lines — 66 by
default — painted the way `FORMAT` paints a screen, plus six line numbers
saying where the page heading, the detail band and the page footing begin and
end. A flat canvas alone cannot say *this line repeats for each record*, which
is the one thing a report has to say; bands alone would hide the page, which is
the thing you actually want to see. The marks are the smallest addition that
makes the canvas mean something.

**Eighty columns now, a width byte in the file.** Screen column *n* is print
column *n*, exactly as in EDIT, so there is no horizontal window to write and
the vertical scroll is the only new mechanism. `pagewid` is in the header from
version 1, so 132-column condensed becomes a later slice and not a format
change.

### The correction to the sketch

An early sketch of the generated code used reference modification —
`MOVE CUST-NAME TO PRT-LINE(6:20)`. **That is COBOL-85 and it is not in the
subset**; `KEYWORDS.md` does not list it, and Report Writer is on the excluded
list beside it. The 1974 mechanism is a group item with `FILLER`, and every
part of it — level numbers, `PIC`, `VALUE`, `FILLER` — is already in the
subset:

```
 01  PRT-DETAIL.
     05  FILLER      PIC X(5)  VALUE SPACES.
     05  PD-NAME     PIC X(20).
     05  FILLER      PIC X(14) VALUE SPACES.
     05  PD-BALANCE  PIC ZZ,ZZ9.99-.
     05  FILLER      PIC X(29) VALUE SPACES.
```

This is the better answer and not merely the available one. REPORT computes
every offset at author time and writes the answer down as `FILLER` widths —
which is the argument `DICTIONARY.md` makes for `recoff`, applied to a print
line instead of a record. Nothing downstream computes layout.

---

## 2. What REPORT is not

**It does not generate the file loop.** The export is a **snippet** — type
`$48 SNP`, structurally identical bytes to a program, exactly as `SCREXP`
writes one. It contains the print-line group items, the counters and
accumulators, and four paragraphs:

| Paragraph | What it does |
|---|---|
| `RPT-BEGIN` | zero the counters and the accumulators |
| `RPT-HEAD` | print the page heading; add one to the page counter |
| `RPT-DETAIL` | print one detail line; add to the accumulators; break the page if the next one will not fit |
| `RPT-END` | print the last footing and the totals |

The programmer's own `READ ... NEXT` loop `PERFORM`s them. That is what keeps
REPORT independent of `RECMAN.S`, which is not written: the generated code's
only unbuilt dependency is `DISPLAY ... UPON PRINTER`, and `PRINTER.S` is about
350 bytes. **A report can be printed long before the record manager exists.**

### How the snippet gets into the program: `COPY`, not paste

A `.SNP` has had nowhere to go — EDIT has no insert-file-at-cursor, which
`STATUS.md` records as the last missing link in the FORMAT → EDIT → COMPILE
chain. **`COPY` is the better answer, and it is now in the subset**; see the
library-facility section at the top of `KEYWORDS.md`.

```
       COPY LEDGER.
```

Pasting is a snapshot. Nudge a column in REPORT, re-export, and a pasted
program silently holds the old layout with nothing to detect the drift.
`COPY` is a live reference: re-export, recompile, and the program has the new
layout with no editing at all. That matters more for a report than for a
screen, because a report's export is four paragraphs *and* a group item per
printed line — nobody is re-pasting that by hand a second time.

Two things follow for REPORT specifically. The export must be **`COPY`-safe**:
self-contained, no dependency on where in the program it lands, and every
generated name prefixed `RPT-`/`R<band><line>-` so a copybook cannot collide
with the programmer's own data names — which the naming scheme in §6 already
does. And the export should stay **one file, not two**: `WORKING-STORAGE`
items and `PROCEDURE` paragraphs in a single `.SNP` would need two `COPY`
statements in two divisions, so slice 6 writes `LEDGER.SNP` (the data) and
`LEDGERP.SNP` (the paragraphs) as a pair, named by convention so the two
cannot be separated by accident.

**It does not invent a field list.** A report is bound to one `.DCT`. Field
entries are picked by name from the loaded dictionary, which supplies the COBOL
data name, the type and the width for free, and guarantees that every `MOVE`
the export emits names something that exists. `DICTLOAD` and `LOADDCT` already
do this and are proven.

---

## 3. The model — entries on a page canvas

`FORMATD`'s model, widened. A report is a header plus a list of **entries**,
each placed at a line and a column. There is no character canvas anywhere: the
canvas is *drawn from* the entry list, never stored.

### Entry kinds

| Code | Kind | Prompted as | What it emits |
|---|---|---|---|
| 0 | LITERAL | `L` | a `FILLER ... VALUE 'text'` in the line's group item |
| 1 | FIELD | `F` | a named subfield, and a `MOVE` from the dictionary field into it |
| 2 | TOTAL | `T` | an accumulator, an `ADD` in the detail band, and a `MOVE` where it is placed |
| 3 | PAGENO | `#` | a `MOVE RPT-PAGE-CTR` |
| 4 | DATE | `D` | `ACCEPT ... FROM DATE` at `RPT-BEGIN`, moved where it is placed |
| 5 | RULE | `R` | a `FILLER PIC X(n) VALUE ALL '-'` |

Six kinds cover the real reports: a title, column headings, a rule under them,
the detail columns, a total line, a page number and a date. Codes 6 upward are
reserved — `TIME` and control-break subtotals are the two that will want them.

### The entry record — 64 bytes, and why

| Off | Len | Field |
|---|---|---|
| 0 | 1 | kind (§3) |
| 1 | 1 | line — **0-based** page line |
| 2 | 1 | col — 0-based print column |
| 3 | 1 | width — the printed width, derived, never asked |
| 4 | 1 | flags — bit0 suppress-if-zero, bit1 right-justify a literal |
| 5 | 1 | decimals |
| 6 | 1 | band — cached: 0 none, 1 heading, 2 detail, 3 footing |
| 7 | 1 | literal length |
| 8 | 10 | data name, space padded |
| 18 | 14 | picture string, space padded |
| 32 | 32 | literal text |

**Sixty-four is a stride, not an estimate.** Entry *n* is at
`RPTENT + (n << 6)` — four shifts and an add, no multiply, the same reason
`AUXMEM`'s record geometry and the editor's ring are powers of two. `FORMATD`
pays for its 16-byte label pool with four `ASL`s already; this is the same
trick one size up, and it buys the format its other property below.

**Sixty-four entries.** A heading block, a rule, eight detail columns with
their headings, a footing and a total line comes to about forty. Sixty-four
leaves room and keeps the table at exactly 4096 bytes.

### One-based on the prompt, zero-based in the file

`FORMAT` prompts for screen rows 0–21 because the screen is 0-based and the
designer is looking at it. **A printed page is not**: line 1 is the first line
of paper. So REPORT prompts `Line?` for 1..`pagelen`, subtracts one on the way
in and adds one on the way out — the rule row, the delete prompt and the band
prompts are all 1-based, and the file is all 0-based. This is the same
convention `SCRPRV` already uses for its `LINE n OF m` rule, for the same
reason.

---

## 4. The screen, and why there is no ring

Twenty page lines of sixty-six visible at a time, laid out as EDIT lays out a
program:

```
row 0      the report name at the left, the dictionary at the right
row 1      the rule: PAGE LINE n OF 66, and the band that line is in
rows 2-21  twenty page lines, drawn from the entry list
row 22     the Open-Apple command bar
row 23     the prompt line - LINEIN, exactly as in FORMAT
```

`FORMAT` could draw its form straight onto rows 0–21 because the form *is* a
screen. A page is not, so REPORT borrows EDIT's frame instead: header, rule,
window, bar, prompt.

### The scrolling

`SCRPRV`'s, verbatim in shape — arrows scroll a line, Open-Apple arrows page
twenty, `RPTMAX` pins the top so a page shorter than the window cannot scroll
off:

| Key | Effect |
|---|---|
| ↑ / ↓ | one page line |
| OA-↑ / OA-↓ | twenty page lines |
| OA-G | go to a page line by number |

### There is no ring, and that is the point

EDIT's ring exists to answer one question: *how do you scroll a document that
lives in auxiliary memory without reading a record per keystroke?* REPORT has
no such document. Its whole report is a list of at most sixty-four entries in
main memory, four kilobytes of it, already resident.

So `RPTDRW` draws a window row like this: fill `ROWBUF` with spaces, walk the
entry list, and paint any entry whose line matches into it; `PUTROW`. Sixty-four
comparisons a row, twenty rows — about thirteen hundred compares for a full
repaint, well under the blit that follows. No cache, no `CVALID`, no
`AXGET`, no staleness, no bugs of the class the ring exists to have.

**This is worth saying plainly in the chapter, because it is the general
lesson:** the ring is not what scrolling costs, it is what scrolling costs *when
the document does not fit in memory*. Reach for it only then. Two overlays in
this system scroll twenty rows over a taller document and only one of them
needs a cache.

Entries render the way the attribute rule in `DICTIONARY.md` demands: literals
and rules **normal**, because they are furniture; fields, totals, the page
number and the date **inverse**, because they are where data lands. A field
with a picture renders its picture (`ZZ,ZZ9.99-`), so you can see the shape of
the number in place; without one it renders `X` repeated to its width.

---

## 5. The `.RPT` file — 32-byte header, then fixed entries

### Header

| Off | Len | Field | Meaning |
|---|---|---|---|
| 0 | 4 | signature | `"ADR1"` — `$41 $44 $52 $31` |
| 4 | 1 | version | 1 |
| 5 | 1 | organization | 0 |
| 6 | 1 | pagelen | lines per page. 66 |
| 7 | 1 | pagewid | print columns. 80 today; 132 later, no version bump |
| 8 | 1 | entrycount | number of entry records |
| 9 | 1 | detspace | blank lines between detail lines. 0 |
| 10 | 1 | headtop | first line of the page heading, 0-based. `$FF` = no band |
| 11 | 1 | headbot | last line of the page heading |
| 12 | 1 | dettop | first line of the detail band |
| 13 | 1 | detbot | last line of the detail band |
| 14 | 1 | foottop | first line of the page footing |
| 15 | 1 | footbot | last line of the page footing |
| 16 | 2 | entryoff | offset to the entry array. Always 32 |
| 18 | 2 | fileend | offset to end of file — the file's own length |
| 20 | 12 | dictname | the `.DCT` this report reads, space padded |

Then `entrycount` entry records of 64 bytes, back to back at offset 32, **in
line order then column order** — the order they print, which is also the order
the emitter walks and the order a delete has to preserve.

### The save is one `WRDCT` and no builder at all

`SAVEDCT` builds a `.DCT` into `DCTOUT` byte by byte through `EMIT`, because
the dictionary has a variable-length label pool and its offsets are not known
until the fields have been counted. **`.RPT` has no variable-length anything.**
So the header lives in memory *immediately below* the entry table:

```
$97E0-$97FF  RPTHDR - the 32-byte header
$9800-$A7FF  RPTENT - 64 entries of 64 bytes
```

and those two are contiguous. Saving is: fill six bytes of the header, compute
`fileend`, `WRDCT` from `$97E0` for `32 + entrycount*64` bytes. Loading is one
`FLOAD` to `$97E0`. There is no build step, no parse step, no `DCTOUT`
equivalent, and no second copy of the report anywhere in memory.

That is the second thing the 64-byte stride buys, and it is the larger one: the
file is the memory image, so the round trip is byte-perfect by construction
rather than by testing. `LOADDCT` has to re-associate labels with fields by
geometry to get back what it wrote; `.RPT` load has nothing to re-associate.

---

## 6. The generated COBOL

One `WORKING-STORAGE` group item per **line that has entries**, named by band
and line — `RPT-H01`, `RPT-D05`, `RPT-F60` — with a `FILLER` for every gap and
a named subfield for every field, total, page number and date.

```
* --- generated by REPORT --- LEDGER 15-AUG-26
* --- reads the dictionary CUSTOMER ---
 01  RPT-PAGE-CTR      PIC 999       VALUE 0.
 01  RPT-LINE-CTR      PIC 999       VALUE 0.
 01  RPT-DATE          PIC X(6).
 01  RPT-TOT-BALANCE   PIC S9(9)V99  VALUE 0.
*
 01  RPT-H01.
     05  FILLER        PIC X(29)     VALUE SPACES.
     05  FILLER        PIC X(15)     VALUE 'CUSTOMER LEDGER'.
     05  FILLER        PIC X(28)     VALUE SPACES.
     05  RH01-PAGE     PIC ZZ9.
     05  FILLER        PIC X(5)      VALUE SPACES.
 01  RPT-H03.
     05  FILLER        PIC X(5)      VALUE SPACES.
     05  FILLER        PIC X(4)      VALUE 'NAME'.
     05  FILLER        PIC X(30)     VALUE SPACES.
     05  FILLER        PIC X(7)      VALUE 'BALANCE'.
     05  FILLER        PIC X(34)     VALUE SPACES.
 01  RPT-D05.
     05  FILLER        PIC X(5)      VALUE SPACES.
     05  RD05-NAME     PIC X(20).
     05  FILLER        PIC X(14)     VALUE SPACES.
     05  RD05-BALANCE  PIC ZZ,ZZ9.99-.
     05  FILLER        PIC X(29)     VALUE SPACES.
*
 RPT-BEGIN.
     MOVE 0 TO RPT-PAGE-CTR
     MOVE 0 TO RPT-TOT-BALANCE
     ACCEPT RPT-DATE FROM DATE.
 RPT-HEAD.
     ADD 1 TO RPT-PAGE-CTR
     MOVE RPT-PAGE-CTR TO RH01-PAGE
     DISPLAY RPT-H01 UPON PRINTER
     DISPLAY SPACES UPON PRINTER
     DISPLAY RPT-H03 UPON PRINTER
     MOVE 4 TO RPT-LINE-CTR.
 RPT-DETAIL.
     IF RPT-LINE-CTR NOT LESS THAN 58
         PERFORM RPT-HEAD.
     MOVE CUST-NAME TO RD05-NAME
     MOVE BALANCE   TO RD05-BALANCE
     ADD  BALANCE   TO RPT-TOT-BALANCE
     DISPLAY RPT-D05 UPON PRINTER
     ADD 1 TO RPT-LINE-CTR.
```

Every verb in there is in the subset and marked ✔ or on the build list: `MOVE`
numeric-to-edited is `PICEDIT` and is built; `ADD` is `BCDADD` and is built;
`ACCEPT ... FROM DATE` is `DATIME.S`; `DISPLAY ... UPON PRINTER` is
`PRINTER.S`. **Those last two are the only unbuilt things a generated report
touches**, and between them they are about 500 bytes.

The `58` in the page test is `foottop` — a constant computed at author time,
which is the whole argument again: the layout is decided by the designer, and
the generated program only counts.

### The emitter has two sinks, and no big buffer

`SCREXP` builds into `EXPOUT`, three thousand bytes of `DS` that ride inside
the `FORMAT` file and are read off the floppy on every call — the one piece of
`FORMAT` that `STATUS.md` already flags for eviction. REPORT does not repeat
it: sixty-four entries would want five kilobytes or more.

Instead the emitter builds **one source line at a time** into an 80-byte
buffer and hands it to a sink:

| Sink | Where the line goes |
|---|---|
| `RPSDSK` | appended to the 512-byte staging buffer in `OVLWORK`; `WRITE` when fewer than 81 bytes are free, flush at the end |
| `RPSCNT` | counted and discarded — the preview's first pass |
| `RPSSCR` | rendered to `ROWBUF` and blitted if the line is inside the preview window — the second pass |

One walk, three sinks, no buffer over 512 bytes anywhere. The disk path is
EDIT's proven `.COB` streaming, byte for byte. `SCRPRV`'s argument for
rebuilding on every entry holds here twice over: the preview renders through
the *same emitter* the file is written by, so it cannot drift.

---

## 7. Memory

REPORT lays the overlay band out the way EDIT does — code low, a large fixed
structure high, at an **address and not a `DS`**, so it costs nothing in the
file that comes off the floppy:

```
$8000-$96FF  code and variables (5.75K)
$9700-$97DF  spare
$97E0-$97FF  RPTHDR - the .RPT header (32 bytes)
$9800-$A7FF  RPTENT - 64 entries x 64 bytes (4K)
$A800-$AFFF  spare - 128 entries, or a second band set, later
```

`RPTEND` at the foot of the last `PUT` must be below `$97E0`, checked after
every assembly the way `LIB.S` checks `LIBEND`, `EDIT` checks `EDEND` and
`FORMAT` checks `FMTEND`.

In `OVLWORK` (`$1C80`, 896 bytes), shared with every other overlay because only
one is ever resident:

```
$1C80-$1E7F  RPSTAGE - the 512-byte export staging buffer
$1E80-$1ECF  RPLINE  - the 80-byte source line under construction
```

The dictionary loads to `DCTBUF` at `$1200`, where `DICTLOAD` already puts it.

---

## 8. The module split

The same stub-of-`PUT`s shape as every other program, for the same Merlin
reason:

| File | What is in it | State |
|---|---|---|
| `REPORT.S` | the stub: header, the equates, `ORG $8000`, `JMP START`, the `PUT` list | **written** |
| `RPTENT.S` | `START`, the main loop, the key dispatch, scrolling, `OA-G`, `DOPREV` | **written** |
| `RPTDRW.S` | `RPWIN`, `RPLINE`, `RPPAINT`, `RPTPUT`, the rule, `BANDOF`, row 0, the bar | **written** |
| `RPTBAR.S` | `BARTAB`, `CMDLIST`, the literals and band names | **written** |
| `RPTVAR.S` | the variables, and `RPTEND` | **written** |
| `RPTADD.S` | `RPADD`, the ASK chain, `ADDENT`, `OVERLAP`, `FINDINS`, `OPENSLOT`, `RPDEL`, `FINDLC`, `DELIDX` | **written** |
| `RPTBND.S` | the band marks: `OA-B`, `OA-P` | slice 4 |
| `RPTIO.S` | save and load `.RPT`; open a `.DCT` and bind to it | slice 5 |
| `RPTEXP.S` | the emitter and its three sinks | slice 6 |
| `RPTPRV.S` | `SA-C`, the generated code on page 2 | slice 7 |

### `PROMPT.S`, and what the extraction actually cost

`LINEIN`, `GETCHORD`, `ATOI`, `ISNUM`, `SHOWERR`, `CLRLINE` and the cursor
helpers lived inside `FORMATD.S`. They are now `PROMPT.S`, `PUT` by both
overlays. Three things came out of doing it that the plan did not have:

**It is not byte-identical, and could not have been.** The `EDIT.S` and `VM.S`
splits preserved their bytes because they only cut a file into pieces in the
original order. This moves scattered routines into one file *and* changes one
of them: `LINEIN` tested five hard-coded command letters, which is FORMAT
policy, so it now walks a `$00`-terminated **`CMDLIST`** the including overlay
defines — FORMAT's is five letters, REPORT's grows a slice at a time. `SA-C`
likewise calls **`DOPREV`**, which each overlay defines for itself. The
verification is therefore: the object assembles with no branch-range errors,
and FORMAT still round-trips a `.DCT` byte-perfect through New / Open / Save /
Delete. Same arrangement `DISKIO` already uses for the form arrays — the shared
file names the symbol, the including overlay owns it.

**`COPYNAME` stayed behind.** It writes into `NAMEBUF`, which lives in
`DISKIO.S`, so it belongs with the path machinery rather than the prompt.

**REPORT cannot simply `PUT DISKIO`.** `SAVEDCT` and `LOADDCT` reference the
form-model arrays — `FCOUNT`, `EROWS`, `ELCOLS`, `ESTORS` — which a report does
not have, so including the file would fail to assemble on a dozen undefined
symbols. Slice 5 therefore needs `MKPATH`, `NAMEBUF` and `FULLPATH` lifted out
of `DISKIO.S` into a shared paths module of their own, exactly as `PROMPT.S`
was lifted out of `FORMATD.S`. Worth knowing now: it makes slice 5 bigger than
it looks, and it is the second time a shared routine has turned out to be
welded to FORMAT's data.

Slice 1 needs no helper modules at all — no `PRODOS`, no `DISKIO` — because it
does no file I/O. Its whole `PUT` list is `EQUATES PROMPT RPTENT RPTDRW RPTBAR
RPTVAR`.

### The menu

`SYSMENU.S` gains option 7 and a pathname:

```
L9 DFB 16
 ASC '7) REPORT layout'
RPTNAME DFB 6
 DFB $52,$45,$50,$4F,$52,$54
```

with `MO7 JSR DORPT` beside `MO4`, and `DORPT` pointing `RUNOVL` at `RPTNAME`.
The `MTAB` rows below Catalog move down two — REPORT sits on row 10, Exit on
12, the `Choice?` prompt on 14. Nothing else in the system changes.

---

## 9. The slices, in build order

Each one leaves something that runs.

1. ~~**The window.**~~ **Written 2026-08-15, never assembled.** `REPORT.S` +
   `RPTENT` + `RPTDRW` + `RPTBAR` + `RPTVAR`, the `PROMPT.S` extraction, and
   menu option 7. An empty 66-line page, the rule saying `PAGE LINE 1 OF 66`,
   arrows and OA-arrows scrolling it, `OA-G` to a line, ESC back to the menu.
   Nothing is stored. **This is the slice that proves the scroll**, and it is
   deliberately first for the same reason EDIT's 2/20/2 screen was.

   Two things it does that the plan did not call for, both to keep later
   slices small. `RPTDRW` **already walks the entry list**, so the whole of
   slice 2 is the prompt chain and not one line of drawing. And the main loop
   **reads keys directly rather than sitting inside `LINEIN`** the way FORMAT
   does — it has to, because `LINEIN` swallows the arrow keys, and in a
   designer whose page is taller than its window the arrows are the most
   important keys on the board. A prompt is entered only when a command needs
   an answer, and left again at once. That is the one structural difference
   between the two designers, and it follows from the scroll.
2. ~~**Entries.**~~ **Written 2026-08-15, never assembled.** `RPTADD.S`:
   `OA-A` asks Line, Column, Kind and then whatever that kind needs; `ADDENT`
   validates and places; `OA-D` takes one away again. The designer works, in
   memory.

   **Four kinds, not two.** This entry said "literals and rules — the two
   kinds that need no dictionary", and that was a miscount: the page number
   and the date need one no more than a rule does. All four are in. So a page
   heading with a title, a rule under it, a page number and a date can be laid
   out before `FORMAT` has ever been opened. `FIELD` and `TOTAL` still wait
   for slice 3, because those genuinely do need a dictionary to name.

   **Entries are kept in printing order** — by line, then by column — which
   §5 already promised the file would be, so `FINDINS` locates the slot and
   `OPENSLOT` shifts the tail up to open a gap. One extra table walk per add,
   and it is what lets slice 6 build a line's group item in a single pass with
   the `FILLER` gaps falling out of the differences between neighbouring
   columns. Sorting at export time instead would need somewhere to sort *into*,
   and there is nowhere.

   Two smaller things. Deleting an entry is **one 64-byte block move per slot**
   where `FORMAT` shifts nine parallel arrays to remove one field — the third
   dividend from the fixed stride. And `RPSETP` now takes its index in `A`
   rather than reading `ENTIX`: four callers walk the table and only one of
   them is the drawing, so `OVERLAP` and `FINDLC` can search without a redraw
   ever disturbing them.
3. **The dictionary binding.** `OA-I` opens a `.DCT`; FIELD and TOTAL entries
   become possible, picked by name from the loaded field list.
4. **Bands.** `OA-B` and `OA-P`, the band column on the rule row, the
   out-of-band warning at export time.
5. **Save and load.** `RPTIO`, both directions. Test it the way `SAVEDCT` was
   tested: save, wipe, load, save again, and compare the two files byte for
   byte.
6. **Export.** `RPTEXP` and the disk sink. A `.SNP` that EDIT can open and
   read, whether or not it can yet be run.
7. **Preview.** `RPTPRV` and the two screen sinks, on page 2, `SA-C`.

`PRINTER.S` is not a REPORT slice — it is a library module the verb list
already owed, and it can be written and proven on its own at any point.
Until it exists the export is correct source that cannot yet run, which is
exactly the state `SCREXP`'s output was in until EDIT could open a file.

---

## 10. Open questions

Recorded rather than guessed at, in the order they will bite.

1. **Control breaks.** Subtotals by a key field — *total by branch, then by
   region* — are the first thing a real report wants that this design does not
   have. Two more bands and a compare on a key field would do it. Deliberately
   out of version 1; the band bytes have room and the entry kinds have codes
   free, so it is an addition and not a rewrite.
2. **Picking a field.** Typing a data name at `Name?` is what `FORMAT` does,
   but REPORT already has the dictionary loaded and could show a picker.
   Cheaper to type first and see whether it grates.
3. **What a total accumulates over.** Today: the detail band, all of it, one
   accumulator per TOTAL entry. Whether a total can sum an expression rather
   than a field is a question for after control breaks, not before.
4. **Overflow of the detail band.** A detail band more than one line tall and a
   page that cannot fit a whole one — the generated test uses `foottop` minus
   the band height, which is right, but it has not been exercised against a
   three-line detail band.
5. **`detspace`** is in the header and read by nothing yet. It is the blank
   lines between detail lines — double-spaced reports — and it is one `DISPLAY
   SPACES` in the emitter when it is wanted.
