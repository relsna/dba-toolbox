DECLARE @tracepath nvarchar(260)

SELECT @tracepath = path 
FROM sys.traces 
WHERE is_default = 1

SELECT g.DatabaseName AS DBName
, mf.physical_name AS DBFileName
, CASE mf.type WHEN 0 THEN 'Row' WHEN 1 THEN 'Log' WHEN 2 THEN 'FILESTREAM' WHEN 4 THEN 'Full-text' END AS FileType
, te.name AS EventName
,  convert(decimal(19,2),g.IntegerData*8/1024.)  AS AutoGrowSize
, g.StartTime
, convert(decimal(19,2),g.Duration/1000./1000.) AS EventDuration -- Length of time necessary to extend the file.
, CASE WHEN mf.is_percent_growth = 1 THEN CONVERT(char(2), mf.growth) + '%'
ELSE CONVERT(varchar(30), convert(decimal(19,2), mf.growth*8./1024.)) + 'MB' END AutoGrowSizeSetting
, convert(decimal(19,2),mf.size* 8./1024.) AS fileSize
, CASE WHEN mf.max_size = -1 THEN 'Unlimited' ELSE convert(varchar(30), convert(decimal(19,2),mf.max_size*8./1024.)) END AS maxFileSize
FROM fn_trace_gettable(@tracepath, default) g
cross apply sys.trace_events te 
inner join sys.master_files mf
on mf.database_id = g.DatabaseID
and g.FileName = mf.name
WHERE g.eventclass = te.trace_event_id
and te.name in ('Data File Auto Grow','Log File Auto Grow')
--GROUP BY StartTime,Databaseid, Filename, IntegerData, Duration
order by StartTime desc