#!/bin/bash
# Email handler for scanned files
# Sends scanned files as email attachments via SMTP

set -euo pipefail

SCAN_FILE="${1:-}"
if [[ -z "$SCAN_FILE" ]]; then
    echo "ERROR: No scan file provided" >&2
    exit 1
fi

if [[ ! -f "$SCAN_FILE" ]]; then
    echo "ERROR: Scan file does not exist: $SCAN_FILE" >&2
    exit 1
fi

# Load environment variables
if [[ -f /.env ]]; then
    set -a
    source /.env
    set +a
fi

# Check if email is enabled
if [[ "${EMAIL_ENABLED:-false}" != "true" ]] || [[ -z "${SMTP_SERVER:-}" ]]; then
    exit 0
fi

SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
EMAIL_FROM="${EMAIL_FROM:-}"
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_SUBJECT="${EMAIL_SUBJECT:-Scanned Document}"

if [[ -z "$EMAIL_FROM" ]] || [[ -z "$EMAIL_TO" ]]; then
    echo "WARNING: EMAIL_FROM or EMAIL_TO not configured" >&2
    exit 1
fi

echo "Sending via email to: $EMAIL_TO"

FILENAME=$(basename "$SCAN_FILE")

# Use sendmail or mailx if available, otherwise use Python
if command -v sendmail >/dev/null 2>&1; then
    {
        echo "From: $EMAIL_FROM"
        echo "To: $EMAIL_TO"
        echo "Subject: $EMAIL_SUBJECT - $FILENAME"
        echo "MIME-Version: 1.0"
        echo "Content-Type: application/pdf; name=\"$FILENAME\""
        echo "Content-Disposition: attachment; filename=\"$FILENAME\""
        echo "Content-Transfer-Encoding: base64"
        echo ""
        base64 < "$SCAN_FILE"
    } | sendmail -t "$EMAIL_TO" && {
        echo "Email sent successfully via sendmail"
        exit 0
    } || {
        echo "WARNING: Failed to send email via sendmail" >&2
        exit 1
    }
elif command -v python3 >/dev/null 2>&1; then
    python3 << EOF
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import os
import sys

smtp_server = "${SMTP_SERVER}"
smtp_port = ${SMTP_PORT}
smtp_user = "${SMTP_USER}"
smtp_pass = "${SMTP_PASS}"
email_from = "${EMAIL_FROM}"
email_to = "${EMAIL_TO}"
email_subject = "${EMAIL_SUBJECT} - ${FILENAME}"
file_path = "${SCAN_FILE}"

msg = MIMEMultipart()
msg['From'] = email_from
msg['To'] = email_to
msg['Subject'] = email_subject

with open(file_path, "rb") as f:
    part = MIMEBase('application', 'octet-stream')
    part.set_payload(f.read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', f'attachment; filename= {os.path.basename(file_path)}')
    msg.attach(part)

try:
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.starttls()
    if smtp_user and smtp_pass:
        server.login(smtp_user, smtp_pass)
    server.send_message(msg)
    server.quit()
    print("Email sent successfully via SMTP")
    sys.exit(0)
except Exception as e:
    print(f"ERROR: Failed to send email: {e}", file=sys.stderr)
    sys.exit(1)
EOF
else
    echo "WARNING: No email sending tool available (sendmail or python3 required)" >&2
    exit 1
fi

