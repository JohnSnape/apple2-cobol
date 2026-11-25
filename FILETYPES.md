# ProDOS File Types — reference card

For the COBOL.SYSTEM project. Print and keep by the machine.

The type is a **byte in the directory entry**, not part of the filename.
ProDOS has carried it since 1983. Our suffix convention — `LEADS.DAT` becomes a
file named `LEADS` with the type set from the suffix — exists so the name never
has to repeat what the type already says.

---

## 1. Our types

| Suffix | Hex | Aux | Contents |
|---|---|---|---|
| `COB` | **$47** | — | COBOL source — a whole program |
| `SNP` | **$48** | — | COBOL **snippet** — a fragment of one |
| `DCT` | **$49** | — | Screen dictionary |
| `OBJ` | **$4A** | — | p-code object (+ language byte) |
| `SCR` | **$4B** | — | Screen image |
| `RPT` | **$4C** | — | Report format |
| `QRY` | **$4D** | — | Saved query — a predicate and a sort spec. `QUERY.md` §7 |
| `MNU` | **$4E** | — | A menu, from FORMAT (`OA-M`): `MNU1`, flags (bit 0 centre), line count, then row, column, length and text per line. `ACCEPT ... FROM MENU` reads it at compile time (2026-11-11) |
| `DAT` | $04 | **record length** | Relative data file |
| `TXT` | $04 | $0000 | Sequential text, procedures |
| `BIN` | $06 | — | Binary; also the fallback when no suffix matches. `COBOL.LIB` and the overlays are BIN |
| `SYS` | $FF | — | `COBOL.SYSTEM`, and a compiled program's launch stub |

**`DAT` is not a type of its own.** A data file is an ordinary `TXT` with its
record length in the **aux** field — which is exactly what BASIC.SYSTEM does for
a random-access text file (`OPEN NAME,L128` leaves 128 in aux). Following the
machine's existing convention beats inventing one beside it, and it means the
record manager can check a file's record length before reading a byte of it.
Aux `$0000` means sequential.

### Notes on the block

- **`$47–$4D` is contiguous and in build order** — program, snippet,
  dictionary, object, screen, report, query. Easy to remember, easy to
  extend upward.
- **`$48` was BASIC source; BASIC left the project, so the slot now holds
  `SNP`** — a fragment of a program rather than a whole one. `COB` and `SNP`
  hold **structurally identical bytes**; the type is the only thing that says
  which is which, and that is exactly what a type byte is for. Inserting a
  snippet is a copy, not a merge. `SCREXP` writes one.
- **`$4A OBJ` carries a language byte** inside the file. With one language that
  byte is always the same, but it costs nothing and it is the thing you would
  wish you had if a second front end ever appears. `VMRUN` checks it before it
  executes a single instruction.
- **`$4B SCR`** is reserved and currently unwritten. It was the GRAB/SHOW
  screen image; with two real text pages there is nothing to save a screen
  *for*, so the slot is held rather than used.
- **`$4D QRY` holds the question, never the answer.** A saved list of record
  numbers is stale the moment a record changes, and a stale answer is worse
  than none. The file is a predicate and a sort spec; the result is rebuilt in
  a second. Its header is deliberately the same shape as a `.DCT` — signature,
  version, offsets, `poolend`, a twelve-byte name at offset 20 — because two
  formats read by the same kind of code should not be laid out two different
  ways. `SELECT.S` reads one; nothing writes one yet.

### No sequence numbers, anywhere

Our source has no columns 1–6. Column 1 is the indicator, Area A starts at 2,
Area B at 6 — standard COBOL's 7, 8 and 12 with the card-sequence field
removed:

```
Standard fixed-form            Ours
1-6    sequence                 (gone)
7      indicator                1      indicator  '*' = comment
8-11   Area A                   2-5    Area A
12-72  Area B                   6-80   Area B
73-80  identification           (gone)
```

The sequence field existed so a dropped card deck could be re-sorted. There
are no card decks, COBOL never refers to a line by number, and every paragraph
here is called by name. **TAB moves 4 columns**, which is exactly the
Area A → Area B step, the same relationship 8 and 12 have in the standard.

EDIT shows no line number either — there is no gutter, so all eighty columns
are text and **screen column n is source column n**. The current line number
appears in the rule at the top, `OA-G` goes to a line by number, and COMPILE is
our own program, so it can put the editor *on* the offending line rather than
printing a number for someone to hunt. A number a machine can act on does not
need to be on the screen.

### Two caveats worth knowing

**These are Apple's reserved space, not user space.** ProDOS set aside
`$F1–$F8` as the eight user-defined types; everything else is nominally
Apple's to assign. In practice this does not matter — Apple stopped issuing
Apple II type assignments decades ago, and nothing outside this system will
ever read these disks. Worth one honest sentence in the book rather than
silence.

**The CATALOG column is aspirational under BASIC.SYSTEM.** Its `CATALOG` knows
a short list of abbreviations — TXT, BIN, BAS, VAR, REL, SYS, DIR and a few
more — and prints anything else as raw hex, so `$47` shows as `$47`, not `COB`.
The mnemonics become real when our own catalog displays them, which is the
argument for having one.

---

## 2. Standard ProDOS types — the ones you'll actually meet

| Hex | Abbrev | Meaning |
|---|---|---|
| $00 | — | Typeless |
| $01 | BAD | Bad-block file |
| $04 | TXT | ASCII text |
| $06 | BIN | Binary |
| $0F | DIR | Directory |
| $19 | ADB | AppleWorks database |
| $1A | AWP | AppleWorks word processor |
| $1B | ASP | AppleWorks spreadsheet |
| $E0 | LBR | Archive (ShrinkIt, etc.) |
| $EF | PAS | Pascal area |
| $F0 | CMD | BASIC.SYSTEM command file |
| $F1–$F8 | — | User-defined 1–8 |
| $FA | INT | Integer BASIC program |
| $FB | IVR | Integer BASIC variables |
| $FC | BAS | Applesoft BASIC program |
| $FD | VAR | Applesoft variables |
| $FE | REL | Relocatable code (EDASM) |
| $FF | SYS | ProDOS system program |

> `$FC` is Applesoft's `BAS`. There is no longer any clash with ours — `$48`
> was called BAS when this project still planned a BASIC, and is now `SNP`.
> Print the hex beside the mnemonic in the catalog anyway.

## 3. The rest of the low range

| Hex | Abbrev | Meaning |
|---|---|---|
| $02 | PCD | Pascal code |
| $03 | PTX | Pascal text |
| $05 | PDA | Pascal data |
| $07 | FNT | Apple III font |
| $08 | FOT | Graphics screen |
| $09 | BA3 | Apple III BASIC program |
| $0A | DA3 | Apple III BASIC data |
| $0B | WPF | Word processor file |
| $0C | SOS | SOS system file |
| $10 | RPD | RPS data |
| $11 | RPI | RPS index |

**On SOS and COBOL:** there is no COBOL file type to find. SOS's own types sit
in this low range, and no Apple system — SOS, ProDOS, or GS/OS — ever assigned
one for COBOL source. On every machine that had a COBOL, the source was plain
text. `$47` is filling a real gap, not duplicating a standard.

## 4. Apple IIgs range — for completeness only

Not used by this system, which is ProDOS 8 on a IIe.

| Hex | Abbrev | Meaning |
|---|---|---|
| $B0 | SRC | APW/IIgs source |
| $B1 | OBJ | Object file |
| $B3 | S16 | GS/OS application |
| $B8 | NDA | New desk accessory |
| $B9 | CDA | Classic desk accessory |
| $C0 | PNT | Packed super hi-res picture |
| $C1 | PIC | Super hi-res picture |
| $C8 | FON | Font |
| $CA | ICN | Icon file |

---

## 5. Where the type byte lives

In the **CREATE call's parameter block**, at offset +4, with aux at +5/+6:

```
CPARM  DFB 7        parameter count
       DA  0        pathname pointer
       DFB $C3      access: destroy/rename/write/read
       DFB $49      >>> file type <<<
       DA  0        >>> aux type <<<   (record length for DAT)
       DFB 1        storage type: 1 = standard file
       DA  0        create date
       DA  0        create time
```

`SPLITNM` in `FILEIO.S` fills the type byte from the suffix; the caller sets
`FAUX` before `FSAVE` if the file needs a record length. Nothing else in the
system should set either by hand.

**Two filenames are deliberately exempt** from the suffix rule:
`COBOL.SYSTEM`, because `SYSTEM` is not three characters, and `COBOL.LIB`,
because the library has to be loaded before the routine that reads the suffix
table exists. That second exemption is a small, honest admission that a
bootstrap always has one thing it cannot use on itself.

## 6. Name collisions

Stripping the suffix means `LEADS.COB` and `LEADS.DAT` both reduce to a file
named `LEADS`, and ProDOS will not hold two files of one name in a directory
whatever their types. Keep source and data in separate subdirectories — which
is how ProDOS volumes were laid out anyway:

```
/COBOL/SRC/LEADS      COB $47
/COBOL/DATA/LEADS     TXT $04, aux = record length
```

Since ProDOS applies the current prefix to any pathname that does not start
with a slash, a program moves between them by setting the prefix, not by
building paths.
