# 📘 FIO Remote Share I/O Tester

A flexible and cache-aware benchmark script for storage shares using `fio`.

## ✅ Features

- Multiple workload profiles: `default`, `balanced`, `vm`, `webserver`, `stress`
- Automatically clears disk caches if `--clear-cache` is set
- Outputs in CSV, Markdown, and HTML
- Detects and filters test metrics based on access mode (read/write)

## 🔧 Requirements

- Linux system with `fio` installed
- Run as root if using `--clear-cache`
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
| `--clear-cache`   | Clears Linux disk caches between each test.      |

> ⚠️ `--clear-cache` requires root privileges (`sudo`).

## 📂 Profiles
You can specify the following `--profiles` if no profile is specified then default will be used

### 📊 I/O Profile Summary

| Profile     | 🧠 Purpose                       | ⚙️ Workload Pattern & Key Params                              | ✅ Best Suited For                  |
|-------------|----------------------------------|---------------------------------------------------------------|-------------------------------------|
| 🧩 `default`   | General-purpose sanity check     | Sequential + random read/write — 128K blocks, 1 job, iodepth 1 | Baseline performance checks        |
| ⚖️ `balanced`  | Mixed-use system simulation      | Mixed rand/seq R/W — 64K blocks, 2 jobs, iodepth 2             | File servers, general workloads     |
| 🖥️ `vm`        | Virtual machine I/O emulation    | Random I/O — 4K blocks, 4 jobs, iodepth 8                       | Hypervisors, guest VM disks         |
| 🌐 `webserver` | Web server access pattern        | Read-heavy random I/O — 4–16K blocks, 8 jobs, iodepth 16       | Static websites, content delivery   |
| 🔥 `stress`    | Max throughput stress test       | High-parallel R/W — 1M blocks, 8+ jobs, iodepth 32+            | Stress testing SSDs, Ceph, RAID     |


## 📊 Sample Output (Profile: default)

### Markdown Table

| Test          | Read MB/s | Write MB/s | Read IOPS | Write IOPS |
|---------------|-----------|------------|-----------|------------|
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

