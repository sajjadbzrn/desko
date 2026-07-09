# desko

A beautiful task manager CLI for your terminal. Add, complete, and track tasks with priorities, progress bars, and colorful output — right from the command line.

![Bun](https://img.shields.io/badge/Built_with-Bun-14b8a6?style=flat-square)
![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178c6?style=flat-square)

## Features

- **Priority levels** — Tag tasks as `low`, `medium`, or `high`
- **Filtering** — View all, pending, or completed tasks
- **Statistics** — Progress bar, badges, and breakdown by priority
- **Relative timestamps** — See how old tasks are at a glance
- **Beautiful terminal UI** — Powered by [ansimax](https://www.npmjs.com/package/ansimax) — gradients, tables, and status badges
- **Fast** — Built on [Bun](https://bun.sh) for instant startup
- **Persistent storage** — Tasks saved in `~/.desko/tasks.json`

## Install

### One-liner (recommended)

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.sh | sh
```

**Windows** (PowerShell)
```powershell
irm https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.ps1 | iex
```

The installer will download the right binary for your platform, place it in `~/.desko/bin/`, and add it to your PATH.

### Manual download

Pre-built binaries are available for **Windows**, **macOS**, and **Linux** on the [Releases](https://github.com/sajjadbzrn/desko/releases) page.

| Platform | Download |
| -------- | -------- |
| **Windows** (x64) | `desko-windows-x64.exe` |
| **macOS** (Apple Silicon) | `desko-macos-arm64` |
| **macOS** (Intel) | `desko-macos-x64` |
| **Linux** (x64) | `desko-linux-x64` |

After downloading, add the binary to your `PATH` or run it directly:

```bash
# macOS / Linux — make executable and move to PATH
chmod +x desko-macos-arm64
mv desko-macos-arm64 /usr/local/bin/desko

# Windows — move to a folder in your PATH
desko-windows-x64.exe --version
```

### Build from source

```bash
# Clone the repository
git clone https://github.com/sajjadbzrn/desko.git
cd desko

# Install dependencies
bun install

# Build a standalone binary
bun run build
```

## Usage

### Add a task

```bash
bun run start add "Write the documentation"
bun run start add "Fix the login bug" --priority high
```

Priority defaults to `medium`. Use `-p low`, `-p medium`, or `-p high`.

### List tasks

```bash
bun run start list          # all tasks
bun run start list --pending  # pending only
bun run start list --done     # completed only
bun run start ls            # alias
```

### Complete a task

```bash
bun run start complete 1    # mark task #1 as done
bun run start done 1        # alias
```

### Reopen a task

```bash
bun run start reopen 1      # reopen task #1
```

### Delete a task

```bash
bun run start delete 1      # remove task #1
bun run start rm 1          # alias
```

### Clear completed tasks

```bash
bun run start clear         # remove all completed tasks
```

### View statistics

```bash
bun run start stats         # progress bar and priority breakdown
```

## Commands Reference

| Command             | Alias  | Description                        |
| ------------------- | ------ | ---------------------------------- |
| `add <description>` | —      | Add a new task (`-p` for priority) |
| `list`              | `ls`   | List tasks (`--pending`, `--done`) |
| `complete <id>`     | `done` | Mark a task as done                |
| `reopen <id>`       | —      | Reopen a completed task            |
| `delete <id>`       | `rm`   | Delete a task                      |
| `clear`             | —      | Remove all completed tasks         |
| `stats`             | —      | Show task statistics               |

## Development

```bash
# Run in watch mode
bun run dev

# Build a standalone binary (outputs ./desko)
bun run build

# Run directly
bun run start
```

## Tech Stack

- [Bun](https://bun.sh) — JavaScript runtime and package manager
- [Commander](https://www.npmjs.com/package/commander) — CLI argument parsing
- [ansimax](https://www.npmjs.com/package/ansimax) — Terminal styling, ASCII art, tables, and gradients

## Storage

Tasks are stored at `~/.desko/tasks.json`. Delete this file to reset all tasks.
