# 📘 FIO I/O - Repeatable Simplified Test Script

A flexible and cache-aware benchmark script for storage shares using `fio`.

## ✅ Features

- Multiple workload profiles: `default`, `balanced`, `vm`, `webserver`, `stress`
- Automatically clears disk caches if `--clear-cache` is set
- Outputs in `CSV`, `Markdown`, and `HTML` or `all`
- Detects and filters test metrics based on access mode (read/write)

## 🔧 Requirements & Install

- Linux system with `fio` installed
- Run as root if using `--clear-cache`
- Dowload and set executable
```
cd ~ && wget https://raw.githubusercontent.com/scyto/fio-test-script/refs/heads/main/io-test.sh && chmod +x io-test.sh
```
- Download and remember to `chmod +x io-test.sh`

## 🧪 Example Usage

```bash
./io-test.sh /mnt/test --output markdown html
```
> this would run the default test and output to text file, markdown file and html table fragment

### 🔧 Options

| Option            | Description                                      |
|-------------------|--------------------------------------------------|
| `--profile`       | Selects which profile directory of tests to run (see bellow) |
| `--output`        | One or more output formats: `html`, `markdown`, `csv`. |
| `--clear-cache`   | Clears Linux disk caches between each test.<br> and runs each FIO tests with `--direct=1`, `--invlidate=1`    |

> ⚠️ `--clear-cache` requires root privileges (`sudo`).

## 📂 Workload Profiles
You can specify the following `--profiles` if no profile is specified then default will be used

### 📊 I/O Profile Summary
A  note on these profiles, i am not actuallu claiming ANY of these are good or representative of real workloads, if you want to see the exact params please look in the code.
I may take suggestions on tweaking these to make the test params more representative of a real workload.  For now these are what chatGPT generated for me.

| Profile     | 🧠 Purpose                       | ⚙️ Workload Pattern & Key Params                              | ✅ Best Suited For                  |
|-------------|----------------------------------|---------------------------------------------------------------|-------------------------------------|
| 🧩 `default`   | General-purpose sanity check     | Sequential + random read/write — 128K blocks, 1 job, iodepth 1 | Baseline performance checks        |
| ⚖️ `balanced`  | Mixed-use system simulation      | Mixed rand/seq R/W — 64K blocks, 2 jobs, iodepth 2             | File servers, general workloads     |
| 🖥️ `vm`        | Virtual machine I/O emulation    | Random I/O — 4K blocks, 4 jobs, iodepth 8                       | Hypervisors, guest VM disks         |
| 🌐 `webserver` | Web server access pattern        | Read-heavy random I/O — 4–16K blocks, 8 jobs, iodepth 16       | Static websites, content delivery   |
| 🔥 `stress`    | Max throughput stress test       | High-parallel R/W — 1M blocks, 8+ jobs, iodepth 32+            | Stress testing SSDs, Ceph, RAID     |


## 📊 Sample Output (Profile: default)

### Markdown Table

| Test         | Read MB/s | Write MB/s | Read IOPS | Write IOPS |
|--------------|-----------|------------|-----------|------------|
| seqwrite-1M  | 310MiB/s  | 0          | -         | 310        |
| seqread-1M   | 420MiB/s  | 0          | 420       | -          |
| randrw-4k    | 12MiB/s   | 11MiB/s    | 3000      | 2800       |

### CSV Format

```
Test,Read MB/s,Write MB/s,Read IOPS,Write IOPS,Path,Timestamp,Profile
seqwrite-1M,0,310MiB/s,-,310,/mnt/test,2025-04-30_17-00-00,default
seqread-1M,420MiB/s,0,420,-,/mnt/test,2025-04-30_17-00-00,default
randrw-4k,12MiB/s,11MiB/s,3000,2800,/mnt/test,2025-04-30_17-00-00,default
```

# 📝 Output Files Created by `io-test.sh` In Detail

When the script runs, it generates a set of output files summarizing the test results. These files are named using a timestamp for uniqueness and traceability.

## 🗂️ File Summary

| Filename Example                             | Description                                                      | Created When                |
|---------------------------------------------|------------------------------------------------------------------|-----------------------------|
| `fio-results-2025-04-30_15-45-30.log`        | **Raw log** of all `fio` test runs, full output per test         | Always                      |
| `fio-summary-2025-04-30_15-45-30.txt`        | **Human-readable summary** in plain text with aligned columns    | Always                      |
| `fio-summary-2025-04-30_15-45-30.csv`        | Summary in **CSV format** for spreadsheets or scripting          | If `--output csv` or `all` |
| `fio-summary-2025-04-30_15-45-30.md`         | Summary in **Markdown table** format                             | If `--output markdown` or `all` |
| `fio-summary-2025-04-30_15-45-30.html`       | Summary in **HTML table** format for web display                 | If `--output html` or `all` |

## 🧹 Optional Cleanup

If the `--output none` flag is used:

- All of the above files will be **deleted at the end of the run**
- A message will confirm:
  ```
  🗑️ Deleting log and summary files as '--output none' was specified.
  ```

## 📌 Notes

- Timestamp format: `YYYY-MM-DD_HH-MM-SS`
- Files are created in the **current working directory** (not the test target directory)
- The test files themselves (`testfile-*.tmp`) are automatically removed after each run

# Use of AI
I am not a programmer, lilke not in the least.  The script was 100% created with AI.  The README.md about 75% with AI.
It wasn't painfree and took around 5 hours.  Much of this time me arguing with chatGPT that the zip files it kept gving me only contained truncated versions of files.  I made it pink swear it would stop doing that, it kept breaking that promise. towards the end i would use github copilot to validate changes chatgpt was telling me to do based on my request for change or a new requirement.  I am impressed with what i ended up with, espeically with all the error handling for bad command line syntax of options.  It even handles dumb cases like still telling you help if you do --someoption --help. 

If folks what to see where this started here is the initial chat, i had to more seperate chats when this chat became unreliable https://chatgpt.com/share/6812d574-f220-800d-bfe6-33110eace4cb 