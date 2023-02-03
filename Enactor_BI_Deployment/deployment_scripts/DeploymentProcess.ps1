# Enactor BI Deployment Script

# For details, please refer to: https://enactor.atlassian.net/wiki/spaces/EBI/pages/27303837766/Deployment

# Pre-requisites

# P1 - ensure Powershell Azure module is installed
# P2 - ensure Powershell AzureAD module is installed
# P3 - ensure Powershell Azure ManagedServiceIdentity module is installed
# P3a- ensure Powershell Azure DataFactory module is installed
# P3b- ensure Powershell SQLServer module is installed
# P4 - ensure Git Client is installed (including Github CLI https://cli.github.com/)
# P4a - get valid Github token for Pietro117/Enactor_BI_Databases.git repo and set environment variable GH_TOKEN to token value, e.g. SET GH_TOKEN=ghb_M6GvTcak9UedIv85eoytYK96iaIk250aWNEa
# P5 - ensure SQL Server Client is installed (SSMS)
# P6 - Confirm correct root folder for deployment Operations
# P7 - latest deployment project is checked out into the Enactor_BI_Deployment folder:
#  Deployment Scripts
#  - DeploymentProcess.ps1 (This File)
#  - RemovalProcess.ps1
#  - BuildADFScripts.ps1
#  - deploy_keyvault.json
#  - deploy_credentials.json
#  - deploy_factory.json
#  - deploy_sql_dbs.json
#  - deploy_as.json


#  Parameter Files
#  - deployment_params.json
#  (note: other required parameter files will be generated automatically by this script)

# P8 - Parameter file is updated correctly
# P9 - Ensure you are on a server with permitted access to the Azure servers (e.g. Enactor Network or VPN)


# Deployment Script files will be in    ./Enactor_BI_Deployment/deployment_scripts
# Parameter files will be in ./Enactor_BI_Deployment/param_files
# DB SQL Script files will be in ./Enactor_BI_Databases (once the SQL Script repo has been cloned

# Execute ./Enactor_BI_Deployment/deployment_scripts/DeploymentProcess.ps1

$ScriptFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/deployment_scripts"
$ParamFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/param_files"
$DBScriptFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/database_scripts"
$armTemplateFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/arm_templates"

# Step A - Preparation

# A1. Log in to Azure (this may launch an interactive login window). Log in to an account who has credentials belonging to the required subscription.

# Connect-AzAccount -Tenant '0e81f23b-8b67-4f1f-832b-ee8815c8ef62' -SubscriptionId '89cee0ec-2e9e-4738-8b18-d3cc5a29c156'
$User = "vikum.kulathunga@enactorsupport.com"
$PWord = ConvertTo-SecureString -String 'Vmk@$$56' -AsPlainText -Force
$tenant = "0e81f23b-8b67-4f1f-832b-ee8815c8ef62"
$subscription = "89cee0ec-2e9e-4738-8b18-d3cc5a29c156"
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User,$PWord
Connect-AzAccount -Credential $Credential -Tenant $tenant -Subscription $subscription



# User Authentication

# Login to your Azure Account
# Connect-AzAccount -Tenant '0e81f23b-8b67-4f1f-832b-ee8815c8ef62' -Credential $credential


# Login to Github
#log into the github account by using auth token
echo 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 | gh auth login --with-token
gh auth status



#https://github.com/Vikum-Kule/Enactor_BI_ADF.git

# A2 Remove any existing Working parameter files
Remove-Item $ParamFolder/deploy_*_params.json

# A3 Create the ADF Deployment Scripts from the ARM templates in Github

invoke-expression -Command $ScriptFolder/build_adf_scripts.ps1
 


# A4 Clone Database Scripts Repository from the SQL Github repo

if (Test-Path $DBScriptFolder) { Remove-Item $DBScriptFolder -Recurse -Force }
gh repo clone https://github.com/pietro117/Enactor_BI_Databases.git $DBScriptFolder


# A5. Get Settings from the Main Parameters file

$deployment_params = Get-Content -Raw -Path $ParamFolder/deployment_params.json | Convertfrom-Json
$azure_subscription_id = $deployment_params.parameters.azure_subscription_id.value
$resourcegroup_name = $deployment_params.parameters.azure_resourcegroup_name.value
$azure_location_name = $deployment_params.parameters.azure_location_name.value
$azure_managed_identity_name = $deployment_params.parameters.azure_managed_identity_name.value
$azure_bi_sqlserver_name =  $deployment_params.parameters.azure_bi_sqlserver_name.value
$azure_bi_sqlserver_admin_user =  $deployment_params.parameters.azure_bi_sqlserver_admin_user.value
$azure_bi_sqlserver_admin_password =  $deployment_params.parameters.azure_bi_sqlserver_admin_password.value
$azure_bi_analysisserver_name =  $deployment_params.parameters.azure_bi_analysisserver_name.value
$azure_bi_database_name =  $deployment_params.parameters.azure_bi_database_name.value
$analysisserver_admin_user =  $deployment_params.parameters.analysisserver_admin_user.value
$azure_bi_keyvault_name =  $deployment_params.parameters.azure_bi_keyvault_name.value
$operational_db_connectionstring =  $deployment_params.parameters.operational_db_connectionstring.value
$factory_name =  $deployment_params.parameters.factory_name.value
$dw_database_name = $deployment_params.parameters.dw_database_name.value

# A6. Select required subscription ID and record tenant id in variable azure_tenant_id

$azure_subscription = Set-AzContext -Subscription "$azure_subscription_id"
$azure_tenant_id = $azure_subscription.Tenant.Id
$azure_user_object_id = $azure_subscription.Account.ExtendedProperties.HomeAccountId.Split('.')[0]

# Step B - Infrastructure

# B1. Create Resource Group (in supplied Subscription)

New-AzResourceGroup -Name $resourcegroup_name -Location "$azure_location_name"



# B2. Create Managed Service Identity for ADF, and record object id in variable azure_adf_mi_object_id

$identityDetails = New-AzUserAssignedIdentity -ResourceGroupName $resourcegroup_name -Name $azure_managed_identity_name -Location "$azure_location_name"

$azure_adf_mi_object_id = $identityDetails.PrincipalId


# B4. Add required settings to KeyVault Parameter file, DBs and AS Param files

$deploy_keyvault_params = Get-Content -Raw -Path $ParamFolder/template_params.json | Convertfrom-Json
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_keyvault_name -Value @{value="$azure_bi_keyvault_name"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name operational_db_connectionstring -Value @{value="$operational_db_connectionstring"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_tenant_id -Value @{value="$azure_tenant_id"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_adf_mi_object_id -Value @{value="$azure_adf_mi_object_id"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_user_object_id -Value @{value="$azure_user_object_id"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_sqlserver_name -Value @{value="$azure_bi_sqlserver_name"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_sqlserver_admin_user -Value @{value="$azure_bi_sqlserver_admin_user"} -Force
$deploy_keyvault_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_sqlserver_admin_password -Value @{value="$azure_bi_sqlserver_admin_password"} -Force
$deploy_keyvault_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_keyvault_params.json

$deploy_sql_dbs_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_sql_dbs_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_sqlserver_name -Value @{value="$azure_bi_sqlserver_name"} -Force
$deploy_sql_dbs_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_sqlserver_admin_user -Value @{value="$azure_bi_sqlserver_admin_user"} -Force
$deploy_sql_dbs_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_sqlserver_admin_password -Value @{value="$azure_bi_sqlserver_admin_password"} -Force
$deploy_sql_dbs_params.parameters | Add-Member -MemberType NoteProperty -Name dw_database_name -Value @{value="$dw_database_name"} -Force
$deploy_sql_dbs_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_sql_dbs_params.json

$deploy_as_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_as_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_analysisserver_name -Value @{value="$azure_bi_analysisserver_name"} -Force
$deploy_as_params.parameters | Add-Member -MemberType NoteProperty -Name analysisserver_admin_user -Value @{value="$analysisserver_admin_user"} -Force
$deploy_as_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_as_params.json




# B5. Deploy KeyVault Template to Resource Group

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile  $armTemplateFolder/deploy_keyvault.json -TemplateParameterFile $ParamFolder/deploy_keyvault_params.json

# B6. Deploy SQL Server & DBs to Resource Group


New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile  $armTemplateFolder/deploy_sql_dbs.json -TemplateParameterFile $ParamFolder/deploy_sql_dbs_params.json


# B7. Deploy Analysis Services Server to Resource Group

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile  $armTemplateFolder/deploy_as.json -TemplateParameterFile $ParamFolder/deploy_as_params.json


# Step C - Deploy Database Schemas



# C0. Substitute server name in Staging Post deployment file (Cross DB Scripts)

((Get-Content -path $DBScriptFolder/BI_Staging/dbo/Script.PostDeployment1.sql -Raw) -replace 'SQL_SERVER_NAME','$azure_bi_sqlserver_name.database.windows.net') | Set-Content -Path $DBScriptFolder/BI_Staging/dbo/Script.PostDeployment1.sql

# C1. Run SQL Scripts - Staging DB


get-childitem "$DBScriptFolder/BI_Staging/dbo/Tables/*.sql" -file | Foreach {sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d ${dw_database_name}_Staging -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $_.fullname}
get-childitem "$DBScriptFolder/BI_Staging/dbo/Views/*.sql" -file | Foreach {sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d ${dw_database_name}_Staging -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $_.fullname}
get-childitem "$DBScriptFolder/BI_Staging/dbo/Stored Procedures/*.sql" -file | Foreach {sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d ${dw_database_name}_Staging -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $_.fullname}
sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d ${dw_database_name}_Staging -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $DBScriptFolder/BI_Staging/dbo/Script.PostDeployment1.sql

# C2. Run SQL Scripts - DW DB

get-childitem "$DBScriptFolder/BI_DW/dbo/Tables/*.sql" -file | Foreach {sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d $dw_database_name -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $_.fullname}
get-childitem "$DBScriptFolder/BI_DW/dbo/Views/*.sql" -file | Foreach {sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d $dw_database_name -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $_.fullname}
get-childitem "$DBScriptFolder/BI_DW/dbo/Stored Procedures/*.sql" -file | Foreach {sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d $dw_database_name -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $_.fullname}
sqlcmd -S "$azure_bi_sqlserver_name.database.windows.net" -d $dw_database_name -U $azure_bi_sqlserver_admin_user -P $azure_bi_sqlserver_admin_password -i $DBScriptFolder/BI_DW/dbo/Script.PostDeployment1.sql


# Step D - Deploy Azure Data Factory

# D1. Populate ADF Factory Parameters files

$deploy_adf_factory_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_adf_factory_params.parameters | Add-Member -MemberType NoteProperty -Name factory_name -Value @{value="$factory_name"} -Force
$deploy_adf_factory_params.parameters | Add-Member -MemberType NoteProperty -Name azure_tenant_id -Value @{value="$azure_tenant_id"} -Force
$deploy_adf_factory_params.parameters | Add-Member -MemberType NoteProperty -Name azure_managed_identity_name -Value @{value="$azure_managed_identity_name"} -Force
$deploy_adf_factory_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_adf_factory_params.json

$deploy_adf_credentials_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_adf_credentials_params.parameters | Add-Member -MemberType NoteProperty -Name factory_name -Value @{value="$factory_name"} -Force
$deploy_adf_credentials_params.parameters | Add-Member -MemberType NoteProperty -Name azure_subscription_id -Value @{value="$azure_subscription_id"} -Force
$deploy_adf_credentials_params.parameters | Add-Member -MemberType NoteProperty -Name azure_resourcegroup_name -Value @{value="$resourcegroup_name"} -Force
$deploy_adf_credentials_params.parameters | Add-Member -MemberType NoteProperty -Name azure_managed_identity_name -Value @{value="$azure_managed_identity_name"} -Force
$deploy_adf_credentials_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_adf_credentials_params.json

$deploy_adf_linked_services_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_adf_linked_services_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_keyvault_name -Value @{value="$azure_bi_keyvault_name"} -Force
$deploy_adf_linked_services_params.parameters | Add-Member -MemberType NoteProperty -Name factory_name -Value @{value="$factory_name"} -Force
$deploy_adf_linked_services_params.parameters | Add-Member -MemberType NoteProperty -Name azure_managed_identity_name -Value @{value="$azure_managed_identity_name"} -Force
$deploy_adf_linked_services_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_adf_linked_services_params.json

$deploy_adf_dataflows_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_adf_dataflows_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_keyvault_name -Value @{value="$azure_bi_keyvault_name"} -Force
$deploy_adf_dataflows_params.parameters | Add-Member -MemberType NoteProperty -Name factory_name -Value @{value="$factory_name"} -Force
$deploy_adf_dataflows_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_adf_dataflows_params.json

$deploy_adf_pipelines_params = Get-Content -Raw -Path ./$ParamFolder/template_params.json | Convertfrom-Json
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_keyvault_name -Value @{value="$azure_bi_keyvault_name"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name factory_name -Value @{value="$factory_name"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_tenant_id -Value @{value="$azure_tenant_id"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_subscription_id -Value @{value="$azure_subscription_id"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_location_name -Value @{value="$azure_location_name"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_analysisserver_name -Value @{value="$azure_bi_analysisserver_name"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_bi_database_name -Value @{value="$azure_bi_database_name"} -Force
$deploy_adf_pipelines_params.parameters | Add-Member -MemberType NoteProperty -Name azure_resourcegroup_name -Value @{value="$resourcegroup_name"} -Force
$deploy_adf_pipelines_params | ConvertTo-Json | Out-File ./$ParamFolder/deploy_adf_pipelines_params.json


# D2. Deploy ADF Factory (incl Managed Identity) - use original script, not Github ARM template

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_factory.json -TemplateParameterFile $ParamFolder/deploy_adf_factory_params.json


# D3. Deploy ADF Credentials and Virtual Network

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_credential.json -TemplateParameterFile $ParamFolder/deploy_adf_credentials_params.json
New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_managedVirtualNetwork.json -TemplateParameterFile $ParamFolder/deploy_adf_credentials_params.json

# D4. Deploy ADF Integration Runtime, Linked Services and Datasets - use automated ADF templates from Github

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_integrationRuntime.json -TemplateParameterFile $ParamFolder/deploy_adf_credentials_params.json
New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_linkedService.json -TemplateParameterFile $ParamFolder/deploy_adf_linked_services_params.json
New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_dataset.json -TemplateParameterFile $ParamFolder/deploy_adf_linked_services_params.json

# D5. Deploy ADF Dataflows and Pipelines - use automated ADF templates from Github

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_dataflow.json -TemplateParameterFile $ParamFolder/deploy_adf_dataflows_params.json
New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_pipeline.json -TemplateParameterFile $ParamFolder/deploy_adf_pipelines_params.json

# D6. Deploy ADF Triggers - use automated ADF templates from Github (use the Pipelines param file)

New-AzResourceGroupDeployment -ResourceGroupName $resourcegroup_name -TemplateFile $armTemplateFolder/deploy_adf_trigger.json -TemplateParameterFile $ParamFolder/deploy_adf_pipelines_params.json


# Step E: Deploy AS Model

# Step E1: Execute AS Model deployment script
invoke-expression -Command $ScriptFolder/deploy_as_model.ps1

# Step E2: Get ADF App ID and add as admin to Analysis Server (so ADF can run processing jobs on AS)
$adf_app_id = (Get-AzADServicePrincipal -ObjectId (Get-AzDataFactoryV2 -ResourceGroupName $resourcegroup_name -Name $factory_name).Identity.PrincipalId).AppId
Set-AzAnalysisServicesServer -Name $azure_bi_analysisserver_name -ResourceGroupName $resourcegroup_name -Administrator "$analysisserver_admin_user,app:$adf_app_id@$azure_tenant_id"

# X Clean up

# X1. Remove Database Repo Clone

if (Test-Path $DBScriptFolder) { Remove-Item $DBScriptFolder -Recurse -Force }

# X2. Clean up Temp Param Files

Remove-Item $ParamFolder/deploy_*_params.json

# X2. Clean up Temp ADF Deployment Scripts

Remove-Item $armTemplateFolder/deploy_adf_*.json

