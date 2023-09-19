
function Get-ODBCData{
    param(
    [string]$query=$(throw 'query is required.'),
    [string]$dsn 
    )
    $conn = New-Object System.Data.Odbc.OdbcConnection
    $conn.ConnectionString = "DSN=$dsn;"
    $conn.open()
    $cmd = New-object System.Data.Odbc.OdbcCommand($query,$conn)
    $dataset = New-Object System.Data.Dataset 
    (New-Object Data.odbc.odbcDataAdapter($cmd)).fill($dataset) | Out-Null
    return ,$dataset.Tables[0]
    $conn.close()
}

function Set-ODBCData{
  param(
  [string]$query=$(throw 'query is required.'),
  [string]$dsn
  )
  $conn = New-Object System.Data.Odbc.OdbcConnection
  $conn.ConnectionString = "DSN=$dsn;"
  $cmd = New-Object System.Data.Odbc.OdbcCommand($query,$conn)
  $conn.open()
  $cmd.ExecuteNonQuery()
  $conn.close()
}

$global:listModelConversions = @"
SELECT
"wb_src_transformation_group"."src_transformation_group_name",
"wb_src_transformation"."src_transformation_name"
FROM "wsmeta"."wb_src_transformation_group"
JOIN "wsmeta"."wb_src_transformation"
  ON "wb_src_transformation_group"."src_transformation_group_key" = "wb_src_transformation"."src_transformation_group_key"
WHERE
"wb_src_transformation"."src_transformation_purpose" = 'mc'
 ORDER BY
 "wb_src_transformation_group"."src_transformation_group_order",
 "wb_src_transformation"."src_transformation_order"
"@

$global:listTemplatesandScripts = @"
SELECT
CASE
    WHEN "wb_script_details"."script_key" IS NOT NULL
    THEN 'script'
    ELSE 'template'
END AS "script_or_template",
"wb_template_header"."template_header_type",
COALESCE("wb_script_details"."script_name",'pebble') AS "script_language",
"wb_template_header"."template_header_name"
FROM "wsmeta"."wb_template_header" "wb_template_header"
LEFT OUTER JOIN "wsmeta"."wb_script_type" "wb_script_type"
  ON "wb_template_header"."template_header_key" = "wb_script_type"."template_header_key"
LEFT OUTER JOIN "wsmeta"."wb_script_details" "wb_script_details"
  ON "wb_script_type"."script_key" = "wb_script_details"."script_key"
"@

$global:listCategories = @"
SELECT DISTINCT "wb_obj_category"."obj_cat_id"
FROM "wsmeta"."wb_obj_category" "wb_obj_category"
"@

$global:listDatabaseFunctions = @"
SELECT DISTINCT
"wb_def_functions_header"."functions_database",
"wb_def_functions_header"."functions_name"
FROM "wsmeta"."wb_def_functions_header" "wb_def_functions_header"
"@

$global:listDataTypeMappings = @"
SELECT DISTINCT
 "wb_def_data_type_mapping_header"."data_type_mapping_from_db_name",
"wb_def_data_type_mapping_header"."data_type_mapping_name"
FROM "wsmeta"."wb_def_data_type_mapping_header" "wb_def_data_type_mapping_header"
"@

$global:listDiscoveryMethodsStep1 = @"
UPDATE "wsmeta"."wb_def_discovery_method"
SET
"method_name" = 'F-' || "method_name", 
"method_user_defined" = 'T'
WHERE method_user_defined = 'F'
"@

$global:listDiscoveryMethodsStep2 = @"
SELECT DISTINCT
"method_name",
CASE
    WHEN "method_name" LIKE 'F-%'
    THEN 'ws'
    ELSE 'user'
END AS "defined_by",
"method_user_defined"
FROM "wsmeta"."wb_def_discovery_method" "wb_def_discovery_method"
"@

$global:listDiscoveryMethodsStep3 = @"
UPDATE "wsmeta"."wb_def_discovery_method"
SET
"method_name" = SUBSTR("method_name",3,LENGTH("method_name")),
"method_user_defined" = 'F'
WHERE
"method_name" LIKE 'F-%'
"@

$global:listProfilingMethodsStep1 = @"
UPDATE "wsmeta"."wb_def_profiling_method"
SET
"method_name" = 'F-' || "method_name", 
"method_user_defined" = 'T'
WHERE 
"method_user_defined" = 'F'
"@

$global:listProfilingMethodsStep2 = @"
SELECT DISTINCT
"method_name",
CASE
    WHEN "method_name" LIKE 'F-%'
    THEN 'ws'
    ELSE 'user'
END AS "defined_by",
"method_user_defined"
FROM "wsmeta"."wb_def_profiling_method" "wb_def_profiling_method"
"@

$global:listProfilingMethodsStep3 = @"
UPDATE "wsmeta"."wb_def_profiling_method"
SET
"method_name" = SUBSTR("method_name",3,LENGTH("method_name")),
"method_user_defined" = 'F'
WHERE
"method_name" LIKE 'F-%'
"@

$global:listUIConfigs = @"
SELECT DISTINCT 
 "wb_ui_config"."ui_config_type",
  "wb_ui_config"."ui_config_name"
FROM "wsmeta"."wb_ui_config" "wb_ui_config"
"@

$global:listWorkflows = @"
SELECT DISTINCT "wb_workflow"."workflow_name"
FROM "wsmeta"."wb_workflow" "wb_workflow"
"@