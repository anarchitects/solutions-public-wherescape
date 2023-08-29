param (
[Parameter(mandatory=$true)]
[string]$repo,
[Parameter(mandatory=$true)]
[ValidateSet('mcrexport','templateexport')]
[string]$exportType,
[string]$workingDirectory,
[string]$ws3dJavaLocation,
[string]$ws3dJarLocation,
[switch]$versionMcrExportDirectory
)


#------------------------------------------------------------------------------
# Global script variables
#------------------------------------------------------------------------------
#Timestamp appended to file and folder names to allow for multiple runs in the same day
$fileTimestamp = ( get-date ).ToString("yyyyMMddTHHmmss")

#Check if a working directory has been supplied and if not then set to a default of c:\temp also check if it exists and create it if not
if (-not ($workingDirectory)) {$workingDirectory = "C:\temp"}
$null = if (-not (Test-Path $workingDirectory)) {New-Item $workingDirectory -ItemType "directory"}

#For the command line based report execution you are required to supply a "selection file" so this variable stores the location of that file, note that it does not need to be timestamped because it is generic
$fileSelectionXml = Join-Path -Path $workingDirectory -ChildPath "Selection_File.xml"

#Location to store the report containing the items to be exported
$fileReportCsv = Join-Path -Path $workingDirectory -ChildPath "$exportType_$fileTimestamp.csv"
$null = if (Test-Path $fileReportCsv) {Remove-Item $fileReportCsv -Force | Out-Null}

#Location of the log file that any logging will be output to
$fileLog = Join-Path -Path $workingDirectory -ChildPath "mcr_export_log_$fileTimestamp.txt"
$null = if (-not (Test-Path $fileLog)) {New-Item $fileLog -ItemType "file" | Out-Null}

#Location of the Java executable as used by 3D, if not supplied then the default install loction is assumed
if (-not ($ws3dJavaLocation)) {$ws3dJavaLocation = "C:\Program Files\WhereScape\WhereScape 3D\jre\bin\java"}

#Location of the 3D jar file, if not supplied then the default install loction is assumed
if (-not ($ws3dJarLocation)) {$ws3dJarLocation = "C:\Program Files\WhereScape\WhereScape 3D"}

#The start of the command for the 3D command line interface
$3dcmd    = '& "' + $ws3dJavaLocation + '" -Xmx512m -XX:MaxMetaspaceSize=256m -splash: -jar "' + $ws3dJarLocation + '\WhereScape-3D-HEAD-bundle.jar"'
#------------------------------------------------------------------------------

function Generate-Report {
    param (
        [string]$reportName=$(throw 'A valid report name is required.')
    )

#Check if the stupid selection file exists and if not then create it with some dummy values that will allow the non version specific report to be run
$selectionFileContent = @"
<?xml version="1.0" encoding="UTF-8"?>

<report_settings xmlns="http://www.wherescape.com/xml/3D" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.wherescape.com/xml/3D ./report_settings_1.xsd">

  <xml_version>1</xml_version>

  <repo name="$repo">
    <category name="category">
       <model name="model">
          <version>version</version>
       </model>
    </category>
 </repo>
</report_settings>
"@

#Check if there is already a selection file in the working directory and remove if there is to avoid potential issues with duplicate data being returned in the report
if (Test-Path $fileSelectionXml) {
        Remove-Item $fileSelectionXml -Force
    }

#Create a new selection file based on the data in this script
$null = New-Item $fileSelectionXml -ItemType "file"
Write-output $selectionFileContent | Out-File -FilePath $fileSelectionXml -Append -Encoding ascii

#Export report containing list of Model Conversions by Group
#Set the command variable
$commandReportExport = $3dcmd + ' reportexport -repo ' + $repo + ' -m ' + $fileSelectionXml + ' -n "' + $reportName + '" -o ' + $fileReportCsv
#Check if the report already exists and remove it if it does
$null = if (Test-Path $fileReportCsv) {Remove-Item $fileReportCsv -Force}
#Run the command to output the report
Invoke-Expression $commandReportExport | Out-Null
}

if ($exportType -eq "mcrexport") {

#Set the top level directory variable for mcr exports
if ($versionMcrExportDirectory) {
    $dirExport = Join-Path -Path $workingDirectory -ChildPath "mcrExport_$fileTimestamp"
}
else {
    $dirExport = Join-Path -Path $workingDirectory -ChildPath "mcrExport"
    $null = if (Test-Path $dirExport) {Remove-Item $dirExport -Recurse -Force}
}

Generate-Report "List Model Conversions"

#Loop through report
#Create directory per group
#Create file per model conversion
$modelConversions = Import-CSV $fileReportCsv 

foreach ($modelConversion in $modelConversions) {
    
        if (-not ($modelConversion.src_transformation_group_name -eq "Default Group")) {

            $dirMcrGroup = Join-Path -Path $dirExport -ChildPath $modelConversion.src_transformation_group_name

            if (-not (Test-Path $dirMcrGroup)) {
                $null = New-Item $dirMcrGroup -ItemType "directory"
                }

                $fileMcrXml = Join-Path -Path $dirMcrGroup -ChildPath $modelConversion.src_transformation_name.Replace("/","").Replace("\","")
                $fileMcrXml = $fileMcrXml + "_$fileTimestamp.xml"


            if (-not (Test-Path $fileMcrXml)) {
                $commandMcrExport = $3dcmd + ' mcrexport -repo "' + $repo + '" -name "' + $modelConversion.src_transformation_name + '" -o "' + $fileMcrXml + '"'

                Invoke-Expression $commandMcrExport | Out-Null

                }
        }            
    
    }
#End of export type = mcr block
}