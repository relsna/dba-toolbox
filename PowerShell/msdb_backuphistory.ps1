<#
Get-DbaDbTable -SqlInstance 'InstanceName' -Database msdb `
    | Where-Object {$_.Name -Like 'backup*'} `
    | Select-Object -Property Name, RowCount, DataSpaceUsed, IndexSpaceUsed `
    | Out-GridView

select *
from msdb..backupset
order by 1 desc

#>
$rowsBefore=$null
$sizeBefore=$null
$rowsAfter=$null
$sizeAfter=$null

$Servers = Get-DbaRegisteredServer -SqlInstance 'CMS' | Where-Object {$_.Group -Like '*Prod*Direct*'};
foreach ($srv in $Servers) {
    Get-DbaDbTable -SqlInstance $srv -Database msdb `
        | Where-Object {$_.Name -Like 'backup*'} `
        | ForEach-Object -Process {$rowsBefore+=$_.RowCount; $sizeBefore+=$_.DataSpaceUsed}
}

Write-Output "backup history total rows: $rowsBefore" 
Write-Output "backup history total size: $sizeBefore" 


foreach ($srv in $Servers) {
    Remove-DbaDbBackupRestoreHistory -SqlInstance $srv -KeepDays 120 -Confirm:$false
}


Start-Sleep -Seconds 10

foreach ($srv in $Servers) {
    Get-DbaDbTable -SqlInstance $srv -Database msdb `
        | Where-Object {$_.Name -Like 'backup*'} `
        | ForEach-Object -Process {$rowsAfter+=$_.RowCount; $sizeAfter+=$_.DataSpaceUsed}
}

Write-Output "backup history total rows: $rowsAfter" 
Write-Output "backup history total size: $sizeAfter" 

$diffRows= $rowsBefore-$rowsAfter
$diffSize= $sizeBefore-$sizeAfter

Write-Output "Diff rows: $diffRows" 
Write-Output "Diff size: $diffSize" 
