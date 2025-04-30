# 🚀 FIO Remote Share I/O Tester

A Bash script to benchmark remote or local filesystems using `fio`. Generates results in plain text, CSV, Markdown, and HTML.

---

## 🛠️ Requirements

- `fio` (install via `sudo apt install fio`)
- Bash shell

---

## 📦 Usage

```bash
./io-test.sh /mount/point [--profile PROFILE] [--output FORMAT...]
```

### Examples

```bash
# Run default tests with markdown and HTML output
./io-test.sh /mnt/cephfs --output markdown html

# Test with VM workload and CSV output
./io-test.sh /mnt/cephfs --profile vm --output csv

# All formats
./io-test.sh /mnt/cephfs --profile stress --output markdown html csv
```

---

## 📋 Profiles

| Profile    | Description                                      |
|------------|--------------------------------------------------|
| `default`  | Basic seq read/write and mixed random workload   |
| `balanced` | Mixed I/O depths and block sizes for general use |
| `vm`       | Emulates virtual machine disk patterns           |
| `webserver`| I/O pattern optimized for web workloads          |
| `stress`   | Heavy random mixed reads/writes                  |

---

## 📤 Output

Each run generates:

- `fio-results-<timestamp>.log` – full raw log
- `fio-summary-<timestamp>.txt` – readable table
- `fio-summary-<timestamp>.csv` – for Excel/Google Sheets
- `fio-summary-<timestamp>.md` – for GitHub-style Markdown
- `fio-summary-<timestamp>.html` – for direct browser viewing

---

## 📎 Sample Markdown Output

```
| Test        | Read MB/s  | Write MB/s | Read IOPS | Write IOPS |
|-------------|------------|------------|-----------|------------|
| seqread     | 431MiB/s   | 0          | 110335    | -          |
| seqwrite    | 0          | 393MiB/s   | -         | 100608     |
```

---

## 🧹 Clean-Up

Temporary files are deleted after each run. Only summaries and logs are retained.

---

## 🧑‍💻 Author

Created by [You]. Contributions welcome!
