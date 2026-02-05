# Canvas Calendar → Obsidian Task Importer

An AppleScript that imports assignments from your Canvas LMS calendar into Obsidian as actionable tasks.

## Features

- **Automatic Import**: Pulls events from a synced Canvas calendar
- **Smart Routing**: Routes tasks to class-specific todo files based on course name
- **Reschedule Detection**: Updates due dates in-place when professors change deadlines
- **Deduplication**: Tracks imported events to prevent duplicates

## Files

```
├── Import_Canvas_Assignments.applescript  # Main script
├── snippets/
│   └── daily-hide-comments.css            # Hide comments in daily notes
└── examples/
    ├── todoClass.md                       # Example todo file format
    └── canvasCalendarLog.md               # Example log file format
```

## Setup

### 1. Sync Canvas Calendar to macOS

1. In Canvas, go to **Calendar → Calendar Feed**
2. Copy the iCal URL
3. In macOS Calendar, **File → New Calendar Subscription**
4. Paste the URL and name it (e.g., "📚 CCP (Canvas)")

### 2. Configure the Script

Edit these properties in the AppleScript:

```applescript
property calendarName : "📚 Your Calendar Name"
property vaultPath : "/path/to/your/vault"

property logRelativePath : "/path/to/canvasCalendarLog.md"
property buslRelativePath : "/path/to/class1Todo.md"
property statRelativePath : "/path/to/class2Todo.md"
property macroRelativePath : "/path/to/class3Todo.md"
```

### 3. Run the Script

- Open in Script Editor and run manually, or
- Use Automator to create a calendar-triggered workflow

## CSS Snippet (Optional)

The included `daily-hide-comments.css` hides inline comments in notes with `cssclasses: daily-hide-comments` in frontmatter. Useful for hiding instructor notes in imported tasks.

## License

MIT
