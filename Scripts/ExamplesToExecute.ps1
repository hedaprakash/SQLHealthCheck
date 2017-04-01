#region variables
$smtpserver="Put your smtp server details here"
$SqlPassword = "put sa password here"
$SqlUser="SA"
$emailToSent="enter email address for health check" 
cls

#endregion

#SQL 2008 STD/ Named Instance / Windows Authentication 
powershell \\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1  `
    -EmailSender $emailToSent `
    -ServerInstance "AALLINONEE1\SQL_2008_STD" `
    -smtpserver $smtpserver

#SQL 2008 R2 ENT/ Named Instance / SQL Authentication 
powershell \\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1     `
    -EmailSender $emailToSent  `
    -ServerInstance "AALLINONEE1\SQL_2008R2_ENT"  `
    -SqlUser $SqlUser  `
    -SqlPassword $SqlPassword   `
    -smtpserver $smtpserver

#SQL 2012 Ent/ Default instance/ SQL Authentication 
powershell \\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1     `
    -EmailSender $emailToSent  `
    -ServerInstance "W16s12E1"  `
    -SqlUser $SqlUser  `
    -SqlPassword $SqlPassword  `
    -smtpserver $smtpserver

#SQL 2014 Ent/ Default instance / Windows Authentication / FQDN 
powershell \\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1  `
    -EmailSender $emailToSent  `
    -ServerInstance "W16s14E1.sqlfeatures.local"  `
    -smtpserver $smtpserver

#SQL 2016 STD/ Default instance / SQL Authentication / FQDN 
powershell \\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1     `
    -EmailSender $emailToSent  `
    -ServerInstance "W16S16s1"  `
    -SqlUser $SqlUser  `
    -SqlPassword $SqlPassword  `
    -smtpserver $smtpserver
