#!/bin/bash

echo "[*] Log cleanup started..."

# This script must be run as root
if [[ $EUID -ne 0 ]]; then
  echo "[!] This script must be run as root"
  exit 1
fi

# Stop syslog socket first (systemd socket activation)
echo "[*] Stopping syslog.socket and rsyslog.service..."
systemctl stop syslog.socket
systemctl stop rsyslog.service

# Truncate all non-compressed log files except PostgreSQL logs
echo "[*] Cleaning general log files..."
find /var/log -type f \
  ! -name "*.gz" \
  ! -path "/var/log/postgresql/*" \
  -exec truncate -s 0 {} \;

# Clean Samba logs if present
echo "[*] Cleaning Samba logs..."
[ -d /var/log/samba ] && find /var/log/samba -type f -exec truncate -s 0 {} \;

# Safely clean PostgreSQL logs by stopping the service
echo "[*] Cleaning PostgreSQL logs..."
if systemctl is-active --quiet postgresql; then
  systemctl stop postgresql
  truncate -s 0 /var/log/postgresql/*.log 2>/dev/null
  truncate -s 0 /var/log/postgresql/*.log.* 2>/dev/null
  systemctl start postgresql
else
  truncate -s 0 /var/log/postgresql/*.log 2>/dev/null
  truncate -s 0 /var/log/postgresql/*.log.* 2>/dev/null
fi

# Truncate binary login/accounting logs
echo "[*] Cleaning binary logs..."
for f in wtmp btmp lastlog faillog; do
  [ -f "/var/log/$f" ] && truncate -s 0 "/var/log/$f"
done

# Clean systemd journal logs
echo "[*] Cleaning systemd journal..."
journalctl --vacuum-time=1s >/dev/null 2>&1

# Restart logging services
echo "[*] Restarting syslog.socket and rsyslog.service..."
systemctl start syslog.socket
systemctl start rsyslog.service

# Clear bash history (disk + memory)
echo "[*] Clearing bash history..."
truncate -s 0 /root/.bash_history 2>/dev/null
history -c
unset HISTFILE

echo "[✓] Log cleanup completed successfully."
