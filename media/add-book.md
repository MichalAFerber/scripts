# add-book
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Adds PDF and EPUB books to the Yoda Bookshelf library. Extracts metadata (title, author, edition) from file contents and filenames, auto-classifies books into categories, extracts cover images, moves/copies files to the appropriate Bookshelf subdirectory, and creates an Obsidian note with frontmatter for each book. Supports batch processing from an inbox folder or individual file arguments.
### How to Use
Requires: `pdfinfo`, `pdftotext`, `pdftoppm` (from poppler), `python3`, `perl`.

Process all books in the inbox (default):
```
./add-book.sh
```
Dry-run (show what would happen without changes):
```
./add-book.sh --dry-run
```
Interactive mode (prompt for each field):
```
./add-book.sh --interactive
```
Process specific files:
```
./add-book.sh /path/to/book.pdf /path/to/book.epub
./add-book.sh --dry-run /path/to/book.pdf
```
### What and Where to Tweak
- `BOOKSHELF` - Root path to the bookshelf library (default: `/Volumes/Yoda/Bookshelf`)
- `INBOX` - Path to the inbox folder for batch processing (default: `$BOOKSHELF/_Inbox`)
- `OBSIDIAN_BOOKS` - Path to the Obsidian vault books directory (default: `/Users/michal/Obsidian/Obsidian-Master/books`)
- `PDF_CATEGORIES` / `EPUB_CATEGORIES` - Arrays of valid category names for each format
- `GENRE_MAP` - Associative array mapping category names to display genre names
- `TITLE_MAP` (inside `clean_title`) - Known filename-to-title fixups for specific files
- `auto_classify()` - Keyword-based classification rules; add patterns for new categories
