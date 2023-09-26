function Write-RedcliCommand {
    param(
        [string]$redcliLocation,
        [string]$command,
        [string]$subCommand,
        [string]$fileExport
    )
    
    #Create some empty variables to hold he login and common arguments
    $MetadataLoginArgs = ""
    $CommonArgs = ""
    #The start of the command for the redcli
    $redcliCmd = '& "' + $redcliLocation + '" '

    $json = Get-Content -Raw -Path $PSScriptRoot\redcli-config.json | ConvertFrom-Json

    foreach ($k in ($json.MetadataLoginArgs | Get-Member -MemberType NoteProperty).Name) {
        if ($json.MetadataLoginArgs.$k) {
            $MetadataLoginArgs += ' ' + $k + ' "' + $($json.MetadataLoginArgs.$k) + '"'
        }
    }

    foreach ($k in ($json.CommonArgs | Get-Member -MemberType NoteProperty).Name) {
        if ($json.CommonArgs.$k) {
            $CommonArgs += ' ' + $k + ' "' + $($json.CommonArgs.$k) + '"'
        }
    }

    $redcliCmd += $command + ' ' + $subCommand + $MetadataLoginArgs + $CommonArgs
    $redcliCmd
}

# Very crude reformatting of the WS generated "JSON" because any standard formatters
# can't seem to handle it but this will make comparisons easier at least
function Format-Json {
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]
        $json,
        [Parameter(Mandatory)]
        [string]$exportType
    ) 
    switch ($exportType) {
        "ext-prop-definition" {
            $descriptionReplace = "`n" + '"description"'
            $formattedJson = $json -replace '"description"',$descriptionReplace
            $displayNameReplace = "`n" + '"displayName"'
            $formattedJson = $formattedJson -replace '"displayName"',$displayNameReplace
            $maskedReplace = "`n" + '"masked"'
            $formattedJson = $formattedJson -replace '"masked"',$maskedReplace
            $scopesReplace = "`n" + '"scopes"'
            $formattedJson = $formattedJson -replace '"scopes"',$scopesReplace
            $variableNameReplace = "`n" + '"variableName"'
            $formattedJson = $formattedJson -replace '"variableName"',$variableNameReplace
            $separatorReplace = "`n" + '},{'
            $formattedJson = $formattedJson -replace '},{',$separatorReplace
            $fileFormatReplace = "`n" + '"fileFormat"'
            $formattedJson = $formattedJson -replace '"fileFormat"',$fileFormatReplace       
        }
        "script-lang-definition" {
            $definitionsReplace = "`n" + '"definitions"'
            $formattedJson = $json -replace '"definitions"',$definitionsReplace
            $commandReplace = "`n" + '"command"'
            $formattedJson = $formattedJson -replace '"command"',$commandReplace
            $descriptionReplace = "`n" + '"description"'
            $formattedJson = $formattedJson -replace '"description"',$descriptionReplace
            $fileExtensionReplace = "`n" + '"fileExtension"'
            $formattedJson = $formattedJson -replace '"fileExtension"',$fileExtensionReplace
            $nameReplace = "`n" + '"name"'
            $formattedJson = $formattedJson -replace '"name"',$nameReplace
            $separatorReplace = "`n" + '},{'
            $formattedJson = $formattedJson -replace '},{',$separatorReplace
            $fileFormatReplace = "`n" + '"fileFormat"'
            $formattedJson = $formattedJson -replace '"fileFormat"',$fileFormatReplace       
        }
    default {"Wrong switch value supplied"; break}
    }

    $formattedJson
}

Function Format-Human {
    param(
        $result
    )

$output = @"
"@

    foreach ($line in $result) {
        if ($line -like "*Name:*") {
            $newLine = $line -replace "Name: ",""
            $newLine = $newLine -replace " -> Value: \[\(empty\)\]",""
            $newLine = $newLine -replace " -> Value: \[",': "'
            $newLine = $newLine -replace "\]",'"'
            $output += $newLine + "`n"
        }
    }
    $output
}