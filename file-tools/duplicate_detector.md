# duplicate_detector
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A read-only analysis tool that identifies exact and fuzzy duplicate records in a pandas DataFrame. Supports Levenshtein and Jaro-Winkler similarity algorithms for fuzzy matching, optional blocking columns to reduce comparisons, and configurable survivorship rules (first, last, most complete, or merge) for resolving which record to keep.
### How to Use
```python
import pandas as pd
from duplicate_detector import DuplicateDetector

df = pd.read_csv("my_data.csv")
detector = DuplicateDetector(df)

# Find exact duplicates on specific columns
exact = detector.find_exact_duplicates(subset=['email', 'phone'])

# Find fuzzy duplicates by name with 85% threshold
fuzzy = detector.find_fuzzy_duplicates(
    match_columns=['name'],
    threshold=0.85,
    method='jaro_winkler',
    blocking_column='city'  # optional: only compare within same city
)

# View report
print(detector.get_duplicate_report())

# Resolve: keep the most complete record from each group
resolved = detector.resolve_duplicates(survivorship='most_complete')
```

Running the script directly executes a built-in demo with sample data:
```bash
python3 duplicate_detector.py
```

Dependencies: `pandas`, `numpy` (install via `pip install pandas numpy`).
### What and Where to Tweak
- `threshold` in `find_fuzzy_duplicates()`: Lower values (e.g., 0.7) catch more fuzzy matches but increase false positives. Higher values (e.g., 0.95) are stricter.
- `method`: Choose `'levenshtein'` or `'jaro_winkler'` depending on your data. Jaro-Winkler weights prefix matches more heavily, which is better for names.
- `blocking_column`: Set this to a column like city or zip code to avoid comparing every pair of records (significant speedup on large datasets).
- `survivorship` in `resolve_duplicates()`: `'first'`, `'last'`, `'most_complete'`, or `'merge'` (combines non-null values from all records in a group).
