# The screen dictionary (`.DCT`) — the keystone format

The one contract every tool in the system reads. `FORMAT` is the only
program that writes a dictionary; `SCRSHOW`, `SCRINP`, `SCREXP`, and later the
compiler and the record manager, all consume it and **may never assume a
layout the dictionary does not state**.

This file is the authority on the format. It is transcribed from the code that
actually emits and parses it — `SAVEDCT` and `LOADDCT` in `src/DISKIO.S`,
`GETFLD` in `src/SCRINP.S` — not from the architecture chapter draft, which
predates several of these fields.

ProDOS type `$49`, mnemonic `DCT`. See `FILETYPES.md`.

---

## 1. Header — 32 bytes

| Off | Len | Field | Meaning |
|---|---|---|---|
| 0 | 4 | signature | `"ADB1"` — `$41 $44 $42 $31` |
| 4 | 1 | version | 2 — NUM and BOOL fields are NUM8 cells (§3). Version 1 kept them as text; see below |
| 5 | 1 | organization | 0 = relative fixed-length. 1 (indexed) is reserved and unused |
| 6 | 2 | reclen | data record length in bytes |
| 8 | 1 | fieldcount | number of field descriptors |
| 9 | 1 | labelcount | number of labels in the pool |
| 10 | 1 | keyfield | 1-based field number used as the record key; 0 = none |
| 11 | 1 | screencols | 80. Always 80 — the 40-column case went with `SCREEN.S` |
| 12 | 2 | fieldoff | offset to the field array. Always 32 |
| 14 | 2 | labeloff | offset to the label pool = `32 + fieldcount × 24` |
| 16 | 2 | validoff | offset to the validation area. **Currently always 0** |
| 18 | 2 | poolend | offset to end of file — the file's own length |
| 20 | 12 | dictname | human name, space-padded. **Currently written as zeros** |

Two fields are emitted but not yet used. `validoff` is the hook for
per-field validation rules; `dictname` is the hook for a title. Both were
given room deliberately, and the field-name slot below is the argument for
having done so.

## 2. Field descriptor — 24 bytes each

`fieldcount` of these, back to back at `fieldoff`, **in TAB order** — the
order the operator visits them, which is also the order `SCRINP` walks.

| Off | Len | Field | Meaning |
|---|---|---|---|
| 0 | 10 | name | the field's COBOL data name, space-padded |
| 10 | 1 | type | data type code (§3) |
| 11 | 1 | width | display width in characters |
| 12 | 1 | decimals | digits after the decimal point — the scale of a NUM cell. `FORMAT` always writes 0 |
| 13 | 2 | recoff | byte offset of this field within the record |
| 15 | 1 | storelen | storage length in bytes: the width for ALPHA/ALNUM, **8** for NUM and BOOL |
| 16 | 1 | row | screen row of the data area, 0-based |
| 17 | 1 | col | screen column of the data area, 0-based |
| 18 | 1 | attr | `$00` normal or `$01` inverse. Editable fields get `$01` |
| 19 | 1 | flags | bit0 required, bit1 auto-advance, bit2 secure, bit3 display-only, bit4 upper-case, bit5 space-pad a numeric instead of zero-pad |
| 20 | 1 | valtype | validation type. **Currently always 0** |
| 21 | 2 | valptr | offset into the validation area; 0 = none. **Currently 0** |
| 23 | 1 | editcode | PICTURE / edit code for display. **Currently 0** |

**The ten bytes at the front are the format's one piece of luck.** They were
reserved from the first version and emitted as ten zeros. When the system
needed somewhere to keep each field's COBOL data name — because a data name is
part of what a record contains, and deriving it at export time would let two
exports of one screen disagree — the space was already there, at no cost in
version number or file size.

`recoff` and `storelen` together are why no tool computes layout. `FORMAT`
packs each field after the previous one and writes the answer down; everything
downstream reads it.

## 3. Data type codes

| Code | Name | On screen | In the record |
|---|---|---|---|
| 0 | ALPHA | letters and spaces only | left-justified, space-padded, `width` bytes |
| 1 | ALNUM | any printable character | left-justified, space-padded, `width` bytes |
| 2 | NUM | digits only, at most 14 | a **NUM8 cell**, 8 bytes, at the field's `decimals` |
| 3 | BOOL | `Y` or `N` | a **NUM8 cell**, 8 bytes: 1 or 0 |

**Why NUM and BOOL are cells (version 2, 2026-11-08).** The record a dictionary
describes is the record a COBOL program writes, and the copybook `SCREXP`
exports declares a NUM field `PIC 9(n)` and a BOOL `9 COMP` — both of which the
compiler makes a NUM8 cell, eight bytes whatever the PICTURE. Version 1 stored
NUM as digit text of the field's width and BOOL as one byte, so the query engine
and a program's own data file read different bytes at different offsets. Now
they agree: `FORMAT` gives every NUM and BOOL field a `storelen` of 8, `SCRINP`
packs them as cells, and `SELECT.S` compares them as numbers and sorts them by
value. Flags bit5 (space-pad) no longer means anything for a cell.

`FORMAT` writes version 2. Opening a version 1 dictionary in `FORMAT` makes its
NUM and BOOL fields cells and repacks the offsets, so **Open then Save upgrades
it**. The `QUERY` verb refuses a version 1 dictionary with status 9 rather than
misread it.

A NUM field wider than 14 digits is refused when it is placed — a cell holds
fourteen.

`FORMAT` prompts for these as **A, X, N, B**.

Four types, not eight. The draft architecture chapter lists date, packed
decimal and signed-numeric types as well; those never existed in the code, and
the arrival of NUM8 removed the reason to want most of them — a COBOL numeric
variable is a NUM8 cell wherever the compiler puts it, and a *screen* field is
text the operator types. `PICTURE.S` is what converts between the two, and it
is driven by a PICTURE string, not by a type code.

`editcode` is where a per-field PICTURE reference will go when edited screen
fields are wired up. It is reserved, and zero today.

## 4. The label pool

`labelcount` entries at `labeloff`, each variable length:

```
byte   row
byte   col
byte   attribute    always $00 (normal) - see the attribute rule below
byte   length L
L      the label text, which may embed MouseText codes $40-$5F
```

Labels are the constant prompts — `NAME:`, `BALANCE:` — drawn once by
`SCRSHOW`. They are not fields and have no storage.

`LOADDCT` re-associates a label with its field by geometry: a label belongs to
the field on the same row whose data column is `col + length + 1`. That is the
rule `FORMAT` places them by, so the round trip is exact.

## 5. The attribute rule

Not decoration — structure, and the reason the format carries an `attr` byte
at all:

- **Screen furniture is normal** (white on black): every label, the command
  rows, borders, any MouseText.
- **Data-entry areas are inverse** (black on white): the field the operator
  types into.

It is hardware-driven. Inverse says *you may type here* at a glance — an empty
inverse field reads as a row of solid blocks — and MouseText, which supplies
the borders and glyphs, **exists only in normal form**: the enhanced IIe
character ROM has no black-on-white MouseText. So anything using MouseText
must be normal, which is exactly why the furniture is normal and only typeable
data is inverse.

Two machine states make it work, and `TDINIT` sets both: 80 columns on, and
the alternate character set enabled (`STA $C00F`). The alternate set is what
simultaneously provides normal lowercase, inverse letters, and the 32 MouseText
glyphs.

A **display-only** field is not an entry area, so it renders normal — which
keeps the promise that inverse always means "type here". `FORMAT` sets the
`attr` byte itself; the designer is never asked to choose one.

### The one trap: inverse uppercase

A character's attribute is carried in the *value* written to screen memory, so
`CONV` translates ASCII to a screen code as it places it:

| ASCII in | Normal code | Inverse code | Note |
|---|---|---|---|
| `$20–$3F` space, digits, punctuation | `ORA #$80` | unchanged | already the inverse symbol/digit block |
| `$40–$5F` `@`, A–Z, `[ \ ] ^ _` | `ORA #$80` | `AND #$3F` → `$00–$1F` | **must fold, or you print MouseText** |
| `$60–$7E` backquote, a–z, `{ | } ~` | `ORA #$80` | unchanged | already the inverse-lowercase block |

Echo a typed `A` (`$41`) into an inverse field by merely clearing the high bit
and you store `$41`, which in the alternate character set is a MouseText glyph,
not an inverse A. Inverse uppercase and symbols live at `$00–$1F`, so that one
range must be folded down by `$40`. This is why the inverse conversion is a
small range test rather than a single mask.

## 6. What the dictionary is not

It is not a COBOL `SCREEN SECTION`, and the compiler never loads one at run
time. `SCREXP` reads a dictionary at **author** time and writes ordinary
`DISPLAY`/`ACCEPT ... AT LINE n COLUMN n` statements a programmer can read and
edit. That is the whole argument for generating rather than interpreting:
no new grammar, no new p-code, and nothing hidden. See `KEYWORDS.md`.
