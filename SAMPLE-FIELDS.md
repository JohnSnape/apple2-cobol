# Sample programs: data files and record fields

A reference for rewriting the sample programs with proper data-entry screens and menus. It lists every data file the samples use, the record layout of each, what the programs ask the operator for today, and the menus they show.

Compiled 2026-11-12 from the source files. Nothing here has been changed in the programs themselves.

## Storage rule used for the byte counts

- Every numeric item (any PICTURE with 9s, signed or unsigned, `COMP`, `COMP-3` or display) is one 8-byte NUM8 cell. The scale (digits after `V`) lives in the compiler's data descriptor, not in the record. `COMP-3` is accepted and means NUM8 (`KEYWORDS.md`, `DICTIONARY.md` section 3).
- `X(n)` and `A(n)` are n bytes, left-justified and space-filled.
- An edited PICTURE is its printed width.
- A relative `.DAT` file carries its record length in the ProDOS aux type (`FILETYPES.md`). The record length is the sum of the FD fields below.

## Summary: all files

| Program | SELECT name | ASSIGN TO | Organization / access | Record | Fields | Record length |
|---|---|---|---|---|---|---|
| MEDIA | `MEDIA-FILE` | `"MEDIA.DAT"` | RELATIVE / DYNAMIC | `MEDIA-REC` | 5 | 72 bytes |
| LEADS | `LEAD-FILE` | `"LEADS.DAT"` | RELATIVE / DYNAMIC | `LEAD-REC` | 5 | 71 bytes |
| FINANCE | `REG-FILE` | `"REGISTER.DAT"` | RELATIVE / DYNAMIC | `REG-REC` | 5 | 51 bytes |
| QFILE / QSORT (test fixture, not a sample) | `CUST-FILE` | `"CUST.DAT"` | RELATIVE / DYNAMIC | `CUST-REC` | 2 | 28 bytes |

`SKEL.COB` (`PROGRAM-ID. SKELETON`) is also in `src\` but it has no files: it only displays `HELLO, WORLD`.

## Source copies

| Program | Canonical source | Other copy | Difference |
|---|---|---|---|
| MEDIA | `src\MEDIA.COB` (146 lines) | `tools\emu\progs\MEDIA.cob` | Line endings only: `src\` uses CR (Apple), `progs\` uses LF. Text identical. |
| LEADS | `src\LEADS.COB` (195 lines) | `tools\emu\progs\LEADS.cob` | Line endings only. |
| FINANCE | `src\FINANCE.COB` (202 lines) | `tools\emu\progs\FINANCE.cob` | Line endings only. |
| SKEL | `src\SKEL.COB` | `tools\emu\progs\SKEL.cob` | Line endings only. |

`QUICKREF.md` shows a LEADS-style `SELECT` with different names (`RELATIVE KEY IS LEAD-NUMBER`, `FILE STATUS IS LEAD-STATUS`, a field `LEAD-BALANCE PIC S9(6)V99 COMP-3`). Those are illustrations in the reference card, not the sample program. The names in this document are the ones in `src\LEADS.COB`.

No `.DCT`, `.SNP`, `.MNU` or `.QRY` file exists for MEDIA, LEADS or FINANCE. The only dictionary and queries built so far describe the CUST test file (last section).

## Shape shared by all three samples

Each sample is one relative file behind a numbered menu. The paragraphs are the same in all three:

- `OPEN-FILE`: `OPEN I-O`; if the status is not `"00"`, `OPEN OUTPUT`, `CLOSE`, `OPEN I-O` (creates the file on first run).
- `COUNT-RECS`: `START ... KEY NOT LESS THAN` key 1, then `READ NEXT` to the end, keeping the highest relative key in `WS-LAST`. A new record is written at `WS-LAST + 1`.
- `SHOW-MENU` / `GET-CHOICE`: menu lines by `DISPLAY`, then `DISPLAY "CHOICE? "` and `ACCEPT WS-CHOICE` (one character). `EVALUATE WS-CHOICE` dispatches; an unlisted key just redraws the menu.
- Adding a record: `MOVE SPACE` to the record, `ACCEPT` straight into each FD field in turn (no working-storage buffer, no validation), then `WRITE ... INVALID KEY DISPLAY "COULD NOT WRITE"`.
- `SHOW-REC`: two `DISPLAY` lines per record, the relative key edited through `WS-SHOWN PIC ZZZ9`.
- No sample uses `DELETE`, `AT LINE ... COLUMN`, `DISPLAY ERASE`, `ACCEPT ... FROM MENU` or a FORMAT copybook.

Working-storage items common to all three:

| Item | PICTURE | Bytes | Use |
|---|---|---|---|
| (file)`-KEY` | `9(4) COMP` | 8 | The RELATIVE KEY. Also ACCEPTed directly for "find by number" (MEDIA, LEADS) and "mark sold" (LEADS). |
| `FILE-STAT` | `XX` | 2 | FILE STATUS. 88 `STAT-OK` VALUE `"00"`. |
| `WS-CHOICE` | `X` | 1 | Menu choice, ACCEPTed in `GET-CHOICE`. |
| `WS-DONE` | `X` VALUE `"N"` | 1 | 88 `ALL-DONE` VALUE `"Y"`; set by choice 9. |
| `WS-EOF` | `X` VALUE `"N"` | 1 | 88 `END-OF-FILE` VALUE `"Y"`. |
| `WS-LAST` | `9(4) COMP` VALUE 0 | 8 | Highest relative key in use. |
| `WS-SHOWN` | `ZZZ9` | 4 | Record number for display. |

---

## MEDIA

- **Source:** `P:\COBOL\src\MEDIA.COB`, `PROGRAM-ID. MEDIA.`
- **Purpose (from its comments):** a minimal media catalogue of books, records and films; one relative file, one record per item; deliberately bare, with fields and validation left to the reader.

### SELECT

| Clause | Value |
|---|---|
| File name | `MEDIA-FILE` |
| ASSIGN TO | `"MEDIA.DAT"` |
| ORGANIZATION | RELATIVE |
| ACCESS MODE | DYNAMIC |
| RELATIVE KEY | `MEDIA-KEY` (working storage, `PIC 9(4) COMP`) |
| FILE STATUS | `FILE-STAT` (working storage, `PIC XX`) |

### FD MEDIA-FILE, record MEDIA-REC (72 bytes)

| Level | Field | PICTURE | Offset | Bytes | Holds |
|---|---|---|---|---|---|
| 01 | `MEDIA-REC` | (group) | 0 | 72 | One catalogue item. |
| 05 | `MR-TITLE` | `X(30)` | 0 | 30 | Title. Prompt `TITLE?`. |
| 05 | `MR-CREATOR` | `X(20)` | 30 | 20 | Author, artist or director. Prompt `CREATOR?`. |
| 05 | `MR-KIND` | `X(6)` | 50 | 6 | Kind of item (free text; the comments name books, records, films). Prompt `KIND?`. No 88-levels, no check. |
| 05 | `MR-YEAR` | `9(4)` | 56 | 8 | Year. Prompt `YEAR?`. NUM8 cell. |
| 05 | `MR-SHELF` | `X(8)` | 64 | 8 | Shelf or location code. Prompt `SHELF?`. Entered and stored but never displayed by `SHOW-REC`. |

### Data entry today (paragraph ADD-ITEM, choice 1)

| Order | Prompt displayed | ACCEPT into |
|---|---|---|
| 1 | `TITLE?   ` | `MR-TITLE` |
| 2 | `CREATOR? ` | `MR-CREATOR` |
| 3 | `KIND?    ` | `MR-KIND` |
| 4 | `YEAR?    ` | `MR-YEAR` |
| 5 | `SHELF?   ` | `MR-SHELF` |

The record key is not entered: it is `WS-LAST + 1`. `FIND-ONE` (choice 3) shows `ITEM NUMBER? ` and ACCEPTs `MEDIA-KEY`, then `READ`; a missing record shows `NO SUCH ITEM`.

Display (`SHOW-REC`): line 1 `WS-SHOWN MR-TITLE`; line 2 five spaces, `MR-CREATOR MR-KIND MR-YEAR`.

### Menu (SHOW-MENU, GET-CHOICE)

```
MEDIA CATALOGUE

1) ADD AN ITEM          -> ADD-ITEM
2) LIST EVERYTHING      -> LIST-ALL
3) FIND BY NUMBER       -> FIND-ONE
9) QUIT                 -> MOVE "Y" TO WS-DONE

CHOICE?                 ACCEPT WS-CHOICE (PIC X)
```

### Working storage specific to MEDIA

None beyond the common items (`MEDIA-KEY`, `FILE-STAT`, `WS-CHOICE`, `WS-DONE`, `WS-EOF`, `WS-LAST`, `WS-SHOWN`).

---

## LEADS

- **Source:** `P:\COBOL\src\LEADS.COB`, `PROGRAM-ID. LEADS.`
- **Purpose (from its comments):** a phone book that knows about sales leads; the MEDIA shape with a status code (88-levels) and a money value per contact.

### SELECT

| Clause | Value |
|---|---|
| File name | `LEAD-FILE` |
| ASSIGN TO | `"LEADS.DAT"` |
| ORGANIZATION | RELATIVE |
| ACCESS MODE | DYNAMIC |
| RELATIVE KEY | `LEAD-KEY` (working storage, `PIC 9(4) COMP`) |
| FILE STATUS | `FILE-STAT` (working storage, `PIC XX`) |

### FD LEAD-FILE, record LEAD-REC (71 bytes)

| Level | Field | PICTURE | Offset | Bytes | Holds |
|---|---|---|---|---|---|
| 01 | `LEAD-REC` | (group) | 0 | 71 | One contact. |
| 05 | `LR-NAME` | `X(24)` | 0 | 24 | Contact's name. Prompt `NAME?`. |
| 05 | `LR-COMPANY` | `X(24)` | 24 | 24 | Company. Prompt `COMPANY?`. |
| 05 | `LR-PHONE` | `X(14)` | 48 | 14 | Phone number, free text. Prompt `PHONE?`. |
| 05 | `LR-STATUS` | `X` | 62 | 1 | Lead status. Not entered: set to `"L"` on add, `"S"` by choice 4. |
| 88 | `LS-LEAD` | VALUE `"L"` | | | New lead. Shown as `LEAD` (also the `WHEN OTHER` word). |
| 88 | `LS-CALLED` | VALUE `"C"` | | | Contacted. Shown as `CONTACTED`. No menu choice sets it. |
| 88 | `LS-SOLD` | VALUE `"S"` | | | Sold. Shown as `SOLD`; excluded from the pipeline total. |
| 05 | `LR-VALUE` | `S9(5)V99 COMP-3` | 63 | 8 | Value of the lead in dollars and cents, up to 99,999.99. Prompt `VALUE?`. NUM8 cell, scale 2. |

### Data entry today (paragraph ADD-LEAD, choice 1)

| Order | Prompt displayed | ACCEPT into |
|---|---|---|
| 1 | `NAME?    ` | `LR-NAME` |
| 2 | `COMPANY? ` | `LR-COMPANY` |
| 3 | `PHONE?   ` | `LR-PHONE` |
| 4 | `VALUE?   ` | `LR-VALUE` |
| (set) | none | `MOVE "L" TO LR-STATUS` |

`LR-VALUE` is zeroed before the ACCEPTs. The key is `WS-LAST + 1`.

Other ACCEPTs: `FIND-ONE` (choice 3) and `MARK-SOLD` (choice 4) both show `CONTACT NUMBER? ` and ACCEPT `LEAD-KEY`. `MARK-SOLD` reads the record, moves `"S"` to `LR-STATUS` and `REWRITE`s it (`COULD NOT UPDATE` on failure). A missing record shows `NO SUCH CONTACT`.

Display (`SHOW-REC`): line 1 `WS-SHOWN LR-NAME LR-PHONE`; line 2 five spaces, `LR-COMPANY WS-WORD WS-MONEY` (status word and value).

### Menu (SHOW-MENU, GET-CHOICE)

```
CONTACTS AND LEADS

1) ADD A CONTACT        -> ADD-LEAD
2) LIST EVERYONE        -> LIST-ALL
3) FIND BY NUMBER       -> FIND-ONE
4) MARK ONE SOLD        -> MARK-SOLD
5) OPEN PIPELINE        -> SHOW-PIPELINE
9) QUIT                 -> MOVE "Y" TO WS-DONE

CHOICE?                 ACCEPT WS-CHOICE (PIC X)
```

`SHOW-PIPELINE` adds `LR-VALUE` of every record that is not `LS-SOLD` into `WS-PIPELINE` and shows `OPEN PIPELINE: ` and the total through `WS-MONEY`.

### Working storage specific to LEADS

| Item | PICTURE | Bytes | Use |
|---|---|---|---|
| `WS-PIPELINE` | `S9(7)V99 COMP-3` VALUE 0 | 8 | Total of unsold lead values. |
| `WS-MONEY` | `$$$,$$9.99` | 10 | Edited value for display. |
| `WS-WORD` | `X(9)` | 9 | Status word: `SOLD`, `CONTACTED` or `LEAD`. |

---

## FINANCE

- **Source:** `P:\COBOL\src\FINANCE.COB`, `PROGRAM-ID. FINANCE.`
- **Purpose (from its comments):** a personal cheque register; the same shape again, written to exercise money (every amount `COMP-3`, every shown amount through an edited PICTURE).

### SELECT

| Clause | Value |
|---|---|
| File name | `REG-FILE` |
| ASSIGN TO | `"REGISTER.DAT"` |
| ORGANIZATION | RELATIVE |
| ACCESS MODE | DYNAMIC |
| RELATIVE KEY | `REG-KEY` (working storage, `PIC 9(4) COMP`) |
| FILE STATUS | `FILE-STAT` (working storage, `PIC XX`) |

### FD REG-FILE, record REG-REC (51 bytes)

| Level | Field | PICTURE | Offset | Bytes | Holds |
|---|---|---|---|---|---|
| 01 | `REG-REC` | (group) | 0 | 51 | One register entry. |
| 05 | `RR-DATE` | `9(6)` | 0 | 8 | Date as MMDDYY (prompt `DATE MMDDYY?`). NUM8 cell. Shown through `WS-DATE-OUT PIC 99/99/99`. Not checked. |
| 05 | `RR-PAYEE` | `X(24)` | 8 | 24 | Payee, or source of a deposit. Prompt `PAYEE?`. |
| 05 | `RR-CATEGORY` | `X(10)` | 32 | 10 | Category, free text (the test run uses `RENT`). Matched exactly by choice 4. Prompt `CATEGORY?`. |
| 05 | `RR-KIND` | `X` | 42 | 1 | Entry type. Prompt `D=DEPOSIT P=PAYMENT?`. Not checked. |
| 88 | `RK-DEPOSIT` | VALUE `"D"` | | | Deposit. Declared but never tested by the program. |
| 88 | `RK-PAYMENT` | VALUE `"P"` | | | Payment: subtracted from the balance. Any other value, including a typo, is added as if it were a deposit. |
| 05 | `RR-AMOUNT` | `S9(6)V99 COMP-3` | 43 | 8 | Amount in dollars and cents, up to 999,999.99, entered positive; `RR-KIND` decides the sign. Prompt `AMOUNT?`. NUM8 cell, scale 2. |

### Data entry today (paragraph ADD-ENTRY, choice 1)

| Order | Prompt displayed | ACCEPT into |
|---|---|---|
| 1 | `DATE MMDDYY? ` | `RR-DATE` |
| 2 | `PAYEE?       ` | `RR-PAYEE` |
| 3 | `CATEGORY?    ` | `RR-CATEGORY` |
| 4 | `D=DEPOSIT P=PAYMENT? ` | `RR-KIND` |
| 5 | `AMOUNT?      ` | `RR-AMOUNT` |

`RR-AMOUNT` is zeroed before the ACCEPTs. The key is `WS-LAST + 1`. There is no find-by-number, change or delete.

Other ACCEPT: `CATEGORY-TOTAL` (choice 4) shows `CATEGORY? ` and ACCEPTs `WS-WANTED PIC X(10)`, then adds `RR-AMOUNT` of every record whose `RR-CATEGORY = WS-WANTED`. It adds deposits and payments alike (no sign by `RR-KIND`) and shows `TOTAL FOR ` category `: ` amount.

Display (`SHOW-REC`, during choice 2 after `POST-ONE` updates the running balance): line 1 `WS-SHOWN WS-DATE-OUT RR-PAYEE`; line 2 five spaces, `RR-CATEGORY WS-MONEY WS-RUNNING` (amount and running balance).

### Menu (SHOW-MENU, GET-CHOICE)

```
CHEQUE REGISTER

1) ADD AN ENTRY         -> ADD-ENTRY
2) LIST THE REGISTER    -> LIST-ALL (with running balance)
3) CURRENT BALANCE      -> SHOW-BALANCE
4) TOTAL ONE CATEGORY   -> CATEGORY-TOTAL
9) QUIT                 -> MOVE "Y" TO WS-DONE

CHOICE?                 ACCEPT WS-CHOICE (PIC X)
```

`SHOW-BALANCE` runs `POST-ONE` over every record and shows `BALANCE: ` through `WS-RUNNING`.

### Working storage specific to FINANCE

| Item | PICTURE | Bytes | Use |
|---|---|---|---|
| `WS-BALANCE` | `S9(7)V99 COMP-3` VALUE 0 | 8 | Running balance (payments subtracted, everything else added). |
| `WS-CAT-TOTAL` | `S9(7)V99 COMP-3` VALUE 0 | 8 | Total for one category. |
| `WS-WANTED` | `X(10)` | 10 | Category typed for choice 4 (a lookup input, not stored). |
| `WS-DATE-OUT` | `99/99/99` | 8 | Date for display. |
| `WS-MONEY` | `$$$,$$9.99CR` | 12 | Edited amount or category total. |
| `WS-RUNNING` | `$$,$$$,$$9.99CR` | 15 | Edited running balance. |

---

## CUST (test fixture, not a sample program)

The customer file used to test FORMAT, QUERY, VIEW and the `QUERY` verb. It is not one of the sample programs, and no menu program maintains it: the test program `QFILE` writes five fixed records. It is listed here because it is the only record that already has a dictionary and queries, and because the capstone of the beginner book (`GETTING-STARTED\OUTLINE.md`, chapters 16-17) is a customer file.

- **Programs:** `tools\emu\progs\qfile.cob` (`PROGRAM-ID. QFILE`: writes CUST.DAT, deletes record 1, runs `BIGBAL`) and `tools\emu\progs\qsort.cob` (`PROGRAM-ID. QSORT`: lists CUST.DAT through `BALDESC`). Both declare the same file and record.
- **SELECT:** `CUST-FILE` ASSIGN TO `"CUST.DAT"`, RELATIVE, DYNAMIC, RELATIVE KEY `CUST-KEY` (`PIC 9(4) COMP`), FILE STATUS `FILE-STAT` (`PIC XX`). Both programs also have `QUERY STATUS IS WS-QSTAT` (`PIC 99`).

### FD CUST-FILE, record CUST-REC (28 bytes)

| Level | Field | PICTURE | Offset | Bytes | Holds | Dictionary field |
|---|---|---|---|---|---|---|
| 01 | `CUST-REC` | (group) | 0 | 28 | One customer. | |
| 05 | `CUST-NAME` | `X(20)` | 0 | 20 | Customer name. | field 0, label `NAME`, row 2 col 5, width 20, type A |
| 05 | `CUST-BAL` | `9(8)` | 20 | 8 | Balance, whole units (no decimals). NUM8 cell. | field 1, label `BALANCE`, row 4 col 5, width 8, type N |

### Related designer files (on the emulator disk only)

These are made by the test scripts on the AppleWin volume; no copy is kept in the project tree.

| File | Made by | Contents |
|---|---|---|
| `CUST.DCT` | `tools\emu\designers.ps1` (FORMAT); `resave.ps1` re-saves it as version 2 | The two fields above. FORMAT rows and columns count from 0. |
| `CUSTSCR.SNP` | `designers.ps1` (FORMAT ⌥-E) | `01 CUSTSCR-REC` with `CUST-NAME PIC A(20)` and `CUST-BAL PIC 9(8)`, plus `CUSTSCR-PAINT` (`DISPLAY "NAME" AT LINE 3 COLUMN 6`, `"BALANCE" AT LINE 5 COLUMN 6`) and `CUSTSCR-ACCEPT` (`CUST-NAME` at line 3 column 11, `CUST-BAL` at line 5 column 14). Text as printed in `MANUAL\CH08.md`. `A(20)` and `X(20)` store the same 20 bytes. |
| `BIGBAL.QRY` | `designers.ps1` (QUERY) | Condition field 1 (`CUST-BAL`) `>` 100; sort key field 0 (`CUST-NAME`) ascending. |
| `BALDESC.QRY` | `tools\emu\qsort.ps1` (QUERY) | No condition; sort key field 1 (`CUST-BAL`) descending. |
| `CUST.DAT` | `qfile.cob` | Records 1-5: ZED 150, AMY 50, EVE 1000, CAL 99, BOB 101; record 1 then deleted. |

---

## Notes for the rewrite

Constraints found in the current documentation that bear on moving these records into FORMAT screens and menus:

- **FORMAT data names are at most ten characters** (`MANUAL\CH08.md`). Every sample field fits except `RR-CATEGORY` (11 characters), which would need a shorter name such as `RR-CATEG` if the screen is built in FORMAT.
- **FORMAT has four field types:** A (letters and spaces), X (any characters), N (digits only, at most 14), B (Y/N flag, stored as a cell 1 or 0). A screen may hold up to fifteen fields; every sample has five.
- **FORMAT always writes 0 decimals for an N field** (`DICTIONARY.md` section 2; `HANDOFF.md`: "a field with nonzero decimals (FORMAT cannot make one yet)"). The exported copybook declares N as `PIC 9(n)`, unsigned. `LR-VALUE` (`S9(5)V99`) and `RR-AMOUNT` (`S9(6)V99`) therefore cannot yet come straight from a FORMAT export with their cents and sign; the generated `05` would need its PICTURE edited by hand, and a dictionary describing them would misstate their scale to QUERY and VIEW.
- **Single-character code fields** (`LR-STATUS`, `RR-KIND`, `MR-KIND`) map to FORMAT type A or X; FORMAT has no list-of-values check, so validation against the 88-levels stays in the program. Type B is a numeric 1/0 cell, not a one-byte `"Y"`/`"N"`.
- **Menus:** `ACCEPT x FROM MENU "NAME"` (added 2026-11-11) clears the screen, draws `NAME.MNU` made in FORMAT with ⌥-M, and waits for one of the menu's keys; the compiler reads the `.MNU` at compile time (`QUICKREF.md`, `tools\emu\progs\menu.cob`). Each sample's `SHOW-MENU` / `GET-CHOICE` pair is the part this replaces. A menu cannot use the same key twice, upper and lower case counting as the same key.
- **PROCS snippets** in `PROCS\` (`SCREEN.SNP`: `SC-YES-NO`, `SC-MENU-PICK`, `SC-GET-NUMBER`; `DATES.SNP`: `DT-CHECK` for a real date; `MONEY.SNP`; `TEXT.SNP`; `WORDS.SNP` for an amount in words) describe no records, but `DT-CHECK` and `SC-GET-NUMBER` cover the validation the samples lack (FINANCE's date and amount, MEDIA's year). `SCREEN.SNP` uses the scrolling console, not `AT LINE`.
- **Changing a record layout changes the file.** The record length is set when the file is created by `OPEN OUTPUT` and kept in the `.DAT` file's aux type (`QUICKREF.md`). An existing `MEDIA.DAT`, `LEADS.DAT` or `REGISTER.DAT` keeps the old length and the old field offsets, so data from the current samples will not line up with a changed record; it would have to be re-entered or converted. What the record manager does when the program's FD and the file's aux length disagree is not stated in the documentation read for this list.
- **At most two files open at once** (three ProDOS buffers, one kept by the catalog; `QUICKREF.md`). Splitting a sample into more than two files, such as a separate category or status table, would run into this.
