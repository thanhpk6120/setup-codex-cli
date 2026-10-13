# test-bootstrap.ps1 - Assert-based test for setup-codex-cli bootstrap script
$ErrorActionPreference = "Stop"

$tempDir = Join-Path $env:TEMP ("codex-test-" + [System.Guid]::NewGuid().ToString("N"))
$tempDir2 = Join-Path $env:TEMP ("codex-test2-" + [System.Guid]::NewGuid().ToString("N"))

try {
    $env:AI_BASE_URL = "https://test.local"
    $env:AI_API_KEY = "test-key-abc"
    $env:JIRA_URL = "https://test.jira"
    $env:JIRA_PERSONAL_TOKEN = "test-jira-token"
    $env:CONFLUENCE_URL = "https://test.conf"
    $env:CONFLUENCE_PERSONAL_TOKEN = "test-conf-token"
    $env:CONTEXT7_API_KEY = "test-ctx-token"

    # Setup mock environment for gitnexus and context7
    $mockBinDir = Join-Path $env:TEMP ("codex-mock-bin-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $mockBinDir | Out-Null
    Set-Content -Path (Join-Path $mockBinDir "gitnexus.cmd") -Value "@echo off`necho gitnexus"
    Set-Content -Path (Join-Path $mockBinDir "npm.cmd") -Value "@echo off`nif `"%1`"==`"root`" if `"%2`"==`"-g`" (echo $mockNpmDir& exit /b 0)`nexit /b 0"
    $oldPath = $env:Path
    $env:Path = "$mockBinDir;$env:Path"

    $mockNpmDir = Join-Path $env:TEMP ("codex-mock-npm-" + [System.Guid]::NewGuid().ToString("N"))
    $mockContext7Path = Join-Path $mockNpmDir "@upstash\context7-mcp\dist"
    New-Item -ItemType Directory -Force -Path $mockContext7Path | Out-Null
    Set-Content -Path (Join-Path $mockContext7Path "index.js") -Value "// mock"

    # =========================================================================
    # Test 1: Chay bootstrap voi -SkipInstall (non-interactive, all MCPs skipped)
    # =========================================================================
    Write-Host "Running Codex CLI bootstrap (Test 1: SkipInstall non-interactive) into: $tempDir"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -CodexDir $tempDir

    $configFile = Join-Path $tempDir "config.toml"
    if (-not (Test-Path $configFile)) {
        throw "ASSERTION FAILED: Missing generated file: $configFile"
    }

    $tomlContent = Get-Content $configFile -Raw
    if (-not $tomlContent.Contains('base_url = "https://test.local"')) {
        throw "ASSERTION FAILED: base_url mismatch in config.toml"
    }
    if (-not $tomlContent.Contains('api_key = "test-key-abc"')) {
        throw "ASSERTION FAILED: api_key mismatch in config.toml"
    }
    if (-not $tomlContent.Contains('model_provider = "custom"')) {
        throw "ASSERTION FAILED: model_provider custom mismatch in config.toml"
    }
    if (-not $tomlContent.Contains('[model_providers.custom]')) {
        throw "ASSERTION FAILED: [model_providers.custom] missing in config.toml"
    }

    foreach ($f in @("AGENTS.md", "CODEX.md")) {
        $p = Join-Path $tempDir $f
        if (-not (Test-Path $p)) {
            throw "ASSERTION FAILED: Missing copied static file: $p"
        }
    }
    foreach ($f in @("RULES.md", "SYSTEM.md")) {
        $p = Join-Path $tempDir $f
        if (Test-Path $p) {
            throw "ASSERTION FAILED: Legacy file should not exist: $p"
        }
    }

    $skillsDir = Join-Path $tempDir "skills"
    if (-not (Test-Path $skillsDir)) {
        throw "ASSERTION FAILED: Missing copied skills/ directory: $skillsDir"
    }

    # =========================================================================
    # Test 2: Chay bootstrap voi -Force (Tu dong cai dat tat ca MCP servers)
    # =========================================================================
    Write-Host "`nRunning Codex CLI bootstrap (Test 2: -Force accept all MCPs) into: $tempDir2"
    & "$PSScriptRoot\bootstrap.ps1" -DryRun:$false -SkipInstall -Force -CodexDir $tempDir2

    $configFile2 = Join-Path $tempDir2 "config.toml"
    if (-not (Test-Path $configFile2)) {
        throw "ASSERTION FAILED: Missing generated file: $configFile2"
    }

    $tomlContent2 = Get-Content $configFile2 -Raw
    if (-not $tomlContent2.Contains('[mcp_servers.gitnexus]')) {
        throw "ASSERTION FAILED: gitnexus missing in config.toml when -Force"
    }
    if (-not $tomlContent2.Contains('[mcp_servers.company-atlassian]')) {
        throw "ASSERTION FAILED: company-atlassian missing in config.toml when -Force"
    }
    if (-not $tomlContent2.Contains('[mcp_servers.context7]')) {
        throw "ASSERTION FAILED: context7 missing in config.toml when -Force"
    }
    if (-not $tomlContent2.Contains('[mcp_servers.cloakbrowser]')) {
        throw "ASSERTION FAILED: cloakbrowser missing in config.toml when -Force"
    }
    if (-not $tomlContent2.Contains('[mcp_servers.glab]')) {
        throw "ASSERTION FAILED: glab missing in config.toml when -Force"
    }
    if (-not $tomlContent2.Contains('JIRA_URL = "https://test.jira"')) {
        throw "ASSERTION FAILED: JIRA_URL mismatch in config.toml"
    }
    if (-not $tomlContent2.Contains('CONTEXT7_API_KEY = "test-ctx-token"')) {
        throw "ASSERTION FAILED: CONTEXT7_API_KEY mismatch in config.toml"
    }

    Write-Host "`nAll isolated tests passed successfully for setup-codex-cli!" -ForegroundColor Green
}
finally {
    $env:Path = $oldPath
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    if (Test-Path $tempDir2) { Remove-Item -Recurse -Force $tempDir2 -ErrorAction SilentlyContinue }
    if ($mockBinDir -and (Test-Path $mockBinDir)) { Remove-Item -Recurse -Force $mockBinDir -ErrorAction SilentlyContinue }
    if ($mockNpmDir -and (Test-Path $mockNpmDir)) { Remove-Item -Recurse -Force $mockNpmDir -ErrorAction SilentlyContinue }
}
