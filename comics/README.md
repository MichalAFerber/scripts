# Comic Library Organizer (process_comics.sh)

This script helps maintain a clean and standardized comic library for apps like **Kavita**, **Komga**, and **YACReader**.

## How It Works

- Recursively scans the current directory (and all subfolders) for `.cbz` and `.cbr` files
- Renames comics to a consistent format:

```bash
Series Name #NNN (YYYY).cbz
````

- Cleans up tags like `(Digital)`, `(WebRip)`, `(ScanGroup)` etc.
- Defaults year to `(0000)` if missing
- Converts ZIP-based `.cbr` files into `.cbz` automatically (true RAR `.cbr` files are left untouched)
- Generates and embeds a `ComicInfo.xml` file for every `.cbz`
- Keeps `.cbr` files untouched (renamed only)
- Logs every run to `logs/process_comics-YYYY-MM-DD-HHMM.txt`

---

## Usage

From inside your `Comics/` folder:

### Preview changes (dry-run)

```bash
./process_comics.sh --dry-run
````

### Rename / Convert / Add metadata

```bash
./process_comics.sh
```

### Regenerate ComicInfo.xml for all `.cbz`

```bash
./process_comics.sh --regen
```

Logs are stored in `Comics/logs/`.

---

## Examples

### Before → After

```bash
Superman 018 (2024) (WebRip) (Group).cbr
→ Superman #018 (2024).cbr
```

```bash
IndieComic 1.cbz
→ IndieComic #001 (0000).cbz
```

```bash
SomeSeries 005.cbr  [zip disguised as cbr]
→ SomeSeries #005 (2019).cbz
```

```bash
The Amazing Spider-Man v2 #05 [HD Scans].cbz
→ The Amazing Spider-Man #005 (0000).cbz
```

---

## ComicInfo.xml Contents

For `.cbz` files, the script creates a `ComicInfo.xml` like this:

```xml
<ComicInfo>
  <Title>Series Name #001</Title>
  <Series>Series Name</Series>
  <Number>001</Number>
  <Year>2024</Year>
  <Month>1</Month>
  <Summary>Added by process_comics.sh</Summary>
  <Publisher>Unknown</Publisher>
  <Genre>Comics</Genre>
  <LanguageISO>en</LanguageISO>
</ComicInfo>
```

These fields follow the ComicInfo XML standard (compatible with Kavita, Komga, etc.).

---

## Notes

- Safe to re-run any time; already processed files are skipped
- `.cbr` files are not modified except for renaming
- `.cbz` files are modified to include ComicInfo.xml
- Logs are timestamped and never overwritten

---

## License

MIT License
