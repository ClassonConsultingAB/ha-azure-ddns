param(
    [switch]$SkipPush,
    [switch]$SkipTests,
    [string]$Version = $null,
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

Task -Title Login -Skip:$SkipPush -Command {
    Exec "echo $env:GH_TOKEN | docker login $Registry -u automation --password-stdin"
}

Task -Title Build -Command {
    # --platform cross-compiles for aarch64 (Home Assistant Yellow) even when run on an amd64 dev
    # machine/runner, via BuildKit + QEMU emulation. Without --push, the built image is loaded into
    # the local image store by default (docker build's normal behavior, unlike `docker buildx build`
    # which requires an explicit --load).
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
        "-t $gitHubImage"
    )
    if (!$SkipPush) { $build_args += '--push' }
    Exec "docker build $($build_args -join ' ') $rootPath"
}

Write-TaskSummary

Write-Host "Image: $gitHubImage" -ForegroundColor Cyan
Write-Host "Remember to set 'version: `"$containerImageVersion`"' in azure-ddns/config.yaml to match." -ForegroundColor Cyan
