#!/usr/bin/env python3
import argparse, json, smtplib, ssl, os, pathlib, sys
from email.message import EmailMessage

def load_config(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def read_tail(path, max_bytes=200_000):
    if not os.path.exists(path): return ""
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        if size > max_bytes:
            f.seek(-max_bytes, os.SEEK_END)
            data = f.read().decode(errors="replace")
            return f"(truncated to last {max_bytes} bytes)\n" + data
        return f.read().decode(errors="replace")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--status", choices=["success","error"], required=True)
    ap.add_argument("--summary", default="SysMaint notification")
    ap.add_argument("--log", required=True)
    ap.add_argument("--err", required=True)
    args = ap.parse_args()

    cfg = load_config(args.config)
    smtp = cfg.get("smtp", {})
    to_list = cfg.get("notify", {}).get("to", [])
    if not smtp or not to_list:
        print("Missing smtp or notify.to in config; aborting email.", file=sys.stderr)
        return 2

    host = smtp.get("host")
    port = int(smtp.get("port", 587))
    user = smtp.get("username")
    pwd  = smtp.get("password")
    use_tls = bool(smtp.get("starttls", True))
    from_addr = smtp.get("from")
    subject_prefix = cfg.get("notify", {}).get("subject_prefix", "[SysMaint]")

    hostname = os.uname().nodename
    status_emoji = "✅" if args.status == "success" else "❌"
    subject = f"{subject_prefix} {status_emoji} {args.summary} ({hostname})"

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_addr or user
    msg["To"] = ", ".join(to_list)

    log_tail = read_tail(args.log)
    err_tail = read_tail(args.err)
    body = []
    body.append(f"Host: {hostname}")
    body.append(f"Summary: {args.summary}")
    body.append(f"Status: {args.status}")
    body.append("")
    if args.status == "error" or err_tail.strip():
        body.append("Errors (tail):")
        body.append("-"*60)
        body.append(err_tail or "(none)")
        body.append("")
    body.append("Full Log (tail):")
    body.append("-"*60)
    body.append(log_tail or "(missing)")
    msg.set_content("\n".join(body))

    context = ssl.create_default_context()
    if use_tls:
        with smtplib.SMTP(host, port) as s:
            s.ehlo()
            s.starttls(context=context)
            s.login(user, pwd)
            s.send_message(msg)
    else:
        with smtplib.SMTP_SSL(host, port, context=context) as s:
            s.login(user, pwd)
            s.send_message(msg)

    print("Notification sent.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
