# Enactor Flash Sales Deployment

# Clone Enactor_BI_Deployment

$FSDeploymentFolder = "./Enactor_BI_Deployment"

if (Test-Path $FSDeploymentFolder) { Remove-Item $FSDeploymentFolder -Recurse -Force }
gh repo clone https://github.com/pietro117/Enactor_BI_Deployment.git $FSDeploymentFolder
