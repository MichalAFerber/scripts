# 📚 process\_comics.sh

Shell script to automatically rename and optionally convert `.cbr` files to `.cbz`, generate embedded `ComicInfo.xml`, and log operations — recursively from current directory.

## 🚀 What it Does

* Finds comic archive files (`*.cbz` and `*.cbr`) in current directory and subdirectories.
* Parses out series name, issue number, and year.
* Renames to standardized format:

  ```bash
  Series Name #NNN (YYYY).cbz
  Series Name #NNN (YYYY).cbr
  ```

  If year is missing or unrecognized, defaults to `0000`.
* Converts `.cbr` (RAR‑based) to `.cbz` if `--convert` flag set; otherwise just renames `.cbr`.
* Embeds a basic `ComicInfo.xml` (with metadata tags like `<Title>`, `<Series>`, `<IssueNumber>`, `<Year>`).
* Logs actions to `logs/process_comics-YYYY-MM-DD-HHMM.txt`, and rotates automatically per run.
* Supports:

  * `--dry-run` (show planned changes).
  * `--regen` (regenerate `ComicInfo.xml` even if it exists).

## 🧪 Usage

```bash
cd /path/to/comics
./process_comics.sh [--dry-run] [--convert] [--regen]
```

### Example Runs

#### Dry-run only renaming and regen

```bash
./process_comics.sh --dry-run --regen
```

#### Full processing — converting `.cbr` to `.cbz` and embedding xml

```bash
./process_comics.sh --convert
```

## 📁 Before / After Examples

| Before Filename                           | After Filename                              |
| ----------------------------------------- | ------------------------------------------- |
| `Captain Marvel Adventures (1941) #1.cbr` | `Captain Marvel Adventures #001 (1941).cbz` |
| `The Spirit (1952) #2.cbz`                | `The Spirit #002 (1952).cbz`                |
| `Amazing-Man Comics-008-1939.cbz`         | `Amazing-Man Comics #008 (1939).cbz`        |
| `Say Hello to Blackjack (v01).cbz`        | `Say Hello to Blackjack #001 (0000).cbz`    |

## 📦 ComicInfo.xml Content

Each generated `ComicInfo.xml` includes:

```xml
<ComicInfo>
  <Title>Series Name #NNN</Title>
  <Series>Series Name</Series>
  <IssueNumber>NNN</IssueNumber>
  <Year>YYYY</Year>
  <Writer></Writer>
  <Publisher></Publisher>
  <Summary></Summary>
</ComicInfo>
```

* Title, Series, IssueNumber, Year are required.
* Writer, Publisher, Summary are blank placeholders you can edit manually.

Scripts automatically embed the XML inside the ZIP archive.

## 📝 Logging

* Each run writes to `logs/process_comics-YYYY-MM-DD-HHMM.txt`
* Includes start and end timestamps.
* Logs actions (e.g. “Renaming X → Y”, “Converted”, “Skipped already formatted”, “Embedded ComicInfo.xml”).
* Supports `--dry-run` to preview without modifying files.

Log files accumulate indefinitely unless manually cleaned.

## 🔧 Requirements

* Bash shell
* `zip`, `unzip` (for `.cbr` → `.cbz`)
* `unrar` (if converting `.cbr` files)
* `awk`, `sed`, `printf`, `date`, etc. (standard Linux/macOS utilities)

Make sure all utilities are in your `$PATH`.

## ⚙️ Installation

1. Place `process_comics.sh` in your `Comics/` directory.
2. Make executable:

   ```bash
   chmod +x process_comics.sh
   ```

3. Commit to GitHub under the `comics/` folder of your repo `MichalAFerber/scripts`.

## 🧠 Tips

* Use `--dry-run` before first real run to check behavior.
* Customize XML content or regex in script if your naming convention changes.
* Run `./process_comics.sh` from root of your comics directory to scan all subfolders.

## License

All scripts in this repository are licensed under the [MIT License](../LICENSE).
