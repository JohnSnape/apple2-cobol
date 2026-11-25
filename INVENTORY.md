# `src/` — the file map

Ninety files. This one is the **index**: what each file is, which program it
belongs to, and what stands between it and the disk.

It does not duplicate `STATUS.md`, which is the authority on **state** — what is
verified, what merely assembles, what is unwritten. This file answers a
different question: *given the source tree, what do I build, and what breaks if
I try?* Where the two touch, `STATUS.md` wins.

Sizes are from a static pass over the sources — instruction sizes resolved and
summed, not a real assembly. They are close: the pass sizes `EDIT` at 4,812
bytes and Merlin's own figure, recorded in `STATUS.md`, is 4,788. Half a per
cent. Treat them as good to about ±1%, and read the real symbol after every
assembly anyway.

---

## 1. The nine things that get built

Everything else in the tree is `PUT` into one of these, or is a harness, or is
data. Each stub is a header, an `ORG`/`JMP`, and a list of `PUT`s.

| Stub | On disk | Loads at | Est. size | Ceiling | Head-room |
|---|---|---|---|---|---|
| `COBOLSYS.S` | `COBOL.SYSTEM` SYS | `$2000` | 2,555 | `$3000` | 1.5K |
| `LIB.S` | `COBOL.LIB` BIN | `$3000` | 12,604 | `$8000` | 7.7K |
| `EDIT.S` | `EDIT` BIN | `$8000` | 4,833 | `$9800` | 1.3K |
| `FORMAT.S` | `FORMAT` BIN | `$8000` | 10,468 | `$B000` | **1.8K** |
| `REPORT.S` | `REPORT` BIN | `$8000` | 3,101 | `$97E0` | 6.9K |
| `QUERY.S` | `QUERY` BIN | `$8000` | 4,105 | `$B000` | 8.0K |
| `VM.S` | `VM` BIN | `$8000` | 4,162 | `$9200` | 446 bytes |
| `COMPILE1.S` | `COMPILE1` BIN | `$8000` | 5,380 | `$A080` | 2.8K |
| `COMPILE2.S` | `COMPILE2` BIN | `$8000` | 8,314 | `$A080` | **6 bytes — full** |

Every one of them fits. `FORMAT` is the tight one and `STATUS.md` already names
the reason — `EXPOUT`'s 3,000 bytes of `DS` ride inside the file and are read
off the floppy on every call.

## 2. The map

### Shared — 1 file

| File | Lines | |
|---|---|---|
| `EQUATES.S` | 678 | Zero-page zones, soft switches, the library jump table, the data region. `PUT` first by every one of the six. Generates no code. **The authority on anything with a number in it.** |

### Library modules — 20 files, `PUT` by `LIB.S`

| File | Lines | Slots | |
|---|---|---|---|
| `TEXTDRV.S` | 560 | 0–15, 64, 76–78 | Two 80-column text pages, output, line input, page swap, the row blit, the Apple command keys |
| `FILEIO.S` | 302 | 16–18 | Suffix → type, whole-file load and save |
| `CATALOG.S` | 446 | 19 | Directory listing with our own type mnemonics |
| `BCD.S` | 1149 | 20–39 | NUM8 decimal arithmetic, conversions, alphanumeric move and compare |
| `BANKS.S` | 211 | 40–41 | RamWorks bank detection, the page mover |
| `CONSOLE.S` | 404 | 42–48 | Scrolling `DISPLAY`/`ACCEPT` with the shadow screen |
| `DSCREEN.S` | 257 | 50–53 | Positioned `DISPLAY`/`ACCEPT ... AT LINE n COLUMN n` |
| `AUXMEM.S` | 307 | 54–57, 60 | Records across auxiliary banks |
| `NUMFMT.S` | 129 | 58–59 | Readable numbers, right-justified |
| `PICTURE.S` | 712 | 65–67 | The edit engine, both directions |
| `SELECT.S` | 1273 | 68–70, 72–75 | The query cursor, predicate evaluator, scan, field fetch |
| `SORT.S` | 200 | 71 | Shell sort over a cursor |
| `PRINTER.S` | — | 79–82, 88 | Output to a printer card without touching the screen |
| `DATIME.S` | — | 84–87, 91 | The ProDOS date word, packed and unpacked |
| `CLOCK.S` | — | 89–90 | The No-Slot Clock probe and driver |
| `RECMAN.S` | 758 | 92–99 | **New 2026-08-16.** Relative files: the eight COBOL file verbs. 1,229 bytes |
| `SCRSHOW.S` | 139 | 100 | **Moved in 2026-08-23.** Draws a form from a dictionary; vector `FRMSHOW` |
| `SCRINP.S` | 500 | 101 | **Moved in 2026-08-23.** The `ACCEPT` field editor; vector `FRMACC`, terminator in A |
| `CLASS.S` | 298 | 102 | **New 2026-08-23.** The class conditions, eleven codes, 382 bytes. Opcode `$62` |
| `ABORT.S` | 159 | 103–104 | **New 2026-08-23.** The runtime error stop: setjmp/longjmp, nine codes, 329 bytes |

### `COBOL.SYSTEM` — 3 files

| File | Lines | |
|---|---|---|
| `SYSBOOT.S` | 151 | Machine checks and cold start. `COLD` is the `$2000` entry |
| `SYSLOAD.S` | 61 | Library and overlay loading, the prefix |
| `SYSMENU.S` | 334 | The menu and overlay dispatch — options 1–7 and 9 |

### `EDIT` — 11 files

| File | Lines | |
|---|---|---|
| `EDITENT.S` | 59 | Entry and screen setup |
| `EDITRNG.S` | 320 | The 64-slot line-cache ring |
| `EDITSHF.S` | 152 | Record insert and delete |
| `EDITDRW.S` | 143 | Window drawing |
| `EDITRUL.S` | 204 | The rule, the bars, repaint |
| `EDITCUR.S` | 96 | Cursor and key input |
| `EDITDSP.S` | 95 | Keystroke dispatch |
| `EDITCMD.S` | 474 | The keystroke handlers |
| `EDITIO.S` | 649 | Open and Save, streamed through a 512-byte staging buffer |
| `EDITBAR.S` | 92 | Command bars and messages |
| `EDITVAR.S` | 62 | Variables — **holds `EDEND`** |

### `FORMAT` — 6 files

| File | Lines | |
|---|---|---|
| `PRODOS.S` | 192 | MLI wrappers, `DICTLOAD` |
| `DISKIO.S` | 517 | Save and load a form as a `.DCT` |
| `PROMPT.S` | 231 | The row-23 question line. **Shared with `REPORT`** |
| `SCREXP.S` | 537 | Export the form as COBOL `DISPLAY`/`ACCEPT` |
| `SCRPRV.S` | 487 | The generated-code preview, on text page 2 |
| `FORMATD.S` | 878 | The designer body |

### `REPORT` — 5 files (plus `PROMPT.S`)

| File | Lines | |
|---|---|---|
| `RPTENT.S` | 208 | Entry, main loop, scrolling |
| `RPTDRW.S` | 437 | Window, rule and header |
| `RPTADD.S` | 627 | Add and delete an entry |
| `RPTBAR.S` | 119 | Command bar and literals |
| `RPTVAR.S` | 70 | Variables — **holds `RPTEND`** |

### `VM` — 9 files

| File | Lines | |
|---|---|---|
| `VMCORE.S` | 138 | Entry, header check, `VMDIE` |
| `VMLOOP.S` | 139 | Fetch, decode, dispatch, operand resolve. `VOPD2` is `VOPD` without the fetch — the query opcodes resolve their operands after reading them all |
| `VMMOVE.S` | 267 | Control and move opcodes |
| `VMMATH.S` | 340 | Arithmetic and the expression stack |
| `VMFLOW.S` | 144 | Compare, branch, `PERFORM`/`RET`/`GOTO` |
| `VMSCRN.S` | 125 | `DISPLAY`/`ACCEPT` opcodes |
| `VMFILE.S` | 209 | **New 2026-08-16.** The file opcodes `$90–$96` — seven opcodes, one handler, 250 bytes |
| `VMQRY.S` | 451 | **New 2026-08-15.** The `QUERY` verb — `$D4` `$D5` `$D7` `$D8`, 719 bytes. The first `$D0–$DF` service wired up |
| `VMTAIL.S` | 158 | Faults, the dispatch table, variables |

### Orphans — none

There were two, `SCRSHOW.S` and `SCRINP.S`, and `RUNTIME.md` called them the
blocking pair: they existed, they worked, and a compiled program still could
not call them, because a `PUT`-included module's entry point moves with every
program that includes it. **Both went into the library on 2026-08-23**, slots
100-101. `classify.js` prints `PUT BY NOTHING (0)`, and it is worth keeping
that line at zero: an orphan is a file the checker never looks at.

### `COMPILE1` and `COMPILE2` — 9 files, two stubs

**One compile, two overlays**, split 2026-08-16 because the `QUERY` statement
put `CMPEND` 210 bytes above `OBDESC`. `BUILD.md` §1 and `MEMMAP.txt` say why it
works; the short version is that all four build areas live above `$9C00` and the
band's code ends at `$9BFF`, so pass two loads over pass one's code and finds
pass one's work exactly as it was left.

| File | Pass | |
|---|---|---|
| `COMPILE1.S` | 1 | Stub and driver: `EMINIT`, `LEXINIT`, `DATDIV`, and the DATA-DIVISION error report |
| `COMPILE2.S` | 2 | Stub and driver: `PROCDIV`, `CMPWRT`, and three reports — compile error, write error, and *pass one has not run* |
| `CMPEMIT.S` | both | The emitter: bytes, words, literals, descriptors, fixups |
| `CMPCOM.S` | both | **New.** `DDFIGN` and `DDVSCL` — the two routines that turned out to cross the division boundary, because a literal is a literal wherever it appears |
| `CMPLEX.S` | both | The lexer. Columns, not just tokens |
| `CMPSYM.S` | both | The symbol table at `$A000`, which is what survives the swap |
| `CMPVAR.S` | both | Opcode numbers, build-area addresses, per-pass scratch — **holds `CMPEND`**. The handover set is *not* here; it is `CMPXFR` in `EQUATES.S` |
| `CMPPIC.S` | 1 | PICTURE parsing |
| `CMPDATA.S` | 1 | Levels, `PIC`, `VALUE`, `OCCURS`, the group measure — and `FILE-CONTROL`: `SELECT`, `FD`, and the file table |
| `CMPOBJ.S` | 2 | The 20-byte header and the object writer |
| `CMPPROC.S` | 2 | The PROCEDURE DIVISION, the `QUERY` statement, the seven file verbs, `COMPUTE` and `EVALUATE` |

### Harnesses and spikes — 8 files

| File | Lines | |
|---|---|---|
| `AXTEST.S` | 254 | 128 banks, 8 MB, every one distinct. **Proven on the machine** |
| `PG2TEST.S` | 147 | Text page 2 is real and drivable. **Proven on the machine** |
| `QRYTEST.S` | 528 | The query engine: eight printed steps over twenty known records |
| `KEYTEST.S` | 206 | The Apple keys: three stages, one of them the compatibility promise |
| `OBJTEST.S` | 375 | The emitter: builds `HELLO.OBJ` — the dozen-instruction object `PCODE.md` §5 asks for |
| `LEXTEST.S` | 292 | The lexer: a twelve-line program into aux, every token printed with its line, column and type |
| `BCDTEST.S` | 782 | **New 2026-08-23.** The money math: 17 arithmetic cases, 6 compares, 6 shift/round. `PCODE.md` §5 item 1 |
| `PICTEST.S` | 702 | **New 2026-08-23.** The edit engine: 18 edits including the back-fill, 8 de-edits. `PCODE.md` §5 item 2 |

### Sample COBOL sources — 4 files

| File | Bytes | |
|---|---|---|
| `SKEL.COB` | 197 | The empty program template — menu option 2 |
| `MEDIA.COB` | 3,776 | |
| `LEADS.COB` | 5,302 | |
| `FINANCE.COB` | 5,627 | |

All four are in the no-sequence-number format and **CR-terminated**, which is
right: 202, 195, 146 and 12 carriage returns and not one line feed between
them. They are already in the form the editor reads.

---

## 3. Ready to go — nothing to do

These assemble clean under the static pass, with no unresolved symbols, no
duplicate labels, no branch out of range and no string-length mismatch.

- **`EDIT` — all 12 files.** The three bugs found on 2026-08-15 (ProDOS `$56`
  from a buffer left in use, TAB drifting off the grid, `OA-N` keeping the old
  filename) are fixed in the source. It needs a reassemble and a retest, not
  an edit.
- **`REPORT` — all 6 files.** Slices 1 and 2. Never assembled; `RPTEND` lands
  around `$8C14` against a `$97E0` ceiling, so there is no size risk at all.
- **`VM` — all 9 files**, `VMQRY.S` included. Never assembled and never run.
  The new file was checked the way the rest of the tree is: no duplicate
  labels, every symbol resolving, no branch out of range, and **both halves of
  the dispatch table still totalling exactly 256 entries** — which is the check
  that matters most, because a table one entry short does not fault, it runs
  the wrong instruction.
- **`COBOL.SYSTEM` — all 4 files.** Clean.
- **`FORMAT` — 6 of 7.** Clean, and 1.8K under the band ceiling.
- **Library — all 13 files**, `CATALOG.S` included since its branch was fixed.
- **`COMPILE` — all 7 files**, three of them honest stubs.
- **`KEYTEST.S`, `QRYTEST.S`, `AXTEST.S`, `PG2TEST.S`.**
- **`EQUATES.S`** and the four `.COB` files.

Sixty-nine of seventy files need no work before they go on a disk. The one
that does is `SCRINP.S`, and nothing currently `PUT`s it.

## 4. Must be fixed first

One file. The two `CATALOG.S` faults were fixed on 2026-08-15:

- ~~**`BCS CATX` needs +134 and the 6502 stops at +127**~~ — now `BCC` over a
  `JMP CATX`. This was blocking the whole disk, because `COBOL.LIB` would not
  assemble and every program loads it.
- ~~**two over-declared strings**~~ — `HDR` said 30 for a 28-character heading
  and `FTR` said 18 for a 17-character footer, so the catalog printed two junk
  characters after its heading and one after its footer.

What remains:

~~**`SCRINP.S:456` — `FTYPE DFB 0` collides with `FTYPE EQU $0CCB`**~~ —
**fixed 2026-08-23**, the local is `SIFTYP`. Nothing `PUT` `SCRINP`, which is
why nobody had met it, and which is the point: a file no stub includes is a
file the checker never sees. The same move found a second one in it —
`GETFLD` computing a sixteen-bit descriptor offset in eight bits, so any form
with more than ten fields read the wrong descriptor. Both are in `STATUS.md`
§0c, and both cost `SCRINP` its **V** until it is re-run against a large form.

**Nothing remains.** Every file in `src/` assembles as far as a static pass can
tell, is owned by a stub, has its length prefixes agreeing with its strings,
and claims no data address another symbol claims. That is four passes, not one,
and tools/README.txt says what each of them still cannot see.

## 5. Needs updating on disk

Nothing outstanding. `BUILD.md` has now been corrected twice in one day, and the
second pass found more than the first because it was made against the tree
rather than against the previous revision. What the **second** pass fixed:
`QUERY` was absent from the build list, the boot layout and the `DSK` list, so
menu option 6 had no build target; the `LIB` `PUT` list still stopped at
`PRINTER`, dropping `DATIME` and `CLOCK` and with them slots 84–91 and the whole
`CLOCKUP` boot step; the assembly count was six when it is eight; **no stub
actually carries the `DSK` line §3 told you to rely on**; the `VM` ceiling was
"the end of `VM`" when the symbol is `VMSIZE` and `VMLOOP` holds a decoy called
`VMEND`; `CLOCKUP` was missing from the boot sequence; the *Not built yet* list
still named option 6; and nothing anywhere said that **81 sources cannot go in a
ProDOS volume directory, which holds 51 entries** — the first build would have
failed on that before it failed on anything interesting. §1a is new and carries
the two-volume layout.

What the **first** pass had fixed:

- §1 listed **five** files on the volume while `SYSMENU` offers **seven**
  options. `REPORT` and `VM` were build targets with no line in the disk
  layout; both are listed now, with which menu option each answers.
- §2's `LIB` `PUT` list predated `SELECT` and `SORT`, so building from it gave
  a library with eight jump-table vectors pointing at nothing.
- §5 checked only `LIBEND` and `EDEND`. All five ceilings are there now —
  `FMTEND`, `RPTEND` and `VM`'s end included — with static estimates beside
  them so a wrong assembly shows up before it is loaded.
- The harnesses were not mentioned at all. All three are, with the two-step
  recipe they need: `BLOAD COBOL.LIB,A$3000` before `BRUN`.

## 6. Missing

### Library — five modules the verb list already owes

| | Est. | Blocks |
|---|---|---|
| `RECMAN.S` | ~600 | **Every file statement in COBOL.** Also the file half of the query engine |
| `PRINTER.S` | ~350 | `DISPLAY ... UPON PRINTER` — and therefore any generated report actually printing |
| `CLASS.S` | ~150 | `IS NUMERIC`, `IS ALPHABETIC` |
| `DATIME.S` | ~100 | `ACCEPT ... FROM DATE / DAY / TIME` |
| `ABORT.S` | ~150 | The runtime error stop |

Plus **moving `SCRSHOW` and `SCRINP` in**, which is not new code — it is the
rename in §4, two `PUT` lines and a handful of vectors.

### The interpreter — handlers that trap today

Seven of them, and none is architectural: the four `GIVING` forms
(`$31`/`$33`/`$35`/`$37`) and the three counted-and-conditional `PERFORM`s.
Plus the wiring for the four query opcodes (`$D4`, `$D5`, `$D7`, `$D8` — `$D3`
`QBE` stays trapping on purpose), the two printer opcodes (`$88`/`$89`) and the
command-key half of `ACCEPT`, all of which have their library sides built.

### Whole programs not started

- **The compiler — started, slice 1 of 8.** `COMPILE.md` is the design and the
  slice list. The **emitter and the object writer are written**; what is left is
  the lexer (2), the keyword tables (3), the DATA DIVISION parser and symbol
  table (4), the PROCEDURE DIVISION parser (5), `COMPUTE`'s expression
  evaluator (6), `COPY`'s source stack (7), and the **launch stub** that makes
  a compiled program a standalone SYS file (8). Menu option 5 still answers
  *Not built yet* and should until slice 5.
- **`VIEW`** — the text and hex viewer, which also reads the `HELP/` files.
- ~~**A `.QRY` writer.**~~ The `QUERY` overlay writes one, since 2026-08-15, and
  the `QUERY` **verb** (`QUERY.md` §15) is how a COBOL program reads one back.
  What is left of that chain is the four VM handlers and the statement parser in
  `CMPPROC` — neither is architectural, and every library routine underneath is
  written.
- **`HELP/`** — the files themselves do not exist.

### Inside programs that do exist

- **`EDIT` slices 4 and 5** — the clipboard and undo.
- **`REPORT` slices 3–7** — dictionary binding, bands, save and load, the
  export, the preview. Slice 6 is the one that matters most: it is what turns a
  `.RPT` into something a program can `COPY`.
- **The bank allocator.** `QRYINIT` currently checks that the cursor will not
  land on the records in use and refuses if it would. That check is a
  placeholder with a clear shape, and it is what an allocator replaces.

### Harnesses that should exist and do not

`STATUS.md` and `PCODE.md` agree on the test order and it is bottom-up: **BCD
first, alone**, then **PICTURE** from a small harness, then the VM from a
hand-assembled object. Neither of the first two harnesses is written, and
`BCD`'s `BMUL`/`BDIV` are still the least-exercised code in the tree.
`QRYTEST.S` is the pattern to copy.
