 param(
     [Parameter(Mandatory=$true)]
     [string]$ProjectName,
     [string]$Description = "Codex project"
 )
 
 $ErrorActionPreference = "Stop"
 
 # Read token from credential file
 $CRED_FILE = "C:\Users\yfs\Documents\Codex\.git-credentials"
 $credContent = Get-Content $CRED_FILE -Raw
 if ($credContent -match "https://([^@]+)@github\.com") {
     $TOKEN = $matches[1]
 } else {
     Write-Error "Token not found in $CRED_FILE. Ensure the file contains: https://TOKEN@github.com"
     exit 1
 }
 
 $GITHUB_USER = "wangkuibi233-cell"
 $GIT = "C:\Users\yfs\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe"
 $PYTHON = "C:\Users\yfs\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
 
 $projectDir = Join-Path (Get-Location) $ProjectName
 Write-Host "=== Initializing project: $ProjectName ===" -ForegroundColor Cyan
 
 # Step 1: Create directory
 Write-Host "[1/5] Creating directory: $projectDir"
 New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
 
 # Step 2: Create GitHub repo via API
 Write-Host "[2/5] Creating GitHub repo: $GITHUB_USER/$ProjectName"
 $apiScript = @"
 import urllib.request, json, ssl, sys
 data = json.dumps({"name": "$ProjectName", "description": "$Description", "private": False, "auto_init": False}).encode()
 ctx = ssl.create_default_context()
 ctx.check_hostname = False
 ctx.verify_mode = ssl.CERT_NONE
 req = urllib.request.Request(
     "https://api.github.com/user/repos",
     data=data,
     headers={"Authorization": "token $TOKEN", "User-Agent": "Codex", "Accept": "application/vnd.github+json", "Content-Type": "application/json"}
 )
 resp = urllib.request.urlopen(req, context=ctx)
 result = json.loads(resp.read())
 print(result["clone_url"])
 "@
 $cloneUrl = & $PYTHON -c $apiScript 2>&1
 if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create GitHub repo: $cloneUrl"; exit 1 }
 Write-Host "  Repo: $cloneUrl"
 
 # Step 3: Init git
 Write-Host "[3/5] Initializing git repository"
 Push-Location $projectDir
 & $GIT init
 & $GIT config user.name "yfs"
 & $GIT config user.email "yfs@users.noreply.github.com"
 & $GIT branch -m main
 & $GIT config credential.helper "store --file $CRED_FILE"
 
 # Step 4: Initial commit
 Write-Host "[4/5] Creating initial commit"
 @"
 __pycache__/
 *.pyc
 *.pyo
 node_modules/
 .env
 .DS_Store
 Thumbs.db
 *.tmp
 *.log
 "@ | Out-File -FilePath ".gitignore" -Encoding ascii
 & $GIT add .gitignore
 & $GIT commit -m "Initial commit: $ProjectName setup"
 
 # Step 5: Connect and push
 Write-Host "[5/5] Connecting to GitHub and pushing"
 & $GIT remote add origin $cloneUrl
 & $GIT -c credential.helper="store --file $CRED_FILE" push -u origin main
 
 Pop-Location
 Write-Host "=== Done: https://github.com/$GITHUB_USER/$ProjectName ===" -ForegroundColor Green
