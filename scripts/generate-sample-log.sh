#!/usr/bin/env bash
#
# generate-sample-log.sh - create a synthetic Nginx access log (combined format)
# for testing the analysers when you don't have a real log at hand.
#
# Usage: generate-sample-log.sh [LINES] [OUTPUT_FILE] [SEED]
#   LINES        number of log lines   (default: 1000)
#   OUTPUT_FILE  where to write        (default: sample/access.sample.log)
#   SEED         random seed           (default: 42)

set -euo pipefail

COUNT=${1:-1000}
OUT=${2:-sample/access.sample.log}
SEED=${3:-42}

mkdir -p "$(dirname "$OUT")"

awk -v count="$COUNT" -v seed="$SEED" '
# Weighted random choice: items[1..n] with weights[1..n].
function pick(items, weights, n,    total, i, r, acc) {
  total = 0
  for (i = 1; i <= n; i++) total += weights[i]
  r = rand() * total
  acc = 0
  for (i = 1; i <= n; i++) {
    acc += weights[i]
    if (r < acc) return items[i]
  }
  return items[n]
}

BEGIN {
  srand(seed)

  n_ip  = split("45.76.135.253|142.93.143.8|178.128.94.113|43.224.43.187|203.0.113.45|198.51.100.7|192.0.2.99|185.220.101.4", ips, "|")
  split("30 20 10 8 6 4 3 2", ip_w, " ")

  n_path = split("/api/v1/users|/api/v1/products|/api/v1/orders|/api/v1/payments|/api/v1/reviews|/login|/index.html|/favicon.ico|/robots.txt|/admin", paths, "|")
  split("30 22 12 8 6 8 6 4 2 2", path_w, " ")

  n_method = split("GET|POST|PUT|DELETE", methods, "|")
  split("70 20 6 4", method_w, " ")

  n_status = split("200|304|404|500|401|301|403", statuses, "|")
  split("62 14 11 3 4 4 2", status_w, " ")

  n_ua = split("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36|Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15|Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0|curl/8.4.0|Googlebot/2.1 (+http://www.google.com/bot.html)|python-requests/2.31.0", uas, "|")
  split("40 20 15 10 8 7", ua_w, " ")

  n_ref = split("-|https://example.com/|https://www.google.com/", refs, "|")
  split("60 25 15", ref_w, " ")

  t = 36000   # start at 10:00:00
  for (i = 0; i < count; i++) {
    t += int(rand() * 4)
    status = pick(statuses, status_w, n_status)
    size = (status == "304") ? 0 : int(rand() * 9000) + 200
    printf "%s - - [11/Aug/2025:%02d:%02d:%02d +0000] \"%s %s HTTP/1.1\" %s %d \"%s\" \"%s\"\n", \
      pick(ips, ip_w, n_ip), int(t / 3600) % 24, int(t / 60) % 60, t % 60, \
      pick(methods, method_w, n_method), pick(paths, path_w, n_path), \
      status, size, pick(refs, ref_w, n_ref), pick(uas, ua_w, n_ua)
  }
}' > "$OUT"

echo "Wrote $COUNT lines to $OUT"
