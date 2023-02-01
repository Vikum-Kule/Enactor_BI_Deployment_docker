FROM mcr.microsoft.com/azure-powershell:ubuntu-22.04

# Install powershell utils
RUN pwsh -c "Install-Module AzureRM.netcore -Force" && \
pwsh -Command "Install-Module -Name SqlServer -Force -Verbose" && \
pwsh -Command "Update-Module SqlServer -AllowPrerelease -Force -Verbose"

# Install system utils
RUN apt update && apt install -y curl gpg  && \ 
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg; \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null; \
apt update && apt install -y gh && \
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/msprod.list && \
apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools

# Set sqlcmd path variable
ENV PATH="$PATH:/opt/mssql-tools/bin"


