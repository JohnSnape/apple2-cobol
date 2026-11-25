# COBOL SYSTEM for the Apple IIe

A complete COBOL programming system for the enhanced Apple IIe, written in
65C02 assembly. You write, compile, run and maintain business programs from
one 80-column menu under ProDOS 8.

| Part | What it does |
|---|---|
| **EDIT** | A full-screen, 80-column editor for COBOL source. It keeps the program in auxiliary memory. |
| **FORMAT** | A screen designer. It saves the layout as a *dictionary* and writes the COBOL that displays and accepts it. |
| **QUERY** | A query designer. You pick conditions and sort keys from a dictionary's fields, and a program can then run the query. |
| **REPORT** | A report designer for the printed page. *Still in progress.* |
| **COMPILE** | A two-pass compiler from COBOL to a compact p-code object file. |
| **RUN** | The p-code interpreter, with the run-time library `COBOL.LIB` behind it. |
| **VIEW** | Shows a data file, laid out by its dictionary, read-only. |
| **Utilities** | Catalog, copy, delete and rename files; set the date, the time, the printer slot and the prefixes; make a turnkey disk. |

The language is a subset of ANSI COBOL chosen for business work on a small
machine:
- relative files;
- exact decimal arithmetic to fourteen digits;
- edited pictures for money and dates;
- `END-IF`, `EVALUATE` and in-line `PERFORM`.

There is one extension, `QUERY`, which selects and sorts records using a saved
query. There is no floating point and no `CALL`. [`QUICKREF.md`](../QUICKREF.md)
lists every keyword and whether it works yet.

```cobol
 IDENTIFICATION DIVISION.
 PROGRAM-ID. HELLO.
 PROCEDURE DIVISION.
 MAIN-PARA.
     DISPLAY "HELLO FROM THE APPLE IIE".
     STOP RUN.
```

## What it needs

| | |
|---|---|
| Computer | An enhanced Apple IIe (65C02). The system checks for the 65C02 when it starts. It hasn't been tried on a IIc or IIGS. |
| Memory | 128K. Extra auxiliary memory, such as a RamWorks card, is used when it's there. |
| Display | 80 columns |
| Disk | ProDOS 8. The system fits on an 800K disk; a hard-disk volume leaves room for your work. |
| Clock, printer | Optional |

It is developed and tested in [AppleWin](https://github.com/AppleWin/AppleWin).

It also runs on [COBOL.OS](https://github.com/JohnSnape/cobol-os), a small
ProDOS-compatible kernel written for it. COBOL.OS handles the ProDOS calls this
system uses, on SmartPort devices only. It is published as a repository of its
own; the build of COBOL SYSTEM for it is not published yet.

## Status

**This is a work in progress, not a release.** No disk image is provided. To
run it, you build it and put it on a ProDOS volume of your own, together with
ProDOS 8, which isn't included.

These files say what works and what doesn't:
- [`DECISIONS.md`](../DECISIONS.md): what was decided, and why;
- [`FIXLIST.md`](../FIXLIST.md): known faults;
- [`QUICKREF.md`](../QUICKREF.md): the state of each keyword.

## Building

**Merlin 8**, on the Apple, is the assembler of record. **Merlin32**, from
Brutal Deluxe, is a byte-identical stand-in for building on a PC.

```sh
sh tools/m32build.sh     # assembles every program into build/obj/
```

- Set the path to `Merlin32.exe` at the top of `tools/m32build.sh`.
- `tools/fwdref.js` catches the forward `EQU` references that Merlin 8
  gets wrong and Merlin32 forgives.
- [`BUILD.md`](../BUILD.md) covers assembling under Merlin 8, the file types,
  and laying out a bootable ProDOS volume.
- [`ASSEMBLE.md`](../ASSEMBLE.md) has the details of the assembly.

The rules the source keeps, so that Merlin 8 can assemble it on a real IIe:
- every line is 60 columns or less;
- `PUT` files stay under about 24K;
- no lowercase character constants;
- no forward `EQU`s.

## Where things are

| | |
|---|---|
| `src/` | The source. `EQUATES.S` holds every address. Each program is a stub of `PUT`s. |
| `src/*.COB` | Sample programs (CR-terminated, for the Apple) |
| `PROCS/` | Sample procedure files |
| `MANUAL/` | Reference manual chapters (drafts) |
| `tools/` | The Merlin32 build, checkers, and the reference-page generator |
| `tools/emu/` | AppleWin test scripts (PowerShell). They drive AppleWin and check its screen. |
| [`MEMMAP.txt`](../MEMMAP.txt) | The memory map: the authority on addresses |
| [`COMPILE.md`](../COMPILE.md), [`PCODE.md`](../PCODE.md), [`RUNTIME.md`](../RUNTIME.md) | The compiler, the p-code machine, the library |
| [`KEYS.md`](../KEYS.md) | Every key the system acts on |
| [`DICTIONARY.md`](../DICTIONARY.md), [`QUERY.md`](../QUERY.md), [`REPORT.md`](../REPORT.md) | The file formats |
| [`CLIPBOARD.md`](../CLIPBOARD.md), [`STARTUP.md`](../STARTUP.md) | Open conventions other programs can share |

## Licence

MIT. See [`LICENSE`](../LICENSE).
