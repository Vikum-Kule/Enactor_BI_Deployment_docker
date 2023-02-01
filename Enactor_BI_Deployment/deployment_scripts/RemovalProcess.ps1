# Enactor BI Deployment Script

# For details, please refer to: https://enactor.atlassian.net/wiki/spaces/EBI/pages/27473510925/Removal

# Pre-requisites

# P1 - ensure Powershell Azure module is installed
# P2 - ensure Powershell AzureAD module is installed
# P3 - ensure Powershell Azure ManagedServiceIdentity module is installed
# P3a- ensure Powershell Azure DataFactory module is installed
# P3b- ensure Powershell SQLServer module is installed
# P4 - ensure Git Client is installed
# P5 - ensure SQL Server Client is installed (SSMS)
# P6 - Confirm correct root folder for deployment Operations
# P7 - latest deployment project is checked out into the Enactor_BI_Deployment folder:
#  Deployment Scripts
#  - RemovalProcess.ps1 (This File)

#  Parameter Files
#  - removal_params.json
#  (note: other required parameter files will be generated automatically by this script)

# P8 - Parameter file is updated correctly
# P9 - Ensure you are on a server with permitted access to the Azure servers (e.g. Enactor Network or VPN)


# Deployment Script files will be in    ./Enactor_BI_Deployment/deployment_scripts
# Parameter files will be in ./Enactor_BI_Deployment/param_files
# DB SQL Script files will be in ./Enactor_BI_Databases (once the SQL Script repo has been cloned

# Execute ./Enactor_BI_Deployment/deployment_scripts/RemovalProcess.ps1

$ScriptFolder = "./Enactor_BI_Deployment/deployment_scripts"
$ParamFolder = "./Enactor_BI_Deployment/param_files"
$DBScriptFolder = "./Enactor_BI_Databases"

# Step A - Preparation

# A1. Log in to Azure (this may launch an interactive login window). Log in to an account who has credentials belonging to the required subscription.

# Connect-AzAccount -Tenant '0e81f23b-8b67-4f1f-832b-ee8815c8ef62' -SubscriptionId '89cee0ec-2e9e-4738-8b18-d3cc5a29c156'
$User = "vikum.kulathunga@enactorsupport.com"
$PWord = ConvertTo-SecureString -String 'Vmk@$$56' -AsPlainText -Force
$tenant = "0e81f23b-8b67-4f1f-832b-ee8815c8ef62"
$subscription = "89cee0ec-2e9e-4738-8b18-d3cc5a29c156"
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User,$PWord
Connect-AzAccount -Credential $Credential -Tenant $tenant -Subscription $subscription




# A2. Get Settings from the Main Parameters file

$removal_params = Get-Content -Raw -Path $ParamFolder/removal_params.json | Convertfrom-Json
$azure_subscription_id = $removal_params.parameters.azure_subscription_id.value
$resourcegroup_name = $removal_params.parameters.azure_resourcegroup_name.value
$azure_location_name = $removal_params.parameters.azure_location_name.value
$delete_databases = $removal_params.parameters.destroy_databases.value
$purge_keyvaults = $removal_params.parameters.purge_keyvaults.value


# A3. Select required subscription ID and record tenant id in variable azure_tenant_id

$azure_subscription = Set-AzContext -Subscription "$azure_subscription_id"
$azure_tenant_id = $azure_subscription.Tenant.Id
$azure_user_object_id = $azure_subscription.Account.ExtendedProperties.HomeAccountId.Split('.')[0]

# Step B - Infrastructure

# B1. Remove Azure Data Factory and Managed Identity
# List Azure Data Factories in specified Resource Group
$adf_list =  Get-AzResource -ResourceGroupName $resourcegroup_name  -ResourceType Microsoft.DataFactory/factories

Foreach ($adf_iterator in $adf_list)
{
	# Remove Azure Data Factory
	Remove-AzResource -ResourceId $adf_iterator.ResourceId -Force
}

$mi_list =  Get-AzResource -ResourceGroupName $resourcegroup_name  -ResourceType Microsoft.ManagedIdentity/userAssignedIdentities

Foreach ($mi_iterator in $mi_list)
{
	Remove-AzResource -ResourceId $mi_iterator.ResourceId -Force
}

# B2. Remove Analysis Services Deployment 
# List AS Instances in specified Resource Group
$as_list =  Get-AzResource -ResourceGroupName $resourcegroup_name  -ResourceType Microsoft.AnalysisServices/servers
Foreach ($as_iterator in $as_list)
{
	# Remove Analysis Services instance
	Remove-AzResource -ResourceId $as_iterator.ResourceId -Force
}

# B3. Remove Keyvault Deployment 
# List Keyvault Instances in specified Resource Group
$keyvault_list =  Get-AzResource -ResourceGroupName $resourcegroup_name  -ResourceType Microsoft.KeyVault/vaults

Foreach ($keyvault_iterator in $keyvault_list)
{
	# Remove Keyvault 
	# note: Keyvaults are "soft delete" so the keyvault will remain in a deleted state for 90 days unless purged
	Remove-AzResource -ResourceId $keyvault_iterator.ResourceId -Force
	
	# Purge the deleted Keyvault Instances if specified
	if ($purge_keyvaults -eq "true")
	{
		Remove-AzKeyVault -VaultName $keyvault_iterator.Name -InRemovedState -Location $azure_location_name -Force
	}
}


# B4. Remove DBs If Specified
if ($delete_databases -eq "true")
{
	
	# List SQL Instances in specified Resource Group
	$sql_list =  Get-AzResource -ResourceGroupName $resourcegroup_name  -ResourceType Microsoft.Sql/servers
	Foreach ($sql_iterator in $sql_list)
		{
			Remove-AzResource -ResourceId $sql_iterator.ResourceId -Force
		}
		
	# Remove Resource Group
	Remove-AzResourceGroup -Name $resourcegroup_name -Force
}



