#--==============================================================================
#-- DBMS Name        :    SQL Server (RED repository) 
#-- Block Name       :    run-dependent-jobs-powershell
#-- Description      :    Enables forward dependency by scheduling this script at the end
#--                       of any job and configuring child jobs in the run_dependent_jobs_config "Host Script"
#-- Author           :    PWG Consulting Ltd (www.pwgconsultingltd.co.uk)
#--==============================================================================
#-- Notes / History
#-- In this context the Host Script run_dependent_jobs_config is being utilised as a text file rather than an actual script

Import-module -Name WslPowershellCommon -DisableNameChecking
Import-module -Name WslPowershellSnowflake -DisableNameChecking
$tgtConn = New-Object System.Data.Odbc.OdbcConnection
Hide-Window

#--============================================================================
#-- General Variables
#--============================================================================

$sequence = ${env:WSL_SEQUENCE}
$jobName = ${env:WSL_JOB_NAME}
$taskName = ${env:WSL_TASK_NAME}
$jobId = ${env:WSL_JOB_KEY}
$taskId = ${env:WSL_TASK_KEY}
$return_Msg = "run_dependent_jobs_powershell completed."
$status = 1
$jobCount = 0
$dependencyCount = 0

$sqlDependencies = @"
SELECT
sl_line
FROM ws_scr_line
JOIN ws_scr_header
 ON sl_obj_key=sh_obj_key
WHERE
sh_name = 'run_dependent_jobs_config'
ORDER BY
sl_line_no
"@

$sqlDependenciesResult = Run-RedSQL -sql $sqlDependencies -dsn "dev_ws_repo" -failureMsg "Failed" -odbcConn $tgtConn
$dependencies = $sqlDependenciesResult[4].sl_line | ConvertFrom-Json

foreach ($dependency in $dependencies.dependencies) {

    if (($dependency.parentJob -ne $null) -and ($dependency.parentJob -eq $jobName)) {
          
          $dependencyCount ++
    }

}


$auditMessage = "The job " + $jobName + " has " + $dependencyCount.ToString() + " dependent job"
if ($dependencyCount -eq 1) {$auditMessage += "."} else {$auditMessage += "s."}

$null = WsWrkAudit -Message $auditMessage

foreach ($dependency in $dependencies.dependencies) {

  if ($dependency.parentJob -ne $null) {
  
    $parentJob = $dependency.parentJob.Trim()

      if ($parentJob -eq $jobName) {
    
      $childJob = $dependency.childJob.Trim()
    
      $childJobStatus = Ws_Job_Status -CheckJob $childJob
        
        if ($childJobStatus[3].ToString() -ne 'R') {
        
              $null = Ws_Job_Release -ReleaseJob $childJob
              
              $auditMessage = $childJob + " released."
              $null = WsWrkAudit -Message $auditMessage
              
              $jobCount ++
            }
        else {
          
    			$auditMessage = "There is an iteration of job " + $childJob + " currently running. Job not released."
          $null = WsWrkAudit -Message $auditMessage
        }
    
      }
    
    }
}

$return_Msg = $return_Msg + " " + $jobCount.ToString() + " dependent job"
if ($dependencyCount -eq 1) {$return_Msg += " released."} else {$return_Msg += "s released."}


$status
$return_Msg
