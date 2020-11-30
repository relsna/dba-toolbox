
$Listeners = Get-DbaRegisteredServer -SqlInstance 'CMS' | Where-Object {$_.Group -Like '*Prod*2014*Listener*'};
$Listeners | ForEach-Object {Get-DbaAvailabilityGroup -SqlInstance $_.ServerName | select ComputerName, InstanceName, LocalReplicaRole, AvailabilityGroupListeners}

