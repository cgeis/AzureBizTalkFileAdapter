param([string]$RepoName = "AzureBizTalkFileAdapter")

gh repo create $RepoName --public --confirm
git init
git add .
git commit -m "Initial commit - BizTalk FILE Adapter replacement"
git branch -M main
git remote add origin "https://github.com/$(gh api user -q .login)/$RepoName.git"
git push -u origin main
Write-Host "✅ Repo created and pushed: https://github.com/$(gh api user -q .login)/$RepoName"
