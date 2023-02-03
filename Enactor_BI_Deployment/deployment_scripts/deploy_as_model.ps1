# Get Parameter values from AS Model Parameter file

$ScriptFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/deployment_scripts"
$ParamFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/param_files"


#set credentials when run Invoke-ASCmd
$username = "vikum.kulathunga@enactorsupport.com"
$password = ConvertTo-SecureString 'Vmk@$$56' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)


# Use main parameter file
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

# Local Parameters
$ASServer= "asazure://${azure_location_name}.asazure.windows.net/${azure_bi_analysisserver_name}"

$modelFolder = "/home/jenkins/powershell/Enactor_BI_Deployment/model"
# $msBuildPath = "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/MSBuild/Current/Bin/msbuild.exe"
# $asDeploymentPath = "C:/Program Files (x86)/Microsoft SQL Server Management Studio 18/Common7/IDE/Microsoft.AnalysisServices.Deployment.exe"

# Model should be checked out to a folder called "model"
if (Test-Path $modelFolder) { Remove-Item $modelFolder -Recurse -Force }
gh repo clone https://github.com/pietro117/Enactor-Retail-Sales-Tabular-Model.git $modelFolder

# Loop through Project folders (e.g. EnactorRetailSales, FlashSales, CashManagement, ...) and deploy to AS
$modelProjectFolders = Get-ChildItem -Path $modelFolder -Directory
Foreach($modelProjectFolder in $modelProjectFolders.fullname)
{

    #use to split link and get the last element to get model name
	$model_name = ($modelProjectFolder -split '/')[-1]
	"model name: "+$model_name

	#get bim file content as a string 
	$CopiedContent = Get-Content -Path "$modelProjectFolder/Model.bim" | Out-String

########################## .bim file into .xmla convertion process ###################################
	
 #wrap bim file content with required JSON feilds
    $xmlaFileContent = '
{
    "create": {
        "database": 
    
        '+ $CopiedContent +'

    }
}'

	# create a new xmla file and save content
    New-Item "$modelProjectFolder/model.xmla" -ItemType File -Value $xmlaFileContent   

	# get xmla file content again to do modifications
    $fileContents = Get-Content "$modelProjectFolder/model.xmla"

    # remove line that containes "id": "SemanticModel"
    $fileContents = $fileContents | Where-Object {$_ -notmatch '"id": "SemanticModel"'}
	# replace "SemanticModel" as model name
    $fileContents = $fileContents -replace 'SemanticModel',$model_name

    # replace sql server name
    $sqlServerName = $azure_bi_sqlserver_name+'.database.windows.net'
	$fileContents = $fileContents -replace 'enactordw001.database.windows.net', $sqlServerName

    # Save the changes to the xmla file
    $fileContents | Set-Content "$modelProjectFolder/model.xmla"

############################################# End of convertion process ###################################

	# Deploy Model to Azure
	Invoke-ASCmd -InputFile "$modelProjectFolder/model.xmla" -Server $ASServer -Credential $credential

}


# Correct Credentials (I think you only need to do this once for all the models ???)
# Populate Credentials.xmla with DB user settings etc. (It's a JSON file)
# $credentials = Get-Content -Raw -Path $ScriptFolder/credentials_template.xmla | ConvertFrom-Json
# $credentials.createOrReplace.dataSource.connectionDetails.address | Add-Member -MemberType NoteProperty -Name server -Value "${azure_bi_sqlserver_name}.database.windows.net" -Force
# $credentials.createOrReplace.dataSource.connectionDetails.address | Add-Member -MemberType NoteProperty -Name database -Value ${dw_database_name} -Force
# $credentials.createOrReplace.dataSource.credential | Add-Member -MemberType NoteProperty -Name path -Value "${azure_bi_sqlserver_name}.database.windows.net;${dw_database_name}" -Force
# $credentials.createOrReplace.dataSource.credential | Add-Member -MemberType NoteProperty -Name Username -Value ${azure_bi_sqlserver_admin_user} -Force
# $credentials.createOrReplace.dataSource.credential | Add-Member -MemberType NoteProperty -Name Password -Value ${azure_bi_sqlserver_admin_password} -Force
# $credentials | ConvertTo-Json -Depth 16 | Out-File $modelFolder/credentials.xmla

# $filePath = join-path (get-location) "$modelFolder/credentials.xmla"
# "File Path : "+ $filePath

# Invoke-ASCmd -InputFile (join-path (get-location) "$modelFolder/credentials.xmla") -Server $ASServer -Credential $credential

# Clean up - remove Model folder
if (Test-Path $modelFolder) { Remove-Item $modelFolder -Recurse -Force }

