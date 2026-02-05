use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions

-- Configuration
property calendarName : "📚 CCP (Canvas)"
property vaultPath : "/Users/mygirleatsmayo/Obsidian/mygirleatsmayo_vault"

-- File Paths
property logRelativePath : "/40_School/Admin/canvasCalendarLog.md"
property buslRelativePath : "/40_School/Admin/todoBUSL101.md"
property statRelativePath : "/40_School/Admin/todoECON112.md"
property macroRelativePath : "/40_School/Admin/todoECON181.md"

on run
	set logFile to vaultPath & logRelativePath
	set buslFile to vaultPath & buslRelativePath
	set statFile to vaultPath & statRelativePath
	set macroFile to vaultPath & macroRelativePath
	
	-- Read Log File (Create if missing)
	-- New format: eventID|YYYY-MM-DD per line
	set logContent to ""
	try
		set logContent to do shell script "cat " & quoted form of logFile
	on error
		do shell script "touch " & quoted form of logFile
	end try
	
	-- Parse log into records: {id, date}
	set logRecords to my parseLogRecords(logContent)
	
	-- Buffers for new content
	set buslBuffer to ""
	set statBuffer to ""
	set macroBuffer to ""
	set logBuffer to ""
	set importCount to 0
	set rescheduleCount to 0
	
	tell application "Calendar"
		if not (exists calendar calendarName) then
			display dialog "Calendar '" & calendarName & "' not found." buttons {"OK"} default button "OK" with icon stop
			return
		end if
		
		set todayDate to current date
		set searchStartDate to todayDate - (21 * days) -- 3 weeks in the past
		set endDate to todayDate + (365 * days)
		
		set theEvents to (every event of calendar calendarName whose start date ≥ searchStartDate and start date ≤ endDate)
		
		repeat with anEvent in theEvents
			set evtID to uid of anEvent
			set rawTitle to summary of anEvent
			set evtStart to start date of anEvent
			
			-- Format Date (YYYY-MM-DD)
			set y to year of evtStart
			set m to text -2 thru -1 of ("0" & (month of evtStart as integer))
			set d to text -2 thru -1 of ("0" & (day of evtStart))
			set dateString to (y as string) & "-" & m & "-" & d
			
			-- Format Title (Prettify)
			set cleanTitle to my cleanTitleRegex(rawTitle)
			
			-- Check if event is already logged
			set existingDate to my getDateForID(logRecords, evtID)
			
			if existingDate is "" then
				-- NEW EVENT: Add to buffer
				set taskString to "- [ ] " & cleanTitle & " 📅 " & dateString & linefeed
				
				-- Route to Class Buffer
				if rawTitle contains "BUSL" then
					set buslBuffer to buslBuffer & taskString
					set logBuffer to logBuffer & evtID & "|" & dateString & linefeed
					set importCount to importCount + 1
				else if rawTitle contains "ECON 112" or rawTitle contains "STAT" then
					set statBuffer to statBuffer & taskString
					set logBuffer to logBuffer & evtID & "|" & dateString & linefeed
					set importCount to importCount + 1
				else if rawTitle contains "ECON 181" or rawTitle contains "MACRO" then
					set macroBuffer to macroBuffer & taskString
					set logBuffer to logBuffer & evtID & "|" & dateString & linefeed
					set importCount to importCount + 1
				end if
				
			else if existingDate is not dateString then
				-- RESCHEDULED EVENT: Update in-place
				set targetFile to ""
				if rawTitle contains "BUSL" then
					set targetFile to buslFile
				else if rawTitle contains "ECON 112" or rawTitle contains "STAT" then
					set targetFile to statFile
				else if rawTitle contains "ECON 181" or rawTitle contains "MACRO" then
					set targetFile to macroFile
				end if
				
				if targetFile is not "" then
					-- Build new task line with reschedule note
					set newTaskLine to "- [ ] " & cleanTitle & " (was " & existingDate & ") 📅 " & dateString
					
					-- Update the task file in-place
					my updateTaskDate(targetFile, existingDate, dateString, cleanTitle)
					
					-- Update log entry
					my updateLogEntry(logFile, evtID, dateString)
					
					set rescheduleCount to rescheduleCount + 1
				end if
			end if
			-- If existingDate equals dateString, do nothing (already up to date)
		end repeat
	end tell
	
	-- Write NEW tasks to Files
	if buslBuffer is not "" then
		my appendToFile(buslFile, linefeed & buslBuffer)
	end if
	
	if statBuffer is not "" then
		my appendToFile(statFile, linefeed & statBuffer)
	end if
	
	if macroBuffer is not "" then
		my appendToFile(macroFile, linefeed & macroBuffer)
	end if
	
	if logBuffer is not "" then
		my appendToFile(logFile, linefeed & logBuffer)
	end if
	
	-- Notification
	if importCount > 0 or rescheduleCount > 0 then
		set msg to ""
		if importCount > 0 then
			set msg to "Imported " & importCount & " new"
		end if
		if rescheduleCount > 0 then
			if msg is not "" then set msg to msg & ", "
			set msg to msg & "Updated " & rescheduleCount & " rescheduled"
		end if
		display notification msg & " assignments." with title "Obsidian Calendar Import"
	end if
	
end run

-- Parse log content into list of {id, date} records
on parseLogRecords(logContent)
	set logRecords to {}
	if logContent is "" then return logRecords
	
	set oldDelimiters to AppleScript's text item delimiters
set AppleScript's text item delimiters to linefeed
	set logLines to text items of logContent
	set AppleScript's text item delimiters to oldDelimiters

repeat with aLine in logLines
set lineText to aLine as string
if lineText contains "|" then
set AppleScript's text item delimiters to "|"
			set parts to text items of lineText
			set AppleScript's text item delimiters to oldDelimiters
if (count of parts) ≥ 2 then
set end of logRecords to {id:(item 1 of parts), logDate:(item 2 of parts)}
end if
else if lineText is not "" then
-- Legacy format: ID only (no date) - treat as needing update
set end of logRecords to {id:lineText, logDate:""}
end if
end repeat

return logRecords
end parseLogRecords

-- Get date for a given event ID from log records
on getDateForID(logRecords, targetID)
repeat with rec in logRecords
if (id of rec) is targetID then
return (logDate of rec)
end if
end repeat
return ""
end getDateForID

-- Update task date in-place using sed
on updateTaskDate(filePath, oldDate, newDate, taskTitle)
try
-- Escape special characters in title for sed
set escapedTitle to do shell script "echo " & quoted form of taskTitle & " | sed 's/[&/\\]/\\\\&/g'"

-- Pattern: find line with this date, add reschedule note
-- From: - [ ] Title 📅 OLD_DATE
-- To:   - [ ] Title (was OLD_DATE) 📅 NEW_DATE
set sedCmd to "sed -i '' 's/\\(- \\[[ x]\\] " & escapedTitle & "\\)\\( ([^)]*) \\)\\{0,1\\}📅 " & oldDate & "/\\1 (was " & oldDate & ") 📅 " & newDate & "/g' " & quoted form of filePath

do shell script sedCmd
on error errMsg
-- Silently fail if pattern not found
end try
end updateTaskDate

-- Update log entry with new date
on updateLogEntry(logPath, evtID, newDate)
try
-- Replace old entry with new date
set sedCmd to "sed -i '' 's/^" & evtID & "|.*$/" & evtID & "|" & newDate & "/' " & quoted form of logPath
do shell script sedCmd
on error errMsg
-- If entry doesn't exist in new format, add it
		my appendToFile(logPath, linefeed & evtID & "|" & newDate)
	end try
end updateLogEntry

-- Helper: Remove text inside brackets [ ... ] and pretty print
on cleanTitleRegex(theText)
	try
		set cmd to "echo " & quoted form of theText & " | sed 's/ \\[.*\\]//g' | sed 's/Chapters /Chs. /g' | sed 's/Chapter /Ch. /g' | sed 's/[ -] / /g' | sed 's/  / /g' | sed -E 's/(Ch\\. [0-9]+)[ ]+Ch\\. /\\1 /g' | sed -E 's/([0-9])([A-Z])/\\1 \\2/g' | sed 's/  */ /g'"
		
		set cleanText to do shell script cmd
		return cleanText
	on error
		return theText
	end try
end cleanTitleRegex

-- Helper to append text to file
on appendToFile(thePath, theContent)
	try
		do shell script "printf %s " & quoted form of theContent & " >> " & quoted form of thePath
	on error errMsg
		display dialog "Error writing to file: " & errMsg
	end try
end appendToFile
