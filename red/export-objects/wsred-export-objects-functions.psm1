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
            $fileFormatReplace = "`n" + '"fileFormat"'
            $formattedJson = $formattedJson -replace '"fileFormat"',$fileFormatReplace       
    }
    default {"Wrong switch value supplied"; break}
    }

    $formattedJson
}