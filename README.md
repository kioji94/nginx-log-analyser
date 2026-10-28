# Nginx Log Analyser

A small command-line tool that reads an Nginx access log and prints the **top 5** of:

1. IP addresses with the most requests
2. Most requested paths
3. Response status codes
4. User agents

Two equivalent implementations:

| Platform | Script | Needs |
|----------|--------|-------|
| Linux / macOS / WSL / Git Bash | `scripts/analyse-logs.sh` | Bash, `awk`, `sort`, `uniq` (all standard) |
| Windows | `scripts/analyse-logs.ps1` | Windows PowerShell 5.1 or PowerShell 7+ |

> Project idea from [roadmap.sh - Nginx Log Analyser](https://roadmap.sh/projects/nginx-log-analyser) (DevOps practice project 2).

---

## Repository layout

```
nginx-log-analyser/
├── scripts/
│   ├── analyse-logs.sh          # Linux version
│   ├── analyse-logs.ps1         # Windows version
│   └── generate-sample-log.sh   # builds a synthetic log for testing
├── sample/
│   └── access.sample.log        # 1000 generated log lines
├── tests/
│   ├── fixture.log              # small log with hand-counted results
│   ├── expected.txt             # the exact output both scripts must produce
│   └── test.sh                  # test runner for the Bash script
├── .github/workflows/ci.yml     # ShellCheck + tests on Ubuntu, output check on Windows
├── .gitattributes               # keeps .sh files LF on Windows checkouts
└── .gitignore
```

## Log format expected

Nginx's default `combined` format:

```
45.76.135.253 - - [11/Aug/2025:10:00:01 +0000] "GET /api/v1/users HTTP/1.1" 200 1532 "https://example.com/" "Mozilla/5.0 ..."
|             |   |                             |       |            |       |   |    |                       |
IP            |   date/time                     method  path         proto   |   size referrer                user agent
              user                                                          status
```

Lines that don't match this shape are skipped, and a warning with the count is printed on stderr.

## Usage

### Linux

```bash
chmod +x scripts/analyse-logs.sh

./scripts/analyse-logs.sh sample/access.sample.log           # top 5
./scripts/analyse-logs.sh -n 10 /var/log/nginx/access.log    # top 10
./scripts/analyse-logs.sh -h                                  # help
```

### Windows (PowerShell)

```powershell
.\scripts\analyse-logs.ps1 .\sample\access.sample.log             # top 5
.\scripts\analyse-logs.ps1 -LogFile C:\logs\access.log -Top 10    # top 10
Get-Help .\scripts\analyse-logs.ps1 -Full                         # help
```

If scripts are blocked by the execution policy, allow them for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Sample output

```
Top 5 IP addresses with the most requests:

45.76.135.253 - 357 requests
142.93.143.8 - 255 requests
178.128.94.113 - 129 requests
43.224.43.187 - 82 requests
203.0.113.45 - 63 requests

Top 5 most requested paths:

/api/v1/users - 304 requests
/api/v1/products - 218 requests
/api/v1/orders - 117 requests
/login - 93 requests
/api/v1/payments - 80 requests

Top 5 response status codes:

200 - 625 requests
304 - 135 requests
404 - 116 requests
301 - 43 requests
401 - 35 requests

Top 5 user agents:

Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 - 360 requests
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15 - 216 requests
Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0 - 175 requests
curl/8.4.0 - 118 requests
Googlebot/2.1 (+http://www.google.com/bot.html) - 74 requests
```

## Using the official sample log

Download the sample `nginx-access.log` from the [project page](https://roadmap.sh/projects/nginx-log-analyser), save it in `sample/`, then run:

```bash
./scripts/analyse-logs.sh sample/nginx-access.log
```

No real log at hand? Generate one:

```bash
./scripts/generate-sample-log.sh 5000 sample/big.sample.log
```

## How it works (Bash version)

Each section is the same classic pipeline:

```bash
awk -F'"' '{ ...print one value per line... }' access.log \
  | sort          # group identical values together
  | uniq -c       # count each group
  | sort -k1,1nr  # biggest count first
  | head -n 5     # keep the top 5
```

The trick is `awk -F'"'`: splitting on double quotes isolates the quoted fields no matter how many spaces the user agent contains.

| Field | Meaning | What we extract |
|-------|---------|-----------------|
| `$1` | `IP - user [date] ` | first word = IP |
| `$2` | `METHOD /path HTTP/1.1` | second word = path |
| `$3` | ` status size ` | first word = status |
| `$4` | referrer | (not used) |
| `$6` | user agent | whole field |

Quick one-liners for the same answers, handy when you just need a single number on a server:

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -5      # top IPs
awk '{print $7}' access.log | sort | uniq -c | sort -rn | head -5      # top paths
awk '{print $9}' access.log | sort | uniq -c | sort -rn | head -5      # top status codes
cut -d'"' -f6 access.log   | sort | uniq -c | sort -rn | head -5       # top user agents
```

The PowerShell version parses each line with one regex and counts in case-sensitive dictionaries, streaming the file line by line so large logs don't load into memory.

## Tests

```bash
bash tests/test.sh
```

`tests/fixture.log` is a 21-entry log plus one deliberately malformed line. The expected counts in `tests/expected.txt` were counted by hand, so they don't depend on the scripts. The CI workflow runs the Bash tests on Ubuntu and diffs the PowerShell output against the same `expected.txt` on Windows, which keeps both implementations in step.

## Notes

- Ties are ordered alphabetically. Bash uses byte order, PowerShell uses culture order, so tied entries can appear in a different order across the two scripts.
- Paths are reported exactly as logged, including query strings (`/search?q=a` and `/search?q=b` count separately). To merge them in Bash, change the path extractor to strip `?...`.
- Compressed logs: `zcat access.log.gz > /tmp/access.log` first, then analyse the copy.

## Ideas to extend it

- Filter by date range or status class (`5xx` only)
- Requests per hour histogram
- Top referrers
- Output as JSON or CSV
- Read from stdin (`tail -n 10000 access.log | ...`)


