#!/bin/bash

set -e

FLAG_FILE="/var/include_headers_linked.flag"

create_flag_file() {
  touch "$FLAG_FILE"
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Check if the flag file exists
if [[ -f "$FLAG_FILE" ]]; then
  echo "Error: Headers have already been linked." >&2
  exit 0
fi

# Check if the path argument is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 --path /path/to/system_headers" >&2
    exit 1
fi

# Parse the argument to get the path to system_headers
for i in "$@"; do
  case $i in
    --path)
    SYSTEM_HEADERS_PATH="$2"
    shift # past argument
    shift # past value
    ;;
    *)
    # unknown option
    ;;
  esac
done

# Ensure the path is not empty and exists
if [[ -z "$SYSTEM_HEADERS_PATH" ]] || [[ ! -d "$SYSTEM_HEADERS_PATH" ]]; then
    echo "Error: Invalid path ($SYSTEM_HEADERS_PATH)." >&2
    echo "Usage: $0 --path /path/to/system_headers" >&2
    exit 1
fi

# Convert to absolute path
SYSTEM_HEADERS_PATH=$(realpath "$SYSTEM_HEADERS_PATH")

# Create a backup directory if it doesn't exist
if [[ ! -d "/usr/include/include_bkp" ]]; then
  mkdir "/usr/include/include_bkp"
  chmod 755 "/usr/include/include_bkp"
fi

# Check if the path is a subdirectory of /usr/include
SUBDIR=$(basename "$SYSTEM_HEADERS_PATH")
if [[ -d "/usr/include/$SUBDIR" ]]; then
  # Backup the subdirectory
  mv "/usr/include/$SUBDIR" "/usr/include/include_bkp/$SUBDIR"
  echo "Found existing /usr/include/$SUBDIR. Moved to /usr/include/include_bkp/$SUBDIR."
  # Link the entire subdirectory
  ln -s "$SYSTEM_HEADERS_PATH" "/usr/include/$SUBDIR"
  echo "Created symbolic link to $SYSTEM_HEADERS_PATH."
else
  # Backup and link individual header files
  for full_header_path in "$SYSTEM_HEADERS_PATH"/*; do
    if [[ ! -f "$full_header_path" ]]; then
      echo "Skipping non-file $full_header_path"
      continue
    fi

    header=$(basename "$full_header_path")

    # Check if the target header already exists
    if [[ -e "/usr/include/$header" ]]; then
      # Move the existing header to backup
      mv "/usr/include/$header" "/usr/include/include_bkp/$header"
      echo "Found existing /usr/include/$header. Moved to /usr/include/include_bkp/$header."
    fi

    # Create a symbolic link to the new header
    if ln -s "$full_header_path" "/usr/include/$header"; then
      echo "Created symbolic link to $full_header_path."
    else
      echo "Error creating symbolic link for $full_header_path." >&2
    fi
  done
fi

echo "Headers have been linked successfully."

create_flag_file
