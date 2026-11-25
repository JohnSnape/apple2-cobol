# The keys

Every key the system acts on is in §9, tool by tool, as the code has it.
§1–8 are how Open-Apple and Solid-Apple reach a COBOL program, and this file
is the authority on the `CRT STATUS` contract and on `KEYMOD` / `KEYCMD` /
`KEYTERM` / `KEYCHAR`.

---

## 1. The hardware fact everything else follows from

`$C061` and `$C062` are **paddle button inputs**, read with bit 7. On a IIe
they are wired to the two Apple keys.

They are **not latched with the keystroke**. The key goes into the keyboard
register and waits there patiently until something strobes `$C010`; the Apple
keys report only what is being held *at the instant you read them*. Read them
three `JSR`s after taking the key and a quick typist has already let go.

So the reading is taken **inside the key wait, off the `BMI`, before anything
else at all** — before the mask, before the strobe, before the cursor is put
back. That is the whole reason `READMOD` is a library vector rather than four
lines copied into each caller.

There were two copies before this: `GETCHORD` in `PROMPT.S` and `EKGOT` in
`EDITCUR.S`, invented independently, identical, and both agreeing that bit 7
means Open-Apple and bit 6 means Solid-Apple. When two people separately write
the same fourteen instructions, the instructions belong in the library.
`EDITCUR`'s copy took its reading *after* `JSR HIDECUR` — a small window, and
one that would have grown the first time anybody put work on that path.

## 2. Four bytes

| | |
|---|---|
| `KEYMOD` `$0CA9` | bit7 Open-Apple, bit6 Solid-Apple, as they were at the keystroke |
| `KEYCMD` `$0CAA` | 0 = the Apple keys are ignored; 1 = a modified key ends an ACCEPT |
| `KEYTERM` `$0CAB` | how the last accept ended, as an ASCII digit |
| `KEYCHAR` `$0CAC` | the command key itself, upper-cased, or a space |

`KEYTERM`: `'0'` RETURN · `'1'` ESC · `'2'` TAB · `'3'` Open-Apple ·
`'4'` Solid-Apple · `'5'` both.

**`KEYTERM` and `KEYCHAR` are adjacent and they are the COBOL `CRT STATUS`
item** — two characters, the way `FILE STATUS` is two characters. ASCII rather
than binary so that a program can `DISPLAY` it without converting anything and
an `88` level can test it against a literal.

`OA-P` is `"3P"`. `ESC` is `"1 "`.

## 3. Opt-in, and why that is the important part

`KEYCMD` is zero unless a program asks otherwise. With it zero, `KEYCHRD`
returns "not a command" every time, `OA-P` is simply `P`, and **every accept
routine in the library behaves exactly as it did before any of this existed**.
That is the promise made to `FORMAT`, `EDIT`, `REPORT` and every program
already written, and it is worth more than the feature.

The compiler sets `KEYCMD` in the `ENTER` prologue when the program declared a
`CRT STATUS` item. Declaring one is how a program says it is prepared to
handle a command key; a program that never mentions it can never be surprised
by one.

## 4. Reading the modifier as a pair

`KEYMOD` carries two bits and there are **three** meaningful states, not two.
`TDKCHD` gets this right — `$80` is `'3'`, `$40` is `'4'`, `$C0` is `'5'` — but
the three places in the tools that dispatch on `CHMOD` did not:

```
        LDA CHMOD          ; EDITDSP, RPKEY and LINEIN all began
        BMI  <open-apple>  ; like this
        AND #$40
        BNE  <solid-apple>
```

**Testing bit 7 first makes `$C0` indistinguishable from `$80`.** Hold both
keys and the Solid-Apple branch is unreachable — the chord runs whatever
Open-Apple command the letter happens to name, and in EDIT `OA-N` is *New
program*, which throws the buffer away. Solid-Apple on its own always worked;
it is the pair that was lost.

Fixed 2026-08-15 in `EDITDSP.S`, `RPTENT.S` and `PROMPT.S` by reading the
modifier as a pair before either bit is looked at alone:

```
        LDA CHMOD
        AND #$C0
        CMP #$C0
        BNE  <the ordinary path>
```

None of the three tools defines an OA+SA chord, so the honest answer is to do
**nothing** — the same rule `VBAD` follows for an opcode it does not know. In
`PROMPT` it waits for another key instead of returning, because abandoning a
half-typed answer is not what anybody meant by holding two keys down.

The general lesson is worth the paragraph: **a modifier is not a flag, it is a
set.** Any code that tests one bit of it and branches away has already decided
the other bit does not exist.

## 5. What each accept routine now does

| Routine | On a chord |
|---|---|
| `CONGETLN` | ends the line, `C=1`, nothing accepted |
| `DSACC` | ends the field, `C=1` |
| `SCRINP`'s `EDITFLD` | sets `TERM` = 2, which stops the form |

A chord ends input **the way ESC does** — carry set, nothing accepted. That is
deliberate: a caller written before any of this existed tests only the carry,
and reading an unhandled command as a cancel is the safe direction to be wrong
in. A caller that cares looks at `KEYTERM`.

`DSACC` also now distinguishes TAB from RETURN in `KEYTERM`, which it always
could have and never did. Both still leave the carry clear.

## 6. What a program sees

```cobol
       SPECIAL-NAMES.
           CRT STATUS IS KEY-STATUS.

       01  KEY-STATUS.
           05  KEY-HOW      PIC X.
               88  ENTERED    VALUE "0".
               88  CANCELLED  VALUE "1".
               88  COMMANDED  VALUE "3".
           05  KEY-CHAR     PIC X.

           DISPLAY "OA-P PRINT   OA-Q QUIT" AT LINE 23 COLUMN 1.
           ACCEPT CUST-NAME AT LINE 5 COLUMN 20.
           EVALUATE KEY-STATUS
               WHEN "3P"  PERFORM PRINT-THE-LIST
               WHEN "3Q"  PERFORM FINISH
               WHEN "1 "  PERFORM CANCEL
           END-EVALUATE.
```

**Acting on a command key needs nothing new.** `EVALUATE` is already in the
subset and already lowers to compares and branches. The runtime's whole job is
to deliver the two bytes; the dispatch is ordinary COBOL.

The runtime has **no opinion about what `OA-D` means**. There is no command
table and no reserved chord. Each tool defines its own — `EDIT` has `OA-G`,
`FORMAT` has `OA-A` — and a user program should too.

## 7. What is built

**Layers 1 and 2 are built and on the disk.**
- `TDKMOD`, `TDKCHD` and `TDKDNE` are in `TEXTDRV.S`, at library slots
  **76–78**.
- `CONGETLN`, `DSACC` and `EDITFLD` all set the status.
- The two duplicate copies in `PROMPT.S` and `EDITCUR.S` are gone,
  replaced by calls.
- It costs 149 bytes of library.
- `KEYTEST.S` is the harness.

**Layer 3, the language, is still not built.**
- `CRT STATUS IS` in `SPECIAL-NAMES` is refused with error 50 (`CMPENV.S`).
  It would cost a pointer at compile time, exactly what `FILE STATUS IS`
  costs, plus one store in the `ENTER` prologue to set `KEYCMD`. So no
  program can yet turn `KEYCMD` on.
- `VACC` must copy `KEYTERM`/`KEYCHAR` into that item after every ACCEPT,
  which is a few instructions in `VMSCRN.S`.
- `ON EXCEPTION` / `END-ACCEPT` on ACCEPT is error 12 at the `ON`. It is
  pure codegen.

**`ACCEPT ... FROM KEY` is built** (2026-11-11, `VAFK`). It takes one
keystroke and does not show it. The Apple keys are not reported, because it
reads the key and nothing else.

## 8. Two things the machine keeps for itself

**OA-Ctrl-Reset is a hardware reboot.** No program can intercept it, and none
should try.

**OA and SA held together at power-on runs the self-test.** Neither belongs in
a manual's command list except as a warning.

A third, smaller: `$C061`/`$C062` are paddle buttons, so a joystick with its
buttons down reads as Apple keys held. Nothing to be done about it, and worth
one sentence rather than a surprise.

---

## 9. Every key, as the code has it

This section was checked against the source on 2026-11-24. It lists every key
the system acts on, not only the Apple keys. Wherever it and this file's
earlier sections disagree, the code and this section are right.

**ESC is *leave* or *cancel* everywhere, and it is not an Apple key.**

### 9.1 Typing one line

All of the following read a line through one of five routines:
- the Utilities questions;
- EDIT's own prompts (go to line, file names, placing a piece);
- a program's `ACCEPT` and `ACCEPT ... AT`;
- screen forms;
- the row-23 questions in FORMAT, QUERY and REPORT.

The five routines are `TDGETLN` (`GETLN80`), `CONGETLN`, `DSACC`, SCRINP's
`EDITFLD` and PROMPT's `LINEIN`.

| Key | What it does |
|---|---|
| **RETURN** | Takes the answer |
| **ESC** | Cancels: nothing is taken (carry set, `KEYTERM` `'1'`) |
| **←** | Erases the last character |
| **DELETE** | Erases the last character, the same as ← (DECISIONS 8.14) |
| **TAB** | In `ACCEPT ... AT` and screen forms, ends the field like RETURN (`KEYTERM` `'2'`); in a form it goes to the next field. Elsewhere it is ignored |
| **→ ↑ ↓**, other Ctrl keys | Ignored |

- **DELETE is new.** Until 2026-11-24 all five routines threw it away, while
  EDIT took it as erase-left.
  - The change is in the source and the build. It is **not yet on
    `COBOL32.po`**: it goes on with 8.11, whose part of COBOL.LIB is not
    tested yet. Until then the disk's copy still ignores DELETE in these
    routines.
  - The COBOL.OS build has the same change (its DECISIONS 6.12).
- **ESC after a typed file name** in Utilities, and in RUN's question,
  used to act as RETURN. So ESC at "DELETE a file" deleted the file.
  - It now cancels (DECISIONS 8.17, 2026-11-25), in the source and in
    both builds.
  - It is not yet on `COBOL32.po`, so the disk's copy still has the bug.
    There, clear the name with ←, then press ESC.
- **A plain `ACCEPT` folds letters to capitals** unless the program says
  `ANYCASE`.
- **A screen form's yes/no field** takes Y or N only, in either case.
- **In FORMAT, QUERY and REPORT's questions** (`LINEIN`) there are two more
  keys:
  - **SA-D** erases the whole answer and asks again;
  - **SA-C** shows the preview and comes back to the half-typed answer.
- **An Open-Apple letter in one of those questions:**
  - If it is on the overlay's `CMDLIST`, it ends the question as a command,
    and the overlay decides what that means (§9.3).
  - If it is not, it is ignored and the half-typed answer stays.
- **Holding both Apple keys** in `LINEIN` does nothing and waits for another
  key (§4).

### 9.2 EDIT, and VIEW (menu 7)

| Key | What it does |
|---|---|
| **← → ↑ ↓** | Move the cursor |
| **DELETE** | Erases the character to the left and closes the line up |
| **RETURN** | Opens a blank line below and moves to its start. It does not split the line |
| **TAB** | To the next column that is a multiple of 4 |
| **ESC** | Ends a selection, if one is on. Otherwise leaves EDIT: the program stays in memory for COMPILE, and it is not saved to disk |
| **Ctrl-C / Ctrl-X / Ctrl-P** | Copy / Cut / Paste lines, through `CLIPBOARD.CLP` |
| **OA-N / OA-O / OA-S** | New / Open / Save |
| **OA-G** | Go to a line |
| **OA-P** | Print the program. ESC stops it between lines |
| **OA-↑ ↓** | Select lines. The first press drops the anchor |
| **SA-↑ ↓** | Page up / down |
| **SA-← →** | Start / end of the line |
| **SA-I** | Insert a blank line above, and stay on it |
| **SA-D** | Delete this line |
| **SA-K** | Insert / overtype. The bar shows which (SA-M until 2026-11-08) |
| **SA-P** | Place a FORMAT `.SNP` or REPORT piece into the program |

- **Typing** inserts, or overtypes in overtype mode.
- **Any other Ctrl key** is ignored.
- **Any key that does not act on a selection ends it.** Copy, Cut and
  OA-↑ ↓ act on it. ESC ends it and does nothing more.
- **VIEW** shows a data file in EDIT, read-only.
  - **It lets through:** the arrows and TAB, SA-↑ ↓ ← →, OA-G, OA-P (it
    prints the view), the selection, Copy and ESC.
  - **It refuses:** typing, RETURN, DELETE, Cut, Paste, the other
    Solid-Apple commands, and OA-N, OA-O and OA-S.

### 9.3 FORMAT

FORMAT is driven by its row-23 questions, so §9.1's `LINEIN` keys apply
throughout.
- **A field starts at "Row?".**
  - An empty RETURN there asks again.
  - ESC there leaves FORMAT.
- **The Open-Apple commands run only at "Row?".**
  - At a later question (column, label, name, width, type), a command
    drops the half-made field and goes back to "Row?" without running.
  - So does ESC.
- **For a menu** (OA-M), the questions are Column? and Text?.

| Key | What it does |
|---|---|
| **ESC** | At "Row?", leaves FORMAT. At a later question, drops the field and goes back to "Row?" |
| **OA-S / OA-N / OA-O** | Save / New form / Open |
| **OA-D** | Delete a field |
| **OA-E** | Export the `.SNP` |
| **OA-M** | New menu `.MNU` (2026-11-11) |
| **SA-C** | Preview the generated code |
| **SA-D** | Erase the answer and ask again |

**The field-type question** takes **A**, **X**, **N** or **B**. SA-D asks it
again, and ESC cancels it.

**The preview** (`SCRPRV.S`):

| Key | What it does |
|---|---|
| **↑ ↓** | Scroll a line |
| **OA-↑ ↓** | Page |
| **ESC** or **SA-C** | Back to the form |

### 9.4 QUERY

| Key | What it does |
|---|---|
| **ESC** | Leave |
| **↑ ↓** | Move the selection through the conditions, then the sort keys |
| **OA-A / OA-D** | Add / delete a condition |
| **OA-K / OA-R** | Add / remove a sort key |
| **OA-I** | Open a dictionary |
| **OA-N / OA-O / OA-S** | New / Open / Save |
| **SA-C** | Nothing. A query has nothing to preview |

Holding both Apple keys does nothing.

### 9.5 REPORT

| Key | What it does |
|---|---|
| **ESC** | Leave |
| **↑ ↓** | Scroll a page line |
| **OA-↑ ↓** | Page |
| **OA-G** | Go to a page line |
| **OA-A / OA-D** | Add / delete an entry |
| **OA-I** | Dictionary |
| **OA-B** | Bands |
| **OA-N / OA-O / OA-S** | New / Open / Save |
| **OA-E** | Export |
| **SA-C** | Preview. Wired, but an RTS until slice 7 |

- **The kind question** takes **L** literal, **R** rule, **P** page number
  or **D** date, in either case. ESC cancels it, and any other key is
  ignored.
- **The rule character** is any printable key. ESC cancels it.
- **The band question** is answered with **H**eading, **D**etail or
  **F**ooting, in either case. ESC cancels it.
- **During an export**, each pause takes any key to go on; ESC stops it.
- **Holding both Apple keys** does nothing.

### 9.6 Menus, waits and a running program

- **The main menu:** **1–9**. ESC does nothing there.
  - **R** (either case) runs a program, the same as **6**. It isn't on the
    menu; it is kept because it was R for long enough that fingers know it.
  - In this build **9** is *Exit to ProDOS*.
  - In the COBOL.OS build it is *Quit*, and goes to COBOL.OS's QUIT screen
    (§9.7).
- **Utilities:** **1–8**, and **ESC** back to the main menu.
  - The COBOL.OS build adds **9**, *Make a disk BOOTABLE*.
- **Every "(key)" message,** "Press any key …" in a catalog, and "Press a
  key to go on" when a program's output fills the screen: any key.
- **A program's end** ("STOP RUN. (Press a Key)") and **a run-time error:**
  any key.
- **`ACCEPT ... FROM KEY`:** one key, not shown, upper-cased under
  `UPPERCASE ONLY`.
- **`ACCEPT ... FROM MENU`:** only the keys the menu's "x)" lines name, a
  letter in either case. Any other key rings the bell. A menu with no such
  line takes any key.
- **A running program** cannot be stopped from the keyboard. No key is
  watched while it runs.

### 9.7 The system's own keys

- **COBOL.OS's QUIT screen** ("Change the disk and press RETURN to restart
  the system"): **RETURN only**. A key typed before the line appears is
  thrown away.
- **Ctrl-Reset:**
  - **Under COBOL.OS:** back to the main menu. Open files are dropped, not
    written back (COBOL.OS DECISIONS 6.6).
  - **This build** sets no reset vector. Ctrl-Reset does whatever ProDOS left
    in `$3F2`, and nothing about it is COBOL's.
- **OA-Ctrl-Reset:** a hardware reboot. Nothing can intercept it.
- **Both Apple keys held at power-on:** the IIe self-test.
- **A joystick with its buttons down** reads as Apple keys held (§8).

### 9.8 Letter case

Every command and one-letter answer is folded to a capital with `AND #$DF`
before it is tested. That upper-cases a letter without touching the
arrows, whose codes have no bit 5. So OA-s and OA-S are the same command,
Caps Lock up or down, and nobody has to test for both.

**Until 2026-11-24, five places did not fold** (DECISIONS 8.15). With Caps
Lock up, these did nothing:
- **`LINEIN`'s `CMDLIST` walk:**
  - all of FORMAT's Open-Apple commands;
  - any command typed in the middle of a QUERY or REPORT question.
- **SA-D and SA-C** in those questions.
- **FORMAT's field-type answer:** A, X, N and B.
- **REPORT's OA-G, OA-A and OA-D.** They were tested before the fold; its
  other letters were tested after it.

They all fold now:
- `LINEIN` folds the letter into `CMDCH` before the walk, so FORMAT reads
  the capital.
- `RPTENT` folds once at the top of its Open-Apple commands.
- FORMAT's type question folds before ESC, which `$1B` survives.

Two places never needed it: EDIT's `ASK` already folds, and the main
menu's hidden **R** tests both cases.

### 9.9 The rule the commands should follow

**Open-Apple acts on the document. Solid-Apple acts on the thing under the
cursor.**

New, Open, Save, Export, Go-to and paging are all *the whole file or where you
are in it*, so they are Open-Apple. Insert line, delete line, overtype, place
and preview are all *this line, this field, this entry*, so they are
Solid-Apple.

That rule describes EDIT exactly.
- **It does not describe FORMAT, REPORT and QUERY.** There `OA-D` deletes the
  field, entry or condition under the cursor. By the rule that should be
  `SA-D`, the key EDIT already uses to delete the line under the cursor: one
  letter, one meaning, one modifier.
- **QUERY uses OA-D to match the other two.** When the question is settled,
  all three change together.
- **The cost is uneven.** `REPORT` has never been run, so changing it is free.
  `FORMAT` is a **V** module and its `CMDLIST` is one of the letters
  `PROMPT`'s `LINEIN` walks, so changing it costs a re-run.

Flagged rather than done.

### 9.10 Held back on purpose

These are reserved across the whole system, so that a later overlay cannot
quietly mean something different by them:

| | |
|---|---|
| **OA-P** | Print. EDIT has it; the others may not use it for anything else |
| **OA-Q** | Quit to the menu |
| **OA-?** | Help |
| **OA-1**…**9** | Go to a numbered thing |

`SA-C` is preview in FORMAT and REPORT, and should stay preview anywhere it
appears.
