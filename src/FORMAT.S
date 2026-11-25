* FORMAT.S  the screen designer (slice 2)
* An overlay: loaded to $8000 by COBOL.SYSTEM,
* runs, and RTSes back into the menu at $2000.
* The band sits above the library at $3000-$7FFF.
* Bottom line (row 23) asks Row, Column, Label,
* Name, Length, Type; draws the labeled field.
* Row/Col = label position; field follows label+1.
* Types: A alpha, X text, N numeric, B boolean.
* Name is the COBOL data name for the field - the
* dictionary is the single source of truth for
* what a record contains, and a field's name is
* part of that.  It rides in the ten bytes at the
* front of each descriptor, which the format
* already reserved.
* OA-N = new (confirm). OA-S save, OA-O open,
* OA-E export as COBOL.
* SA-C shows the COBOL that would be exported, on
* text page 2, and comes back to the form.
* SA-D during input erases + restarts that prompt.
* ESC at Row? quits.  Overlap is rejected.

 ORG $8000
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/FORMAT
 JMP START
* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC
 PUT EQUATES
 PUT EQUATES2
 PUT PRODOS
 PUT DISKIO
* PROMPT is the row-23 question line, shared with
* REPORT.  It was inside FORMATD until 2026-08-15;
* moving it changed no instruction except LINEIN's
* command test, which now walks CMDLIST (at the
* foot of FORMATD) instead of five hard CMPs.
 PUT PROMPT
 PUT SCREXP
 PUT SCRPRV
 PUT FMTMNU
* The designer body is FORMATD, PUT last so its
* code follows the helper modules - exactly the
* order it had inline.  JMP START above reaches it.
 PUT FORMATD
