param (
    [string]$EmailSender = "Pass Email address",
    [string]$ServerInstance = "Pass server name",
    [string]$SqlUser = "SQL user name for sql authentication",
    [string]$SqlPassword = "",
    [string]$smtpserver = "Enter SMTP Server here fo emails"
    )

#+-------------------------------------------------------------------+    
#| = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = |    
#|{>/-------------------------------------------------------------\<}| 
#|: | Script Name: SQLHealthCheck.ps1                               | 
#|: | Author:  Prakash Heda                                          | 
#|: | Email:   Pheda@advent.com	 Blog:www.sqlfeatures.com   		 |
#|: | Purpose: Collect and Consolidated SQL server Health            |
#|: | 			Check Information 	 								 |
#|: | 							 	 								 |
#|: |Date       Version ModifiedBy    Change 						 |
#|: |05-16-2015 1.0     Prakash Heda  Initial version                |
#|: |07-25-2015 1.1     Prakash Heda  Additional checks added        |
#|: |01-07-2016 1.2     Prakash Heda  Support added for SQL 2016     |
#|: |03-02-2016 1.3     Prakash Heda  Eamil support added            |
#|: |06-02-2016 2.0     Prakash Heda  multiple bug fixes             |
#|: |07-22-2016 2.1     Prakash Heda  multiple bug fixes             |
#|: |03-31-2017 3.0     Prakash Heda  Enhanced logging and fixes     |
#|{>\-------------------------------------------------------------/<}|  
#| = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = |  
#+-------------------------------------------------------------------+  


$ScriptDir =  split-path -parent $MyInvocation.MyCommand.Path

    cls

    $readIntent =$true
# Import common function module
Import-Module $ScriptDir\CommonModule.ps1

    $Logtime=Get-Date -format "yyyyMMddHHmmss"
    $LogPath= join-path $ScriptDir -ChildPath "pslogs"
    if(!(test-path $LogPath)){[IO.Directory]::CreateDirectory($LogPath)}

    $ScriptNameWithoutExt=[system.io.path]::GetFilenameWithoutExtension($MyInvocation.MyCommand.Path)
    $CentralHost=${$env:COMPUTERNAME}

"Get Host name and Instance name"
    $SQlInstanceName =$null
    $FullSQlInstance =$null
    $lHostNameShort=$null
    
    IF (($ServerInstance.split("\")| measure).count -gt 1)
    {
        $SQlInstanceName = $($ServerInstance.Split('\') | Select-Object -last 1)
        $lHostName= $($ServerInstance.Split('\') | Select-Object -First 1)
    }
    else
    {
        $lHostName= $ServerInstance
    }

    IF (($lHostName.split(".")| measure).count -gt 1)
    {
        $lHostNameShort= $lHostName.trim().Split('.') | Select-Object -first 1
        $lHostNameFull= $lHostName
    }
    else
    {
        $lHostNameShort= $lHostName
    }

    Try{
            if ($lHostNameFull -eq $null)
            {
                $fqdn=(Resolve-DnsName $lHostName -Type A).Name | select -first 1
                $lHostNameFull=$fqdn
            }
        }
    catch
        {
            "Not able to get DNS server name for: $lHostName "| write-PHLog  -echo -Logtype Debug2
            $_.exception.message | write-PHLog  -echo -Logtype Debug2
            $emailSubject=$lHostName + ": Could not resolve server name - $((Get-Date).ToShortDateString())  $((Get-Date).ToShortTimeString())" 
            $RetsqlConfigHTML="Pass FQDN for server name"
            fnSendEmail -FromEmail  $EmailSender -EmailHTML $RetsqlConfigHTML -emailSubject $emailSubject -HostName $CentralHost
            exit
        }

    if ($SQlInstanceName -eq $null)
    {
        $FullSQlInstance = $lHostNameFull
    }
    else
    {
        $FullSQlInstance = $lHostNameShort + "\" + $SQlInstanceName 
    }

    $ExecutionSummaryLogFile=$LogPath + "\" + $lHostNameShort + "_" +$ScriptNameWithoutExt + "_" + $Logtime + ".html"


"Starting run for Hostname: $lHostNameFull `n  SQL connection name: $FullSQlInstance"| write-PHLog -Logtype Success
"`nServerInstance: $ServerInstance `nSQlInstanceName: $SQlInstanceName `nlHostNameShort: $lHostNameShort `nlHostNameFull: $lHostNameFull `nFullSQlInstance: $FullSQlInstance`n" | write-PHLog -Logtype Debug

$Observation=@()
$AppErrorCollection=@()

$queryToCheckSQLAccess="select @@servername as Servername,@@version as Sqlversion"


$RetCheckSQlAccess = fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $queryToCheckSQLAccess
$RetCheckSQlAccess 

if ($RetCheckSQlAccess.TestSqlAcces -eq $false) 
{
    $FailedConnection= [pscustomobject] @{
        Hostname=$lHostName
        ServerInstance=$FullSQlInstance
        FailedConnection="SQL Access failed for Connection, please try connecting to  $FullSQlInstance manually"
        ErrorMessage=$RetCheckSQlAccess.ExecuteSQLError
        }
    $FailedConnection | write-PHLog -echo -Logtype Warning
    $FailedConnection.ErrorMessage | write-PHLog -echo -Logtype Warning
    "Verify connecting to ServerInstance $($FailedConnection.ServerInstance) manually via SSMS"| write-PHLog -echo -Logtype Error
    "Verify telnet command to check sql port: telnet $lHostName 1433"| write-PHLog -echo -Logtype Error
    $emailSubject=$FullSQlInstance + ": Could not connect to SQL instance $FullSQlInstance - $((Get-Date).ToShortDateString())  $((Get-Date).ToShortTimeString())" 
    $RetsqlConfigHTML= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    fnSendEmail -FromEmail  $EmailSender -EmailHTML $RetsqlConfigHTML -emailSubject $emailSubject -HostName "AALLINONEE1" -smtpserver $smtpserver
    exit
}



"Collect SQL instnce related information" | write-PHLog -echo -Logtype Debug2
$QuerySystemSummary= 
"
Declare @SQLServer_UpTime datetime,@Machine_UpTime datetime
SELECT  @SQLServer_UpTime=login_time   
,@Machine_UpTime =DATEADD(s,((-1)*([ms_ticks]/1000)), CURRENT_TIMESTAMP)
FROM sys.dm_exec_sessions cross join sys.dm_os_sys_info
WHERE session_id = 1

	declare @OS varchar(200)
	select @os= substring(@@version,charindex('Microsoft Corporation',@@version)+23,len(@@version))
	select @os = replace(@os,'Windows NT 5.2','Windows 2003 R2')
	SELECT     
		CONVERT(varchar(100), SERVERPROPERTY('Servername')) AS ServerVersion
		,CONVERT(varchar(100), @@version) AS Server
		,@Machine_UpTime as Machine_UpTime 
		,@SQLServer_UpTime as SQLServer_UpTime 
		,@OS as OperatingSystem
		,CONVERT(varchar(100), SERVERPROPERTY('ProductVersion')) AS ProductVersion
		,CONVERT(varchar(100), SERVERPROPERTY('ProductLevel')) AS ProductLevel
		,CASE 
			WHEN SERVERPROPERTY('EngineEdition') = 1 
				THEN 'Personal Edition' 
			WHEN SERVERPROPERTY('EngineEdition') = 2 
				THEN 'Standard Edition' 
			WHEN SERVERPROPERTY('EngineEdition') = 3 
				THEN 'Enterprise Edition' 
			WHEN SERVERPROPERTY('EngineEdition') = 4 
				THEN 'Express Edition' END AS EngineEdition
		,isnull(CONVERT(varchar(100), SERVERPROPERTY('InstanceName')),'Default') AS InstanceName
		,CONVERT(varchar(100), SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS ComputerNamePhysicalNetBIOS
		,CONVERT(varchar(100), SERVERPROPERTY('Collation')) AS Collation
			, CASE 
				WHEN CONVERT(varchar(100),SERVERPROPERTY('IsClustered')) = 1 
					THEN 'Clustered' 
				WHEN SERVERPROPERTY('IsClustered') = 0 
					THEN 'Not Clustered' 
				WHEN SERVERPROPERTY('IsClustered') = NULL 
					THEN 'Error' END AS IsClustered
			,CASE 
				WHEN CONVERT(varchar(100),SERVERPROPERTY('IsFullTextInstalled')) = 1 
					THEN 'Full-text is installed' 
				WHEN SERVERPROPERTY('IsFullTextInstalled') = 0 
					THEN 'Full-text is not installed' 
				WHEN SERVERPROPERTY('IsFullTextInstalled') = NULL 
					THEN 'Error' END AS IsFullTextInstalled
            , isnull(serverproperty('IsHadrEnabled'),0) as IsHadrEnabled
            , (select count(1) from master.sys.database_mirroring_endpoints ) as MirroringEnabled

" 
	$RetSystemSummary = fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerySystemSummary 

if ($RetSystemSummary.TestSqlAcces -eq $true) 
{
    $RetSystemSummaryResult = $RetSystemSummary.sqlresult

    if (($RetSystemSummaryResult.IsHadrEnabled -eq 0) -or ($RetSystemSummaryResult.MirroringEnabled -ne 0))
    {
        $readIntent =$false
    }

	$RetSystemSummaryResult | Format-Table
    $body="<H2>SQL Summary</H2>" 
    $RetsqlConfigHTML= $RetSystemSummaryResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body



"Collect processor information" | write-PHLog -echo -Logtype Debug2
    $GetProcessorCount= 'powershell.exe -c "$colItems =Get-WmiObject -class "Win32_Processor" -namespace "root/CIMV2" ;    $NOfLogicalCPU = 0;    foreach ($objcpu in $colItems)    {$NOfLogicalCPU = $NOfLogicalCPU + ($objcpu.NumberOfLogicalProcessors) }; $NOfLogicalCPU "'
    $RetProcessorCount =fnExecuteXPCmdShell  $FullSQlInstance $GetProcessorCount
    if (($RetProcessorCount.ExecuteXMCmdShellError -ne "") -and ($RetProcessorCount.ExecuteXMCmdShellError.length -ne 0))
    {
        $FailedConnection= [pscustomobject] @{FailedConnection="Could not get powershellprocessor info $FullSQlInstance"; ErrorMessage=$RetProcessorCount.ExecuteXMCmdShellError}
        $RetsqlConfigHTMLCombined= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }
    else 
    {
        $TotalProcessorCount=$RetProcessorCount.SQLResult.output|out-string
    }

"Collect last boot time" | write-PHLog -echo -Logtype Debug2
    $GetMemorySpecs= 'powershell.exe -c "Get-WmiObject Win32_OperatingSystem | select csname,lastbootuptime,TotalVisibleMemorySize,FreePhysicalMemory | ConvertTo-XML -NoTypeInformation -As String"  '
    $RetMemorySpecs =fnExecuteXPCmdShell  $FullSQlInstance $GetMemorySpecs
    if (($RetMemorySpecs.ExecuteXMCmdShellError -ne "") -and ($RetMemorySpecs.ExecuteXMCmdShellError.length -ne 0))
    {
        $FailedConnection= [pscustomobject] @{FailedConnection="Could not get OS info $FullSQlInstance"; ErrorMessage=$RetMemorySpecs.ExecuteXMCmdShellError}
        $RetsqlConfigHTMLCombined= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }
    else 
    {
        $RetMemorySpecsresult1=($RetMemorySpecs.SQLResult.output)
        $RetMemorySpecsresult2 =[xml]"$RetMemorySpecsresult1 "
        $LastBootTime=$RetMemorySpecsresult2.objects.object.SelectSingleNode('Property[@Name="lastbootuptime"]').innerxml
        $LastBootTime
        $Boot=Get-WmiObject win32_operatingsystem
        $Boot.ConvertToDateTime($LastBootTime)
    }


"Collect OS related details" | write-PHLog -echo -Logtype Debug2
    $GetServerSpecs= 'powershell.exe -c "Get-WmiObject Win32_ComputerSystem | select Name,Model, Manufacturer, Description, DNSHostName,Domain, DomainRole, PartOfDomain, NumberOfProcessors,NumberOfLogicalProcessors,SystemType, TotalPhysicalMemory, UserName,Workgroup,CurrentTimeZone | ConvertTo-XML -NoTypeInformation -As String" '
    $RetServerSpecs =fnExecuteXPCmdShell  $FullSQlInstance $GetServerSpecs

"Convert XML output to PS object" | write-PHLog -echo -Logtype Debug2
    if ($RetServerSpecs.ExecuteXMCmdShellError.length -eq 0) 
    {
        $RetServerSpecsresult1=($RetServerSpecs.SQLResult.output)
        $RetServerSpecsresult2 =[xml]"$RetServerSpecsresult1 "
        #$RetServerSpecsresult2.InnerXml 
        $RetServerSpecsresult3=$RetServerSpecsresult2.objects.object| foreach {
            [pscustomobject]  @{
            Name=($_.SelectSingleNode('Property[@Name="Name"]').innerxml)
            Model=($_.SelectSingleNode('Property[@Name="Model"]').innerxml)
            Manufacturer=($_.SelectSingleNode('Property[@Name="Manufacturer"]').innerxml)
            Description=($_.SelectSingleNode('Property[@Name="Description"]').innerxml)
            DNSHostName=($_.SelectSingleNode('Property[@Name="DNSHostName"]').innerxml)
            Domain=($_.SelectSingleNode('Property[@Name="Domain"]').innerxml)
            DomainRole=($_.SelectSingleNode('Property[@Name="DomainRole"]').innerxml)
            PartOfDomain=($_.SelectSingleNode('Property[@Name="PartOfDomain"]').innerxml)
            NumberOfSocket=($_.SelectSingleNode('Property[@Name="NumberOfProcessors"]').innerxml)
            TotalProcessorCount=$TotalProcessorCount
            NumberOfLogicalProcessors=($_.SelectSingleNode('Property[@Name="NumberOfLogicalProcessors"]').innerxml)
            SystemType=($_.SelectSingleNode('Property[@Name="SystemType"]').innerxml)
            TotalPhysicalMemory=$([math]::round(((($_.SelectSingleNode('Property[@Name="TotalPhysicalMemory"]').innerxml)/1GB)),2))  
            FreePhysicalMemory=$([math]::round(((($RetMemorySpecsresult2.objects.object.SelectSingleNode('Property[@Name="FreePhysicalMemory"]').innerxml))/(1024*1024)),1)) 
            UserName=($_.SelectSingleNode('Property[@Name="UserName"]').innerxml)
            Workgroup=($_.SelectSingleNode('Property[@Name="Workgroup"]').innerxml)
            CurrentTimeZone=($_.SelectSingleNode('Property[@Name="CurrentTimeZone"]').innerxml)
           }
    }


    $RetServerSpecsresult3 | Format-Table
    
    $body="<H2>Computer Summary</H2>" 
    $RetsqlConfigHTML+= $RetServerSpecsresult3 |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
}
    else 
    {
        $FailedConnection= [pscustomobject] @{FailedConnection="Convert XML output to PS object $FullSQlInstance"; ErrorMessage=$RetServerSpecs.ExecuteXMCmdShellError}
        $RetsqlConfigHTMLCombined+= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }


"Collect SQL key performance couters averaging last 1 min" | write-PHLog -echo -Logtype Debug2
$QueryDB_PerfCounter= 
"
DECLARE @CounterPrefix NVARCHAR(30),@StoreFirstTime datetime,@StoreSecondTime datetime,@timeDiff int

SET @CounterPrefix = CASE
WHEN @@SERVICENAME = 'MSSQLSERVER'
THEN 'SQLServer:'
ELSE 'MSSQL$'+@@SERVICENAME+':'
END;

select @StoreFirstTime =getdate()
SELECT CAST(1 AS INT) AS collection_instance ,[OBJECT_NAME],counter_name ,
instance_name,cntr_value,cntr_type,CURRENT_TIMESTAMP AS collection_time
INTO #perf_counters_init
FROM sys.dm_os_performance_counters
WHERE ( OBJECT_NAME = @CounterPrefix+'Access Methods'
    AND counter_name = 'Full Scans/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Access Methods'
    AND counter_name = 'Index Searches/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager'
    AND counter_name = 'Lazy Writes/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager'
    AND counter_name = 'Page life expectancy')
   OR ( OBJECT_NAME = @CounterPrefix+'General Statistics'
    AND counter_name = 'Processes Blocked')
   OR ( OBJECT_NAME = @CounterPrefix+'General Statistics'
    AND counter_name = 'User Connections')
   OR ( OBJECT_NAME = @CounterPrefix+'Locks'
    AND counter_name = 'Lock Waits/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Locks'
    AND counter_name = 'Number of Deadlocks/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Locks'
    AND counter_name = 'Lock Wait Time (ms)')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'SQL Re-Compilations/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Memory Manager'
    AND counter_name = 'Memory Grants Pending')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'Batch Requests/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'SQL Compilations/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'SQL Re-Compilations/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Access Methods'
    AND counter_name = 'Page Splits/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager'
    AND counter_name = 'Checkpoint Pages/sec')

WAITFOR DELAY '00:01:00'


select @StoreSecondTime =getdate()

SELECT CAST(2 AS INT) AS collection_instance ,[OBJECT_NAME],counter_name ,
     instance_name,cntr_value,cntr_type,CURRENT_TIMESTAMP AS collection_time
INTO #perf_counters_second
FROM sys.dm_os_performance_counters
WHERE ( OBJECT_NAME = @CounterPrefix+'Access Methods'
     AND counter_name = 'Full Scans/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Access Methods'
     AND counter_name = 'Index Searches/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager'
     AND counter_name = 'Lazy Writes/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager'
    AND counter_name = 'Page life expectancy')
   OR ( OBJECT_NAME = @CounterPrefix+'General Statistics'
    AND counter_name = 'Processes Blocked')
   OR ( OBJECT_NAME = @CounterPrefix+'General Statistics'
    AND counter_name = 'User Connections')
   OR ( OBJECT_NAME = @CounterPrefix+'Locks'
    AND counter_name = 'Lock Waits/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Locks'
    AND counter_name = 'Lock Wait Time (ms)')
   OR ( OBJECT_NAME = @CounterPrefix+'Locks'
    AND counter_name = 'Number of Deadlocks/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'SQL Re-Compilations/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Memory Manager'
    AND counter_name = 'Memory Grants Pending')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'Batch Requests/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'SQL Compilations/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics'
    AND counter_name = 'SQL Re-Compilations/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Access Methods'
    AND counter_name = 'Page Splits/sec')
   OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager'
    AND counter_name = 'Checkpoint Pages/sec')

select @timeDiff = datediff(ss,@StoreFirstTime, @StoreSecondTime)

-- Calculate the cumulative counter values

SELECT i.OBJECT_NAME , rtrim(ltrim(i.counter_name)) as counter_name, rtrim(ltrim(i.instance_name)) as instance_name,
    CASE WHEN i.cntr_type = 272696576
    THEN (s.cntr_value - i.cntr_value)/@timeDiff
    WHEN i.cntr_type = 65792 THEN s.cntr_value
    END AS cntr_value
into #perf_counters
FROM #perf_counters_init AS i
JOIN #perf_counters_second AS s
ON i.collection_instance + 1 = s.collection_instance
   AND i.OBJECT_NAME = s.OBJECT_NAME
   AND i.counter_name = s.counter_name
   AND i.instance_name = s.instance_name
ORDER BY OBJECT_NAME


select @@servername as ServerName,*,getdate() as RunTime from #perf_counters where cntr_value>0

-- Cleanup tables
DROP TABLE #perf_counters
DROP TABLE #perf_counters_init
DROP TABLE #perf_counters_second 


" 
	$RetQueryDB_PerfCounter= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QueryDB_PerfCounter
    $RetQueryDB_PerfCounterResult = $RetQueryDB_PerfCounter.sqlresult
	$RetQueryDB_PerfCounterResult | Format-Table
    $body="<H2>Database perf counters</H2>" 
    $RetsqlConfigHTML+= $RetQueryDB_PerfCounterResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body




"Collect SQL wait Stats summary" | write-PHLog -echo -Logtype Debug2
$QueryDB_WaitStats= 
"
--DBCC SQLPERF (N'sys.dm_os_wait_stats', CLEAR);
--GO
set nocount on
go
if object_id('tempdb..tmpWaitStats') is not null drop table tempdb..tmpWaitStats
go
if object_id('tempdb..tmpWaitTasks') is not null drop table tempdb..tmpWaitTasks
go
WITH [Waits] AS
    (SELECT
        [wait_type],
        [wait_time_ms] / 1000.0 AS [WaitS],
        ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
        [signal_wait_time_ms] / 1000.0 AS [SignalS],
        [waiting_tasks_count] AS [WaitCount],
        100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
        ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
    FROM sys.dm_os_wait_stats
    WHERE [wait_type] NOT IN (
        N'BROKER_EVENTHANDLER',             N'BROKER_RECEIVE_WAITFOR',
        N'BROKER_TASK_STOP',                N'BROKER_TO_FLUSH',
        N'BROKER_TRANSMITTER',              N'CHECKPOINT_QUEUE',
        N'CHKPT',                           N'CLR_AUTO_EVENT',
        N'CLR_MANUAL_EVENT',                N'CLR_SEMAPHORE',
        N'DBMIRROR_DBM_EVENT',              N'DBMIRROR_EVENTS_QUEUE',
        N'DBMIRROR_WORKER_QUEUE',           N'DBMIRRORING_CMD',
        N'DIRTY_PAGE_POLL',                 N'DISPATCHER_QUEUE_SEMAPHORE',
        N'EXECSYNC',                        N'FSAGENT',
        N'FT_IFTS_SCHEDULER_IDLE_WAIT',     N'FT_IFTSHC_MUTEX',
        N'HADR_CLUSAPI_CALL',               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
        N'HADR_LOGCAPTURE_WAIT',            N'HADR_NOTIFICATION_DEQUEUE',
        N'HADR_TIMER_TASK',                 N'HADR_WORK_QUEUE',
        N'KSOURCE_WAKEUP',                  N'LAZYWRITER_SLEEP',
        N'LOGMGR_QUEUE',                    N'ONDEMAND_TASK_QUEUE',
        N'PWAIT_ALL_COMPONENTS_INITIALIZED',
        N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
        N'QDS_SHUTDOWN_QUEUE',
        N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
        N'REQUEST_FOR_DEADLOCK_SEARCH',     N'RESOURCE_QUEUE',
        N'SERVER_IDLE_CHECK',               N'SLEEP_BPOOL_FLUSH',
        N'SLEEP_DBSTARTUP',                 N'SLEEP_DCOMSTARTUP',
        N'SLEEP_MASTERDBREADY',             N'SLEEP_MASTERMDREADY',
        N'SLEEP_MASTERUPGRADED',            N'SLEEP_MSDBSTARTUP',
        N'SLEEP_SYSTEMTASK',                N'SLEEP_TASK',
        N'SLEEP_TEMPDBSTARTUP',             N'SNI_HTTP_ACCEPT',
        N'SP_SERVER_DIAGNOSTICS_SLEEP',     N'SQLTRACE_BUFFER_FLUSH',
        N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        N'SQLTRACE_WAIT_ENTRIES',           N'WAIT_FOR_RESULTS',
        N'WAITFOR',                         N'WAITFOR_TASKSHUTDOWN',
        N'WAIT_XTP_HOST_WAIT',              N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
        N'WAIT_XTP_CKPT_CLOSE',             N'XE_DISPATCHER_JOIN',
        N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT')
    AND [waiting_tasks_count] > 0
 )
SELECT
    MAX ([W1].[wait_type]) AS [WaitType],
    CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
    CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
    CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
    MAX ([W1].[WaitCount]) AS [WaitCount],
    CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
    CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
    CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
    CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S]
into tempdb..tmpWaitStats
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
    ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95; -- percentage threshold
GO

select * 
into tempdb..tmpWaitTasks
from sys.dm_os_waiting_tasks where wait_type in (select Waittype from tempdb..tmpWaitStats)

go

select * from tempdb..tmpWaitStats


" 
	$RetQueryDB_WaitStats= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QueryDB_WaitStats
    $RetQueryDB_WaitStatsResult = $RetQueryDB_WaitStats.sqlresult
	$RetQueryDB_WaitStatsResult | Format-Table
    $body="<H2>Database Wait Stats</H2>" 
    $RetsqlConfigHTML+= $RetQueryDB_WaitStatsResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body


"Collect SQL OS waits from sys.dm_os_waiting_tasks" | write-PHLog -echo -Logtype Debug2
    $QueryDB_WaitTasks="select * from tempdb..tmpWaitTasks"
	$RetQueryDB_WaitTasks= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QueryDB_WaitTasks
    $RetQueryDB_WaitTasksResult = $RetQueryDB_WaitTasks.sqlresult
	$RetQueryDB_WaitTasksResult | Format-Table
    $body="<H2>OS Wait Tasks</H2>" 
    $RetsqlConfigHTML+= $RetQueryDB_WaitTasksResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body



"Collect important sp_configure Stats" | write-PHLog -echo -Logtype Debug2
$Querysp_configure= 
"
    Declare @tmpsp_configure table
    (
       name Varchar(2000),
       minimum bigINT,
       maximum bigINT,
       config_value bigINT,
	    run_value bigint
    )


	    declare @ShowAdvancedOptionValue int

	    declare @ShowAdvancedOptiontbl table
	    (
	    Name varchar(200),
	    Minimum int,
	    maximum int,
	    config_value int,
	    run_value int
	    )
	    insert into @ShowAdvancedOptiontbl
	    EXEC sp_configure 'show advanced option'

	    select @ShowAdvancedOptionValue = run_value from @ShowAdvancedOptiontbl

	    if @ShowAdvancedOptionValue = 0
	    begin
		    USE master;
		    EXEC sp_configure 'show advanced option', '1';
		    RECONFIGURE WITH OVERRIDE;
		    INSERT INTO @tmpsp_configure
		    exec sp_configure
		    EXEC sp_configure 'show advanced option', '0';
		    RECONFIGURE WITH OVERRIDE;
	    end
	    else
	    begin
		    INSERT INTO @tmpsp_configure
		    exec sp_configure
	    end

    select * from @tmpsp_configure where name in (

    'backup compression default',
    'blocked process threshold (s)',
    'clr enabled',
    'cost threshold for parallelism',
    'cross db ownership chaining',
    'filestream access level',
    'fill factor (%)',
    'index create memory (KB)',
    'lightweight pooling',
    'max degree of parallelism',
    'max server memory (MB)',
    'max worker threads',
    'min memory per query (KB)',
    'min server memory (MB)',
    'network packet size (B)',
    'Ole Automation Procedures',
    'optimize for ad hoc workloads',
    'PH timeout (s)',
    'priority boost',
    'recovery interval (min)',
    'remote login timeout (s)',
    'remote query timeout (s)',
    'set working set size'

    )

" 
	$RetQuerysp_configure= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $Querysp_configure
    $RetQuerysp_configureResult = $RetQuerysp_configure.sqlresult
	$RetQuerysp_configureResult | Format-Table
    $body="<H2>Database configuration</H2>" 
    $RetsqlConfigHTML+= $RetQuerysp_configureResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body

"Collecting Database IO latency summary since SQL restart" | write-PHLog -echo -Logtype Debug2
$QuerydatabaseIOLatency= 
"
    if object_id('tempdb..##tmp_DiskLatency') is not null drop table ##tmp_DiskLatency

    SELECT top 5
        [ReadLatency] =
            CASE WHEN [num_of_reads] = 0
                THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
        [WriteLatency] =
            CASE WHEN [num_of_writes] = 0
                THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
        [Latency] =
            CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
                THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
        [AvgBPerRead] =
            CASE WHEN [num_of_reads] = 0
                THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
        [AvgBPerWrite] =
            CASE WHEN [num_of_writes] = 0
                THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
        [AvgBPerTransfer] =
            CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
                THEN 0 ELSE
                    (([num_of_bytes_read] + [num_of_bytes_written]) /
                    ([num_of_reads] + [num_of_writes])) END,
        LEFT ([mf].[physical_name], 2) AS [Drive],
        DB_NAME ([vfs].[database_id]) AS [DB],
	    SUBSTRING(mf.physical_name, len(mf.physical_name)-CHARINDEX('\',REVERSE(mf.physical_name))+2, 100) as FileName,
        [mf].[physical_name]
    into ##tmp_DiskLatency
    FROM
        sys.dm_io_virtual_file_stats (NULL,NULL) AS [vfs]
    JOIN sys.master_files AS [mf]
        ON [vfs].[database_id] = [mf].[database_id]
        AND [vfs].[file_id] = [mf].[file_id]
    -- WHERE [vfs].[file_id] = 2 -- log files
    -- ORDER BY [Latency] DESC
    -- ORDER BY [ReadLatency] DESC
    ORDER BY [WriteLatency] DESC


    insert into ##tmp_DiskLatency
    SELECT top 5
        [ReadLatency] =
            CASE WHEN [num_of_reads] = 0
                THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
        [WriteLatency] =
            CASE WHEN [num_of_writes] = 0
                THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
        [Latency] =
            CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
                THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
        [AvgBPerRead] =
            CASE WHEN [num_of_reads] = 0
                THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
        [AvgBPerWrite] =
            CASE WHEN [num_of_writes] = 0
                THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
        [AvgBPerTransfer] =
            CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
                THEN 0 ELSE
                    (([num_of_bytes_read] + [num_of_bytes_written]) /
                    ([num_of_reads] + [num_of_writes])) END,
        LEFT ([mf].[physical_name], 2) AS [Drive],
        DB_NAME ([vfs].[database_id]) AS [DB],
	    SUBSTRING(mf.physical_name, len(mf.physical_name)-CHARINDEX('\',REVERSE(mf.physical_name))+2, 100) as FileName,
        [mf].[physical_name]
    FROM
        sys.dm_io_virtual_file_stats (NULL,NULL) AS [vfs]
    JOIN sys.master_files AS [mf]
        ON [vfs].[database_id] = [mf].[database_id]
        AND [vfs].[file_id] = [mf].[file_id]
    -- WHERE [vfs].[file_id] = 2 -- log files
    -- ORDER BY [Latency] DESC
    -- ORDER BY [ReadLatency] DESC
    ORDER BY [ReadLatency] DESC

    if object_id('tempdb..DiskLatency') is not null drop table tempdb..DiskLatency
    select distinct * into tempdb..DiskLatency from ##tmp_DiskLatency
    select * from tempdb..DiskLatency order by Latency desc


" 
if ($readIntent -eq $true)
{
	$RetatabaseIOLatency= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseIOLatency -ReadIntentTrue $readIntent
    $RetatabaseIOLatency= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  "select * from tempdb..DiskLatency order by Latency desc"
}
else
{
    $RetatabaseIOLatency= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseIOLatency
}
    $RetatabaseIOLatencyResult = $RetatabaseIOLatency.sqlresult
	$RetatabaseIOLatencyResult | Format-Table
    $body="<H2>Database IO latency</H2>" 
    $RetsqlConfigHTML+= $RetatabaseIOLatencyResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body



"Collecting OS Disk Stats" | write-PHLog -echo -Logtype Debug2
    $GetDiskSpecs= 'powershell.exe -c "Get-WmiObject Win32_LogicalDisk -filter "DriveType=3" | Select SystemName, DeviceID, VolumeName, size,freespace  | convertto-xml -NoTypeInformation -As String"' 

    $RetDiskSpecs =fnExecuteXPCmdShell  $FullSQlInstance $GetDiskSpecs
    if ($RetDiskSpecs.ExecuteXMCmdShellError.length -eq 0) 
    {
    $RetDiskSpecs1=($RetDiskSpecs.SQLResult.output)
    $RetDiskSpecs2 =[xml]"$RetDiskSpecs1 "
    #$RetDiskSpecs2.InnerXml 
    $RetDiskSpecs3=$RetDiskSpecs2.objects.object | foreach {
        [pscustomobject]  @{
        SystemName=($_.SelectSingleNode('Property[@Name="SystemName"]').innerxml)
        DeviceID=($_.SelectSingleNode('Property[@Name="DeviceID"]').innerxml)
        VolumeName=($_.SelectSingleNode('Property[@Name="VolumeName"]').innerxml)
        DiskSize=$([math]::round(((($_.SelectSingleNode('Property[@Name="size"]').innerxml))/1GB),2)) 
        DiskUsedSpace=$([math]::round(((($_.SelectSingleNode('Property[@Name="size"]').innerxml)-($_.SelectSingleNode('Property[@Name="freespace"]').innerxml))/1GB),2)) 
        DiskFreespace=$([math]::round(((($_.SelectSingleNode('Property[@Name="freespace"]').innerxml))/1GB),2)) 
        DiskFreePercentage=$([math]::round($([math]::round(((($_.SelectSingleNode('Property[@Name="freespace"]').innerxml))/1GB),2)*100) / $([math]::round(((($_.SelectSingleNode('Property[@Name="size"]').innerxml))/1GB),2))))
        }
    } 
        $RetDiskSpecs3 | ft
        $body="<H2>Disk State</H2>" 
        $RetsqlConfigHTML+= $RetDiskSpecs3 |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }
    else 
    {
        $FailedConnection= [pscustomobject] @{FailedConnection="Collecting OS Disk Stats $FullSQlInstance"; ErrorMessage=$RetDiskSpecs.ExecuteXMCmdShellError}
        $RetsqlConfigHTMLCombined= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }


"Collecting Database Disk Usage Summary" | write-PHLog -echo -Logtype Debug2
$QuerydatabaseUsageSummary= 
"
DECLARE @DBInfo TABLE  
( ServerName VARCHAR(100),  
DatabaseName VARCHAR(100),  
FileSizeMB INT,  
LogicalFileName sysname,  
PhysicalFileName NVARCHAR(520),  
Status sysname,  
Updateability sysname,  
RecoveryMode sysname,  
FreeSpaceMB INT,  
FreeSpacePct VARCHAR(7),  
FreeSpacePages INT,  
growth varchar(20),
maxsize varchar(200),
PollDate datetime,
FileType varchar(200)
)  

DECLARE @command VARCHAR(5000)  
if not(convert(varchar(200),SERVERPROPERTY('ProductVersion')) like '10.0%')
Begin
	SELECT @command = 'Use [' + '?' + '] SELECT  
	@@servername as ServerName,  
	' + '''' + '?' + '''' + ' AS DatabaseName  
		, (case size when  0 then 1 else size/128.0 end) as FileSize,name as LogicalFileName
		,physical_name as PhysicalFileName,state_desc as Status
		,CONVERT(sysname,DatabasePropertyEx(''?'',''Updateability'')) AS Updateability 
		,CONVERT(sysname,DatabasePropertyEx(''?'',''Recovery'')) AS RecoveryMode  
		,CAST((case size when  0 then 1 else size/128.0 end) - CAST(FILEPROPERTY(name, ''SpaceUsed'' ) AS int)/128.0 AS int) AS FreeSpaceMB  
		,convert(int,((size-FILEPROPERTY(name,''SpaceUsed''))*100.00)/(case size when  0 then 1 else size end)) AS FreeSpacePct
		,case when growth>100 then convert(varchar(200),(growth/128)) + ''MB'' else convert(varchar(200),(growth)) + ''%''  end growth ,
		case max_size when -1 then ''unrestricted'' when 0 then ''restricted'' when 268435456 
			then ''unrestricted'' else convert(varchar(200),(growth)) + ''%''  end maxsize ,
		GETDATE() as PollDate, 
		type_desc as Type from sys.database_files
	'  
	--select @command
end
Else
Begin
	SELECT @command = 'Use [' + '?' + '] SELECT  
	@@servername as ServerName,  
	' + '''' + '?' + '''' + ' AS DatabaseName,  
	CAST(sysfiles.size/128.0 AS int) AS FileSize,  
	sysfiles.name AS LogicalFileName, sysfiles.filename AS PhysicalFileName,  
	CONVERT(sysname,DatabasePropertyEx(''?'',''Status'')) AS Status,  
	CONVERT(sysname,DatabasePropertyEx(''?'',''Updateability'')) AS Updateability,  
	CONVERT(sysname,DatabasePropertyEx(''?'',''Recovery'')) AS RecoveryMode,  
	CAST(sysfiles.size/128.0 - CAST(FILEPROPERTY(sysfiles.name, ' + '''' +  
		   'SpaceUsed' + '''' + ' ) AS int)/128.0 AS int) AS FreeSpaceMB,  
	CAST(100 * (CAST (((sysfiles.size/128.0 -CAST(FILEPROPERTY(sysfiles.name,  
	' + '''' + 'SpaceUsed' + '''' + ' ) AS int)/128.0)/(sysfiles.size/128.0))  
	AS decimal(4,2))) AS varchar(8)) + ' + '''' + '%' + '''' + ' AS FreeSpacePct,  
	case when growth>100 then convert(varchar(200),(growth/128)) + ''MB'' else convert(varchar(200),(growth)) + ''%''  end growth ,
	case maxsize when -1 then ''unrestricted'' when 0 then ''restricted'' when 268435456 
		then ''unrestricted'' else convert(varchar(200),(growth)) + ''%''  end maxsize ,
	GETDATE() as PollDate 
	,case groupid 
		when  0 
			then ''LOGS'' 
			else ''ROWS''
		end	 as Type
	FROM dbo.sysfiles'  
--select @command
End

INSERT INTO @DBInfo  
   (ServerName,  
   DatabaseName,  
   FileSizeMB,  
   LogicalFileName,  
   PhysicalFileName,  
   Status,  
   Updateability,  
   RecoveryMode,  
   FreeSpaceMB,  
   FreeSpacePct,  growth ,maxsize,
   PollDate, FileType)  
EXEC sp_MSForEachDB @command  

if object_id('tempdb..##tmpSpace1234') is not null drop table ##tmpSpace1234

SELECT  
   ServerName,  
   DatabaseName,  
   FileType,
   left((physicalFileName),(len(physicalFileName)-charindex('\',reverse(physicalFileName)))) as FolderLocation,
   FileSizeMB as FileSizeMB,  
   FileSizeMB - FreeSpaceMB as FileSpaceUsedMB,  
   FreeSpaceMB as FreeSpaceMB
into ##tmpSpace1234
FROM @DBInfo  
-- where DatabaseName like 'AdventDirectPlatformDb876637%'
ORDER BY  
   ServerName,  
   DatabaseName  


if object_id('tempdb..tmpphdatabaseUsageSummary') is not null drop table tempdb..tmpphdatabaseUsageSummary


select ServerName,left(folderLocation,1) as Drive,FileType,CONVERT(DECIMAL(10,2),sum(FileSizeMB)/1024.00) as FileSizeGB, CONVERT(DECIMAL(10,2),sum(FreeSpaceMB)/1024.00)  as FileFreeSpaceGB
, CONVERT(DECIMAL(10,2),(sum(FileSizeMB)-sum(FreeSpaceMB))/1024.00)  as FileSpaceUsedGB, CONVERT(DECIMAL(10,2),((sum(FreeSpaceMB))*100)/sum(FileSizeMB))  as  DBFreePercentage
into tempdb..tmpphdatabaseUsageSummary
from ##tmpSpace1234
 where FolderLocation not like '\\%'
group by ServerName,FileType,left(folderLocation,1)


select * from tempdb..tmpphdatabaseUsageSummary 


--select DB_NAME(database_id),mf.name as [file_name],physical_name
-- FROM sys.master_files as mf

" 
    if ($readIntent -eq $true)
    {
	    $RetdatabaseUsageSummary1= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseUsageSummary -ReadIntentTrue $readIntent
        if ($RetdatabaseUsageSummary1.ExecuteSQLError -ne "")
        {
            $FailedConnection= [pscustomobject] @{FailedConnection="Could not collect database usage summary $FullSQlInstance"; ErrorMessage=$RetdatabaseUsageSummary1.ExecuteSQLError}
            $RetsqlConfigHTMLCombined= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
        }
        else 
        {
            $RetdatabaseUsageSummary= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  "select * from tempdb..tmpphdatabaseUsageSummary"
        }
    }
    else
    {
        $RetdatabaseUsageSummary= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseUsageSummary
    }
    $RetdatabaseUsageSummaryResult = $RetdatabaseUsageSummary.sqlresult
	$RetdatabaseUsageSummaryResult | Format-Table


"Summarizing Disk Stats with OS disk and Database files for free space" | write-PHLog -echo -Logtype Debug2
    $DiskStatsSummarized=@()
    foreach ($DataUsage in $RetdatabaseUsageSummaryResult)
    {
        $MatchDiskStats=$RetDiskSpecs3 | Where-Object {$_.DeviceID -match $DataUsage.Drive}
        $DiskStatsNew=[pscustomobject]  @{
            ServerName=$DataUsage.ServerName 
            Drive=$DataUsage.Drive 
            FileType=$DataUsage.FileType 
            DBFileSizeGB=$DataUsage.FileSizeGB
            DBFileSpaceUsedGB=$DataUsage.FileSpaceUsedGB 
            DBFileFreeSpaceGB=$DataUsage.FileFreeSpaceGB 
            DBFreePercentage=$DataUsage.DBFreePercentage
            DiskSize=$MatchDiskStats.DiskSize
            DiskUsedSpace=$MatchDiskStats.DiskUsedSpace
            DiskFreespace=$MatchDiskStats.DiskFreespace
            DiskFreePercentage=$MatchDiskStats.DiskFreePercentage
        }
        $DiskStatsSummarized+=$DiskStatsNew

    }
    $DiskStatsSummarized | select ServerName,Drive,FileType,DiskSize,DiskUsedSpace,DiskFreespace,DiskFreePercentage,DBFileSizeGB,DBFileSpaceUsedGB,DBFileFreeSpaceGB,DBFreePercentage




"Collecting Database growth in last 2 days" | write-PHLog -echo -Logtype Debug2
$QuerydatabaseGrowth= 
"
if object_id('tempdb..##tmp_growthLog') is not null drop table ##tmp_growthLog
go
DECLARE @filename NVARCHAR(1000);
DECLARE @bc INT;
DECLARE @ec INT;
DECLARE @bfn VARCHAR(1000);
DECLARE @efn VARCHAR(10);

-- Get the name of the current default trace
SELECT @filename = CAST(value AS NVARCHAR(1000))
FROM ::fn_trace_getinfo(DEFAULT)
WHERE traceid = 1 AND property = 2;

-- rip apart file name into pieces
SET @filename = REVERSE(@filename);
SET @bc = CHARINDEX('.',@filename);
SET @ec = CHARINDEX('_',@filename)+1;
SET @efn = REVERSE(SUBSTRING(@filename,1,@bc));
SET @bfn = REVERSE(SUBSTRING(@filename,@ec,LEN(@filename)));

-- set filename without rollover number
SET @filename = @bfn + @efn

-- process all trace files
SELECT 
  ftg.StartTime
,te.name AS EventName
,DB_NAME(ftg.databaseid) AS DatabaseName  
,ftg.Filename
,(ftg.IntegerData*8)/1024.0 AS GrowthMB 
,(ftg.duration/1000)AS DurMS
into ##tmp_growthLog
FROM ::fn_trace_gettable(@filename, DEFAULT) AS ftg 
INNER JOIN sys.trace_events AS te ON ftg.EventClass = te.trace_event_id  
WHERE (ftg.EventClass = 92  -- Date File Auto-grow
    OR ftg.EventClass = 93) -- Log File Auto-grow
ORDER BY ftg.StartTime

--select * from ##tmp_growthLog
----where FILENAME like 'FirmLog%'
--order by StartTime desc

if object_id('tempdb..tmpphdatabaseGrowth') is not null drop table tempdb..tmpphdatabaseGrowth

select Duration,DatabaseName,Filename,EventName,TotalGrowthMB,totalDurationMs 
into tempdb..tmpphdatabaseGrowth
from (
select 'Growth in Last Hour' as Duration, DatabaseName,Filename,EventName,sum(GrowthMB) as TotalGrowthMB,sum(DurMS) as totalDurationMs,1 as id 
from ##tmp_growthLog
where starttime > dateadd (HH,-1,getdate())
group by DatabaseName,FileName,EventName
union all
select 'Growth in Last 2 days' as Duration, DatabaseName,Filename,EventName,sum(GrowthMB) as TotalGrowthMB,sum(DurMS) as totalDurationMs ,2 as id 
from ##tmp_growthLog
where starttime > dateadd (DD,-2,getdate())
group by DatabaseName,FileName,EventName
) a
order by id,DatabaseName,FileName,EventName  desc

select * from tempdb..tmpphdatabaseGrowth



" 

    if ($readIntent -eq $true)
    {
	    $RetQuerydatabaseGrowth= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseGrowth -ReadIntentTrue $readIntent
        $RetQuerydatabaseGrowth= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  "select * from tempdb..tmpphdatabaseGrowth"
    }
    else
    {
        $RetQuerydatabaseGrowth= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseGrowth 
    }

	
    $RetQuerydatabaseGrowthResult = $RetQuerydatabaseGrowth.sqlresult
	$RetQuerydatabaseGrowthResult | Format-Table
    $body="<H2>Database growth Detail</H2>" 
    $RetsqlConfigHTML+= $RetQuerydatabaseGrowthResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body

"Collecting Database data and log file Usage Summary" | write-PHLog -echo -Logtype Debug2
$QuerydatabaseUsage= 
"
DECLARE @DBInfo TABLE  
( ServerName VARCHAR(100),  
DatabaseName VARCHAR(100),  
FileSizeMB INT,  
LogicalFileName sysname,  
PhysicalFileName NVARCHAR(520),  
Status sysname,  
Updateability sysname,  
RecoveryMode sysname,  
FreeSpaceMB INT,  
FreeSpacePct VARCHAR(7),  
FreeSpacePages INT,  
growth varchar(20),
maxsize varchar(200),
PollDate datetime,
FileType varchar(200)
)  

DECLARE @command VARCHAR(5000)  
if not(convert(varchar(200),SERVERPROPERTY('ProductVersion')) like '10.0%')
Begin
	SELECT @command = 'Use [' + '?' + '] SELECT  
	@@servername as ServerName,  
	' + '''' + '?' + '''' + ' AS DatabaseName  
		, (case size when  0 then 1 else size/128.0 end) as FileSize,name as LogicalFileName
		,physical_name as PhysicalFileName,state_desc as Status
		,CONVERT(sysname,DatabasePropertyEx(''?'',''Updateability'')) AS Updateability 
		,CONVERT(sysname,DatabasePropertyEx(''?'',''Recovery'')) AS RecoveryMode  
		,CAST((case size when  0 then 1 else size/128.0 end) - CAST(FILEPROPERTY(name, ''SpaceUsed'' ) AS int)/128.0 AS int) AS FreeSpaceMB  
		,convert(int,((size-FILEPROPERTY(name,''SpaceUsed''))*100.00)/(case size when  0 then 1 else size end)) AS FreeSpacePct
		,case when growth>100 then convert(varchar(200),(growth/128)) + ''MB'' else convert(varchar(200),(growth)) + ''%''  end growth ,
		case max_size when -1 then ''unrestricted'' when 0 then ''restricted'' when 268435456 
			then ''unrestricted'' else convert(varchar(200),(growth)) + ''%''  end maxsize ,
		GETDATE() as PollDate, 
		type_desc as Type from sys.database_files
	'  
	--select @command
end
Else
Begin
	SELECT @command = 'Use [' + '?' + '] SELECT  
	@@servername as ServerName,  
	' + '''' + '?' + '''' + ' AS DatabaseName,  
	CAST(sysfiles.size/128.0 AS int) AS FileSize,  
	sysfiles.name AS LogicalFileName, sysfiles.filename AS PhysicalFileName,  
	CONVERT(sysname,DatabasePropertyEx(''?'',''Status'')) AS Status,  
	CONVERT(sysname,DatabasePropertyEx(''?'',''Updateability'')) AS Updateability,  
	CONVERT(sysname,DatabasePropertyEx(''?'',''Recovery'')) AS RecoveryMode,  
	CAST(sysfiles.size/128.0 - CAST(FILEPROPERTY(sysfiles.name, ' + '''' +  
		   'SpaceUsed' + '''' + ' ) AS int)/128.0 AS int) AS FreeSpaceMB,  
	CAST(100 * (CAST (((sysfiles.size/128.0 -CAST(FILEPROPERTY(sysfiles.name,  
	' + '''' + 'SpaceUsed' + '''' + ' ) AS int)/128.0)/(sysfiles.size/128.0))  
	AS decimal(4,2))) AS varchar(8)) + ' + '''' + '%' + '''' + ' AS FreeSpacePct,  
	case when growth>100 then convert(varchar(200),(growth/128)) + ''MB'' else convert(varchar(200),(growth)) + ''%''  end growth ,
	case maxsize when -1 then ''unrestricted'' when 0 then ''restricted'' when 268435456 
		then ''unrestricted'' else convert(varchar(200),(growth)) + ''%''  end maxsize ,
	GETDATE() as PollDate 
	,case groupid 
		when  0 
			then ''LOGS'' 
			else ''ROWS''
		end	 as Type
	FROM dbo.sysfiles'  
--select @command
End


INSERT INTO @DBInfo  
   (ServerName,  
   DatabaseName,  
   FileSizeMB,  
   LogicalFileName,  
   PhysicalFileName,  
   Status,  
   Updateability,  
   RecoveryMode,  
   FreeSpaceMB,  
   FreeSpacePct,  growth ,maxsize,
   PollDate, FileType)  
EXEC sp_MSForEachDB @command  

if object_id('tempdb..tmpphdatabaseUsage') is not null drop table tempdb..tmpphdatabaseUsage

SELECT  
   ServerName,  
   DatabaseName,  
   FileType,
--   left((physicalFileName),(len(physicalFileName)-charindex('\',reverse(physicalFileName)))) as FolderLocation,
   physicalFileName as FileLocation,
   FileSizeMB as FileSizeMB,  
   FileSizeMB - FreeSpaceMB as FileSpaceUsedMB,  
   FreeSpaceMB as FreeSpaceMB,
	sum(FileSizeMB) OVER (PARTITION BY DatabaseName) as DatabaseSize
into tempdb..tmpphdatabaseUsage
FROM @DBInfo  
-- where DatabaseName like 'AdventDirectPlatformDb876637%'
ORDER BY  
	DatabaseSize desc,
   ServerName,  
   DatabaseName  

select * from tempdb..tmpphdatabaseUsage
order by DatabaseSize desc,DatabaseName,FileType desc

" 

    if ($readIntent -eq $true)
    {
	    $RetQuerydatabaseUsage= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseUsage -ReadIntentTrue $readIntent
        $RetQuerydatabaseUsage= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  "select * from tempdb..tmpphdatabaseUsage order by DatabaseSize desc"
    }
    else
    {
	    $RetQuerydatabaseUsage= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseUsage 
    }

    $RetQuerydatabaseUsageResult = $RetQuerydatabaseUsage.sqlresult
	$RetQuerydatabaseUsageResult | Format-Table
    $body="<H2>Database Usage Detail</H2>" 
    $Sort1 = @{Expression='DatabaseSize'; Descending=$true }
    $Sort2 = @{Expression='FileType'; Descending=$true }
    $RetsqlConfigHTML+= $RetQuerydatabaseUsageResult | Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | Sort-Object $Sort1, $Sort2 | ConvertTo-HTML  -head $a  -body $body 



"Collecting Top space consuming Tables for the instance" | write-PHLog -echo -Logtype Debug2
$QuerydatabaseTopTables= 
@"
set nocount on
go
use tempdb
go
if object_id('tempdb..Table_Row_Counts') is not null drop table tempdb..Table_Row_Counts
go
CREATe TABLE tempdb..Table_Row_Counts(
tblschema  varchar (200),
Table_name varchar (200),
No_Of_rows varchar (200),
SpaceInMB varchar (200),
data_MB varchar (200),
index_size_MB varchar (200),
unused_MB varchar (200)
)
GO

if object_id('tempdb..All_DB_Table_Row_Counts') is not null drop table tempdb..All_DB_Table_Row_Counts
go
CREATe TABLE tempdb..All_DB_Table_Row_Counts(
dbname varchar (200),
tblschema  varchar (200),
Table_name varchar (200),
No_Of_rows bigint,
SpaceInMB bigint,
data_MB varchar (200),
index_size_MB varchar (200),
unused_MB varchar (200)
)
GO
declare @command1 varchar(8000)
select @command1 = 

'
IF ''@'' <> ''master'' AND ''@'' <> ''model'' AND ''@'' <> ''msdb'' AND ''@'' <> ''tempdb'' AND ''@'' <> ''dbastuff'' AND ''@'' <> ''test'' AND ''@'' <> ''SharePoint_AdminContent_bc1148e8-7066-4104-9f2f-8707b885ab8b''
begin

truncate table tempdb..Table_Row_Counts



		INSERT INTO tempdb..Table_Row_Counts
		SELECT
			t3.name AS [schema]
			,t2.name AS [table]
			,t1.rows AS row_count
			,((t1.reserved + ISNULL(a4.reserved,0))* 8) / 1024 AS SpaceInMB 
			,(t1.data * 8) / 1024 AS data_MB
			,((CASE WHEN (t1.used + ISNULL(a4.used,0)) > t1.data THEN (t1.used + ISNULL(a4.used,0)) - t1.data ELSE 0 END) * 8) /1024 AS index_size_MB
			,((CASE WHEN (t1.reserved + ISNULL(a4.reserved,0)) > t1.used THEN (t1.reserved + ISNULL(a4.reserved,0)) - t1.used ELSE 0 END) * 8)/1024 AS unused_MB
		FROM
		 (SELECT 
			 ps.object_id
			,SUM (CASE WHEN (ps.index_id < 2) THEN row_count ELSE 0 END) AS [rows]
			,SUM (ps.reserved_page_count) AS reserved
			,SUM (CASE WHEN (ps.index_id < 2) THEN (ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count) END) AS data
			,SUM (ps.used_page_count) AS used
		  FROM [@].sys.dm_db_partition_stats ps
		  GROUP BY ps.object_id) AS t1
		LEFT OUTER JOIN 
		 (SELECT 
			   it.parent_id
			  ,SUM(ps.reserved_page_count) AS reserved
			  ,SUM(ps.used_page_count) AS used
		  FROM [@].sys.dm_db_partition_stats ps
		  INNER JOIN [@].sys.internal_tables it ON (it.object_id = ps.object_id) WHERE it.internal_type IN (202,204)
		  GROUP BY it.parent_id) AS a4 ON (a4.parent_id = t1.object_id)
		INNER JOIN [@].sys.all_objects t2  ON ( t1.object_id = t2.object_id) 
		INNER JOIN [@].sys.schemas t3 ON (t2.schema_id = t3.schema_id)
		WHERE t2.type <> ''S'' and t2.type <> ''IT''



		insert into tempdb..All_DB_Table_Row_Counts
		select ''@'',tblschema,Table_name,No_Of_rows,SpaceInMB,data_MB,index_size_MB,unused_MB from tempdb..Table_Row_Counts
end	
	'
--select @command1	
exec sp_MSforeachdb @command1, '@'

select top 10 
	dbname as 'Database',Table_name as 'TableName',No_Of_rows as [Row Count],SpaceInMB as [Total Space MB],data_MB,index_size_MB,unused_MB
from tempdb..All_DB_Table_Row_Counts
order by SpaceInMB desc

"@
 
	$RetQuerydatabaseTopTables= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseTopTables
    $RetQuerydatabaseTopTablesResult = $RetQuerydatabaseTopTables.sqlresult
	$RetQuerydatabaseTopTablesResult | Format-Table
    $body="<H2>Database Top tables </H2>" 
    $RetsqlConfigHTML+= $RetQuerydatabaseTopTablesResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body


"Collecting top database memory consumption" | write-PHLog -echo -Logtype Debug2
$QueryMemoryConsumptionByDB= 
@"
set nocount on
go
SELECT
    (CASE WHEN ([database_id] = 32767)
        THEN N'Resource Database'
        ELSE DB_NAME ([database_id]) END) AS [DatabaseName],
    COUNT (*) * 8 / 1024 AS [MBUsed],
    SUM (CAST ([free_space_in_bytes] AS BIGINT)) / (1024 * 1024) AS [MBEmpty]
FROM sys.dm_os_buffer_descriptors
GROUP BY [database_id]
order by MBUsed desc
GO

"@
 
	$RetQueryMemoryConsumptionByDB= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QueryMemoryConsumptionByDB
    $RetQueryMemoryConsumptionByDBResult = $RetQueryMemoryConsumptionByDB.sqlresult
	$RetQueryMemoryConsumptionByDBResult | Format-Table
    $body="<H2>Database memory consumption</H2>" 
    $RetsqlConfigHTML+= $RetQueryMemoryConsumptionByDBResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body


"Collecting Top memory consuming processes from OS" | write-PHLog -echo -Logtype Debug2
    $GetTopMemoryProcesses= 'powershell.exe -c "get-wmiobject WIN32_PROCESS | Sort-Object -Property ws -Descending|select -first 5|Select processname, ws,ProcessID,PageFileUsage,VM,VirtualSize,Handle,ReadTransferCount,ReadOperationCount,MaximumWorkingSetSize,MinimumWorkingSetSize   ,PageFaults,ParentProcessId,PeakPageFileUsage,PeakVirtualSize,PeakWorkingSetSize,Priority,PrivatePageCount,ThreadCount,WorkingSetSize,WriteOperationCount,WriteTransferCount       | ConvertTo-XML -NoTypeInformation -As String"  '
    $RetTopMemoryProcesses =fnExecuteXPCmdShell  $FullSQlInstance $GetTopMemoryProcesses
    if (($RetTopMemoryProcesses.ExecuteXMCmdShellError -ne "") -and ($RetTopMemoryProcesses.ExecuteXMCmdShellError.length -ne 0))
    {
        $FailedConnection= [pscustomobject] @{FailedConnection="Could not get WIN32_PROCESS WMI data  $FullSQlInstance"; ErrorMessage=$RetTopMemoryProcesses.ExecuteXMCmdShellError}
        $RetsqlConfigHTMLCombined= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }
    else
    {
        $RetTopMemoryProcessesresult1=($RetTopMemoryProcesses.SQLResult.output)
        $RetTopMemoryProcessesresult2 =[xml]"$RetTopMemoryProcessesresult1"
        $TopMemoryProcesses=@()
        $RetTopMemoryProcessesresult2.Objects.Object| foreach {
            $TopMemoryProcesses+=[pscustomobject]  @{
            ProcessName=($_.SelectSingleNode('Property[@Name="ProcessName"]').innerxml)
            WS=$([math]::round(((($_.SelectSingleNode('Property[@Name="WS"]').innerxml)/1MB))))  
            ProcessID=($_.SelectSingleNode('Property[@Name="ProcessID"]').innerxml)
            PageFileUsage=$([math]::round(((($_.SelectSingleNode('Property[@Name="PageFileUsage"]').innerxml)/1MB))))  
            VirtualSize=$([math]::round(((($_.SelectSingleNode('Property[@Name="VM"]').innerxml)/1MB))))  
            ReadTransferCount=($_.SelectSingleNode('Property[@Name="ReadTransferCount"]').innerxml)
            ReadOperationCount=($_.SelectSingleNode('Property[@Name="ReadOperationCount"]').innerxml)
            WriteOperationCount=($_.SelectSingleNode('Property[@Name="WriteOperationCount"]').innerxml)
            WriteTransferCount=($_.SelectSingleNode('Property[@Name="WriteTransferCount"]').innerxml)
            ThreadCount=($_.SelectSingleNode('Property[@Name="ThreadCount"]').innerxml)
            WorkingSetSize=($_.SelectSingleNode('Property[@Name="WorkingSetSize"]').innerxml)
            Priority=($_.SelectSingleNode('Property[@Name="Priority"]').innerxml)
            ParentProcessId=($_.SelectSingleNode('Property[@Name="ParentProcessId"]').innerxml)
            PageFaults=($_.SelectSingleNode('Property[@Name="PageFaults"]').innerxml)
            }
        }

        $TopMemoryProcesses| select ProcessName,WS,VirtualSize,PageFileUsage,ProcessID,ReadTransferCount

        $body="<H2>Top Memory consuming processes</H2>" 
        $RetsqlConfigHTML+= $TopMemoryProcesses |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    }






"Collecting OS CPU usage from sys.dm_os_ring_buffers" | write-PHLog -echo -Logtype Debug2
$QuerydatabaseCPUUsage= 
"
-- select * from dbastuff.[vSacAxdb22_1].sys_dm_os_ring_buffers  

-- select sqlserver_start_time,* from sys.dm_os_sys_info

if object_id('tempdb..##tmp_sys_dm_os_ring_buffers') is not null drop table ##tmp_sys_dm_os_ring_buffers
select * 
into ##tmp_sys_dm_os_ring_buffers
from sys.dm_os_ring_buffers  
--where timestamp = (select max(timestamp) from sys.dm_os_ring_buffers where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' and record like '%<SystemHealth>%') 

if object_id('tempdb..##tmp_sys_dm_os_sys_info') is not null drop table ##tmp_sys_dm_os_sys_info
select * 
into ##tmp_sys_dm_os_sys_info
from sys.dm_os_sys_info

GO

declare @ts_now bigint 
select @ts_now = cpu_ticks / (cpu_ticks/ms_ticks) from ##tmp_sys_dm_os_sys_info
select record_id, dateadd(ms, -1 * (@ts_now - [timestamp]), GetDate()) as EventTime, 
      convert(bigint,SQLProcessUtilization) as SQLProcessUtilization, 
      SystemIdle, 
      100 - SystemIdle - SQLProcessUtilization as OtherProcessUtilization 
from ( 
      select 
            record.value('(./Record/@id)[1]', 'int') as record_id, 
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') as SystemIdle, 
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') as SQLProcessUtilization, 
            timestamp 
      from ( 
            select timestamp, convert(xml, record) as record 
            from ##tmp_sys_dm_os_ring_buffers 
            where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
            and record like '%<SystemHealth>%') as x 
      ) as y 
order by record_id desc 


" 
	$RetQuerydatabaseCPUUsage= fnExecuteQuery -ServerInstance $FullSQlInstance -Database "master" -Query  $QuerydatabaseCPUUsage
    $RetQuerydatabaseCPUUsageResult = $RetQuerydatabaseCPUUsage.sqlresult
	$RetQuerydatabaseCPUUsageResult | Format-Table
    $body="<H2>Database CPu Usage </H2>" 
    $RetsqlConfigHTML+= $RetQuerydatabaseCPUUsageResult |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body


    Try{
        $ActivityName="Preparing data for OS and SQL Server uptime"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        $Machine_UpTime = (Get-Date) - $RetSystemSummaryResult.Machine_UpTime
        $Machine_UpTime_Display = "Uptime: " + $Machine_UpTime.Days + " days, " + $Machine_UpTime.Hours + " hours, " + $Machine_UpTime.Minutes + " minutes" 
        $SQLServer_UpTime = (Get-Date) - $RetSystemSummaryResult.SQLServer_UpTime
        $SQLServer_UpTime_Display = "Uptime: " + $SQLServer_UpTime.Days + " days, " + $SQLServer_UpTime.Hours + " hours, " + $SQLServer_UpTime.Minutes + " minutes" 

        $ActivityName="Preparing highest Read/Write latency stats"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        $ReadLatency=($RetatabaseIOLatencyResult| Sort-Object ReadLatency -descending | select -First 1 ).ReadLatency
        $WriteLatency=($RetatabaseIOLatencyResult| Sort-Object WriteLatency -descending | select -First 1).WriteLatency
        $Latency=($RetatabaseIOLatencyResult| Sort-Object Latency -descending | select -First 1).Latency

        $ActivityName="Consolidating SQL server stats for Observations"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        $Servercheck=[pscustomobject]  @{
            Name=$RetSystemSummaryResult.ComputerNamePhysicalNetBIOS
            Machine_UpTime=$Machine_UpTime_Display
            SQLServer_UpTime=$SQLServer_UpTime_Display
            TotalPhysicalMemory=$RetServerSpecsresult3.TotalPhysicalMemory
            FreePhysicalMemory=$RetServerSpecsresult3.FreePhysicalMemory
            NumberOfLogicalProcessors=$RetServerSpecsresult3.NumberOfLogicalProcessors
            PLE =($RetQueryDB_PerfCounterResult | where-object {$_.counter_name -match 'Page life expectancy'} | select cntr_value).cntr_value
            MinMem=($RetQuerysp_configureResult | where-object {$_.name -match "min server memory"} ).run_value
            MaxMem=($RetQuerysp_configureResult | where-object {$_.name -match "max server memory"} ).run_value
            ReadLatency=$ReadLatency
            WriteLatency=$WriteLatency
            Latency=$Latency
        }

        $ActivityName="Checking if Disk Latency to be reported in observations"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        if (($Servercheck.ReadLatency -gt 200) -And ($Servercheck.ReadLatency -lt 300))
        {$Observation+=[pscustomobject]  @{Observations="DB Read latency is high: $($Servercheck.ReadLatency), pleaes check are top database and queries causing it"; Priority="Low"}}
        Elseif (($Servercheck.ReadLatency -gt 300))
        {$Observation+=[pscustomobject]  @{Observations="DB Read latency is high: $($Servercheck.ReadLatency), pleaes check are top database and queries causing it"; Priority="Low"}}

        if (($Servercheck.WriteLatency -gt 100) -And ($Servercheck.WriteLatency -lt 200))
        {$Observation+=[pscustomobject]  @{Observations="DB Write latency is high: $($Servercheck.WriteLatency), pleaes check are top database and queries causing it"; Priority="Low"}}
        Elseif (($Servercheck.WriteLatency -gt 200))
        {$Observation+=[pscustomobject]  @{Observations="DB Write latency is high: $($Servercheck.WriteLatency), pleaes check are top database and queries causing it"; Priority="Medium"}}

        if (($Servercheck.Latency -gt 100) -And ($Servercheck.Latency -lt 200))
        {$Observation+=[pscustomobject]  @{Observations="DB latency is high: $($Servercheck.Latency), pleaes check are top database and queries causing it"; Priority="Low"}}
        Elseif (($Servercheck.Latency -gt 200))
        {$Observation+=[pscustomobject]  @{Observations="DB latency is high: $($Servercheck.Latency), pleaes check are top database and queries causing it"; Priority="Medium"}}

    }
    catch
    {
        $AppErrorCollection+=[pscustomobject] @{ErrorType="Powershell";ErrorActivityName=$ActivityName;ErrorMessage=$($_.exception.message) }
        $AppErrorCollection  | write-PHLog -echo -Logtype Error
    }


    Try
    {
        $ActivityName="Checking if database growth to be reported in observations"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        if ($RetQuerydatabaseGrowthResult)
        {
            $DbGrowthSummary=$RetQuerydatabaseGrowthResult | measure-object -property TotalGrowthMB -minimum -maximum -average -sum

            if (!($DbGrowthSummary -eq $null)) {$DbGrowthSummary.Sum=[math]::round($DbGrowthSummary.Sum)}

            if ($DbGrowthSummary.Sum -gt 1000) 
            {$Observation+=[pscustomobject]  @{Observations="Unusual DB growth have been noticed in last 2 days: $($DbGrowthSummary.Sum) MB, pleaes check if this is due to any adhoc activity"; Priority="Low"}}

            if (($DbGrowthSummary.Count -gt 1) -and ($DbGrowthSummary.Sum -gt 200))
            {$Observation+=[pscustomobject]  @{Observations="$($DbGrowthSummary.Count) DB growth events have been noticed in last 2 days, pleaes check if this is due to any adhoc activity"; Priority="Low"}}

        }

        $ActivityName="Checking if OS or SQL uptime to be reported in observations"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        if (($Machine_UpTime.Days -gt 30) -And ($Machine_UpTime.Days -lt 90))
        {$Observation+=[pscustomobject]  @{Observations="OS has not been rebooted for a while $($Servercheck.Machine_UpTime)"; Priority="Low"}}
        elseif (($Machine_UpTime.Days -gt 90))
        {$Observation+=[pscustomobject]  @{Observations="OS has not been rebooted for a while $($Servercheck.Machine_UpTime)"; Priority="Medium"}}

        if (($SQLServer_UpTime.Days -gt 30) -And ($SQLServer_UpTime.Days -lt 90))
        {$Observation+=[pscustomobject]  @{Observations="SQL Server has not been rebooted for a while $($Servercheck.SQLServer_UpTime)"; Priority="Low"}}
        elseif (($SQLServer_UpTime.Days -gt 90))
        {$Observation+=[pscustomobject]  @{Observations="SQL Server has not been rebooted for a while $($Servercheck.SQLServer_UpTime)"; Priority="Medium"}}
    
    
        $ActivityName="Checking if OS or SQL memory configuraion to be reported in observations"
        $ActivityName | write-PHLog -echo -Logtype Debug2
        $ExpectedPLE=$($Servercheck.TotalPhysicalMemory/4)*300

        if ($Servercheck.FreePhysicalMemory -lt .3)
        {
            $Observation+=[pscustomobject]  @{Observations="Free memory for OS is very low, check whats consuming OS memory"; Priority="Medium"}

            if ($Servercheck.PLE -gt $ExpectedPLE)
            {
                $Observation+=[pscustomobject]  @{Observations="OS free memory is low though PLE is very high, reduce Min/Max to releaes memory for OS"; Priority="Medium"}
            }
        }

        if ($Servercheck.PLE -lt $ExpectedPLE)
        {
            if ($Servercheck.FreePhysicalMemory -gt 1)
            {
                $Observation+=[pscustomobject]  @{Observations="PLE is low, OS has more than 1 GB free memory, please check if increase Min/Max memory for SQL make sense"; Priority="Medium"}
            }
        }


        if ($Servercheck.MinMem -ne $Servercheck.MaxMem)
        {
                $Observation+=[pscustomobject]  @{Observations="SQL assigned Min and Max ram is diff please validate if thats expected?"; Priority="Low"}
        }

        $TotalPhysicalMemory=$Servercheck.TotalPhysicalMemory
        if ($TotalPhysicalMemory -le 4) {$SQLMaxMinMemoryGB = 2700}
        elseif ($TotalPhysicalMemory -le 16000) {$SQLMaxMinMemoryGB = $($TotalPhysicalMemory*1024)-2000}
        else {$SQLMaxMinMemoryGB = $($TotalPhysicalMemory*1024)-4000}

        if ($Servercheck.MaxMem -gt $SQLMaxMinMemoryGB)
        {
                $Observation+=[pscustomobject]  @{Observations="SQL assigned Max ram more than recommended memory value: $($SQLMaxMinMemoryGB) please validate why?"; Priority="Low"}
        }
    }
    catch
    {
        $AppErrorCollection+=[pscustomobject] @{ErrorType="Powershell";ErrorActivityName=$ActivityName;ErrorMessage=$($_.exception.message) }
        $AppErrorCollection  | write-PHLog -echo -Logtype Error
    }





    $ActivityName="Adding key memory info to be added to the top of report"
    $ActivityName | write-PHLog -echo -Logtype Debug2
    $body="<H2>Memory Stats</H2>" 
    $KeyServerStats=$Servercheck | select Name,TotalPhysicalMemory,FreePhysicalMemory,MaxMem,MinMem,PLE | ConvertTo-HTML  -head $a  -body $body 

    $ActivityName="Adding key CPU info to be added to the top of report"
    $ActivityName | write-PHLog -echo -Logtype Debug2
    $body="<H2>CPU Stats</H2>" 
    $KeyServerStats+=$Servercheck | select Machine_UpTime,SQLServer_UpTime,NumberOfLogicalProcessors | ConvertTo-HTML  -head $a   -body $body 

    $SQLProcessUtilizationLast30Min=$RetQuerydatabaseCPUUsageResult| select -first 30 | measure-object -property SQLProcessUtilization -minimum -maximum -average
    $SQLProcessUtilization=$RetQuerydatabaseCPUUsageResult| measure-object -property SQLProcessUtilization -minimum -maximum -average
    $SQLProcessUtilizationIdle=$RetQuerydatabaseCPUUsageResult| measure-object -property SystemIdle -minimum -maximum -average
    $OtherProcessUtilization=$RetQuerydatabaseCPUUsageResult| measure-object -property OtherProcessUtilization -minimum -maximum -average
    $CPUMeasureDuration=$RetQuerydatabaseCPUUsageResult| measure-object -property EventTime -minimum -maximum | select minimum,maximum
    $CPUDuration=$((NEW-TIMESPAN –Start $CPUMeasureDuration.Minimum –End $CPUMeasureDuration.Maximum).TotalHours)



    $CPUStats=[pscustomobject]  @{
        CPUDurationHours=[math]::round($CPUDuration)
        SQLCPUAverage30Min=[math]::round($SQLProcessUtilizationLast30Min.average,2)
        SQLCPUmaximum30Min=[math]::round($SQLProcessUtilizationLast30Min.maximum)
        SQLCPUminimum30Min=[math]::round($SQLProcessUtilizationLast30Min.minimum)
        SQLCPUAverage=[math]::round($SQLProcessUtilization.average,2)
        SQLCPUmaximum=[math]::round($SQLProcessUtilization.maximum)
        SQLCPUminimum=[math]::round($SQLProcessUtilization.minimum)
        IdleCPUAverage=[math]::round($SQLProcessUtilizationIdle.average,2)
        IdleCPUmaximum=[math]::round($SQLProcessUtilizationIdle.maximum)
        IdleCPUminimum=[math]::round($SQLProcessUtilizationIdle.minimum)
        OtherProcessUtilizationAverage=[math]::round($OtherProcessUtilization.average,2)
        OtherProcessUtilizationMaximum=[math]::round($OtherProcessUtilization.maximum)
        OtherProcessUtilizationminimum=[math]::round($OtherProcessUtilization.minimum)
    }

    $ActivityName="Checking if CPU stats to be reported in observations"
    $ActivityName | write-PHLog -echo -Logtype Debug2
    if ($CPUStats.SQLCPUAverage30Min -gt 40)
    {$Observation+=[pscustomobject]  @{Observations="SQL is using high CPU, check top queries and sessions using CPU in last 30 Minute"; Priority="Medium"}}

    if ($CPUStats.OtherProcessUtilizationAverage -gt 20)
    {$Observation+=[pscustomobject]  @{Observations="Non SQL processes are using very high CPU in last $($CPUStats.CPUDurationHours) hours, check non sql proceseses"; Priority="Medium"}}

    $CPUStats | select CPUDurationHours,SQLCPUAverage30Min,SQLCPUAverage,OtherProcessUtilizationAverage,IdleCPUAverage,SQLCPUmaximum30Min,SQLCPUmaximum,OtherProcessUtilizationMaximum,IdleCPUmaximum,SQLCPUminimum30Min,SQLCPUminimum,OtherProcessUtilizationminimum,IdleCPUminimum
    $KeyServerStats+=$CPUStats | select CPUDurationHours,SQLCPUAverage30Min,SQLCPUAverage,OtherProcessUtilizationAverage,IdleCPUAverage,SQLCPUmaximum30Min,SQLCPUmaximum,OtherProcessUtilizationMaximum,IdleCPUmaximum,SQLCPUminimum30Min,SQLCPUminimum,OtherProcessUtilizationminimum,IdleCPUminimum| ConvertTo-HTML  -head $a  

    $ActivityName="Adding key dataabse usage stats to be added to the top of report"
    $ActivityName | write-PHLog -echo -Logtype Debug2
    $body="<H2>Database Usage Summary</H2>" 
    $KeyServerStats+=$Servercheck | select Latency,WriteLatency,ReadLatency | ConvertTo-HTML  -head $a   -body $body 
    $KeyServerStats+= $DiskStatsSummarized | select ServerName,Drive,FileType,DiskSize,DiskUsedSpace,DiskFreespace,DiskFreePercentage,DBFileSizeGB,DBFileSpaceUsedGB,DBFileFreeSpaceGB,DBFreePercentage | Sort-Object -Property FileType -Descending | ConvertTo-HTML  -head $a 

    $ActivityName="Adding observations sumamry to the top of report"
    $ActivityName | write-PHLog -echo -Logtype Debug2
    $body="<H2>Observations</H2>" 
    $ObservationsHTML=$Observation  | Select Observations,Priority| ConvertTo-HTML  -head $a  -body $body

    $RetsqlConfigHTMLCombined= $ObservationsHTML+ $KeyServerStats+$RetsqlConfigHTML

    $RetsqlConfigHTMLCombined= $RetsqlConfigHTMLCombined|
    Foreach-Object {
        $_ -replace  $ColorIncomplete -replace $ColorFailed -replace $ColorCancelled -replace $ColorActive
        }	
}
else
{

    $FailedConnection= [pscustomobject] @{FailedConnection="Could not connect to server $lHostName"; ErrorMessage=$RetSystemSummary.ExecuteSQLError}
    $RetsqlConfigHTMLCombined+= $FailedConnection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors| ConvertTo-HTML  -head $a   -body $body
    $connectionfailed=$true
}

if ($AppErrorCollection)
{
    $body="<H2>Errors during collecting server health check v2</H2>" 
    $RetsqlConfigHTMLCombined+=$AppErrorCollection |Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-HTML  -head $a  -body $body 
}


$ActivityName="Sending email with all observations to $EmailSender"
$ActivityName | write-PHLog -echo -Logtype Debug2
$emailSubject=$FullSQlInstance + ": Server Summary as of - $((Get-Date).ToShortDateString())  $((Get-Date).ToShortTimeString()) " 
fnSendEmail -FromEmail   $EmailSender  -EmailHTML $RetsqlConfigHTMLCombined -emailSubject $emailSubject -HostName $CentralHost -smtpserver $smtpserver
"Script completed" | write-PHLog -echo -Logtype Success


