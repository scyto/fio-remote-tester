# FIO Remote Share I/O Tester

A lightweight Bash tool for non-destructive benchmarking of remote filesystems using `fio`.

## Features

- Runs safe, minimal `fio` read/write tests
- Supports CSV, Markdown, and HTML report output
- Automatically logs timestamp and tested path
- Friendly CLI with `--help`
- Output filenames are timestamped for historical comparison

## Requirements

- Linux system with `fio` installed
  ```bash
  sudo apt install fio
  ```

## Usage

```bash
./io-test.sh /mnt/cephfs --output csv markdown html
```

### Options

| Flag           | Description                                 |
|----------------|---------------------------------------------|
| `/path/to/test`| Directory to benchmark                      |
| `--output`     | Followed by any of: `csv`, `markdown`, `html` |
| `--help`, `-h` | Show usage and examples                     |

## Sample Output

```
📊 Summary (from fio-results-2025-04-30_14-10-12.log):
| Test        | Read MB/s  | Write MB/s | Read IOPS | Write IOPS |
|-------------|------------|------------|-----------|------------|
| seqwrite    | 0          | 424MiB/s   | -         | 424        |
| seqread     | 448MiB/s   | 0          | 448       | -          |
| randrw      | 12.0MiB/s  | 5264KiB/s  | 3072      | 1316       |
```

## License

[MIT](LICENSE)
