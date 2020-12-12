
<#
Take a Primary Replica instance as input
    - Add all databases to the Availability Group.
    - Maunal Seeding => Backup -> Copy -> Restore

#inspired by code from ijeb
#https://github.com/sqlcollaborative/dbatools/issues/4610

#  todo:  restore login SA
#>

$listener = 'LSTN-APP-QUAL'

$primaryReplica =    Get-DbaAgReplica -SqlInstance $listener | Where-Object Role -eq Primary
$secondaryReplicas = Get-DbaAgReplica -SqlInstance $listener | Where-Object Role -eq Secondary
$AG = (Get-DbaAvailabilityGroup -SqlInstance $primaryReplica.Name).AvailabilityGroup
$databases = Get-DbaDatabase -SqlInstance $primaryReplica.Name

$allbackups = @{}

foreach ($db in $databases) {
    $primaryDb = Get-DbaDatabase -SqlInstance $primaryReplica.Name -Database $db.Name
    
    foreach ($second in $secondaryReplicas) {
        Write-Output "priamry: " +$db
        $secondaryDb = Get-DbaDatabase -SqlInstance $second.Name -Database $db.Name
        Write-Output "secondary: " +$secondaryDb

        if (-not $secondaryDb) {
            Write-Output $db.Name
            # Backup Primary 
            $fullbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Full -EnableException -Initialize
            $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
            $allbackups[$db] = $fullbackup, $logbackup

            foreach ($file in $allbackups[$db]) {
                $backupPath =  $file.Path -replace ':', '$'
                $primaryHost = $primaryReplica.Name.Substring(0, $primaryReplica.Name.IndexOf('\')+1)
                $secondaryHost = $second.Name.Substring(0, $second.Name.IndexOf('\')+1)

                $secondaryPath = '\\' + $secondaryHost + $backupPath
                $primaryPath = '\\' + $primaryHost + $backupPath
                Write-Output $primaryPath

                Copy-Item -Path $primaryPath -Destination $secondaryPath
            }
        
            $allbackups[$db] | Restore-DbaDatabase -SqlInstance $second.Name -WithReplace -NoRecovery -EnableException
        
            #Check si la DB est déjà dans le groupe ou pas
            $agInDb = Get-DbaAgDatabase -SqlInstance $primaryReplica.Name -AvailabilityGroup $AG | Where-Object Name -eq $db.Name
            if (-not $agInDb) {
                Write-Output "not agInDb"
                $query = "ALTER AVAILABILITY GROUP [$($AG)] ADD DATABASE [$($db.Name)]" 
                Invoke-DbaQuery -SqlInstance $primaryReplica.Name -Query $query
            }
            Write-Output "set hadr"
            #Add-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG -Database $db.Name -Secondary
            $query = "ALTER DATABASE [$($db.Name)] SET HADR AVAILABILITY GROUP = [$($AG)]"
            Invoke-DbaQuery -SqlInstance $second.Name -Query $query

        } # if (-not $secondaryDb)

    } # foreach ($second in $secondaries)
}

