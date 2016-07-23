$smtpserver="sfsmtp.sqlfeatures.local" # Change this with your own SMTP address
$SqlPassword = "Sequoia2012"
$SqlUser="SA"
$emailToSent="sqlfeatures@testemail.com" 
cls

#SQL 2008 STD/ Named Instance / Windows Authentication 
\\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1  `
    -EmailSender $emailToSent `
    -ServerInstance "AALLINONEE1\SQL_2008_STD" `
    -smtpserver $smtpserver

#SQL 2008 R2 ENT/ Named Instance / SQL Authentication 
\\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1     `
    -EmailSender $emailToSent  `
    -ServerInstance "AALLINONEE1\SQL_2008R2_ENT"  `
    -SqlUser $SqlUser  `
    -SqlPassword $SqlPassword   `
    -smtpserver $smtpserver

#SQL 2012 Ent/ Default instance/ SQL Authentication 
\\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1     `
    -EmailSender $emailToSent  `
    -ServerInstance "w12s12"  `
    -SqlUser $SqlUser  `
    -SqlPassword $SqlPassword  `
    -smtpserver $smtpserver

#SQL 2014 Ent/ Default instance / Windows Authentication / FQDN 
\\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1  `
    -EmailSender $emailToSent  `
    -ServerInstance "w12r2s14.sqlfeatures.local"  `
    -smtpserver $smtpserver

#SQL 2016 STD/ Default instance / SQL Authentication / FQDN 
\\w12r2hv\SQLSetup\Scripts\SQLHealthCheck\SQLHealthCheck.ps1     `
    -EmailSender $emailToSent  `
    -ServerInstance "w12r2s16"  `
    -SqlUser $SqlUser  `
    -SqlPassword $SqlPassword  `
    -smtpserver $smtpserver
