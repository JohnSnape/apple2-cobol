# Building the disk

Appendix G. How to assemble the system under Merlin 8 and lay out a ProDOS
volume that boots into it. Written for the first real build — the one that
turns the source tree into something you can run.

Environment assumed, matching the project's: AppleWin with **Merlin 8 in slot
6** and an **800K 3.5" drive in slot 7**. It takes **two** 3.5" volumes — one to
assemble on, one to boot — and §1a says why.

> This appendix has not itself been carried out end to end yet. The file names,
> load addresses and boot rules are all verified against the source; the exact
> Merlin directive for setting a file's type is the one place that depends on
> your assembler version, and §4 says how to check it.
>
> Revised 2026-08-15, against the tree rather than against the previous
> revision. Eight things had fallen behind: `QUERY` was missing from the build
> list entirely, the `LIB` `PUT` list was two modules short, the count of
> assemblies was six, no stub actually carries the `DSK` line §3 assumes, the
> `VM` ceiling symbol was unnamed (and `VM` has a decoy), `CLOCKUP` was missing
> from the boot sequence, the menu-option list was a version old, and nothing
> said that the sources will not fit in a ProDOS volume directory.

---

## 1. What you are building

Nine files. Eight are ours; `PRODOS` is copied. Three are required before
anything runs at all; the rest are one menu option each.

| Built from | File on disk | ProDOS type | Loads at | Needed for |
|---|---|---|---|---|
| — | `PRODOS` | SYS ($FF) | (the kernel) | booting |
| `COBOLSYS.S` | `COBOL.SYSTEM` | **SYS ($FF)** | `$2000` | the menu |
| `LIB.S` | `COBOL.LIB` | BIN ($06) | `$3000` | everything |
| `EDIT.S` | `EDIT` | BIN ($06) | `$8000` | options 1, 2, 3 |
| `FORMAT.S` | `FORMAT` | BIN ($06) | `$8000` | option 4 |
| `QUERY.S` | `QUERY` | BIN ($06) | `$8000` | option 6 |
| `REPORT.S` | `REPORT` | BIN ($06) | `$8000` | option 7 |
| `VM.S` | `VM` | BIN ($06) | `$8000` | running a compiled object |
| `COMPILE1.S` | `COMPILE1` | BIN ($06) | `$8000` | option 5, pass one |
| `COMPILE2.S` | `COMPILE2` | BIN ($06) | `$8000` | option 5, pass two |

**The compiler is two overlays and one compile.** `SYSMENU`'s `DOCMP` loads
`COMPILE1`, tests `CMPERR`, and loads `COMPILE2` only if pass one was clean —
so both files must be on the volume or option 5 fails with *Overlay load
failed* halfway through. One overlay would not fit: with the `QUERY` statement
in, `CMPEND` landed above `OBDESC` at `$9C00`, which is the descriptor table
the compiler is building.

It works because **the four build areas are outside the band** — `OBDESC`
`$9C00`, `OBLIT` `$9E00`, `SYMTAB` `$A000`, `OBCODE` `$A400` — so pass two
loads over pass one's *code* and finds pass one's *work* untouched. The values
that could not stay in the band are in `CMPXFR` at `$1F00`. `MEMMAP.txt` has
the layout.

`PRODOS` is the ProDOS 8 kernel itself — copy it from any ProDOS system disk,
do not build it. Everything else is ours.

**The menu offers nine options and the volume must be able to answer all of
them.** `SYSMENU` dispatches 1–9. Options **2 and 3** call `STUBM` and answer
*Not built yet* — both want a file picker. Options **4, 5, 6, 7 and R** load
overlays by name — **R runs a compiled program**: it asks for the name, loads
the `.OBJ` to `$9200` and then loads `VM`, and a missing overlay is an *Overlay load failed* message
rather than anything more helpful. Option 8 (Utilities) is resident and 9 quits.

The six overlay names `SYSMENU` asks the MLI for are exactly `EDIT`, `FORMAT`,
`COMPILE1`, `COMPILE2`, `QUERY` and `REPORT`, and the library is exactly
`COBOL.LIB`. They are length-prefixed byte strings in `SYSMENU.S`; a file named
anything else is not found.

Only `COBOL.SYSTEM` must be a SYS file. The overlays and the library are loaded
by name through the MLI, which does not care about their type, so BIN is
correct for them.

### The four harnesses

None is part of the system and none belongs on the boot volume, but all four
need saying somewhere:

| Built from | File | Loads at | Proves |
|---|---|---|---|
| `QRYTEST.S` | `QRYTEST` | `$8000` | SELECT and SORT |
| `KEYTEST.S` | `KEYTEST` | `$8000` | the Apple command keys |
| `OBJTEST.S` | `OBJTEST` | `$8000` | the p-code emitter and the object format |
| `LEXTEST.S` | `LEXTEST` | `$8000` | the lexer — a token dump you read against the source |

`OBJTEST` `PUT`s `CMPEMIT`, `CMPOBJ` and `CMPVAR`; `LEXTEST` `PUT`s `CMPLEX`
and `CMPVAR`. Those pieces must be on the Merlin disk beside them.

`OBJTEST` writes `HELLO.OBJ` — the object `PCODE.md` §5 asks for, without the
hand-assembly. `LEXTEST` prints a token dump you read against the source: a
word in Area A shows a column of 2–5 and a word in Area B shows 6 or more, and
that difference is the whole of fixed-form COBOL's grammar.

They are **standalone `BRUN` programs that still need the library**, because
they call it through the jump table at `$3000`. Run them in two steps from
BASIC.SYSTEM, not one:

```
BLOAD COBOL.LIB,A$3000
BRUN QRYTEST
```

`BRUN` on its own gets a jump into whatever happens to be at `$3000`, which on
a freshly booted machine is nothing at all. `AXTEST` and `PG2TEST` are older
spikes that stand alone and need no library (both `ORG $2000`; the other four
are at `$8000`).

## 1a. Two volumes, and a limit that decides the layout

**The sources do not fit beside Merlin, and they do not fit in a volume
directory.** Both facts change the plan, and neither is obvious until the first
build fails.

- `src/` is **84 files, about 490 KB — roughly 1,120 ProDOS blocks** with index
  blocks counted. A 140 K 5.25" cannot hold a tenth of it, so the Merlin disk in
  slot 6 holds the assembler and nothing else.
- **A ProDOS volume directory holds exactly 51 entries** — four blocks, thirteen
  entries each, less one for the volume header. Eighty-four sources will not go
  in the root of anything. Subdirectories grow; volume directories do not.

**On a 32 MB volume none of this bites** — a 32 MB image is the ProDOS 8
maximum and holds the whole tree many times over, and `/COBOL/SRC/` and
`/COBOL/OBJ/` are subdirectories, which have no entry limit. One volume, two
subdirectories, and the only rule left is that Merlin's prefix must be
`/COBOL/SRC/` when you assemble, because `PUT` resolves against the prefix.
`DSK OBJ/EDIT` or a prefix change puts the objects where you want them.

On 800 K disks, which is what the project assumed until now, build with **two
volumes**:

| Volume | Holds |
|---|---|
| **work** (slot 7 while assembling) | `/WORK/SRC/` — all 84 sources, plus the objects `DSK` writes beside them. ~1,120 of 1,600 blocks; there is no room for a second copy of anything large |
| **boot** (slot 7 when running) | the nine files in §6, copied across after the build |

Set Merlin's prefix to the subdirectory before assembling. `PUT` resolves its
names against the current prefix, so **every `PUT` file must sit in that one
directory** beside the stub that reads it.

`DSK` writes its object into the current prefix too — so the objects land in
`/WORK/SRC/` next to the sources, and copying the nine of them to the boot
volume is the last step of the build rather than something to arrange in
advance.

## 2. Source names on the Apple side

**Keep the `.S` suffix on the Merlin disk.** Merlin 8 under ProDOS adds `.S`
to source names itself, for `LOAD` and for `PUT` alike: `PUT EQUATES` opens
`EQUATES.S`, and `LOAD LIB` opens `LIB.S`. So the files go onto the disk with
the same names they have in `P:\COBOL\src`. A file renamed to
plain `EQUATES` is **not** found. (This section used to say the opposite; it
was wrong. DeskWorks has always assembled with `.S` names, and `COBOL32.po` was
built that way on 2026-11-07.)

The `PUT` lines and the stub you load are written **without** the suffix. The **nine** you actually run the assembler on are `LIB`,
`COBOLSYS`, `EDIT`, `FORMAT`, `QUERY`, `REPORT`, `VM`, `COMPILE1` and
`COMPILE2`; the other **sixty-eight** are pulled in by `PUT` and are never
assembled directly.

Every one of those nine is a **stub** — a small file of `PUT`s, the same shape
as `LIB` — so the code lives in pieces that must be on the disk beside their
stub. The files each stub pulls in, in the order it pulls them:

| Stub | `PUT`s (after `EQUATES`) |
|---|---|
| `LIB` | `TEXTDRV FILEIO CATALOG BCD BANKS CONSOLE DSCREEN AUXMEM NUMFMT PICTURE SELECT SORT PRINTER DATIME CLOCK RECMAN` |
| `COBOLSYS` | `SYSBOOT SYSLOAD SYSMENU SYSUTIL` — `SYSBOOT` **first**, and there is no `JMP` in the stub, so `COLD` is `$2000` |
| `EDIT` | `EDITENT EDITRNG EDITSHF EDITDRW EDITRUL EDITCUR EDITDSP EDITCMD EDITIO EDITBAR EDITVAR` — `EDITVAR` **last**, so `EDEND` is the real end |
| `FORMAT` | `PRODOS DISKIO PROMPT SCREXP SCRPRV FORMATD` — `FORMATD` **last**, so `FMTEND` is the real end |
| `QUERY` | `PRODOS PROMPT QRYENT QRYADD QRYIO QRYVAR` — `QRYVAR` **last**, so `QRYEND` is the real end |
| `REPORT` | `PROMPT RPTENT RPTDRW RPTADD RPTBAR RPTVAR` — `RPTVAR` **last**, so `RPTEND` is the real end. No `PRODOS`, no `DISKIO`: slice 1–2 REPORT does no file I/O |
| `VM` | `VMCORE VMLOOP VMMOVE VMMATH VMFLOW VMSCRN VMQRY VMTAIL` — `VMTAIL` **last**, so `VMSIZE` is the real end |
| `COMPILE1` | `CMPEMIT CMPCOM CMPLEX CMPSYM CMPPIC CMPDATA CMPVAR` — `CMPVAR` **last**, so `CMPEND` is the real end |
| `COMPILE2` | `CMPEMIT CMPCOM CMPOBJ CMPLEX CMPSYM CMPPROC CMPVAR` — same rule |

> **The `LIB` list grew twice and this file missed both.** It used to stop at
> `PICTURE`, which gave a library with the eight query vectors pointing at
> nothing; it then stopped at `PRINTER`, which left slots 84–91 dangling and took
> `CLOCKUP` out of the boot sequence with it. `DATIME` and `CLOCK` are the last
> two `PUT`s in `LIB.S` and both belong on the disk. When a module is added to
> the library, this table is the second place to change.

**Four files are pulled in by more than one stub.** `PROMPT` by `FORMAT`,
`QUERY` and `REPORT`; `CMPEMIT`, `CMPCOM`, `CMPLEX`, `CMPSYM` and `CMPVAR` by
both compiler passes. Each must be on the disk once and every assembly that
wants it reads it from there.

`CMPCOM` is new with the compiler split and exists for one reason: `DDFIGN`
(figurative constants) was in `CMPDATA` and `DDVSCL` (numeric-literal scaling)
was in `CMPPIC`, both pass-one files, and the PROCEDURE parser calls both —
because a literal is a literal wherever it appears. Same operation `PROMPT.S`
was, one level down. It also means **each of the three overlays has to
define `CMDLIST` and `DOPREV`** for itself, since `LINEIN` walks the one and
`SA-C` calls the other:

| Overlay | `CMDLIST` in | `DOPREV` in |
|---|---|---|
| `FORMAT` | `FORMATD` | `SCRPRV` |
| `QUERY` | `QRYVAR` | `QRYENT` (an `RTS` — no preview yet) |
| `REPORT` | `RPTBAR` | `RPTENT` (an `RTS` until slice 7) |

A missing one shows up as an undefined label rather than as bad behaviour,
which is the good kind of wrong.

**Two files are `PUT` by nothing**: `SCRSHOW.S` and `SCRINP.S`. Copy them to the
work volume for completeness, but do not add them to any stub —
`SCRINP.S:456` declares `FTYPE DFB 0` against `EQUATES.S`'s `FTYPE EQU $0CCB`,
so it will not assemble inside anything until the local one is renamed.

The pieces must be present on the same disk, because `PUT` opens them at
assembly time — but they are never *loaded* into the editor, so their size does
not matter. See the note below, which is the important one.

Transfer the source in with CiderPress II's **`merlin` importer**
(`cp2 import <image> merlin SRC`), which stores Merlin's own format as ProDOS
**TXT** files and converts the line endings. The sources are already in
Merlin's single-space paste format — one space before each opcode, labels in
column 1 — so nothing else needs changing. `ASSEMBLE.md` Phase 1 has the
whole recipe.

> **Why every program is a stub.** Merlin holds the *loaded* file in memory;
> `PUT` files stream from disk as they assemble and never sit in the editor.
> That is the whole reason `LIB` — a 4 KB file that pulls in ~100 KB of modules
> — assembles without complaint, while `EDIT` and `VM`, with their code inline
> (~22 KB and ~24 KB), ran the machine out of memory. `VM` in particular could
> never have been assembled as one file; it is larger than the editor buffer.
>
> So all five are built the way `LIB` always was: the stub is just the header,
> the constants, `ORG`/`JMP` and a list of `PUT` lines, and the code lives in
> the pieces listed in §2. Two rules keep every such split correct, and both
> are already satisfied throughout:
>
> 1. **The `PUT` order is the original code order.** `PUT` concatenates each
>    file at its line, so the assembled bytes — fall-throughs and all — are
>    identical to the former single file. The `JMP` at the top of each stub
>    lands on the first byte of the first piece (or, for `COBOLSYS`, there is no
>    `JMP` and `SYSBOOT` is `PUT` first so `COLD` stays at `$2000`). `EDITVAR`
>    stays last because `EDEND` marks the end there.
> 2. **A `PUT` file carries no `ORG`, `DSK`, `PUT`, or `END`** — only the stub
>    has directives, and Merlin allows just this one level of `PUT` (no nesting).
>
> `DSK` (optional, §3) helps the same way from the other side: with the object
> written straight to disk it never occupies memory during assembly. After a
> build, `EDEND` from the `EDIT` symbol table is still the number that matters —
> it must be below `$9800`.

## 3. Assembling

Each source already carries its own `ORG`, so there is nothing to set at
assembly time except where the object goes. The clean way is Merlin's `DSK`
directive, which writes the assembled bytes straight to a named disk file as it
assembles — correct regardless of `ORG`, which is the point.

**No stub carries a `DSK` line today.** Adding them is the first thing this
appendix asks you to do to the sources. One line in each of the eight, just
after the `ORG`:

```
        DSK COBOL.LIB        ;in LIB
        DSK COBOL.SYSTEM     ;in COBOLSYS
        DSK EDIT             ;in EDIT
        DSK FORMAT           ;in FORMAT
        DSK QUERY            ;in QUERY
        DSK REPORT           ;in REPORT
        DSK VM               ;in VM
        DSK COMPILE1         ;in COMPILE1
        DSK COMPILE2         ;in COMPILE2
```

Then, for each, load it into Merlin and assemble (`ASM`). **Nine separate
assemblies. Nothing links and nothing consumes another's object, so the order
is free** — but there is a risk order, and it is the one to use:

1. **`LIB` first.** Everything loads it, and `LIBEND` gates the whole disk.
2. `COBOLSYS` — the menu, and it is the smallest.
3. `EDIT` — all you need for the first boot test in §7.
4. `FORMAT` — the tight one, and the object that changed most recently: the
   `PROMPT` extraction moved blocks about, which is exactly how branch-range
   errors are caused.
5. `QUERY`, then `REPORT` — first-ever assemblies, both.
6. `VM`, then `COMPILE1` and `COMPILE2`. The two passes are independent
   assemblies but not independent programs: check `CMPEND` on **both**, and
   remember that a compile that gets through pass one and cannot load pass two
   leaves a half-built object in memory and nothing on disk.

If you would rather not edit the sources, assemble without `DSK` and `BSAVE`
the object from the Merlin monitor instead; `DSK` is simply less to get wrong.

## 4. Setting the file types

`DSK` creates BIN files. Seven of the eight are supposed to be BIN, so they are
already right. **`COBOL.SYSTEM` must become SYS ($FF)** or the disk will not
boot into it.

Two ways, and which you use depends on your Merlin:

- **If your Merlin has the `TYP` directive** (Merlin 8/16 and later), add
  `TYP $FF` alongside the `DSK` line in `COBOLSYS`, and the file is written as
  SYS directly. Confirm your version supports it before relying on it — assemble
  once and check the catalogued type.
- **Otherwise set the type afterward** with a file utility: Copy II Plus, or a
  one-line BASIC program using the ProDOS `SET_FILE_INFO` MLI call, or
  CiderPress on the host. Change `COBOL.SYSTEM` from BIN to SYS.

After this step, catalog the volume and confirm: `COBOL.SYSTEM` and `PRODOS`
show as **SYS**, the other six as **BIN**.

## 5. The size checks — do them now

Merlin prints the symbol table after assembly. Seven symbols are load-bearing,
and every one of them fails *silently at run time* rather than at assembly:

| Symbol | From | Must be below | What happens above it |
|---|---|---|---|
| Symbol | Defined in | Must be below | What happens above it |
|---|---|---|---|
| `LIBEND` | `LIB.S` | `$8000` | The library has grown into the overlay band and is overwritten the moment an overlay loads |
| `EDEND` | `EDITVAR.S` | `$9800` | EDIT's code has grown into its own line ring. The first symptom is corrupted text, not a crash |
| `FMTEND` | `FORMATD.S` | `$B000` | FORMAT has run off the end of the band. **This is the tight one** — it carries roughly 10.5K of the 12K, most of the growth being `EXPOUT`'s 3,000 bytes of `DS` |
| `QRYEND` | `QRYVAR.S` | `$B000` | QUERY has run off the end of the band |
| `RPTEND` | `RPTVAR.S` | `$97E0` | REPORT's code has grown into the report header it is editing |
| `VMSIZE` | `VMTAIL.S` | `$9200` | The interpreter has grown into the object file it is running. The ceiling **moved up 512 bytes on 2026-08-16** when the file opcodes went in; `OBJBASE` in `VM.S` is the one line that sets it, and 479 bytes are spare |
| `CMPEND` | `CMPVAR.S` | `$A080` | The compiler has grown into the descriptor table it is building, and the first symptom is an object whose descriptors are p-code |

> **`VMSIZE`, not `VMEND`.** This appendix used to say "the end of `VM`" without
> naming a symbol, and `VM` has both. `VMEND` is an `RTS` inside `VMLOOP.S` —
> where the fetch loop goes when `VMHLT` is set — and reading it tells you
> nothing. `VMSIZE EQU *` at the foot of `VMTAIL.S` is the end of the object.

If any of them fails, stop — nothing downstream will behave, and no amount of
careful testing will tell you why.

Static estimates from the host, good to about one per cent, as a sanity check
before you assemble: `LIB` ≈ 9,768 (`LIBEND` ≈ `$562B`), `COBOLSYS` ≈ 1,501,
`EDIT` ≈ 4,812, `FORMAT` ≈ 10,468, `QUERY` ≈ 4,105, `REPORT` ≈ 3,101,
`VM` ≈ 4,129 (`VMSIZE` ≈ `$9021`), `COMPILE` ≈ 1,554. The pass that produced them sized `EDIT` at
4,812 against Merlin's own 4,788, which is half a per cent — so if Merlin
disagrees with one of these by more than a few per cent, something is being
assembled that you did not mean to assemble.

**If `FMTEND` overruns**, the fix is not to shrink anything: move `EXPOUT` (and
`DCTOUT`) out of the object and into the data region. `OVLWORK` is only 896
bytes, so that needs a fresh allocation rather than a corner of an existing one.

## 6. Laying out the boot volume

Put these on the 3.5" ProDOS volume:

```
PRODOS          SYS   the kernel, copied from a ProDOS disk
COBOL.SYSTEM    SYS   our menu
COBOL.LIB       BIN   loaded by everything
EDIT            BIN   menu options 1, 2, 3
FORMAT          BIN   menu option 4
COMPILE1        BIN   menu option 5, pass one
COMPILE2        BIN   menu option 5, pass two
QUERY           BIN   menu option 6
REPORT          BIN   menu option 7
VM              BIN   runs a compiled object
SKEL.COB        COB   the template menu option 2 copies
```

Eleven files, which the volume directory holds comfortably — it is the *work*
volume that needs the subdirectory (§1a), not this one.

`EDIT` alone is enough for the first boot test below. Leave the rest off if you
only want to prove the menu and the editor — but then do not press 4, 5, 6 or
7, because a missing overlay is an *Overlay load failed* message and nothing
more diagnostic than that. **`COMPILE1` and `COMPILE2` travel together**: pass
one leaves a half-built object in memory and writes nothing, so a volume with
only the first of them fails after doing work rather than before.

Two rules decide whether it boots into our system rather than something else:

1. **`PRODOS` must be present.** The boot blocks load it by name; without it the
   disk is not bootable at all.
2. **`COBOL.SYSTEM` must be the first — ideally the only — `.SYSTEM` file.**
   After the kernel loads, it launches the *first* file of type SYS whose name
   ends in `.SYSTEM`. If you built the volume from a copy of a BASIC.SYSTEM
   disk, **delete `BASIC.SYSTEM`**, or it will win and you will land at an
   Applesoft prompt instead of our menu.

Source, data and object files belong on *other* volumes — that is what the work
volume in §1a is. The boot disk needs only the eleven files above. (A program's `.COB` source
and `.DAT` data live in their own subdirectories — see `FILETYPES.md` — but
none of that exists to collide with anything yet.)

## 7. Boot and test

Boot the 3.5" volume (slot 7). `COLD` in `SYSBOOT.S` runs, in order, and the
order is load-bearing:

```
CHK128 → CHK65 → LOADLIB → CLAIM → INIT80
       → FINDBNK → BMINIT → SETPFX → CLOCKUP → MENU
```

If it stops before the menu, the message says which check failed — those run
through the 40-column monitor precisely so they can report before the driver
exists.

**`CLOCKUP` is new and has not run on the machine.** It sits after `INIT80`
because it may have to talk to the operator and there is no screen before that,
and before `MENU` because every file the session creates is stamped from what it
settles. It either says *Clock found — dates on.* or asks for the date; **an
empty line means leave it**, which is the answer to give while testing. It calls
the library through the jump table (`CLKFIND`, `CLKASK`), so a `COBOL.LIB` built
without `PUT CLOCK` fails here as an unresolved symbol at assembly time rather
than as a hang.

At the menu, press **1** (Create NEW program and EDIT). The top line should
show the version at the left and today's date at the right — if the date is
wrong or absent, `CLOCKUP` is what to look at.

Options **2 and 3** answer *Not built yet*; **4** is FORMAT, **5** is the
compiler (two overlays in sequence), **6** is QUERY, **7** is REPORT, **8** is
Utilities and **9** quits. Inside Utilities, 1
catalogs, 3 deletes, 4 renames, 6 sets the date and 7 sets the printer slot; 2
(COPY) and 5 (VIEW) are stubs, because both are overlay-sized and unwritten.

What a correct EDIT screen looks like:

- row 0: the prefix at the left, `UNTITLED`, and a byte count at the right
- row 1: the rule — `LINE 1 OF 1 COLUMN 1`
- rows 2–21: twenty blank lines
- rows 22–23: the two command bars, now including `⌥-O Open` and `⌥-S Save`

Reaching that screen means the ring, `PUTROW`, `AUXMEM` and `NUMFMT` all work —
most of Part I, exercised at once. It is a demanding first test for exactly that
reason: `EDINIT` writes a blank line into auxiliary memory *before it draws
anything*, so if `AMGET`/`AMPUT` are wrong you get a hang with a blank screen
and no clue on it. `AXTEST` already proved bank select composes with `AUXMOVE`,
so the mechanism under them is sound; these two routines themselves have not run
before.

Then the milestone — the first `.COB` file the system has ever made:

1. type a line of anything
2. `⌥-S`, name it `TEST`, Return
3. `⌥-N` to clear, confirm
4. `⌥-O`, `TEST`, Return

If the line comes back, Open and Save round-trip and the tool chain is a system.
`TEST` catalogs as type **COB** — the suffix defaulted, because EDIT edits
COBOL source and a bare name is `.COB`.

## 8. If it goes wrong

- **Nothing boots / lands in Applesoft.** A `.SYSTEM` file other than ours came
  first, or `PRODOS` is missing. Recheck §6.
- **"Cannot load COBOL.LIB".** The library is not on the boot volume, is
  misnamed, or `DSK` wrote it somewhere else. It must be named exactly
  `COBOL.LIB`.
- **Blank screen, hang, on menu option 1.** `AUXMEM` — the first thing EDIT does
  is write a record to aux. This is the expected failure mode if `AMGET`/`AMPUT`
  or `AMMAP` is wrong, and the reason to trust `AXTEST` first.
- **Garbled or doubled text on entry.** Almost always the 80-column split — an
  `AUXWR`/`MAINWR` left in the wrong state, or `CONV`/`PUTROW`. It means the
  driver, not EDIT.
- **A save appears to work but the file is wrong on reload.** Look at the
  DESTROY-before-CREATE and CLOSE-on-error paths in `DSAVE`; a file left open
  loses its blocks, and ProDOS has no truncate.

### At assembly time, before any of that

- **"Undefined label: `CMDLIST`" or "`DOPREV`".** `PROMPT` is shared by three
  overlays and each must define both (§2). You are assembling a stub whose
  `PUT` list is missing the piece that holds them.
- **Undefined `CLKFIND` / `CLKASK` / `DTMDATE`, or the query vectors.** The
  `LIB` `PUT` list is short. §2's table is the current one.
- **"File not found" in the middle of an assembly.** A `PUT` file is not in the
  current prefix. `PUT` resolves against the prefix, not against the stub's
  location — put every piece in the one subdirectory.
- **The volume directory is full at 51 files.** Not a bug. §1a: the sources go
  in a subdirectory, never in a volume root.
- **Out of memory assembling.** Something has an `ORG` but no `DSK`, or a piece
  was loaded into the editor instead of being `PUT`. Merlin holds the *loaded*
  file in memory; `PUT` files stream from disk. `VM` is larger than the editor
  buffer and can only be built as a stub.
