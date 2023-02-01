# Purpose of this script is to automatically assemble deployable ARM templates
# From the ARM templates committed to github by the ADF tools
# One template file is created for each category (dataflows, pipelines, etc.)

$armTemplateFolder = "./Enactor_BI_Deployment/arm_templates"
$checkedOutArmFolder = "./$armTemplateFolder/checkedout"

# Set Up Parameter Objects

$factory_name_param = New-Object -TypeName PSObject
$factory_name_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$factory_name_param | Add-Member -MemberType NoteProperty -Name "metadata" -Value "Data Factory name" -Force
$factory_name_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "DUMMY-DATA-FACTORY" -Force

$keyvault_name_param = New-Object -TypeName PSObject
$keyvault_name_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$keyvault_name_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "bi-keyvault-001" -Force

$tenant_id_param = New-Object -TypeName PSObject
$tenant_id_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$tenant_id_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "0e81f23b-8b67-4f1f-832b-ee8815c8ef62" -Force

$subscription_id_param = New-Object -TypeName PSObject
$subscription_id_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$subscription_id_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "89cee0ec-2e9e-4738-8b18-d3cc5a29c156" -Force

$location_param = New-Object -TypeName PSObject
$location_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$location_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[resourceGroup().location]" -Force

$as_server_param = New-Object -TypeName PSObject
$as_server_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$as_server_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "prevalas001" -Force

$bi_database_param = New-Object -TypeName PSObject
$bi_database_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$bi_database_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "EnactorRetailSales" -Force

$resourcegroup_param = New-Object -TypeName PSObject
$resourcegroup_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$resourcegroup_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "PR_EVAL_BI" -Force

$managed_identity_param = New-Object -TypeName PSObject
$managed_identity_param | Add-Member -MemberType NoteProperty -Name "type" -Value "string" -Force
$managed_identity_param | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "adf_mi_002" -Force


# Remove existing ADF Deployment files
Remove-Item $armTemplateFolder/deploy_adf_*.json

# Check out the ARM Templates from Github (adf_main branch)
if (Test-Path $checkedOutArmFolder) { Remove-Item $checkedOutArmFolder -Recurse -Force }
gh repo clone https://github.com/pietro117/Enactor_BI_ADF.git $checkedOutArmFolder -- -b adf_main 

# Loop through subfolders in ARMTemplates folder and create a deployment ARM script for each one.
$categories = get-childitem "$checkedOutArmFolder/" -directory
"categories: "+ $categories

Foreach ($category_extend in $categories)
{
	#use to split link and get the last element
	$category = ($category_extend -split '/')[-1]

	"Category: "+$category

	$template_script = Get-Content -Raw -Path $armTemplateFolder/template_adf_script.json | ConvertFrom-Json 

	# Add  Parameters
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "factory_name" -Value $factory_name_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_bi_keyvault_name" -Value $keyvault_name_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_tenant_id" -Value $tenant_id_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_subscription_id" -Value $subscription_id_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_location_name" -Value $location_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_bi_analysisserver_name" -Value $as_server_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_bi_database_name" -Value $bi_database_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_resourcegroup_name" -Value $resourcegroup_param -Force
	$template_script.parameters | Add-Member -MemberType NoteProperty -Name "azure_managed_identity_name" -Value $managed_identity_param -Force

	# Add  Variables
	$template_script.variables | Add-Member -MemberType NoteProperty -Name "factoryId" -Value "[concat('Microsoft.DataFactory/factories/', parameters('factory_name'))]" -Force
	$template_script.variables | Add-Member -MemberType NoteProperty -Name "azure_keyvault_url" -Value "[concat('https://',parameters('azure_bi_keyvault_name'),'.vault.azure.net/')]" -Force

	# Add all individual ARM templates from GitHub to the Resources section

	# For each json file in arm templates...
	$templates = get-childitem "$checkedOutArmFolder/$category/*.json" -file
	Foreach ($template in $templates) 
	{
		$resource = Get-Content -Raw -Path $template.fullname | ConvertFrom-Json

		# Set name and add API version and Type (may be missing from some)
		$resource.name = "[concat(parameters('factory_name'), '/$($resource.name)')]"
		$resource | Add-Member -MemberType NoteProperty -Name "apiVersion" -Value "2018-06-01" -Force
		$resource | Add-Member -MemberType NoteProperty -Name "type" -Value "Microsoft.DataFactory/factories/$($category)s" -Force

		# Set Keyvault Parameter to use variable value - if the param exists
		# And other parameters (mainly for Pipelines) where required
		if($null -ne $resource.properties.parameters.KeyVault_URL)
		{
				$resource.properties.parameters.KeyVault_URL | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[variables('azure_keyvault_url')]" -Force
		}
		if($null -ne $resource.properties.parameters.TenantID)
		{
			$resource.properties.parameters.TenantID | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[parameters('azure_tenant_id')]" -Force
		}
		if($null -ne $resource.properties.parameters.SubscriptionID)
		{
			$resource.properties.parameters.SubscriptionID | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[parameters('azure_subscription_id')]" -Force
		}
		if($null -ne $resource.properties.parameters.Region)
		{
			$resource.properties.parameters.Region | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[parameters('azure_location_name')]" -Force
		}
		if($null -ne $resource.properties.parameters.Server)
		{
			$resource.properties.parameters.Server | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[parameters('azure_bi_analysisserver_name')]" -Force
		}
		if($null -ne $resource.properties.parameters.DatabaseName)
		{
			$resource.properties.parameters.DatabaseName | Add-Member -MemberType NoteProperty -Name "defaultValue" -Value "[parameters('azure_bi_database_name')]" -Force
		}
		# Managed Identity reference - Linked Service
		if($null -ne $resource.properties.typeProperties.credential)
		{
			$resource.properties.typeProperties.credential | Add-Member -MemberType NoteProperty -Name "referenceName" -Value "[parameters('azure_managed_identity_name')]" -Force
		}
		
		# Add Linked Service Dependencies
		# Excludes KeyVault Linked Service - it doesnt need the dependencies
		# TODO: Improve this by extracting the dependencies from the linked service data
		if(($resource.type -eq "Microsoft.DataFactory/factories/linkedservices") -and !($resource.name -like "*keyvault*"))
		{
			$resource | Add-Member -MemberType NoteProperty -Name "dependsOn" -value (New-object System.Collections.Arraylist)
			$resource.dependsOn += "[concat(variables('factoryId'), '/linkedServices/BIAzureKeyVault')]"
		}	

		# Add Pipeline Dependencies	
		# Add a dependency for each activity used by the pipeline that has a type of ExecutePipeline	
		if($resource.type -eq "Microsoft.DataFactory/factories/pipelines")
		{
			$resource | Add-Member -MemberType NoteProperty -Name "dependsOn" -value (New-object System.Collections.Arraylist)
				
			Foreach ($activity in $resource.properties.activities) 
			{
				if ($activity.type -eq "ExecutePipeline")
				{
					$resource.dependsOn += "[concat(variables('factoryId'), '/pipelines/$($activity.typeProperties.pipeline.referenceName)')]"
				}
			}
		}
		
		# Add Trigger Details (Different structure to other components)
		# Each trigger relates to a single pipeline, so we add the properties needed to the first pipeline we find
		if (($resource.type -eq "Microsoft.DataFactory/factories/triggers") -and ($resource.name -like "*DailyTrigger*"))
		{
			$resource.properties.pipelines[0].parameters | Add-Member -MemberType NoteProperty -Name "KeyVault_URL" -value "[variables('azure_keyvault_url')]" -Force
		}	
		if (($resource.type -eq "Microsoft.DataFactory/factories/triggers") -and (($resource.name -like "*Shutdown AS*") -or ($resource.name -like "*Startup AS*")))
		{
			$resource.properties.pipelines[0].parameters | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -value "[parameters('azure_subscription_id')]" -Force
			$resource.properties.pipelines[0].parameters | Add-Member -MemberType NoteProperty -Name "Server" -value "[parameters('azure_bi_analysisserver_name')]" -Force
			$resource.properties.pipelines[0].parameters | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -value "[parameters('azure_resourcegroup_name')]" -Force
		}	
		
		# Add Credential Details (Different structure to other components)
		if ($resource.type -eq "Microsoft.DataFactory/factories/credentials")
		{
			$resource.name = "[concat(parameters('factory_name'), '/' , parameters('azure_managed_identity_name'))]"
			$resource.properties.typeProperties.resourceId = "[concat('/subscriptions/',parameters('azure_subscription_id'),'/resourceGroups/',parameters('azure_resourcegroup_name'),'/providers/Microsoft.ManagedIdentity/userAssignedIdentities/', parameters('azure_managed_identity_name'))]"
		}

		# Add VirtualNetwork Details (Different structure to other components)
		if ($resource.type -eq "Microsoft.DataFactory/factories/managedVirtualNetworks")
		{
			$resource | Add-Member -MemberType NoteProperty -Name "properties" -value @{}  
		
		}
		
		# Add details to resources section of template file
		$template_script.resources += $resource
	}



	# Write Out File
	# This nastiness is to deal with the way the Powershell ConvertTo-Json cmdlet converts ' characters to /u0027

	$template_script | ConvertTo-Json -Depth 16 | %{
		[Regex]::Replace($_, 
			"//u(?<Value>[a-zA-Z0-9]{4})", {
				param($m) ([char]([int]::Parse($m.Groups['Value'].Value,
					[System.Globalization.NumberStyles]::HexNumber))).ToString() } )} | Out-File $armTemplateFolder/deploy_adf_$category.json
}

# Clean up - remove arm templates folder
if (Test-Path $checkedOutArmFolder) { Remove-Item $checkedOutArmFolder -Recurse -Force }
