param(
    [switch]$Publish,
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
$changelogPath = Join-Path $homeAssistantDirPath unreleased.json
$licensePath = Join-Path $rootPath LICENSE
$repositoryYamlPath = Join-Path $rootPath repository.yaml
$dependabotConfigPath = Join-Path $rootPath .github/dependabot.yml
$publishBranchName = 'publish'
$publishWorktreePath = Join-Path $outputDirPath $publishBranchName
$imageName = $Repository.ToLower()
$standardChangelogHeadings = @('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')

function ConvertTo-ChangelogMarkdown($Sections) {
    $blocks = foreach ($heading in $standardChangelogHeadings) {
        $bullets = @($Sections.$heading)
        if ($bullets.Count -gt 0) {
            $bulletLines = ($bullets | ForEach-Object { "- $_" }) -join "`n"
            "### $heading`n`n$bulletLines"
        }
    }
    $blocks -join "`n`n"
}

if (Test-Path $outputDirPath) { Remove-Item $outputDirPath -Recurse }
New-Item $outputDirPath -ItemType Directory | Out-Null
Install-GitVersion
Exec "dotnet-gitversion $rootPath /output file /outputfile $versionFilePath"
$versionInfo = (Get-Content $versionFilePath | ConvertFrom-Json)

$containerImageVersion = if ([string]::IsNullOrEmpty($Version)) { $versionInfo.LegacySemVerPadded } else { $Version }
$gitHubImage = '{0}/{1}/{2}:{3}' -f $Registry, $Organization.ToLower(), $imageName, $containerImageVersion

$unreleasedSections = Get-Content $changelogPath -Raw | ConvertFrom-Json -AsHashtable
foreach ($heading in $standardChangelogHeadings) {
    $unreleasedSections.$heading = @($unreleasedSections.$heading | Where-Object { $_ })
}
$unreleasedHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes((Get-Content $changelogPath -Raw)))) -Algorithm SHA256).Hash
$mergedBody = $null

if ($Publish) {
    $remotePublishRef = Exec "git -C $rootPath ls-remote origin $publishBranchName" -ReturnOutput
    $lastReleasedSha = $null
    $storedHash = $null
    if (-not [string]::IsNullOrWhiteSpace($remotePublishRef)) {
        Exec "git -C $rootPath fetch origin $publishBranchName"

        $match = Exec "git -C $rootPath log origin/$publishBranchName --oneline --fixed-strings --grep=`"Publish $Channel v$containerImageVersion`"" -ReturnOutput
        if (-not [string]::IsNullOrWhiteSpace($match)) {
            Write-Host "Version $containerImageVersion is already published to the '$publishBranchName' branch. Nothing to do." -ForegroundColor Cyan
            exit 0
        }

        $hashEntry = Exec "git -C $rootPath ls-tree origin/$publishBranchName -- CHANGELOG.hash" -ReturnOutput
        if (-not [string]::IsNullOrWhiteSpace($hashEntry)) {
            $storedHash = (Exec "git -C $rootPath show origin/${publishBranchName}:CHANGELOG.hash" -ReturnOutput).Trim()
        }

        $shaEntry = Exec "git -C $rootPath ls-tree origin/$publishBranchName -- CHANGELOG.sha" -ReturnOutput
        if (-not [string]::IsNullOrWhiteSpace($shaEntry)) {
            $lastReleasedSha = (Exec "git -C $rootPath show origin/${publishBranchName}:CHANGELOG.sha" -ReturnOutput).Trim()
        }
    }

    $commitRange = if ($lastReleasedSha) { "$lastReleasedSha..HEAD" } else { 'HEAD' }
    $commitAuthorEmails = @((Exec "git -C $rootPath log $commitRange --format=%ae" -ReturnOutput) | Where-Object { $_ })
    $humanCommitCount = @($commitAuthorEmails | Where-Object { $_ -notlike '*49699333*' }).Count
    $unreleasedUnchanged = $storedHash -and ($storedHash -eq $unreleasedHash)

    if ($Channel -eq 'beta' -and $unreleasedUnchanged -and $humanCommitCount -gt 0) {
        throw "home-assistant/unreleased.json hasn't changed since the last stable publish, but human commits exist since then. Did you forget to fill in the changelog delta?"
    }

    $dependabotCommits = @((Exec "git -C $rootPath log $commitRange --author=49699333 --format=%s" -ReturnOutput) | Where-Object { $_ })
    if ($dependabotCommits.Count -gt 0) {
        $unreleasedSections.Changed += $dependabotCommits | ForEach-Object { "$($_.TrimEnd('.'))." }
    }
    $mergedBody = ConvertTo-ChangelogMarkdown $unreleasedSections
}

Task -Title Test -Skip:$SkipTests -Command {
    $codeCoverageFilePath = "$codeCoverageFilePathPrefix.xml"
    Exec "dotnet test $slnPath --logger 'trx;LogFileName=$testResultsFilePath' /property:CollectCoverage=True /property:CoverletOutputFormat=opencover /property:CoverletOutput=$codeCoverageFilePath /property:Exclude='[System.*]*' /property:ExcludeByFile='**/obj/**/*.cs'"
    Install-ReportGenerator
    $codeCoverageFilePaths = @(Resolve-Path "$codeCoverageFilePathPrefix*") -join ';'
    Exec "reportgenerator -reports:'$codeCoverageFilePaths' -targetdir:$codeCoverageReportDirPath -reporttypes:'TextSummary;HTML'"
    Get-Content (Join-Path $codeCoverageReportDirPath Summary.txt)
}

Task -Title Login -Skip:(!$Publish) -Command {
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
    if ($Publish) { $build_args += '--push' }
    Exec "docker build $($build_args -join ' ') $rootPath"
}

Task -Title 'Publish add-on config' -Skip:(!$Publish) -Command {
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

    $publishedChangelogPath = Join-Path $activeAddonDirPath CHANGELOG.md
    if ($Channel -eq 'stable') {
        $unreleasedHashPath = Join-Path $publishWorktreePath CHANGELOG.hash
        $lastReleasedShaPath = Join-Path $publishWorktreePath CHANGELOG.sha
        Set-Content $unreleasedHashPath -Value $unreleasedHash -NoNewline
        Exec "git -C $rootPath rev-parse HEAD" -ReturnOutput | Set-Content $lastReleasedShaPath -NoNewline

        $newChangelogEntry = "## [$containerImageVersion] - $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'))`n`n$mergedBody`n"
        $existingPublishedBody = ''
        if (Test-Path $publishedChangelogPath) {
            $existingPublishedBody = ((Get-Content $publishedChangelogPath -Raw) -replace '(?ms)^#\s*Changelog\s*\r?\n', '').Trim()
        }
        $combinedChangelogContent = "# Changelog`n`n$newChangelogEntry"
        if ($existingPublishedBody) { $combinedChangelogContent += "`n$existingPublishedBody`n" }
        Set-Content $publishedChangelogPath -Value $combinedChangelogContent -NoNewline
    }
    else {
        Set-Content $publishedChangelogPath -Value "# Changelog`n`n## Unreleased`n`n$mergedBody`n" -NoNewline
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
if ($Publish) {
    Write-Host "Published '$publishBranchName' branch ($Channel channel) with version $containerImageVersion." -ForegroundColor Cyan
}
else {
    Write-Host "Run with -Publish to push the image and publish this version to the '$publishBranchName' branch." -ForegroundColor Cyan
}
