EMU - driving AppleWin from PowerShell to test the system on the machine
(written 2026-11-07; every bug found that night was found this way)

aw.ps1        start | shot <png> | keys <text> | raw <SendKeys> | dbg "cmd;cmd" | stop
              keys go through the clipboard + Shift+Insert, because plain key
              events never reach the emulated keyboard.  ~ is Return.
              Open-Apple is left Alt: raw "%s" is OA-S.
              RUN IT IN THE FOREGROUND - a backgrounded PowerShell's
              clipboard calls can hang with nothing typed.
deploy.ps1    -Src NAME,... (src/NAME.S into SRC:)  -Obj NAME,... (build/obj
              NAME.OBJ to the volume root)  -Delete FILE,...
              Refuses while AppleWin is running.  Backs the image up to
              COBOL32.backup.po first.
runprog.ps1   -File progs\x.cob -Tag t : boot, option 1, paste, ESC, option 5,
              R UNTITLED, screenshots t-compile.png and t-run.png
regress.ps1   beta1, conds, money, files, qverb - expected results below
leadstest.ps1 / fintest.ps1   the two samples end to end
designers.ps1 FORMAT (save CUST, export CUSTSCR) then QUERY (BIGBAL on CUST)
resave.ps1    FORMAT: open CUST and save it - upgrades a version 1 .DCT
runprog.ps1 -File progs\qfile.cob   QUERY ... OF a relative file (writes CUST.DAT)
viewtest.ps1  menu screenshot, option 7 VIEW of CUST, refused edit keys,
              a missing file (status 35), COMPILE after (nothing to compile)
edtest.ps1    the editor: bars, Ins/Ovr, prompts, PLACE F (all three
              defaults) and Q, PRINT (into print-test.txt)
turntest.ps1  Utilities 7 onto TURN.po (/NEWDISK), then boots it alone
aw.ps1 sa K   Solid-Apple + a letter (right Alt, by keybd_event)
aw.ps1 start "A.po;B.po"   B.po as hard disk 2
qsort.ps1     QUERY designer BALDESC (field 1 descending), then progs\qsort.cob
aw.ps1 sa UP  Solid-Apple + an arrow: UP DOWN LEFT RIGHT (2026-11-11)
runfile.ps1   -File progs\x.cob -Name X -Tag x : like runprog, but X.COB goes
              onto the volume and EDIT opens it with OA-O - seconds, not the
              minutes typing takes.  Deletes X.COB/X.OBJ after: the root
              directory holds only 51 entries.  -Keep leaves X.OBJ for
              ..pdis.js.  A FULL ROOT LOOKS LIKE A BUG: OPEN OUTPUT
              cannot make its file and every later verb says 35 or 42
              (2026-11-22: a stopped run left EAST/WEST.DAT and
              UNTITLED.OBJ, and fchk failed).  Count before blaming code
clptest.ps1   select (OA-Down), Ctrl-X, Ctrl-P, Ctrl-C on one line, ESC with a
              selection, SA-Right; leaves CLIPBOARD.CLP
deployprocs.ps1  PROCS\*.SNP into /COBOL/PROCS ($48, CR line ends)
mkproc.js     DRIVER.drv OUT.cob SNP... : @DATA / @PROCS in the driver become
              each .SNP's data and paragraph pieces
procsuite.ps1 deployprocs, then pdates ptext pscreen pmoney pwords (each
              line says what it expects), then plproc (SA-P P DATES)
size.cob      ON SIZE ERROR / REMAINDER; ends on "Size error at line 49"
runfile.ps1 -Steps "KEYS|TAG",...  more keys after the run, a screenshot
              after each (2026-11-11)
pxtest.ps1    the prefixes: Utilities 8 sets 1/ and 0/, EDIT opens
              1/DATES.SNP, a reboot keeps them (COBOL.SETTINGS), all put back
              and COBOL.SETTINGS deleted
scrn.cob      DISPLAY ERASE, FROM KEY (keys A 7), SET / FROM PREFIX:
              K2 [A] / K3 7 / P1 [/COBOL/PROCS/] / P2 [/COBOL/SRC/] /
              P3 [/COBOL/] / P4 [ ]
page.cob      SET PRINTER TO SCREEN: PAGE 1 + LINE 1-21, pause, LINE 22-30,
              pause, PAGE 2 + LINE 1-3 (no blank lines), END
mnutest.ps1   FORMAT OA-M, four lines, a fifth "q)" refused (mn-dup:
              Key already used), OA-S MAIN centred, OA-O MAIN.MNU;
              e42: a hand-made DUP.MNU (Q) and q)) is compile error 42;
              menu.cob (X refused, q, 2: M1 [Q] / M2 2); e40 e41
rptscr.ps1    after rpttest: LISTR.SNP off the disk into progs\rptscr.drv,
              SET PRINTER TO SCREEN: page 1 (AMY BOB CAL, TOTAL 250), pause,
              page 2 (DEE EVE, blank, TOTAL 1257), END OF REPORT
safetytest.ps1  2026-11-12: sz49 (error 49 PROGRAM AND DATA OVER 7,680
              BYTES), e50a-d (LINKAGE SECTION, ORGANIZATION INDEXED,
              JUSTIFIED, level 66: error 50 NOT PART OF THIS COBOL),
              envok (E1 00 / E2 00 / E3 ABCD 00 / E4 Y / E5 2 -005),
              caseup (abc def q -> C2 [ABC  ] [DEF  ] [Q]) and caseany
              (the same, kept lower case)
limtest.ps1   names to 30 characters, 128 names, 128 items: longnm (L1
              0000100 0000200 0000300 / L2 YES / L3 DONE), many (M1 120 /
              M2 001 / M3 END), e48 (31 characters, line 7), e5 (129th
              name, line 134), e2 (129th item, line 134)
copytest.ps1  COPY: progs\copybooks onto the volume (MYREC.SNP in /COBOL,
              the rest in /COBOL/CPYT), then ccopy (NAME/BALANCE painted,
              C1 COPIED 42 Y, F1 AMY 00000050, C2 COPIED 42), cdates (as
              pdates, DATES found in */PROCS/), e43 e44 e45 e47, and ebook
              (error 15 at line 10, COPY book line 2); all removed after

Expected:
  beta1   000055
  conds   T1-T12 OK (T7/T8 print 4 (4))
  money   A 00250.75 / B    $250.75 / C   42 / D 00250.75 / E    $250.75
  files   OPEN 00 WRITE 00 CLOSE 00 OPEN2 00 READ 00 HELLO
  qverb   A 00 0000 / ERR2 07 / B 07   (needs designers.ps1 first)
  qfile   E0 05 / D 00 / A 00 0002 / 0005 BOB 101.00 000101 /
          0003 EVE 1,000.00 001000
  view    RECORD CUST-NAME CUST-BAL / 0002 AMY 00000050 ... 0005 BOB 00000101
  qsort   A 00 0004 / 0003 EVE 00001000 / 0005 BOB 00000101 /
          0004 CAL 00000099 / 0002 AMY 00000050   (after qfile)
  --- 2026-11-20, the QUICKREF half-built marks, by runfile.ps1; delete
      FCHK.DAT from the image after (cp2 delete) ---
  fchk    R AAA / R CCC / T1 02 10 / T2 OK 23 / T3 00 AAA / T4 OK 23 /
          T5 OK 23 / T6 00 / DONE   (FD clauses, AT END, INVALID KEY)
  fchk2   D1 00 / R2 INV / R2 23 / D2 INV / D2 23 / R9 INV / R9 23 /
          D9 INV / D9 23 / X2 INV / X2 23 ?BB   (A20, fixed 2026-11-20;
          ? is the $FF deletion mark)
  notat   error 12 at line 24 (NOT AT END not built)
  exc     error 12 at line 9 (ON EXCEPTION not built)
  --- 2026-11-22, FIXLIST A21, by runfile.ps1; a21run.ps1 runs these two
      with the DATA DIVISION error tests, beta1, conds, files, listd,
      listm and leadstest ---
  lvl16   G1 [HELLO] / G16 [HELLO] / W [HELLO]   (16 groups, the most)
  lvl17   error 51 at line 23 (OVER 16 GROUP LEVELS NESTED; before the fix
          G17 [] and W [     ], with no error)
  --- 2026-11-22, ASSIGN TO a data name and FIXLIST A22-A24; a22run.ps1
      runs the new tests and every program that opens a file or prints ---
  asn     E1 00 / W1 00 / E2 00 EAST ONE / W2 00 WEST ONE / N1 35 / DONE
          (before: E1 42 ... every OPEN failed); leaves EAST.DAT, WEST.DAT
  asne15  error 15 (ASSIGN TO an undeclared name)
  asne18  error 18 (a SELECT with no ASSIGN)
  prt17   error 13 (17 operands before UPON PRINTER)
  --- 2026-11-22, programs at $8000 (12,288) and p-code in aux (4,864) ---
  bigpg   AT-TEST at line 12 col 10; C1 0250 / D1 END OF DATA / D2 FIRST
          (250 ADDs, 15 bytes each: over 2,816 of p-code; 30 x 250 of data: over 7,680)
  sz49    error 49 PROGRAM + DATA OVER 12,288 BYTES (50 x 250 of data)
  asne15  error 15 (it said 18 until FCRES stopped overwriting it)
  --- 2026-11-22, bad file names refused (DECISIONS 8.10) ---
  badnm   B1 31 / B2 31 / B3 31 / B4 31 / B5 31 / B6 31 / B7 00 / B8 00 /
          B9 35 / B10 31 / DONE   (leaves GOOD.DAT: cp2 delete it)
  badnames.ps1  "MY FILE!" / "BAD NAME" typed into each tool: RUN, EDIT,
          FORMAT, QUERY, REPORT, Utilities DELETE say Bad file name;
          VIEW says File status 31
  fchk, qfile, qsort, conds  as above - FIXLIST A25: on the first aux-
          p-code build every PERFORM UNTIL left at once (fchk T1 00 00,
          qfile and qsort no rows)
  sdbtest.ps1  SALESDB.cob, all seven menu items with printer slot 1:
          EAST.DAT 4 records $6,050.70; MA >= 1000: 1 ACME, 3 CAPE,
          $5,700.00; S preview: whole lines; edit 2 -> ORLANDO, delete 1:
          3 records $4,550.70; copy to WEST.DAT renumbers 1-3; add
          SEQUOIA: WEST 4 records $5,350.70, EAST still $4,550.70;
          P with MA: print-test.txt "SALES - EAST.DAT" / 3 CAPE FISH
          HYANNIS MA $4,200.00 / 1 RECORDS TOTAL $4,200.00
  --- FIXLIST list A (2026-11-08): progs at, lista, listd, listm by
      runprog.ps1 (at.cob with -Keys "JOE~123.45~"); errtest.ps1 runs the
      compile-error programs e33 e14 e34 e35 and then regress.ps1 ---
  LEADS   list shows $1,500.00 and $250.75; pipeline after selling #1: $250.75
  at      NAME/BALANCE labels at line 3/5 col 6, inverse fields; GOT JOE ! /
          00123.45 at line 8/9 col 1/3
  lista   A3 A3B A3C A5 OK / A6 005 / A7A 00001.50 / A7B 00004.00 /
          A7C 00002.50 / A7D 00003.00 / A8A A8B 00002.50 / Divide by zero
  listd   A9 ABCDEF/SEVN / A11 11/08 / A11B 99 END! / A12 007 009 /
          A12N A12B A12C OK
  listm   A13 -005 / A13B OK / A13C -002 / A16 042 007 / A16B [ 30 spaces ]
  e33 e14 e34 e35   compile errors 33, 14 (at the paragraph), 34, 35
  FINANCE running balance 2,500.00 / 1,299.50 / 1,212.25; RENT $1,200.50

AppleWin is D:\AppleWin1.32.0.0, image COBOL32.po, settings in
applewin-cobol.ini (-conf).  cp2 is D:\cp2_1.2.0_win-x64_sc\cp2.exe.
