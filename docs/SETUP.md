Prerequisites (manual – one-time)

Azure subscription (logged in: az login).
PowerShell 7+, Az module (Install-Module -Name Az -Force).
GitHub CLI (gh installed & gh auth login).
.NET 8 SDK + Azure Functions Core Tools.
Git.

Step-by-Step Setup (run in order)

Create the project structure


1. Create the folders/files exactly as above and paste the content from the sections below.


2. Run Azure resource creation (automated)PowerShell

# Register the App Configuration provider
Register-AzResourceProvider -ProviderNamespace Microsoft.AppConfiguration

# Verify the registration state (it may take a minute to switch from 'Registering' to 'Registered')
Get-AzResourceProvider -ProviderNamespace Microsoft.AppConfiguration

Clear-AzContext       See https://johan.driessen.se/posts/Fixing-the-missing-Azure-Context-in-Azure-Powershell/
Connect-AzAccount [-UseDeviceAuthentication]

Unblock-File -Path "scripts\create-azure-resources.ps1"
scripts\create-azure-resources.ps1 -Environment DEV   # repeat for PRE, PROD

(Script creates RG, two storage accounts, File Shares input/output, App Configuration store, Function App, and populates all settings + macros + mask.)


3. Initialize & push to GitHub (automated)PowerShell

Unblock-File -Path "scripts\init-github-repo.ps1"
scripts\init-github-repo.ps1 -RepoName "AzureBizTalkFileAdapter"

 (Creates public repo + pushes everything.)

Deploy code (automated / configurable)

Go to your GitHub repo → Actions → “Deploy to Azure” workflow.

Click “Run workflow” → choose DEV, PRE, or PROD.

Uses GitHub Environments (create them in repo Settings → Environments with Azure credentials).

Test
Drop a file (e.g. invoice.xml) into the input share.
Wait ≤5 min → file disappears from input and appears in output as Processed_invoice_20250315115023_12345678-... .xml (macros expanded).
All logs in Application Insights (enabled by default).