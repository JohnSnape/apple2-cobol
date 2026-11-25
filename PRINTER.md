# The printer

How a COBOL program prints. The authority on `PRINTER.S`, the slot, and the
control-code mnemonics.

---

## 1. The thing that makes this easy

**We never gave the screen to the firmware, so the printer cannot take it.**

The normal way to print on an Apple II is `PR#n`, which points `CSW` at the
card's firmware and sends every subsequent `COUT` through it. That is why
printing on this machine has always disturbed the display: the card's firmware
is a *character output hook*, it shares `CSW` with the screen, and many cards
reset the 80-column firmware on the way past.

None of that applies here. `TEXTDRV` writes screen memory itself, keeps
80STORE off for the life of the system, and **never calls `COUT` or touches
`CSW` at all** after `INIT80`. So the printer can be driven directly, the
display is not involved, and there is nothing to save and restore.

That is worth stating in the book plainly, because it is a dividend from a
decision made for a completely different reason — page 2 — three months
earlier.

## 2. Which slot

```cobol
       SPECIAL-NAMES.
           PRINTER IS SLOT 1.
```

Compile-time, one byte. `PRSLOT` holds 1–7; `PRINIT` turns it into the card's
entry point. Slot 1 is the convention and the default, and a program that says
nothing gets it.

`SLOT 0` means **no printer**: `PRPUTC` returns immediately and a program that
prints to nowhere runs to completion instead of hanging. That is the honest
behaviour for a machine with no card in it, and it is what lets a report be
tested on a machine without a printer.

## 3. How a byte reaches the card

Two paths, chosen by `PRMODE`, because the two kinds of card are genuinely
different and only one of them can be driven with certainty.

### `PRMODE` = 0 — the firmware entry (default)

Almost every printer card, parallel or serial, carries the **Pascal 1.1
firmware protocol**. Its signature is four bytes in the card's ROM:

```
$Cn05 = $38    $Cn07 = $18    $Cn0B = $01    $Cn0C = $31
```

and when they are all present, `$Cn0F` holds the *offset* of the card's
character-output routine within its own page. So the write entry is
`$Cn00 + [$Cn0F]`, called with the character in `A`.

This is the card-independent path and it is the one to use. **It has not been
verified on the machine** — the signature test and the entry convention are
transcribed from the documented protocol, and the register setup on entry is
the part most likely to need adjusting for a particular card. `PRTEST` is the
harness for exactly that.

If the signature is absent, `PRINIT` falls back to `$Cn00`, the old
`CSW`-style entry. That will work on most cards and is the one case where a
card's firmware may write to the screen — so `PRINIT` reports which path it
took and the fallback is worth knowing about rather than discovering.

### `PRMODE` = 1 — a Super Serial Card, driven directly

A serial card in slot *n* is a 6551 ACIA at fixed addresses:

```
$C088+n0   data
$C089+n0   status   bit 4 = transmit register empty
$C08A+n0   command
$C08B+n0   control
```

Poll the status bit and write the data register. No firmware, no `CSW`, no
possibility of touching the screen. **This is the path we can be sure about**,
and it is the one to fall back to if the firmware path misbehaves — at the cost
of only working for serial cards.

## 4. Control codes, and how a program says them

A printer's modes are byte sequences: `Ctrl-O` for condensed, `ESC "W" "1"` for
double-wide, and every make different. Rather than build a table of printers
into the runtime, the *program* declares what its printer wants:

```cobol
       SPECIAL-NAMES.
           PRINTER    IS SLOT 1.
           CONDENSED  IS CONTROL "O".
           PICA       IS CONTROL "R".
           WIDE-ON    IS ESCAPE "W" "1".
           WIDE-OFF   IS ESCAPE "W" "0".
           EMPHASIZED IS ESCAPE "E".
```

- `CONTROL "x"` is one byte, the letter masked to `$1F` — `CONTROL "O"` is
  `$0F`.
- `ESCAPE "x" …` is `$1B` followed by the literals given, up to four.

Each declaration is a **mnemonic-name**, which is exactly what SPECIAL-NAMES is
for, and it is used the way any mnemonic-name is used:

```cobol
           DISPLAY CONDENSED UPON PRINTER.
           DISPLAY RPT-D05   UPON PRINTER.
           DISPLAY PICA      UPON PRINTER.
```

### Why that shape and not a new verb

Because it costs nothing. The compiler pools the declared bytes as an ordinary
literal and emits `DISPPL` with its offset — the same instruction
`DISPLAY "text" UPON PRINTER` already needs. **A mnemonic-name is a literal
with a name on it**, and the runtime never learns that `CONDENSED` exists.

It also means a program can be moved to a different printer by editing five
lines of SPECIAL-NAMES, which is the whole argument for declaring them instead
of writing `DISPLAY X"0F"` in the middle of the report logic.

## 5. Two opcodes

`$80–$86` are spoken for; `$87–$8F` are free at the top of the screen block.

| Op | Mnem | Operands | For |
|---|---|---|---|
| `$88` | DISPP | src word | `DISPLAY item UPON PRINTER` |
| `$89` | DISPPL | literal-offset word | `DISPLAY "…" UPON PRINTER`, and every mnemonic |

Two rather than a device byte on `$80`/`$81`, because changing an existing
opcode's encoding breaks every object already compiled against it. The table is
append-only for the same reason the jump table is.

`$87` stays reserved for `ACCEPT … FROM KEY` — see `KEYS.md`.

## 6. What `PRINTER.S` provides

Slots **79–82**, appended.

| Slot | Name | |
|---|---|---|
| 79 | `PRINIT` | `PRSLOT` → the entry point. C=1 if there is no card |
| 80 | `PRPUTC` | one byte, high bit set on the way out |
| 81 | `PRPUTS` | `STRPTR` → a length-prefixed string |
| 82 | `PRCR` | a carriage return, and the line counter |

**The high bit goes on.** Apple II printer interfaces expect ASCII with bit 7
set, the same as the screen — a byte sent with it clear prints as nothing on
most cards, which is a silent failure and worth one `ORA #$80`.

`PRCR` sends `$0D` only. **No line feed**, because every Apple II printer
interface has a setting for whether it adds one and adding a second is the
classic double-spaced-report bug. If a report comes out double spaced, the card
is adding line feeds and the card is where to turn them off.

## 7. What this unblocks

`REPORT`'s generated code is `MOVE`, `ADD` and `DISPLAY … UPON PRINTER`, and
`PRINTER.S` is the last unbuilt thing in it except `DATIME.S`. With both, **a
generated report can be printed before the compiler exists** — the four
paragraphs are ordinary COBOL and the runtime behind every verb in them is
built.

## 8. Not done

- **Nothing is verified on hardware.** The Pascal 1.1 signature test, the entry
  convention and the register setup all need a real card. `PRTEST` is written
  for that and does nothing else.
- **No `WRITE … AFTER ADVANCING`.** That is the file-oriented way to print and
  it needs `RECMAN`; `DISPLAY … UPON PRINTER` needs nothing.
- **No page eject.** `$0C` through `PRPUTC` does it, and REPORT counts lines
  itself, so there is nothing for the runtime to decide.
