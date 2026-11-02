# LMS submission (MIVA naming)

Per [CA - September Cohort 2026](https://lms.miva.university/mod/page/view.php?id=166107):

| Rule | Format |
|------|--------|
| **Folder** | `Surname_Firstname_StudentID` |
| **Files** | `Surname_Firstname_StudentID_DocumentType` |

**Your names:** Efagene_Valentine_`<StudentID>`

## Steps

1. Open `student.identity` and set `STUDENT_ID=` (from MIVA SIS), or pass it on the command line.
2. From repo root:

```bash
chmod +x submission/apply_lms_naming.sh
./scripts/init_and_evidence.sh
./submission/apply_lms_naming.sh YOUR_STUDENT_ID
```

3. Edit `submission/Efagene_Valentine_<ID>/Efagene_Valentine_<ID>_README.txt` — paste your **private GitHub URL**.
4. Export `Efagene_Valentine_<ID>_CA_DOCUMENTATION.md` to PDF with the **same base name** (`.pdf`).
5. Upload via the [Google Form](https://docs.google.com/forms/d/e/1FAIpQLSezIt3hWMbx0MpN6ynp9wBXqq5unzc5DiXD3tQKPzkA3CNIeg/viewform) (**one attempt**).

Do not use spaces or generic names (`Assignment`, `Final File`, etc.).

The old file `MIT8103_CA_Documentation.md` is replaced by the generated `Efagene_Valentine_*` files.
