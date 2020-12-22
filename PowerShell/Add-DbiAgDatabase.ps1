
function Add-DbiAgDatabase {
    
    param (
        [Parameter(Mandatory=$true)]$Listener
    )

    <#
        .SYNOPSIS
        Adds databases to AlwaysOn Availability Group

        .DESCRIPTION
        Work In Progress
        Do not use in Prod

        Takes a Listener name as parameter.
            - Go to the primary replica the listener is currently on
            - For all databases that are not existing on any secondary replica
                - Backup database
                - Copy to secondary replica default backup folder
                - Restore database with recovery
                - Add DB to the Availability Group related to the Listener in parameter
            
        To Do :
            - EXECUTE AS LOGIN = 'sa'

        .PARAMETER Listener
        Listener Name


        .EXAMPLE
        C:\PS> Add-DbiAgDatabase -Listener 'LST-APP-QUAL' -Verbose
        File.txt

        .LINK
        Online version: https://github.com/relsna/dba-toolbox/tree/main/PowerShell
    #>

    $primaryReplica =    Get-DbaAgReplica -SqlInstance $listener | Select-Object -Unique | Where-Object Role -eq Primary
    $secondaryReplicas = Get-DbaAgReplica -SqlInstance $listener | Select-Object -Unique | Where-Object Role -eq Secondary
    # Get only the AG related to the listener. Excluse other AG on the instance
    $AG = (Get-DbaAgListener -SqlInstance $listener | Where-Object Name -eq $listener).AvailabilityGroup

    $allbackups = @{}
    $databases = Get-DbaDatabase -SqlInstance $primaryReplica.Name

    foreach ($db in $databases) {
        $primaryDb = Get-DbaDatabase -SqlInstance $primaryReplica.Name -Database $db.Name
        
        foreach ($second in $secondaryReplicas) {
            Write-Verbose "priamry:  $db"
            $secondaryDb = Get-DbaDatabase -SqlInstance $second.Name -Database $db.Name
            Write-Verbose "secondary:  $secondaryDb"

            if (-not $secondaryDb) {
                Write-Verbose $db.Name
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
                    Write-Verbose $primaryPath

                    Copy-Item -Path $primaryPath -Destination $secondaryPath
                }
            
                $allbackups[$db] | Restore-DbaDatabase -SqlInstance $second.Name -WithReplace -NoRecovery -EnableException
            
                #Check si la DB est déjà dans le groupe ou pas
                $agInDb = Get-DbaAgDatabase -SqlInstance $primaryReplica.Name -AvailabilityGroup $AG | Where-Object Name -eq $db.Name
                if (-not $agInDb) {
                    Write-Verbose "not agInDb"
                    $query = "ALTER AVAILABILITY GROUP [$($AG)] ADD DATABASE [$($db.Name)]" 
                    Invoke-DbaQuery -SqlInstance $primaryReplica.Name -Query $query
                }
                Write-Verbose "set hadr"
                $agInDb = Get-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG | Where-Object Name -eq $db.Name
                if (-not $agInDb) {
                    Write-Verbose "set hadr2"
                    #Add-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG -Database $db.Name -Secondary
                    $query = "ALTER DATABASE [$($db.Name)] SET HADR AVAILABILITY GROUP = [$($AG)]"
                    Invoke-DbaQuery -SqlInstance $second.Name -Query $query
                }

            } # if (-not $secondaryDb)

        } # foreach ($second in $secondaries)
    }
}
