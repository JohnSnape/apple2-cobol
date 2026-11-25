* QRYVAR.S  QUERY's variables (holds QRYEND)
* PUT from QUERY.S - no ORG, not assembled alone.
* PUT LAST, so QRYEND is the real end of the code.
*
* PARALLEL ARRAYS, like FORMAT and unlike REPORT.
* REPORT went to a fixed 64-byte stride because it
* has sixty-four entries and deletes from the middle
* of them; eight conditions delete just as cheaply
* eight ways, and the arrays read better in a
* listing.  The choice is about the size of the
* table, not about taste.

* MAXCOND, MAXKEY and MAXLIT are in QUERY.S, ahead
* of every PUT: QRYADD and QRYIO compare against
* them, and a small EQU met after its first use is
* an ILLEGAL FORWARD REFERENCE to Merlin 8.

* ---- the conditions ----------------------------
* QCCON is the connector IN FRONT of a condition, so
* the first one's is never looked at.  0 = AND,
* 1 = OR.
QNCOND DFB 0
QCFLD DS MAXCOND
QCREL DS MAXCOND
QCCON DS MAXCOND
QCLEN DS MAXCOND
QCTXT DS MAXCOND*MAXLIT

* ---- the sort keys -----------------------------
QNKEY DFB 0
QKFLD DS MAXKEY
QKDIR DS MAXKEY

* ---- what is loaded ----------------------------
QHASD DFB 0
QSEL DFB 0
QQUIT DFB 0
QT DFB 0
QT2 DFB 0
QIX DFB 0
QJX DFB 0
QNFLD DFB 0
QRESB DFB 0

* ---- the file being built ----------------------
* Thirty-two of header, twelve of sort spec and at
* most ninety-six of predicate: one buffer, one
* FSAVE, no streaming.  A query is the smallest file
* the system writes.
QDBUF DS 160
QDFLEN DS 2

* ---- CMDLIST: the Open-Apple letters we take ----
* PROMPT's LINEIN walks this instead of testing
* letters itself, and swallows anything not on it.
* A add, D delete, K key, R remove key, I dictionary,
* N new, O open, S save.
CMDLIST DFB $41,$44,$4B,$52,$49,$4E,$4F,$53,$00


* ---- the strings, length-prefixed for PUTS ----
QSHDR DFB 5
 ASC 'QUERY'
QSNOD DFB 13
 ASC 'NO DICTIONARY'
QSCND DFB 10
 ASC 'CONDITIONS'
QSKEY DFB 9
 ASC 'SORT KEYS'
QSAND DFB 4
 ASC 'AND '
QSOR DFB 4
 ASC 'OR  '
QSBLK DFB 4
 ASC '    '
QSASC DFB 11
 ASC '  ASCENDING'
QSDESC DFB 12
 ASC '  DESCENDING'
QSBAR1 DFB 40
 ASC 'OA-A Add  OA-D Del  OA-K Key  OA-R UnKey'
QSBAR2 DFB 51
 ASC 'OA-I Dict  OA-N New  OA-O Open  OA-S Save  ESC Exit'
QPFLD DFB 14
 ASC 'Field number? '
QPREL DFB 19
 ASC 'Test = # < ( > ) ? '
QPVAL DFB 14
 ASC 'Compare with? '
QPCON DFB 23
 ASC 'Join with A)nd or O)r? '
QPKEY DFB 22
 ASC 'Sort on field number? '
QPDIR DFB 27
 ASC 'A)scending or D)escending? '
QPSAVE DFB 9
 ASC 'Save as? '
QPOPEN DFB 6
 ASC 'Open? '
QPDICT DFB 12
 ASC 'Dictionary? '
QSSAVD DFB 11
 ASC 'Saved (key)'
QSEND DFB 26
 ASC 'No dictionary loaded (key)'
QSEFL DFB 25
 ASC 'No room for another (key)'
QSEFN DFB 19
 ASC 'No such field (key)'
QSEIO DFB 16
 ASC 'Disk error (key)'
QSEBN DFB 19
 ASC 'Bad file name (key)'
QSEBAD DFB 20
 ASC 'Not a QRY file (key)'

* ---- the six relations, as the interpreter
* numbers them ----
QRELTB DA QR0
 DA QR1
 DA QR2
 DA QR3
 DA QR4
 DA QR5
QR0 DFB 4
 ASC ' =  '
QR1 DFB 4
 ASC ' #  '
QR2 DFB 4
 ASC ' <  '
QR3 DFB 4
 ASC ' <= '
QR4 DFB 4
 ASC ' >  '
QR5 DFB 4
 ASC ' >= '

* ---- the dictionary name for the top line ----
QDNAME DS 14

QRYEND EQU *
