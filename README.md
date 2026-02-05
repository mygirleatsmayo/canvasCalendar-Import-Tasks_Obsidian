# Canvas Calendar → Obsidian Task Importer

An AppleScript that imports assignments from your Canvas LMS calendar into Obsidian as actionable tasks.

## Features

- **Setup Wizard** — Interactive configuration on first run
- **Dynamic Classes** — Add as many classes as you need
- **Smart Routing** — Routes tasks to class-specific todo files based on identifier strings
- **Pretty Names** — Optionally remap class IDs to friendly display names
- **Reschedule Detection** — Updates due dates in-place when professors change deadlines
- **Deduplication** — Tracks imported events to prevent duplicates
- **Notifications** — Shows import summary after each run
- **Reconfigure Anytime** — Hold **⌥ Option** key on launch to re-run setup
- **Tasks Plugin Compatible** — Designed to work with [Obsidian Tasks](https://github.com/obsidian-tasks-group/obsidian-tasks) plugin

## Files

```
├── Import_Canvas_Assignments.applescript  # Main script
├── snippets/
│   └── daily-hide-comments.css            # Hide comments in daily notes
└── examples/
    ├── todoClass.md                       # Example todo file format
    └── canvasCalendarLog.md               # Example log file format
```

## Quick Start

### 1. Sync Canvas Calendar to macOS

1. In Canvas, go to **Calendar → Calendar Feed**
2. Copy the iCal URL
3. In macOS Calendar, **File → New Calendar Subscription**
4. Paste the URL and name it (e.g., "📚 Canvas")

### 2. Run the Script

1. Open `Import_Canvas_Assignments.applescript` in Script Editor
2. Click **Run** (▶️)
3. Follow the setup wizard:
   - Select your Canvas calendar
   - Choose your Obsidian vault folder
   - Set up each class with an identifier and todo file
4. Done! The script will import assignments automatically

### 3. Class Identifiers

During setup, enter the string that appears in Canvas event titles:
- **Good:** `ECON 112`, `BUSL 101`, `STAT-201`
- **Bad:** `Economics` (too generic, may match wrong events)

You can optionally set a "pretty name" for display (e.g., "Macroeconomics").

## Usage

After initial setup:
- **Normal run:** Just run the script — it imports and shows notification
- **Reconfigure:** Hold **⌥ Option** while running to re-run setup

## Task Format

Tasks are added like this:
```
- [ ] Ch. 1-3 Reading Quiz 📅 2024-01-15
```

Rescheduled tasks show the original date:
```
- [ ] Midterm Exam (was 2024-02-15) 📅 2024-02-20
```

## CSS Snippet (Optional)

The included `daily-hide-comments.css` hides inline comments in notes with `cssclasses: daily-hide-comments` in frontmatter.

## Config Location

Settings are stored at:
```
~/Library/Preferences/com.canvasCalendarImport.plist
```

To reset, delete this file and re-run the script.

## License

MIT
