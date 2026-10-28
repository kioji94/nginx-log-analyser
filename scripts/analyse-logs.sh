#!/usr/bin/env bash
#
# analyse-logs.sh - summarise an Nginx access log (combined log format).
#
# Reports the top N: IP addresses, requested paths, response status codes
# and user agents.
#
# Usage: analyse-logs.sh [-n COUNT] LOGFILE

set -euo pipefail

TOP_N=5
PROG=${0##*/}

usage() {
  cat <<EOF
Usage: $PROG [-n COUNT] LOGFILE

Analyse an Nginx access log (combined format) and print the top entries for:
  - IP addresses
  - requested paths
  - response status codes
  - user agents

Options:
  -n COUNT   number of entries per section (default: 5)
  -h         show this help

Example:
  $PROG sample/access.sample.log
  $PROG -n 10 /var/log/nginx/access.log
EOF
}

while getopts ":n:h" opt; do
  case $opt in
    n) TOP_N=$OPTARG ;;
    h) usage; exit 0 ;;
    :) echo "Error: option -$OPTARG requires an argument" >&2; usage >&2; exit 2 ;;
    \?) echo "Error: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if ! [[ $TOP_N =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: -n must be a positive integer (got '$TOP_N')" >&2
  exit 2
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

LOG_FILE=$1
[[ $LOG_FILE == -* ]] && LOG_FILE="./$LOG_FILE"

if [[ ! -f $LOG_FILE || ! -r $LOG_FILE ]]; then
  echo "Error: cannot read '$LOG_FILE'" >&2
  exit 1
fi

# Combined log format, split on double quotes (-F'"'):
#   $1 = IP - user [date]      $2 = "METHOD /path HTTP/x"   $3 = status size
#   $4 = referrer              $6 = user agent
# A well-formed line therefore has at least 6 quote-separated fields.

# report TITLE AWK_STATEMENTS
#   Runs AWK_STATEMENTS on every well-formed line (it must print one value per
#   line), then counts, ranks and prints the top N values.
report() {
  local title=$1 extract=$2
  printf '%s\n\n' "$title"
  awk -F'"' "NF >= 6 { $extract }" "$LOG_FILE" \
    | LC_ALL=C sort \
    | uniq -c \
    | LC_ALL=C sort -k1,1nr -k2 \
    | awk -v n="$TOP_N" 'NR <= n {
        count = $1
        sub(/^ *[0-9]+ /, "")
        printf "%s - %d %s\n", $0, count, (count == 1 ? "request" : "requests")
      }'
}

skipped=$(awk -F'"' 'NF < 6 && length($0) > 0' "$LOG_FILE" | wc -l)
if (( skipped > 0 )); then
  echo "Warning: skipped $skipped malformed line(s)" >&2
fi

report "Top $TOP_N IP addresses with the most requests:" \
  'split($1, f, " "); if (f[1] != "") print f[1]'
echo
report "Top $TOP_N most requested paths:" \
  'split($2, f, " "); print (f[2] == "" ? "-" : f[2])'
echo
report "Top $TOP_N response status codes:" \
  'split($3, f, " "); if (f[1] != "") print f[1]'
echo
report "Top $TOP_N user agents:" \
  'print ($6 == "" ? "-" : $6)'
