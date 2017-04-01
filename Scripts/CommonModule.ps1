# HTML table Formatting for email
$a = "<style>"
$a = $a + "BODY{background-color:peachpuff;}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:thistle}"
$a = $a + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:palegoldenrod}"
$a = $a + "tr.datacellcolor {background-color: #CC9999; color: black;}"
$a = $a + "td.datacellgreen {background-color: #CC9999; color: black;}"
$a = $a + "td.datacellred {background-color: #CC9999; color: black;}"
$a = $a + "td.datacellYellow {background-color: #CC9999; color: black;}"
$a = $a + "td.datacellthistle {background-color: #CC9999; color: black;}"
$a = $a + "</style>"


# Function to write logs to HTML log file with color coded format
function write-PHLog {
    param([string] $Logtype,
          [string] $fileName,
          [switch] $echo,
          [switch] $clear
    )
    switch ($Logtype) 
        { 
            "DEBUG" {$LogtypeEntry="White";$cmdPrint="White"} 
            "DEBUG2" {$LogtypeEntry="White";$cmdPrint="White"} 
            "WARNING" {$LogtypeEntry="Magenta";$cmdPrint="Magenta"} 
            "ERROR" {$LogtypeEntry="Red";$cmdPrint="Red"} 
            "Success" {$LogtypeEntry="LightGreen";$cmdPrint="Green"} 
            default {$LogtypeEntry="DarkRed";$cmdPrint="RED"}
        }


$CurrentPath=$pwd
set-location c:\ -PassThru | out-null

if ([string]::IsNullOrEmpty($ExecutionSummaryLogFile))
{
    write-warning ("Write-PHLog function failed as log file name is not populated `nPleaes populate variable: `$ExecutionSummaryLogFile `nexiting now `n`n")
    exit
}

    Try {            
            $LogToWriteRec=@()
            $flgObject=$false
            $input | %{
                    $LogToWriteRec+=$_; 
                    if ($_.length -gt 0) {if ($_.GetType().name -ne "String") {$flgObject=$true}} else {$flgObject=$true}
                }
            $LogToWrite =$LogToWriteRec | Out-String
            if (($Logtype -eq "Debug2")-and ($flgObject -ne $true) -and ($LogToWrite.Length -lt 120))
            {
                $LogToWrite="          "+$LogToWrite
            }
            $LogToWrite=$LogToWrite.TrimEnd()

            if ($functionname) {$LogToWrite= "        "+$functionname +":"+ $LogToWrite}
            if ($echo.IsPresent)
            {
                Write-host $LogToWrite -ForegroundColor $cmdPrint
            }

            if (($flgObject -eq $true) -or ($LogToWrite.Length -gt 129)) 
            {
                $LogToWrite="<blockquote>" + $LogToWrite + "</blockquote>"
            }

            $LogToWrite=($LogToWrite).Replace("`n","<br>")
            $LogToWrite=($LogToWrite).Replace("  ","&nbsp;&nbsp;")
            [boolean] $isAppend = !$clear.IsPresent
            if (($isAppend -eq $false ) -or (!(test-path $ExecutionSummaryLogFile)) )
            {$BodyColor="<body bgcolor=""DarkBlue"">"} else {$BodyColor=""}

            $BodyColor + "<font color=""$LogtypeEntry"">" + $LogToWrite  + "</font> <br>"  | out-file $ExecutionSummaryLogFile -encoding UTF8 -Append:$isAppend | Out-Null
            Start-Sleep -Milliseconds 10
            #<blockquote>Whatever you need to indent</blockquote>
        }
        catch
        {
            write-warning ("Write-PHLog function failed, very unsual pleae check with script writer`n`n $($_.exception.message) `n`n"  )
        }
    set-location $CurrentPath | out-null
}


# Function to execute SQL commands and trap errors gracefully
function fnExecuteQuery {
Param (
  [string] $ServerInstance = $(throw "DB Server Name must be specified."),
  [string] $Database = "master",
  [string] $Query = $(throw "QueryToExecute must be specified."),
  [string] $ReadIntentTrue = $null,
  [int] $QueryTimeout=60000
  )

    Try
    {

        $TestSqlAcces=$false

        if (!($Query -match "SET TRANSACTION ISOLATION LEVEL"))
        {
            $Query = "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
                    go
            " + $Query
        }

        if ($SqlPassword.Length -ne 0)
        {	    
            $ReturnResultset=invoke-sqlcmd -ServerInstance $ServerInstance -database $Database -Query $Query -QueryTimeout $QueryTimeout -Username $SqlUser -Password $SqlPassword   -Verbose  -ErrorAction Stop 
        }
        else
        {
            $ReturnResultset=invoke-sqlcmd -ServerInstance $ServerInstance -database $Database -Query $Query -QueryTimeout $QueryTimeout -Verbose  -ErrorAction Stop 
        }
        $TestSqlAcces=$true
        $sqlresult=$ReturnResultset
        if ($sqlresult -match "Timeout expired")
        {
            $SQLTimeoutExpired=$True
            $errorMsg=$sqlresult
        }

    }
        Catch 
        {
            Write-Warning $_.exception.message
            $errorMsg=$_.exception.message

            if ($errorMsg -match "Timeout expired")
            {
                $SQLTimeoutExpired=$True
            }

            if ($errorMsg -match "A network-related or instance-specific error occurred while establishing a connection to SQL Server")
            {$SQLPortissue=$True}
            
            if ($errorMsg -match "Access is denied.")
            {$Authenticationfailed=$True}
            
            $TestSqlAcces=$false
        }

        $QueryTable="testtblStoreQuery";$QueryExecuted = New-Object system.Data.DataTable “$QueryTable”
        $col1 = New-Object system.Data.DataColumn QueryToExecute,([string])
        $QueryExecuted.columns.add($col1)
        $row2 = $QueryExecuted.NewRow();$row2.QueryToExecute = $QueryToExecute ;$QueryExecuted.Rows.Add($row2)

        $functionOutput=[pscustomobject]   @{
        QueryExecuted=$QueryExecuted
        TestSqlAcces = $TestSqlAcces; sqlresult = $sqlresult
        DestinationHost=$DBServer
        DatabaseName=$DatabaseName
        ReturnServerName=$ReturnServerName
        UserName = $UserName; ExecuteSQLError = $errorMsg
        SQLPortIssue=$SQLPortissue
        Authenticationfailed=$Authenticationfailed
        SQLTimeoutExpired=$SQLTimeoutExpired
        }
        return $functionOutput
}



# Function to execute OS WMI commands via XP_cmdshell and trap errors gracefully
function fnExecuteXPCmdShell {
Param (
  [string] $NodeName = $(throw "User Name must be specified."),
  [string] $CommandToExecute = $(throw "User Name must be specified.")
)

$UserName="";$CommandSuccess="";$AdvanceOptionsConfigValue=""; $XPCMDShellConfigValue=""; 
$QueryEnableXP_cmdshell=""; $QueryEnable_AdvanceOptionsConfigValue=""
$QueryGet_XP_cmdshellValue=""; $QueryGet_AdvanceOptionsConfigValue=""; $QueryGet_XP_cmdshellCommandToexecute=""

$QueryGet_AdvanceOptionsConfigValue="EXEC sp_configure 'show advanced option'"

$QueryGet_XP_cmdshellCommandToexecute = "Exec xp_cmdshell '" + $CommandToExecute + "'"



$QueryEnable_AdvanceOptionsConfigValue = 
"
	USE master;
	EXEC sp_configure 'show advanced option', '1';
	RECONFIGURE WITH OVERRIDE;
	EXEC sp_configure 'show advanced option'
"

$QueryEnableXP_cmdshell = 
"
	USE master;
	EXEC sp_configure N'xp_cmdshell', 1;
	RECONFIGURE WITH OVERRIDE;
    EXEC sp_configure N'xp_cmdshell'
"


$QueryDisable_AdvanceOptionsConfigValue = 
"
	USE master;
	EXEC sp_configure 'show advanced option', '0';
	RECONFIGURE WITH OVERRIDE;
	EXEC sp_configure 'show advanced option'
"

$QueryDisableXP_cmdshell = 
"
	USE master;
	EXEC sp_configure N'xp_cmdshell', 0;
	RECONFIGURE WITH OVERRIDE;
    EXEC sp_configure N'xp_cmdshell'
"


$QueryGet_XP_cmdshellValue = 
"
if (CAST(SUBSTRING((CAST(SERVERPROPERTY('productversion') AS NVARCHAR)),1,CHARINDEX('.',(CAST(SERVERPROPERTY('productversion') AS NVARCHAR)))-1) AS float))<9
begin
	select 1 as config_value
end
else
begin
	USE master;
    EXEC sp_configure N'xp_cmdshell'
end
"

#fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryDisableXP_cmdshell
#fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryDisable_AdvanceOptionsConfigValue

    try
	{

	    $Ret_AdvanceOptionsConfigValue = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryGet_AdvanceOptionsConfigValue
        if (($Ret_AdvanceOptionsConfigValue.TestSqlAcces -eq $true) )
        {
            $UserName=$Ret_AdvanceOptionsConfigValue.UserName
            $AdvanceOptionsConfigValue = $Ret_AdvanceOptionsConfigValue.sqlresult.config_value
            if ($Ret_AdvanceOptionsConfigValue.sqlresult.config_value -eq 0) 
            {		    
            $retEnable_AdvanceOptionsConfigValue = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryEnable_AdvanceOptionsConfigValue
                if (!($retEnable_AdvanceOptionsConfigValue.TestSqlAcces -eq $true))
                {
                    $SQLResult=$retEnable_AdvanceOptionsConfigValue.sqlresult 
                    $ErrorMessage=$retEnable_AdvanceOptionsConfigValue.ExecuteSQLError 
                    Write-error "not able to enable advance configuration"
                }
            }

            $RetGet_XP_cmdshellValue = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryGet_XP_cmdshellValue
            if ($RetGet_XP_cmdshellValue.TestSqlAcces -eq $true) 
            {
                $XPCMDShellConfigValue = $RetGet_XP_cmdshellValue.sqlresult.config_value
                if ($RetGet_XP_cmdshellValue.sqlresult.config_value -eq 0) 
                {		    
                    $retQueryEnableXP_cmdshell = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryEnableXP_cmdshell
                    if (!($retQueryEnableXP_cmdshell.TestSqlAcces -eq $true))
                    {
                        $SQLResult=$retQueryEnableXP_cmdshell.sqlresult 
                        $ErrorMessage=$retQueryEnableXP_cmdshell.ExecuteSQLError 
                        Write-error ("not able to enable XMCmdshell configuration `n" + $ErrorMessage)
                    }
                }

            }
            else
            {
                $SQLResult=$RetGet_XP_cmdshellValue.sqlresult 
                $ErrorMessage=$RetGet_XP_cmdshellValue.ExecuteSQLError 
                Write-error ("not able to get XPCmdshell configuration `n" + $ErrorMessage)
            }

            $RetGet_XP_cmdshellCommandToexecute = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryGet_XP_cmdshellCommandToexecute 
            if ($RetGet_XP_cmdshellCommandToexecute.TestSqlAcces -eq $true)
            {
                $CommandSuccess=$true
                $SQLResult=$RetGet_XP_cmdshellCommandToexecute.sqlresult 
            }
            else
            {
                $SQLResult=$RetGet_XP_cmdshellCommandToexecute.sqlresult 
                $ErrorMessage=$RetGet_XP_cmdshellCommandToexecute.ExecuteSQLError 
            }
            
        }
        else
        {
            $SQLResult=$Ret_AdvanceOptionsConfigValue.sqlresult 
            $ErrorMessage=$Ret_AdvanceOptionsConfigValue.ExecuteSQLError 
        }

        if (($XPCMDShellConfigValue -eq 0) -and ($Ret_AdvanceOptionsConfigValue.TestSqlAcces -eq $true))
        {
    	    $Ret_DisableXP_cmdshell = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryDisableXP_cmdshell
        }
        if (($AdvanceOptionsConfigValue -eq 0) -and ($Ret_AdvanceOptionsConfigValue.TestSqlAcces -eq $true))
        {
    	    $RetDisable_AdvanceOptionsConfigValue = fnExecuteQuery -ServerInstance $NodeName -Database "master" -Query $QueryDisable_AdvanceOptionsConfigValue
            
        }

    }
    Catch 
    {
        Write-Warning $_.exception.message
        $ErrorMessage=$_.exception.message
    }


    $functionVariables=[pscustomobject]   @{
        AdvanceOptionsConfigValue = $AdvanceOptionsConfigValue
        XPCMDShellConfigValue = $XPCMDShellConfigValue
        CommandToExecute = $CommandToExecute; 
        CommandSuccess=$CommandSuccess
        TotalExecutionTime=$RetGet_XP_cmdshellCommandToexecute.TotalExecutionTime
        QueryGet_XP_cmdshellCommandToexecute=$QueryGet_XP_cmdshellCommandToexecute
        NodeName=$NodeName
        UserName = $UserName; 
        SQLResult = $SQLResult; 
        ExecuteXMCmdShellError=$ErrorMessage;}

    return $functionVariables
}

#Function to Send emails

function fnSendEmail{
    Param (
      [string] $FromEmail = $(throw "From email must be specified."),
      [string] $emailSubject = $(throw "Email Subject must be specified."),
      [string] $EmailHTML = $(throw "Email content must be specified."),
      [string] $HostName = $(throw "Host Name must be specified."),
      [string] $smtpserver = "",
      [string] $ToEmail = "")
<#
$RetsqlConfigHTML="test"
$EmailHTML="Test"
$fromemail= "svcsqlmon@sqlfeatures.local"
$emailSubject=$lServerName + ": Server Summary as of - $((Get-Date).ToShortDateString())  $((Get-Date).ToShortTimeString()) " 
fnSendEmail -FromEmail  svcsqlmon@sqlfeatures.local -EmailHTML $EmailHTML -emailSubject $emailSubject -Host "AALLINONEE1"
#>


    $userDomain=$env:userdnsdomain

    if ($smtpserver -eq "")
    {
        switch ($userDomain) 
            { 
                "SQLFEATURES.LOCAL" {$smtpserver="mail.sqlfeatures.local"} 
                "Contoso.local" {$smtpserver="mail.sqlfeatures.local"} 
                default {$smtpserver="mail.sqlfeatures.local"}
            }
    }

    if (!($ToEmail.Length -eq 0))  {$EmailSender = $ToEmail}


    $ErrorActionPreference = "Stop"                        
    $messageParameters = @{                        
        Subject = $emailSubject
        Body = $EmailHTML | Out-String
        From = $fromemail                       

        To = $EmailSender
        SmtpServer = $smtpserver

    }                        

    Send-MailMessage @messageParameters -BodyAsHtml
}

