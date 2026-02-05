use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions

-- Configuration
property configPath : (POSIX path of (path to preferences folder)) & "com.canvasCalendarImport.plist"

-- ============================================================================
-- MAIN ENTRY POINT
-- ============================================================================
on run
	-- Check if Option key is held (for re-setup)
	set optionDown to false
	try
		set optionDown to (do shell script "python3 -c \"import Quartz; print(Quartz.CGEventSourceFlagsState(Quartz.kCGEventSourceStateCombinedSessionState) & Quartz.kCGEventFlagMaskAlternate)\"") is not "0"
	end try
	
	-- Load config or run setup
	set config to loadConfig()
	
	if config is missing value or optionDown then
		set config to runSetupWizard()
		if config is missing value then return -- User cancelled
		saveConfig(config)
	end if
	
	-- Run import
	set result to runImport(config)
	
	-- Show notification
	set importCount to item 1 of result
	set rescheduleCount to item 2 of result
	showNotification(importCount, rescheduleCount)
end run

-- ============================================================================
-- SETUP WIZARD
-- ============================================================================
on runSetupWizard()
	-- Welcome
	display dialog "Canvas Calendar → Obsidian Importer

This wizard will help you set up:
• Which calendar to import from
• Your Obsidian vault location
• Class identifiers and todo files" buttons {"Cancel", "Begin Setup"} default button "Begin Setup" with title "Setup Wizard" with icon note
	if button returned of result is "Cancel" then return missing value
	
	-- Step 1: Calendar Selection
	set calendarName to selectCalendar()
	if calendarName is missing value then return missing value
	
	-- Step 2: Vault Path
	set vaultPath to selectVaultPath()
	if vaultPath is missing value then return missing value
	
	-- Step 3: Log File
	set logPath to setupLogFile(vaultPath)
	if logPath is missing value then return missing value
	
	-- Step 4: Classes
	set classList to setupClasses(vaultPath)
	if classList is missing value then return missing value
	
	-- Build config
	return {calendarName:calendarName, vaultPath:vaultPath, logPath:logPath, classes:classList}
end runSetupWizard

on selectCalendar()
	tell application "Calendar"
		set calNames to name of every calendar
	end tell
	
	set chosenCal to choose from list calNames with prompt "Select the calendar containing Canvas assignments:" with title "Calendar Selection"
	if chosenCal is false then return missing value
	return item 1 of chosenCal
end selectCalendar

on selectVaultPath()
	set vaultFolder to choose folder with prompt "Select your Obsidian vault folder:"
	if vaultFolder is false then return missing value
	return POSIX path of vaultFolder
end selectVaultPath

on setupLogFile(vaultPath)
	set logFileName to "canvasCalendarLog.md"
	set defaultLogPath to vaultPath & logFileName
	
	display dialog "Log File Setup

The log file tracks imported events to prevent duplicates.

Default location:
" & defaultLogPath buttons {"Cancel", "Use Default", "Choose Location"} default button "Use Default" with title "Log File"
	
	set choice to button returned of result
	if choice is "Cancel" then return missing value
	
	if choice is "Use Default" then
		-- Create if doesn't exist
		do shell script "touch " & quoted form of defaultLogPath
		return defaultLogPath
	else
		set chosenFile to choose file name with prompt "Save log file as:" default name logFileName default location (POSIX file vaultPath as alias)
		return POSIX path of chosenFile
	end if
end setupLogFile

on setupClasses(vaultPath)
	set classList to {}
	set addMore to true
	
	repeat while addMore
		-- Get class identifier
		display dialog "Enter the class identifier string that appears in Canvas event titles.

Examples: ECON 112, BUSL 101, STAT-201

This is used to match events to the correct todo file." default answer "" buttons {"Cancel", "Next"} default button "Next" with title "Class Setup"
		if button returned of result is "Cancel" then return missing value
		set classID to text returned of result
		
		if classID is "" then
			display dialog "Class identifier cannot be empty." buttons {"OK"} with icon stop
		else
			-- Get optional pretty name
			display dialog "Optional: Enter a display name for this class.

Leave blank to use \"" & classID & "\"

Examples: Macroeconomics, Statistics I" default answer "" buttons {"Cancel", "Next"} default button "Next" with title "Display Name"
			if button returned of result is "Cancel" then return missing value
			set prettyName to text returned of result
			if prettyName is "" then set prettyName to classID
			
			-- Get todo file
			set todoPath to setupTodoFile(vaultPath, prettyName)
			if todoPath is missing value then return missing value
			
			-- Add to list
			set end of classList to {identifier:classID, displayName:prettyName, todoPath:todoPath}
			
			-- Add another?
			display dialog "Class \"" & prettyName & "\" configured.

Add another class?" buttons {"Done", "Add Another"} default button "Add Another" with title "Class Setup"
			if button returned of result is "Done" then set addMore to false
		end if
	end repeat
	
	return classList
end setupClasses

on setupTodoFile(vaultPath, className)
	display dialog "Todo file for " & className & ":" buttons {"Cancel", "Create New", "Select Existing"} default button "Create New" with title "Todo File"
	
	set choice to button returned of result
	if choice is "Cancel" then return missing value
	
	if choice is "Create New" then
		set defaultName to "todo" & my sanitizeFilename(className) & ".md"
		set newFile to choose file name with prompt "Create todo file for " & className & ":" default name defaultName default location (POSIX file vaultPath as alias)
		set newPath to POSIX path of newFile
		-- Create with header
		do shell script "echo '# " & className & " Assignments\n' > " & quoted form of newPath
		return newPath
	else
		set existingFile to choose file with prompt "Select existing todo file for " & className & ":" of type {"md", "txt"}
		return POSIX path of existingFile
	end if
end setupTodoFile

on sanitizeFilename(theText)
	set cleanText to do shell script "echo " & quoted form of theText & " | sed 's/[^a-zA-Z0-9]//g'"
	return cleanText
end sanitizeFilename

-- ============================================================================
-- CONFIG STORAGE
-- ============================================================================
on loadConfig()
	try
		set configData to do shell script "defaults read " & quoted form of configPath & " 2>/dev/null"
		-- Parse plist into record (simplified: read individual keys)
		set calendarName to do shell script "defaults read " & quoted form of configPath & " calendarName"
		set vaultPath to do shell script "defaults read " & quoted form of configPath & " vaultPath"
		set logPath to do shell script "defaults read " & quoted form of configPath & " logPath"
		set classCount to (do shell script "defaults read " & quoted form of configPath & " classCount") as integer
		
		set classList to {}
		repeat with i from 0 to (classCount - 1)
			set classID to do shell script "defaults read " & quoted form of configPath & " class" & i & "_identifier"
			set displayName to do shell script "defaults read " & quoted form of configPath & " class" & i & "_displayName"
			set todoPath to do shell script "defaults read " & quoted form of configPath & " class" & i & "_todoPath"
			set end of classList to {identifier:classID, displayName:displayName, todoPath:todoPath}
		end repeat
		
		return {calendarName:calendarName, vaultPath:vaultPath, logPath:logPath, classes:classList}
	on error
		return missing value
	end try
end loadConfig

on saveConfig(config)
	-- Write each key
	do shell script "defaults write " & quoted form of configPath & " calendarName " & quoted form of (calendarName of config)
	do shell script "defaults write " & quoted form of configPath & " vaultPath " & quoted form of (vaultPath of config)
	do shell script "defaults write " & quoted form of configPath & " logPath " & quoted form of (logPath of config)
	
	set classList to classes of config
	do shell script "defaults write " & quoted form of configPath & " classCount -int " & (count of classList)
	
	repeat with i from 1 to count of classList
		set classItem to item i of classList
		set idx to (i - 1)
		do shell script "defaults write " & quoted form of configPath & " class" & idx & "_identifier " & quoted form of (identifier of classItem)
		do shell script "defaults write " & quoted form of configPath & " class" & idx & "_displayName " & quoted form of (displayName of classItem)
		do shell script "defaults write " & quoted form of configPath & " class" & idx & "_todoPath " & quoted form of (todoPath of classItem)
	end repeat
end saveConfig

-- ============================================================================
-- IMPORT LOGIC
-- ============================================================================
on runImport(config)
	set logFile to logPath of config
	set classList to classes of config
	
	-- Read Log File
	set logContent to ""
	try
		set logContent to do shell script "cat " & quoted form of logFile
	on error
		do shell script "touch " & quoted form of logFile
	end try
	
	-- Parse log records
	set logRecords to parseLogRecords(logContent)
	
	-- Initialize buffers for each class
	set classBuffers to {}
	repeat with classItem in classList
		set end of classBuffers to {classRef:classItem, buffer:""}
	end repeat
	
	set logBuffer to ""
	set importCount to 0
	set rescheduleCount to 0
	
	tell application "Calendar"
		if not (exists calendar (calendarName of config)) then
			display dialog "Calendar '" & (calendarName of config) & "' not found." buttons {"OK"} default button "OK" with icon stop
			return {0, 0}
		end if
		
		set todayDate to current date
		set searchStartDate to todayDate - (21 * days)
		set endDate to todayDate + (365 * days)
		
		set theEvents to (every event of calendar (calendarName of config) whose start date ≥ searchStartDate and start date ≤ endDate)
		
		repeat with anEvent in theEvents
			set evtID to uid of anEvent
			set rawTitle to summary of anEvent
			set evtStart to start date of anEvent
			
			-- Format Date (YYYY-MM-DD)
			set y to year of evtStart
			set m to text -2 thru -1 of ("0" & (month of evtStart as integer))
			set d to text -2 thru -1 of ("0" & (day of evtStart))
			set dateString to (y as string) & "-" & m & "-" & d
			
			-- Clean title
			set cleanTitle to my cleanTitleRegex(rawTitle)
			
			-- Check existing
			set existingDate to my getDateForID(logRecords, evtID)
			
			-- Find matching class
			set matchedClass to missing value
			set matchedBuffer to missing value
			repeat with i from 1 to count of classBuffers
				set bufferItem to item i of classBuffers
				set classItem to classRef of bufferItem
				if rawTitle contains (identifier of classItem) then
					set matchedClass to classItem
					set matchedBuffer to i
					exit repeat
				end if
			end repeat
			
			if matchedClass is not missing value then
				if existingDate is "" then
					-- NEW EVENT
					set taskString to "- [ ] " & cleanTitle & " 📅 " & dateString & linefeed
					set buffer of (item matchedBuffer of classBuffers) to (buffer of (item matchedBuffer of classBuffers)) & taskString
					set logBuffer to logBuffer & evtID & "|" & dateString & linefeed
					set importCount to importCount + 1
				else if existingDate is not dateString then
					-- RESCHEDULED
					my updateTaskDate(todoPath of matchedClass, existingDate, dateString, cleanTitle)
					my updateLogEntry(logFile, evtID, dateString)
					set rescheduleCount to rescheduleCount + 1
				end if
			end if
		end repeat
	end tell
	
	-- Write buffers to files
	repeat with bufferItem in classBuffers
		if (buffer of bufferItem) is not "" then
			my appendToFile(todoPath of (classRef of bufferItem), linefeed & (buffer of bufferItem))
		end if
	end repeat
	
	if logBuffer is not "" then
		my appendToFile(logFile, linefeed & logBuffer)
	end if
	
	return {importCount, rescheduleCount}
end runImport

-- ============================================================================
-- NOTIFICATION
-- ============================================================================
on showNotification(importCount, rescheduleCount)
	set msg to ""
	
	if importCount is 0 and rescheduleCount is 0 then
		set msg to "No new assignments."
	else
		if importCount > 0 then
			set msg to "Imported " & importCount & " new"
		end if
		if rescheduleCount > 0 then
			if msg is not "" then set msg to msg & ", "
			set msg to msg & "updated " & rescheduleCount & " rescheduled"
		end if
		set msg to msg & " assignment"
		if (importCount + rescheduleCount) > 1 then set msg to msg & "s"
		set msg to msg & "."
	end if
	
	display notification msg with title "Canvas Import" subtitle "Hold ⌥ Option to reconfigure"
end showNotification

-- ============================================================================
-- HELPERS (from original)
-- ============================================================================
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
			set end of logRecords to {id:lineText, logDate:""}
		end if
	end repeat
	
	return logRecords
end parseLogRecords

on getDateForID(logRecords, targetID)
	repeat with rec in logRecords
		if (id of rec) is targetID then
			return (logDate of rec)
		end if
	end repeat
	return ""
end getDateForID

on updateTaskDate(filePath, oldDate, newDate, taskTitle)
	try
		set escapedTitle to do shell script "echo " & quoted form of taskTitle & " | sed 's/[&/\\]/\\\\&/g'"
		set sedCmd to "sed -i '' 's/\\(- \\[[ x]\\] " & escapedTitle & "\\)\\( ([^)]*) \\)\\{0,1\\}📅 " & oldDate & "/\\1 (was " & oldDate & ") 📅 " & newDate & "/g' " & quoted form of filePath
		do shell script sedCmd
	end try
end updateTaskDate

on updateLogEntry(logPath, evtID, newDate)
	try
		set sedCmd to "sed -i '' 's/^" & evtID & "|.*$/" & evtID & "|" & newDate & "/' " & quoted form of logPath
		do shell script sedCmd
	on error
		my appendToFile(logPath, linefeed & evtID & "|" & newDate)
	end try
end updateLogEntry

on cleanTitleRegex(theText)
	try
		set cmd to "echo " & quoted form of theText & " | sed 's/ \\[.*\\]//g' | sed 's/Chapters /Chs. /g' | sed 's/Chapter /Ch. /g' | sed 's/[ -] / /g' | sed 's/  / /g' | sed -E 's/(Ch\\. [0-9]+)[ ]+Ch\\. /\\1 /g' | sed -E 's/([0-9])([A-Z])/\\1 \\2/g' | sed 's/  */ /g'"
		return do shell script cmd
	on error
		return theText
	end try
end cleanTitleRegex

on appendToFile(thePath, theContent)
	try
		do shell script "printf %s " & quoted form of theContent & " >> " & quoted form of thePath
	on error errMsg
		display dialog "Error writing to file: " & errMsg
	end try
end appendToFile
