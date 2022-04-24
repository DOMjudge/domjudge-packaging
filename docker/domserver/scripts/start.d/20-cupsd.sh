#!/bin/bash -e

function file_or_env {
    file=${1}_FILE
    if [ -n "${!file}" ]; then
        cat "${!file}"
    else
        echo -n "${!1}"
    fi
}

PRINTER_URL=$(file_or_env PRINTER_URL)

/usr/sbin/cupsd

if [ -n "$PRINTER_URL" ]; then
  echo "Setting contest printer to $PRINTER_URL"
  set_printer $PRINTER_URL
fi
