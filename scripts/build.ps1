param(
    [switch]$Push,
    [switch]$SkipTests,
    [string]$Version = $null,
    [ValidateSet('stable', 'beta')]
    [string]$Channel = 'beta',
    [string]$Organization = 'ClassonConsultingAB',
    [string]$Repository = 'ha-azure-ddns',
    [string]$Registry = 'ghcr.io',
    [ValidateSet('linux/arm64', 'linux/amd64')]
    [string]$Platform = 'linux/arm64'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($env:GH_TOKEN)) {
    throw 'GH_TOKEN environment variable is not set.'
}

Import-Module "$PSScriptRoot/modules/BuildTasks/BuildTasks.psm1" -Force

$rootPath = Resolve-Path "$PSScriptRoot/.."
$outputDirPath = Join-Path $rootPath output
$versionFilePath = Join-Path $outputDirPath version.json
$slnPath = Join-Path $rootPath AzureDdns.slnx
$testResultsFilePath = Join-Path $outputDirPath AzureDdns.trx
$codeCoverageFilePathPrefix = Join-Path $outputDirPath AzureDdns.coverage
$codeCoverageReportDirPath = Join-Path $outputDirPath AzureDdns.coveragereport
$addonConfigDirNames = @{ stable = 'azure-ddns'; beta = 'azure-ddns-beta' }
$activeAddonDirName = $addonConfigDirNames[$Channel]
$homeAssistantDirPath = Join-Path $rootPath home-assistant
$addonConfigPath = Join-Path $homeAssistantDirPath config.yaml
$iconPath = Join-Path $homeAssistantDirPath icon.png
$docsPath = Join-Path $homeAssistantDirPath DOCS.md
$changelogPath = Join-Path $homeAssistantDirPath CHANGELOG.md
$licensePath = Join-Path $rootPath LICENSE
$repositoryYamlPath = Join-Path $rootPath repository.yaml
$dependabotConfigPath = Join-Path $rootPath .github/dependabot.yml
$publishBranchName = 'publish'
$publishWorktreePath = Join-Path $outputDirPath $publishBranchName
$imageName = $Repository.ToLower()
if (Test-Path $outputDirPath) { Remove-Item $outputDirPath -Recurse }
New-Item $outputDirPath -ItemType Directory | Out-Null
Install-GitVersion
Exec "dotnet-gitversion $rootPath /output file /outputfile $versionFilePath"
$versionInfo = (Get-Content $versionFilePath | ConvertFrom-Json)

$containerImageVersion = if ([string]::IsNullOrEmpty($Version)) { $versionInfo.LegacySemVerPadded } else { $Version }
$gitHubImage = '{0}/{1}/{2}:{3}' -f $Registry, $Organization.ToLower(), $imageName, $containerImageVersion

Task -Title Test -Skip:$SkipTests -Command {
    $codeCoverageFilePath = "$codeCoverageFilePathPrefix.xml"
    Exec "dotnet test $slnPath --logger 'trx;LogFileName=$testResultsFilePath' /property:CollectCoverage=True /property:CoverletOutputFormat=opencover /property:CoverletOutput=$codeCoverageFilePath /property:Exclude='[System.*]*' /property:ExcludeByFile='**/obj/**/*.cs'"
    Install-ReportGenerator
    $codeCoverageFilePaths = @(Resolve-Path "$codeCoverageFilePathPrefix*") -join ';'
    Exec "reportgenerator -reports:'$codeCoverageFilePaths' -targetdir:$codeCoverageReportDirPath -reporttypes:'TextSummary;HTML'"
    Get-Content (Join-Path $codeCoverageReportDirPath Summary.txt)
}

Task -Title Login -Skip:(!$Push) -Command {
    Exec "echo $env:GH_TOKEN | docker login $Registry -u automation --password-stdin"
}

Task -Title Build -Command {
    # --platform cross-compiles for aarch64 (Home Assistant Yellow) even when run on an amd64 dev
    # machine/runner, via BuildKit + QEMU emulation. Without --push, the built image is loaded into
    # the local image store by default (docker build's normal behavior, unlike `docker buildx build`
    # which requires an explicit --load).
    $haArch = @{ 'linux/arm64' = 'aarch64'; 'linux/amd64' = 'amd64' }[$Platform]
    $build_args = @(
        "--secret id=github_token,env=GH_TOKEN"
        "--platform $Platform"
        "--label org.opencontainers.image.title=$Repository"
        '--label org.opencontainers.image.description='
        "--label org.opencontainers.image.url=https://github.com/$Organization/$Repository"
        "--label org.opencontainers.image.source=https://github.com/$Organization/$Repository"
        "--label org.opencontainers.image.version=$containerImageVersion"
        "--label org.opencontainers.image.created=$([DateTime]::UtcNow.ToString('o'))"
        "--label org.opencontainers.image.revision=$($versionInfo.ShortSha)"
        "--label io.hass.version=$containerImageVersion"
        "--label io.hass.type=app"
        "--label io.hass.arch=$haArch"
        "-t $gitHubImage"
    )
    if ($Push) { $build_args += '--push' }
    Exec "docker build $($build_args -join ' ') $rootPath"
}

Task -Title 'Publish add-on config' -Skip:(!$Push) -Command {
    # The '$publishBranchName' branch is the repository's default branch and is intentionally
    # unprotected and has no branch-protection relationship to 'main'. Home Assistant fetches the
    # add-on repository's default branch, so every publish checks it out in a worktree, updates only
    # the channel being published (the other channel's config.yaml is already there, untouched), and
    # pushes a normal commit. This keeps version-bump commits off 'main' entirely, so they never
    # conflict with branch protection there and never affect GitVersion's commit-based version
    # calculation.
    Exec "git -C $rootPath worktree prune"
    if (Test-Path $publishWorktreePath) { Remove-Item $publishWorktreePath -Recurse -Force }
    if (Exec "git -C $rootPath branch --list $publishBranchName" -ReturnOutput) { Exec "git -C $rootPath branch -D $publishBranchName" }

    $remotePublishRef = Exec "git -C $rootPath ls-remote origin $publishBranchName" -ReturnOutput
    $publishBranchExistsRemotely = -not [string]::IsNullOrWhiteSpace($remotePublishRef)
    if ($publishBranchExistsRemotely) {
        Exec "git -C $rootPath fetch origin $publishBranchName"
        Exec "git -C $rootPath worktree add -b $publishBranchName $publishWorktreePath origin/$publishBranchName"
    }
    else {
        Exec "git -C $rootPath worktree add --orphan -b $publishBranchName $publishWorktreePath"
    }

    $addonConfigContent = Get-Content $addonConfigPath -Raw
    $addonConfigContent = $addonConfigContent -replace '(?m)^version: ".*"$', "version: `"$containerImageVersion`""
    if ($Channel -eq 'beta') {
        $addonConfigContent = $addonConfigContent -replace '(?m)^(name: ".*)"$', '$1 (Beta)"'
        $addonConfigContent = $addonConfigContent -replace '(?m)^(slug: ".*)"$', '$1-beta"'
    }
    $activeAddonDirPath = Join-Path $publishWorktreePath $activeAddonDirName
    New-Item $activeAddonDirPath -ItemType Directory -Force | Out-Null
    Set-Content (Join-Path $activeAddonDirPath config.yaml) -Value $addonConfigContent -NoNewline
    Copy-Item $iconPath (Join-Path $activeAddonDirPath icon.png)
    Copy-Item $docsPath (Join-Path $activeAddonDirPath DOCS.md)

    $unreleasedMatch = [regex]::Match((Get-Content $changelogPath -Raw), '(?ms)^##\s*Unreleased\s*\r?\n(.*?)(?=^##\s|\z)')
    $unreleasedBody = $unreleasedMatch.Groups[1].Value.Trim()

    $isDependabot = $env:GITHUB_ACTOR -eq 'dependabot[bot]'
    if ($isDependabot -and [string]::IsNullOrWhiteSpace($unreleasedBody)) {
        $unreleasedBody = "### Changed`n`n- Bumped dependencies."
    }

    # Guards against publishing without having filled in the "Unreleased" delta: the hash of the
    # delta is stored in a shared file at the publish worktree root, and if it matches the hash from
    # the last stable publish, the delta clearly hasn't been updated since. Only stable publishes
    # update this baseline, so repeated pushes to the same PR branch (beta) keep comparing against the
    # same baseline and never re-trigger the guard, while a genuinely forgotten changelog still throws.
    # Dependabot builds bypass the guard entirely, so consecutive dependency-bump releases can carry
    # the same "Bumped dependencies." wording without tripping it.
    $unreleasedHashPath = Join-Path $publishWorktreePath CHANGELOG.hash
    $unreleasedHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($unreleasedBody))) -Algorithm SHA256).Hash
    if (-not $isDependabot -and (Test-Path $unreleasedHashPath) -and ((Get-Content $unreleasedHashPath -Raw).Trim() -eq $unreleasedHash)) {
        throw "The CHANGELOG.md 'Unreleased' section hasn't changed since the last stable publish. Did you forget to fill in the changelog delta?"
    }
    if ($Channel -eq 'stable') { Set-Content $unreleasedHashPath -Value $unreleasedHash -NoNewline }

    $publishedChangelogPath = Join-Path $activeAddonDirPath CHANGELOG.md
    if ($Channel -eq 'stable') {
        $newChangelogEntry = "## [$containerImageVersion] - $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'))`n`n$unreleasedBody`n"
        $existingPublishedBody = ''
        if (Test-Path $publishedChangelogPath) {
            $existingPublishedBody = ((Get-Content $publishedChangelogPath -Raw) -replace '(?ms)^#\s*Changelog\s*\r?\n', '').Trim()
        }
        $combinedChangelogContent = "# Changelog`n`n$newChangelogEntry"
        if ($existingPublishedBody) { $combinedChangelogContent += "`n$existingPublishedBody`n" }
        Set-Content $publishedChangelogPath -Value $combinedChangelogContent -NoNewline
    }
    else {
        Set-Content $publishedChangelogPath -Value "# Changelog`n`n## Unreleased`n`n$unreleasedBody`n" -NoNewline
    }

    Copy-Item $licensePath (Join-Path $publishWorktreePath LICENSE)
    Copy-Item $repositoryYamlPath (Join-Path $publishWorktreePath repository.yaml)
    $publishGitHubDirPath = Join-Path $publishWorktreePath .github
    New-Item $publishGitHubDirPath -ItemType Directory -Force | Out-Null
    Copy-Item $dependabotConfigPath (Join-Path $publishGitHubDirPath dependabot.yml)
    if ($Channel -eq 'stable') {
        $sourceCodeSection = "`n`n## Source code`n`nThis branch only contains the files Home Assistant needs to install the add-on. Source code, build`nscripts, and CI configuration live on the [``main``](https://github.com/$Organization/$Repository/tree/main) branch of this repository.`n"
        Set-Content (Join-Path $publishWorktreePath README.md) -Value ((Get-Content $docsPath -Raw) + $sourceCodeSection) -NoNewline
    }

    Exec "git -C $publishWorktreePath add -A"
    if (git -C $publishWorktreePath status --porcelain) {
        Exec "git -C $publishWorktreePath commit -m 'Publish $Channel v$containerImageVersion'"
        Exec "git -C $publishWorktreePath push origin HEAD:$publishBranchName"
    }
    Exec "git -C $rootPath worktree remove $publishWorktreePath --force"
}

Write-TaskSummary

Write-Host "Image: $gitHubImage" -ForegroundColor Cyan
if ($Push) {
    Write-Host "Published '$publishBranchName' branch ($Channel channel) with version $containerImageVersion." -ForegroundColor Cyan
}
else {
    Write-Host "Run with -Push to push the image and publish this version to the '$publishBranchName' branch." -ForegroundColor Cyan
}
