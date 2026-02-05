# Canvas Calendar Log Example

This file tracks which events have been imported to prevent duplicates.

## Format

Each line contains: `EVENT_UID|YYYY-MM-DD`

The script uses this to:
1. Skip already-imported events
2. Detect rescheduled events (same UID, different date)

## Example

ABC123-DEF456|2024-01-15
GHI789-JKL012|2024-02-20
