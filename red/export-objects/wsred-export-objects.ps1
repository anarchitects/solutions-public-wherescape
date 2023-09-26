param (
[Parameter(mandatory=$true)]
[ValidateSet('dfs','dtm','ext-prop-definition','script-lang-definition','options','parameter')]
[string]$exportType,
[string]$dsn,
[string]$workingDirectory,
[string]$redcliLocation,
[switch]$versionExportDirectory,
[switch]$versionExportFile,
[switch]$excludeWsMethods
)

Import-Module -Name $PSScriptRoot\wsred-export-objects-functions.psm1 -Force
#------------------------------------------------------------------------------
# Global script variables
#------------------------------------------------------------------------------
#Timestamp appended to file and folder names to allow for multiple runs in the same day
$fileTimestamp = ( get-date ).ToString("yyyyMMddTHHmmss")

#Check if a working directory has been supplied and if not then set to a default of c:\temp also check if it exists and create it if not
if (-not ($workingDirectory)) {$workingDirectory = "C:\temp"}
$null = if (-not (Test-Path $workingDirectory)) {New-Item $workingDirectory -ItemType "directory"}

#Set the top level directory variable for exports
if ($versionExportDirectory) {
    $exportDirectory = $exportType + "_" + $fileTimestamp
    $dirExport = Join-Path -Path $workingDirectory -ChildPath $exportDirectory
    $null = if (-not (Test-Path $dirExport)) {New-Item $dirExport -ItemType "directory" | Out-Null}
}
else {
    $dirExport = Join-Path -Path $workingDirectory -ChildPath "$exportType"
    $null = if (Test-Path $dirExport) {Remove-Item $dirExport -Recurse -Force}
    $null = if (-not (Test-Path $dirExport)) {New-Item $dirExport -ItemType "directory" | Out-Null}
}

#Location of the log file that any logging will be output to
$fileLog = Join-Path -Path $workingDirectory -ChildPath $exportType
$fileLog += "_log_$fileTimestamp.txt"
$null = if (-not (Test-Path $fileLog)) {New-Item $fileLog -ItemType "file" | Out-Null}

#Location of the redcli executable, if not supplied then the default install loction is assumed
if (-not ($redcliLocation)) {$redcliLocation = "C:\Program Files\WhereScape\RED\RedCli.exe"}

#------------------------------------------------------------------------------

switch ($exportType) {
    "dfs" {
        $listObjectsCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand list-all
        $listObjectsResult = Invoke-Expression $listObjectsCommand
        foreach ($line in $listObjectsResult) {
            if (($line -like "*Name*Value*") -and (-not ($line -like "*Database Function Sets*"))) {
                $line = $line.substring($line.IndexOf("[")) -replace "\[","" -replace "\]",""
                $fileName = $line -replace " ",""
                $fileExport = Join-Path -Path $dirExport -ChildPath $fileName
                $exportCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand export
                $exportCommand = ($exportCommand -replace "human","xml") + ' -n "' + $line + '" -f "' + $fileExport + '.xml"'
                Invoke-Expression $exportCommand | Out-File $fileLog -Append
            }
        }
    }
    "dtm" {
        $listObjectsCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand list-all
        $listObjectsResult = Invoke-Expression $listObjectsCommand
        foreach ($line in $listObjectsResult) {
            if (($line -like "*Name*Value*") -and (-not ($line -like "*Data Type Mapping Sets*")) -and (-not ($line -like "*DtmSet*"))) {
                $line = $line.substring($line.IndexOf("[")) -replace "\[","" -replace "\]",""
                $fileName = $line -replace " ",""
                $fileExport = Join-Path -Path $dirExport -ChildPath $fileName
                $exportCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand export
                $exportCommand = ($exportCommand -replace "human","xml") + ' -n "' + $line + '" -f "' + $fileExport + '.xml"'
                Invoke-Expression $exportCommand | Out-File $fileLog -Append
            }
        }
    }
    "options" {
        $fileExport = Join-Path -Path $dirExport -ChildPath $exportType
        $fileExport += ".xml"
        $exportCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand export
        $exportCommand = ($exportCommand -replace "human","xml") + ' -f "' + $fileExport + '"'
        Invoke-Expression $exportCommand | Out-File $fileLog -Append
    }
    "parameter" {
        $fileExport = Join-Path -Path $dirExport -ChildPath $exportType
        $fileExport += ".txt"
        $exportCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand list-all
        $exportResult = Invoke-Expression $exportCommand
        Format-Human $exportResult | Out-File $fileExport -Append
    }
    "ext-prop-definition" {
        $fileExport = Join-Path -Path $dirExport -ChildPath $exportType
        $fileExport += ".json"
        $exportCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand export
        $exportCommand = ($exportCommand -replace "human","json") + ' -f "' + $fileExport + '"'
        Invoke-Expression $exportCommand | Out-File $fileLog -Append
        (Get-Content -Path $fileExport) | Format-Json -exportType $exportType | Set-Content -Path $fileExport
    }
    "script-lang-definition" {
            $fileExport = Join-Path -Path $dirExport -ChildPath $exportType
            $fileExport += ".json"
            $exportCommand = Write-RedcliCommand -redcliLocation $redcliLocation -command $exportType -subCommand export
            $exportCommand = ($exportCommand -replace "human","json") + ' -f "' + $fileExport + '"'
            Invoke-Expression $exportCommand | Out-File $fileLog -Append
            (Get-Content -Path $fileExport) | Format-Json -exportType $exportType | Set-Content -Path $fileExport
    }
    default {"Wrong switch value supplied"; break}
}