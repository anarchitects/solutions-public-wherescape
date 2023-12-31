param (
[Parameter(mandatory=$true)]
[string]$repo,
[Parameter(mandatory=$true)]
[ValidateSet('mcrexport','templateexport','categoryexport','dtmexport','discoveryexport','profilingexport','functionsexport','uiconfigexport','workflowexport')]
[string]$exportType,
[string]$dsn,
[string]$workingDirectory,
[string]$ws3dJavaLocation,
[string]$ws3dJarLocation,
[switch]$versionExportDirectory,
[switch]$versionExportFile,
[switch]$excludeWsMethods
)

Import-Module -Name $PSScriptRoot\ws3d-exports-queries.psm1 -Force
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
}
else {
    $dirExport = Join-Path -Path $workingDirectory -ChildPath "$exportType"
    $null = if (Test-Path $dirExport) {Remove-Item $dirExport -Recurse -Force}
}

#For the command line based report execution you are required to supply a "selection file" so this variable stores the location of that file, note that it does not need to be timestamped because it is generic
$fileSelectionXml = Join-Path -Path $workingDirectory -ChildPath "Selection_File.xml"

#Location to store the report containing the items to be exported
$fileReportCsv = Join-Path -Path $workingDirectory -ChildPath $exportType
$fileReportCsv += "_$fileTimestamp.csv"
$null = if (Test-Path $fileReportCsv) {Remove-Item $fileReportCsv -Force | Out-Null}

#Location of the log file that any logging will be output to
$fileLog = Join-Path -Path $workingDirectory -ChildPath $exportType
$fileLog += "_log_$fileTimestamp.txt"
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

#Export report
#Set the command variable
$commandReportExport = $3dcmd + ' reportexport -repo ' + $repo + ' -m ' + $fileSelectionXml + ' -n "' + $reportName + '" -o ' + $fileReportCsv
#Check if the report already exists and remove it if it does
$null = if (Test-Path $fileReportCsv) {Remove-Item $fileReportCsv -Force}
#Run the command to output the report
Invoke-Expression $commandReportExport | Out-Null
}

if ($exportType -eq "mcrexport") {

    if ($dsn) {
        $modelConversions = Get-ODBCData -query $listModelConversions -dsn $dsn
    } else {
        Generate-Report "List Model Conversions"
        $modelConversions = Import-CSV $fileReportCsv 
    }

    #Loop through report
    #Create directory per group
    #Create file per model conversion
    foreach ($modelConversion in $modelConversions) {
    
                $dirMcrGroup = Join-Path -Path $dirExport -ChildPath $modelConversion.src_transformation_group_name
    
                if (-not (Test-Path $dirMcrGroup)) {
                    $null = New-Item $dirMcrGroup -ItemType "directory"
                    }
    
                    $fileExport = Join-Path -Path $dirMcrGroup -ChildPath $modelConversion.src_transformation_name.Replace("/","").Replace("\","")
                    if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}
    
    
                if (-not (Test-Path $fileExport)) {
                    $commandMcrExport = $3dcmd + ' mcrexport -repo "' + $repo + '" -name "' + $modelConversion.src_transformation_name + '" -o "' + $fileExport + '.xml"'
    
                    Invoke-Expression $commandMcrExport | Out-Null
    
                    }
        }
    #End of export type = mcrexport block
}
elseif ($exportType -eq "templateexport") {

    if ($dsn) {
        $templates = Get-ODBCData -query $ListTemplatesandScripts -dsn $dsn
    } else {
        Generate-Report "List Templates and Scripts"
        $templates = Import-CSV $fileReportCsv 
    }

    #Loop through results
    #For scripts create directory per type, header type & language
    #For templates create directory per type & header type
    #Create file per template or script
    foreach ($template in $templates) {

        $dirLevel1 = Join-Path -Path $dirExport -ChildPath $template.script_or_template
        $dirLevel2 = Join-Path -Path $dirLevel1 -ChildPath $template.template_header_type
        $dirLevel3 = Join-Path -Path $dirLevel2 -ChildPath $template.script_language

        if ($template.script_or_template -eq "script") {
            if (-not (Test-Path $dirLevel3)) {$null = New-Item $dirLevel3 -ItemType "directory"}
            $fileExport = Join-Path $dirLevel3 -ChildPath $template.template_header_name
            if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}
        } else {
            if (-not (Test-Path $dirLevel2)) {$null = New-Item $dirLevel2 -ItemType "directory"}
            $fileExport = Join-Path $dirLevel2 -ChildPath $template.template_header_name
            if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}
        }

        if (-not (Test-Path $fileExport)) {
            $commandTemplateExport = $3dcmd + ' templateexport -repo "' + $repo + '" -name "' + $template.template_header_name + '" -o "' + $fileExport + '.xml"'
            Invoke-Expression $commandTemplateExport | Out-Null
            }
    }
#End of export type = templateexport block
}
elseif ($exportType -eq "categoryexport") {

    if ($dsn) {
        $categories = Get-ODBCData -query $listCategories -dsn $dsn
    } else {
        Generate-Report "List Categories"
        $categories = Import-CSV $fileReportCsv 
    }

    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}
    
    #Loop through report
    #Create file per model category
    foreach ($category in $categories) {

            $fileExport = Join-Path $dirExport -ChildPath $category.obj_cat_id
            if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

        if (-not (Test-Path $fileExport)) {
            $commandCategoryExport = $3dcmd + ' categoryexport -repo "' + $repo + '" -c "' + $category.obj_cat_id + '" -o "' + $fileExport + '.xml"'
            Invoke-Expression $commandCategoryExport | Out-Null
            }
    }
#End of export type = categoryexport block
}
elseif ($exportType -eq "dtmexport") {

    if ($dsn) {
        $mappings = Get-ODBCData -query $listDataTypeMappings -dsn $dsn
    } else {
        Generate-Report "List Data Type Mappings"
        $mappings = Import-CSV $fileReportCsv 
    }

    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}

    #Loop through report
    #Create directory per from database
    #Create file per data type mapping
    foreach ($mapping in $mappings) {

        $dirDtmFrom = Join-Path -Path $dirExport -ChildPath $mapping.data_type_mapping_from_db_name
        if (-not (Test-Path $dirDtmFrom)) {$null = New-Item $dirDtmFrom -ItemType "directory"}

        $fileExport = Join-Path $dirDtmFrom -ChildPath $mapping.data_type_mapping_name
        $fileExport = $fileExport -replace "\(\*\)","AllVersions"
        if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

    if (-not (Test-Path $fileExport)) {
        $commandDtmExport = $3dcmd + ' dtmexport -repo "' + $repo + '" -name "' + $mapping.data_type_mapping_name + '" -o "' + $fileExport + '.xml"'
        Invoke-Expression $commandDtmExport | Out-Null
        }
    }
#End of export type = dtmexport block
}
elseif ($exportType -eq "discoveryexport") {

    if (-not ($excludeWsMethods)) {
        if ($dsn) {
            $null = Set-ODBCData -query $listDiscoveryMethodsStep1 -dsn $dsn
        } else {
            #Update the metadata so that ws defined discovery methods can be exported
            Generate-Report "List Discovery Methods - Step 1"
        }
    }

    if ($dsn) {
        $discoveryMethodsReport = Get-ODBCData -query $listDiscoveryMethodsStep2 -dsn $dsn
    } else {
        #Run the report that returns the list of discovery methods
        Generate-Report "List Discovery Methods - Step 2"
        $discoveryMethodsReport = Import-CSV $fileReportCsv
    }
    
    #Create and populate a new iterable array 
    $discoveryMethods = New-Object -TypeName "System.Collections.ArrayList"

    foreach ($dm in $discoveryMethodsReport) {
        if ($excludeWsMethods) {
            if (($dm.defined_by -eq "user") -and ($dm.method_user_defined -eq "T")) { $discoveryMethods.Add($dm) | Out-Null }
        } else {
            $discoveryMethods.Add($dm) | Out-Null
        }
    }

    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}

    #Loop through results
    #Create file per data type mapping
    foreach ($discoveryMethod in $discoveryMethods) {

        $discoveryDirectory = Join-Path $dirExport -ChildPath $discoveryMethod.defined_by
        if (-not (Test-Path $discoveryDirectory)) {$null = New-Item $discoveryDirectory -ItemType "directory"}

        $discoveryMethodName = $discoveryMethod.method_name 
        if ($discoveryMethodName -like "F-*") {
            $fileExport = Join-Path $discoveryDirectory -ChildPath $discoveryMethodName.Substring(2)
        } else {
            $fileExport = Join-Path $discoveryDirectory -ChildPath $discoveryMethodName
        }

        $fileExport = $fileExport -replace " ","_"

        if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

        if (-not (Test-Path $fileExport)) {
            $commandDiscoveryMethodExport = $3dcmd + ' discoveryexport -repo "' + $repo + '" -name "' + $discoveryMethod.method_name + '" -o "' + $fileExport + '.xml"'
            Invoke-Expression $commandDiscoveryMethodExport | Out-Null
            #$commandDiscoveryMethodExport
            }
    }

    if (-not ($excludeWsMethods)) {
        if ($dsn) {
            $null = Set-ODBCData -query $listDiscoveryMethodsStep3 -dsn $dsn
        } else {
            #Update the metadata to reset it to the original values
            Generate-Report "List Discovery Methods - Step 3"
        }
    }

#End of export type = discoveryexport block
}
elseif ($exportType -eq "profilingexport") {

    if (-not ($excludeWsMethods)) {
        if ($dsn) {
            $null = Set-ODBCData -query $listProfilingMethodsStep1 -dsn $dsn
        } else {
            #Update the metadata so that ws defined profiling methods can be exported
            Generate-Report "List Profiling Methods - Step 1"
        }
    }

    if ($dsn) {
        $profilingMethodsReport = Get-ODBCData -query $listProfilingMethodsStep2 -dsn $dsn
    } else {
        #Run the report that returns the list of profiling methods
        Generate-Report "List Profiling Methods - Step 2"
        $profilingMethodsReport = Import-CSV $fileReportCsv
    }

    $profilingMethods = New-Object -TypeName "System.Collections.ArrayList"

    foreach ($pm in $profilingMethodsReport) {
        if ($excludeWsMethods) {
            if (($pm.defined_by -eq "user") -and ($pm.method_user_defined -eq "T")) { $profilingMethods.Add($pm) | Out-Null }
        } else {
            $profilingMethods.Add($pm) | Out-Null
        }
    }

    #Set the correct export directory
    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}

    #Loop through report
    #Create file per data type mapping
    foreach ($profilingMethod in $profilingMethods) {

        $profilingDirectory = Join-Path $dirExport -ChildPath $profilingMethod.defined_by
        if (-not (Test-Path $profilingDirectory)) {$null = New-Item $profilingDirectory -ItemType "directory"}

        $profilingMethodName = $profilingMethod.method_name 
        if ($profilingMethodName -like "F-*") {
            $fileExport = Join-Path $profilingDirectory -ChildPath $profilingMethodName.Substring(2)
         } else {
            $fileExport = Join-Path $profilingDirectory -ChildPath $profilingMethodName
         }

         $fileExport = $fileExport -replace " ","_"

        if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

        if (-not (Test-Path $fileExport)) {
            $commandprofilingMethodExport = $3dcmd + ' profilingexport -repo "' + $repo + '" -name "' + $profilingMethod.method_name + '" -o "' + $fileExport + '.xml"'
            Invoke-Expression $commandprofilingMethodExport | Out-Null
            }
    }

    if (-not ($excludeWsMethods)) {
        if ($dsn) {
            $null = Set-ODBCData -query $listProfilingMethodsStep3 -dsn $dsn
        } else {
            #Update the metadata to reset it to the original values
            Generate-Report "List Profiling Methods - Step 3"
        }
    }

#End of export type = profilingexport block
}
elseif ($exportType -eq "functionsexport") {

    if ($dsn) {
        $databaseFunctions = Get-ODBCData -query $listDatabaseFunctions -dsn $dsn
    } else {
        #Run the report that returns the list of database functions
        Generate-Report "List Database Functions"
        $databaseFunctions = Import-CSV $fileReportCsv
    }
     
    #Set the correct export directory
    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}

    #Loop through report
    #Create directory per database
    #Create file per database function set
    foreach ($databaseFunction in $databaseFunctions) {

        $functionsDirectory = Join-Path $dirExport -ChildPath $databaseFunction.functions_database
        if (-not (Test-Path $functionsDirectory)) {$null = New-Item $functionsDirectory -ItemType "directory"}

        $databaseFunctionName = $databaseFunction.functions_name 
        $fileExport = Join-Path $functionsDirectory -ChildPath $databaseFunctionName
        if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

        if (-not (Test-Path $fileExport)) {
            $commandDatabaseFunctionsExport = $3dcmd + ' functionsexport -repo "' + $repo + '" -name "' + $databaseFunction.functions_name + '" -o "' + $fileExport + '.xml"'
            Invoke-Expression $commandDatabaseFunctionsExport | Out-Null
            }
    }

#End of export type = functionsexport block
}
elseif ($exportType -eq "uiconfigexport") {

    if ($dsn) {
        $uiConfigs = Get-ODBCData -query $listUIConfigs -dsn $dsn
    } else {
        #Run the report that returns the list of database functions
        Generate-Report "List UI Configs"
        $uiConfigs = Import-CSV $fileReportCsv 
    }
    
    #Set the correct export directory
    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}

    #Loop through report
    #Create directory per database
    #Create file per database function set
    foreach ($uiConfig in $uiConfigs) {

        $uiConfigsDirectory = Join-Path $dirExport -ChildPath $uiConfig.ui_config_type
        if (-not (Test-Path $uiConfigsDirectory)) {$null = New-Item $uiConfigsDirectory -ItemType "directory"}

        $uiConfigName = $uiConfig.ui_config_name 
        $fileExport = Join-Path $uiConfigsDirectory -ChildPath $uiConfigName
        if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

        if (-not (Test-Path $fileExport)) {
            $commandUiConfigsExport = $3dcmd + ' uiconfigexport -repo "' + $repo + '" -name "' + $uiConfig.ui_config_name + '" -o "' + $fileExport + '.uiconfig"'
            Invoke-Expression $commandUiConfigsExport | Out-Null
            }
    }

#End of export type = uiconfigexport block
}
elseif ($exportType -eq "workflowexport") {

    if ($dsn) {
        $workflows = Get-ODBCData -query $listWorkflows -dsn $dsn
    } else {
        #Run the report that returns the list of configured workflows
        Generate-Report "List Workflows"
        $workflows = Import-CSV $fileReportCsv
    }
    
    if (-not (Test-Path $dirExport)) {$null = New-Item $dirExport -ItemType "directory"}

    #Loop through report
    #Create file per workflow
    foreach ($workflow in $workflows) {

            $fileExport = Join-Path $dirExport -ChildPath $workflow.workflow_name
            $fileExport = $fileExport -replace " ",""
            if ($versionExportFile) {$fileExport += "_$fileTimestamp.xml"}

        if (-not (Test-Path $fileExport)) {
            $commandworkflowExport = $3dcmd + ' workflowexport -repo "' + $repo + '" -name "' + $workflow.workflow_name + '" -o "' + $fileExport + '.xml"'
            Invoke-Expression $commandworkflowExport | Out-File -FilePath $fileLog -Append
            }
    }
#End of export type = workflowexport block
}