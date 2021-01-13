try {
    Get-Module -Name dbatools | Remove-Module
    Import-Module dbatools -MinimumVersion '1.0.135' -Force
} catch {
    Write-Warning 'dbatools module 1.0.135+ is mandatory. Exit...'
    exit
}

function Add-DbiAgDatabase {
    
    param (
        [Parameter(Mandatory=$true)]$Listener
        , [Parameter(Mandatory=$false)]$DbOwner = "sa"
    )

    <#
        .SYNOPSIS
        Adds databases to AlwaysOn Availability Group

        .DESCRIPTION
        Work In Progress
        Do not use in Prod

        Requires dbatools 1.0.135 minimum (Restore-DbaDatabase -ExecuteAs)

        Takes a Listener name as parameter.
            - Go to the primary replica the listener is currently on
            - For all databases that are not existing on any secondary replica
                - Backup database
                - Copy to secondary replica default backup folder
                - Restore database with recovery
                - Add DB to the Availability Group related to the Listener in parameter
            
        To Do :
            - Not take new backup - Use existing backups - Get-DbaBackupHistory
            - Some instances (2017) have automatic seeding - Add-DbaAgDatabase
            - Delete backup files
            - Use dbi tools backup path

        .PARAMETER Listener
        Listener Name

        .EXAMPLE
        C:\PS> Add-DbiAgDatabase -Listener 'LST-APP-QUAL' -Verbose

        .LINK
        Online version: https://github.com/relsna/dba-toolbox/tree/main/PowerShell
    #>

    # To check if this is OK with multiple AG primary on this replica?
    $primaryReplica =    Get-DbaAgReplica -SqlInstance $listener | Select-Object -Unique | Where-Object Role -eq Primary
    $secondaryReplicas = Get-DbaAgReplica -SqlInstance $listener | Select-Object -Unique | Where-Object Role -eq Secondary
    
    # Get only the AG related to the listener. Excluse other AG on the instance
    $AG = (Get-DbaAgListener -SqlInstance $listener | Where-Object Name -eq $listener).AvailabilityGroup
    $databases = Get-DbaDatabase -SqlInstance $primaryReplica.Name
    $allbackups = @{}

    foreach ($db in $databases) {
        $primaryDb = Get-DbaDatabase -SqlInstance $primaryReplica.Name -Database $db.Name
        
        foreach ($second in $secondaryReplicas) {
            $secondaryDb = Get-DbaDatabase -SqlInstance $second.Name -Database $db.Name
            Write-Verbose "secondary:  $secondaryDb"

            if (-not $secondaryDb) {
                Write-Verbose $db.Name

                # Check if database is in FULL recovery Model
                #$primaryDb | select *
                if ($primaryDb.RecoveryModel -ne 'Full') {
                    $primaryDb | Set-DbaDbRecoveryModel -RecoveryModel Full -Confirm:$false
                }
                
                # Primary Replica Backup
                #$allbackups[$db] = Get-DbaDbBackupHistory -SqlInstance $primaryReplica.Name -Database $primarydb.Name -IncludeCopyOnly -Last -EnableException
                #if (-not $allbackups[$db]) {
                    $fullbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Full -EnableException -Initialize
                    $logbackup = $primarydb | Backup-DbaDatabase -Checksum -CompressBackup -Type Log -EnableException -Initialize
                    $allbackups[$db] = $fullbackup, $logbackup
                #}

                foreach ($file in $allbackups[$db]) {
                    $backupPath =  $file.Path -replace ':', '$'
                    $primaryHost = $primaryReplica.Name.Substring(0, $primaryReplica.Name.IndexOf('\')+1)
                    $secondaryHost = $second.Name.Substring(0, $second.Name.IndexOf('\')+1)

                    $secondaryPath = '\\' + $secondaryHost + $backupPath
                    $primaryPath = '\\' + $primaryHost + $backupPath
                    Write-Verbose $primaryPath

                    Copy-Item -Path $primaryPath -Destination $secondaryPath
                }
            
                $allbackups[$db] | Restore-DbaDatabase -SqlInstance $second.Name -ExecuteAS $DbOwner -WithReplace -NoRecovery -EnableException
            
                # Check if DB is aready joined to AG
                $agInDb = Get-DbaAgDatabase -SqlInstance $primaryReplica.Name -AvailabilityGroup $AG | Where-Object Name -eq $db.Name
                if (-not $agInDb) {
                    Write-Verbose "not agInDb primary"
                    $query = "ALTER AVAILABILITY GROUP [$($AG)] ADD DATABASE [$($db.Name)]" 
                    Invoke-DbaQuery -SqlInstance $primaryReplica.Name -Query $query
                }
                $agInDb = Get-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG |Where-Object {($_.Name -eq $db.Name) -and ($_.IsJoined -eq $true) -and ($_.SynchronizationState -eq 'Synchronized')}
                if (-not $agInDb) {
                    Write-Verbose "not agInDb secondary"
                    # Add-DbaAgDatabase -SqlInstance $second.Name -AvailabilityGroup $AG -Database $db.Name -Secondary
                    $query = "ALTER DATABASE [$($db.Name)] SET HADR AVAILABILITY GROUP = [$($AG)]"
                    Invoke-DbaQuery -SqlInstance $second.Name -Query $query
                }
            }
        }
    }
}
