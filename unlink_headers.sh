#!/bin/bash

set -e

FLAG_FILE="/var/include_headers_linked.flag"

delete_flag_file() {
  rm "$FLAG_FILE"
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Check if the flag file exists
if [[ ! -f "$FLAG_FILE" ]]; then
  echo "Error: Headers are not linked." >&2
  exit 1
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
    exit 1
fi

# Convert to absolute path
SYSTEM_HEADERS_PATH=$(realpath "$SYSTEM_HEADERS_PATH")

# Check if the path is a subdirectory of /usr/include
SUBDIR=$(basename "$SYSTEM_HEADERS_PATH")
if [[ -d "/usr/include/$SUBDIR" ]]; then
  # Remove the symbolic link from /usr/include
  if [[ -L "/usr/include/$SUBDIR" ]]; then
    if rm "/usr/include/$SUBDIR"; then
      echo "Removed symbolic link /usr/include/$SUBDIR."
    else
      echo "Failed to remove /usr/include/$SUBDIR." >&2
    fi
  fi

  # Restore the subdirectory from backup
  if [[ -d "/usr/include/include_bkp/$SUBDIR" ]]; then
    mv "/usr/include/include_bkp/$SUBDIR" "/usr/include/$SUBDIR"
    echo "Restored /usr/include/$SUBDIR from backup."
  else
    echo "No backup found for /usr/include/$SUBDIR."
  fi
else
  # Restore individual header files from backup
  for full_header_path in "$SYSTEM_HEADERS_PATH"/*; do
    header=$(basename "$full_header_path")

    # Remove the symbolic link from /usr/include
    if [[ -L "/usr/include/$header" ]]; then
      if rm "/usr/include/$header"; then
        echo "Removed symbolic link /usr/include/$header."
      else
        echo "Failed to remove /usr/include/$header." >&2
      fi
    fi

    # Check if the backup exists
    if [[ -e "/usr/include/include_bkp/$header" || -L "/usr/include/include_bkp/$header" ]]; then
      # Move the backup back to its original location
      if mv "/usr/include/include_bkp/$header" "/usr/include/$header"; then
        echo "Restored /usr/include/$header from backup."
      else
        echo "Failed to restore /usr/include/$header from backup." >&2
      fi
    else
      echo "No backup found for /usr/include/$header."
    fi
  done
fi

echo "Headers have been restored to their original versions."

delete_flag_file
