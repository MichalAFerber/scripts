# wwpv_specials_check
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Checks which World's Wildest Police Videos specials (compilations, spin-offs, related shows) are present in the Season 00 folder. Compares files on disk against a built-in list of official special titles using fuzzy normalized matching. Reports each title as FOUND or MISSING.
### How to Use
```
python3 wwpv_specials_check.py /path/to/series/root
```
If no path is given, uses the current directory. The script looks for a `Season 00` subfolder within the given root.

This is a read-only check -- no files are modified.
### What and Where to Tweak
- `official` - The list of expected special titles. Add or remove entries to match your collection's expected specials.
