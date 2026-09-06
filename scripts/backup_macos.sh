#!/usr/bin/env bash
set -euo pipefail

DEST="/Volumes/alexandria/cloud/macos"
LOG_FILE="macos_backup_log.txt"

EXCLUDES=(
  --exclude ".git/**"
  --exclude "node_modules/**"
  --exclude ".DS_Store"
  --exclude "__pycache__/**"
  --exclude "*.pyc"
  --exclude ".cache/**"
  --exclude "Thumbs.db"
  --exclude "*.tmp"
  --exclude "*.log"
)

SOURCES=(
  "Documents"
  "Downloads"
  "Pictures"
  "Music"
  "Calibre Library"
  "scripts"
)

if ! mount | grep -q "${DEST}"; then
  echo "ERROR: ${DEST} is not mounted. Aborting backup." >&2
  exit 1
fi

for dir in "${SOURCES[@]}"; do
  src="${HOME}/${dir}"
  dest="${DEST}/${dir}"
  echo "==> Syncing: ${src}"
  rclone sync "${src}" "${dest}" --progress "${EXCLUDES[@]}"
done

echo "last backup was $(date -Iseconds)" >"${LOG_FILE}"

echo ""
echo "Backup complete!"
