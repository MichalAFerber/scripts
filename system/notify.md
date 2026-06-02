# notify
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Helper script that sends email notifications about system maintenance results. Called by sysmaint.sh after maintenance completes (or fails). Reads SMTP credentials and recipient addresses from a JSON config file, attaches tails of the log and error files to the email body, and sends via SMTP with STARTTLS or SSL.
### How to Use
```bash
# Typically called automatically by sysmaint.sh, but can be run standalone:
python3 notify.py --config /path/to/config.json --status success --summary "Maintenance OK" --log /path/to/logfile.log --err /path/to/errfile.log

# Preview what would be sent without sending
python3 notify.py --config /path/to/config.json --status error --summary "Test" --log log.log --err err.log --dry-run
```

**Flags:**
- `--config PATH` (required) — Path to config.json with SMTP and notification settings
- `--status success|error` (required) — Whether to report success or error
- `--summary TEXT` — Subject line summary (default: "SysMaint notification")
- `--log PATH` (required) — Path to the full log file to include in the email
- `--err PATH` (required) — Path to the error log file to include in the email
- `--dry-run` — Print what would be sent without actually sending the email

**Prerequisites:** Python 3, a config.json file with SMTP settings.

**config.json format:**
```json
{
  "smtp": {
    "host": "smtp.example.com",
    "port": 587,
    "username": "user@example.com",
    "password": "app-password",
    "starttls": true,
    "from": "user@example.com"
  },
  "notify": {
    "to": ["recipient@example.com"],
    "subject_prefix": "[SysMaint]"
  }
}
```
### What and Where to Tweak
- **config.json** — All SMTP and recipient settings live here. Update host, port, credentials, and the `to` list for your environment.
- **subject_prefix** — Change `notify.subject_prefix` in config.json to customize the email subject tag.
- **max_bytes** in `read_tail()` — Controls how much of each log file is included in the email body (default: 200,000 bytes). Increase if your logs are large and you want more context.
- **starttls** — Set to `true` for STARTTLS on port 587, or `false` for SMTP_SSL (typically port 465).
