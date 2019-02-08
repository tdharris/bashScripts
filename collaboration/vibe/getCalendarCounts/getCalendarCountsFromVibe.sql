-- ------------------------------------------------------------------------------
-- Authors: 
-- Tyler Harris, Shane Nielson
-- 
-- Purpose: 
-- Get events & attendees counts from a Vibe calendar for a specific date range
-- 
-- Assumptions: 
-- 	-attendee teams & groups will be ignored in counts
-- 
-- Tip for executing:
-- # mysql -u<user> -p -t < getCalendarCountsFromVibe.sql > getCalendarCountsFromVibe.txt
-- Report output can be found in getCalendarCountsFromVibe.txt
-- ------------------------------------------------------------------------------

-- Set variables
-- Note: Only change year and month for startDate and endDate. Day value needs to be % since query uses LIKE.
SET @lv_input_startDate := '2016-05-%'; 
SET @lv_input_endDate := '2016-05-%';
SET @lv_input_calendarPathName := '/Novell Workspaces/Team Workspaces/Services/Global Technical Support/Technical Training Resources/Calendar';

-- Use database
use sitescape;

-- Get total count of events
SELECT count(e.id) AS 'TotalCountOfEvents'
FROM SS_Forums f 
INNER JOIN SS_Events e ON f.id = e.owningBinderId
INNER JOIN SS_FolderEntries fe ON e.ownerId = fe.id
WHERE f.pathName = @lv_input_calendarPathName
AND e.dtStart LIKE @lv_input_startDate AND e.dtEnd LIKE @lv_input_endDate;

-- List of events and a count of their attendees
SELECT  fe.title,
		(LENGTH(TRIM(BOTH ',' FROM ca.stringValue)) - LENGTH(REPLACE(TRIM(BOTH ',' FROM ca.stringValue), ',', '')) + 1) as attendee_count,
		e.dtStart,
		e.dtEnd,
		fe.description_text,
		fe.creation_date,
		ca.name,
		ca.stringValue
	FROM SS_Forums f 
	INNER JOIN SS_Events e ON f.id = e.owningBinderId
	INNER JOIN SS_FolderEntries fe ON e.ownerId = fe.id
	INNER JOIN SS_CustomAttributes ca ON ca.folderEntry = e.folderEntry
	WHERE f.pathName = @lv_input_calendarPathName
	AND e.dtStart LIKE @lv_input_startDate AND e.dtEnd LIKE @lv_input_endDate
	AND ca.name = 'attendee'
	AND (ca.name IS NOT NULL AND ca.name != '');

-- Get total count of attendees
Select
	@lv_input_startDate AS 'StartDate',
	@lv_input_endDate AS 'EndDate',
	SUM(attendee_count) AS 'TotalAttendeeCount'
FROM (
	SELECT 
		fe.title,
		e.id,
		e.dtStart,
		e.dtEnd,
		fe.description_text,
		fe.creation_date,
		ca.name,
		ca.stringValue,
		(LENGTH(TRIM(BOTH ',' FROM ca.stringValue)) - LENGTH(REPLACE(TRIM(BOTH ',' FROM ca.stringValue), ',', '')) + 1) as attendee_count
	FROM SS_Forums f 
	INNER JOIN SS_Events e ON f.id = e.owningBinderId
	INNER JOIN SS_FolderEntries fe ON e.ownerId = fe.id
	INNER JOIN SS_CustomAttributes ca ON ca.folderEntry = e.folderEntry
	WHERE f.pathName = @lv_input_calendarPathName
	AND e.dtStart LIKE @lv_input_startDate AND e.dtEnd LIKE @lv_input_endDate
	AND ca.name = 'attendee'
	AND (ca.name IS NOT NULL AND ca.name != '')	
) a