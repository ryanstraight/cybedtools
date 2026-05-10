# Build the Concordance Quarto subsite locally and deploy the rendered
# output to the gh-pages branch under /concordance/. Uses a temporary git
# worktree so the main working tree is untouched.
#
# Coexists with the pkgdown deploy workflow: both write to the same
# gh-pages branch but to disjoint paths (pkgdown at root, this script
# at /concordance/). Neither wipes the other.
#
# Prerequisites
#   - quarto installed and on PATH
#   - cybedtools R package installed (devtools::load_all or remotes
#     install of the local checkout)
#   - Staged framework graph at data/processed/ntriples/_combined.nt
#     (see docs/framework-data-sources.md)
#   - Precomputed alignment data at concordance/_data/*.rds (run the
#     concordance/_data-prep-*.R scripts once after the graph is staged)
#   - Push access to origin (the repo owner's working clone)
#
# Usage (from anywhere; the script resolves the repo root itself)
#   pwsh tools/publish-concordance.ps1
#   pwsh tools/publish-concordance.ps1 -DryRun
#   pwsh tools/publish-concordance.ps1 -Message "deploy: Concordance NICE-K12 prep"

param(
    [switch]$DryRun,
    [string]$Message = "deploy: Concordance subsite refresh"
)

$ErrorActionPreference = "Stop"

# Resolve repo root from the script's own location.
$scriptRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path

Write-Host "Repo root: $repoRoot" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $repoRoot "concordance/_quarto.yml"))) {
    throw "concordance/_quarto.yml not found at $repoRoot. Run from a cybedtools checkout that contains the concordance subproject."
}

# Verify the data dependencies the alignment query pages need. These
# files are gitignored. If they are missing, the corresponding pages
# will fail to render and the script will abort during quarto render.
$expectedRds = @(
    "concordance/_data/k12_alignment.rds",
    "concordance/_data/nice_csec2017_alignment.rds",
    "concordance/_data/nice_csec2017_best.rds",
    "concordance/_data/nice_ecsf_alignment.rds",
    "concordance/_data/nice_ecsf_best.rds",
    "concordance/_data/top_work_roles.rds"
)
$missing = $expectedRds | Where-Object { -not (Test-Path (Join-Path $repoRoot $_)) }
if ($missing) {
    Write-Warning "Missing precomputed data files. The alignment query pages will fail to render."
    $missing | ForEach-Object { Write-Warning "  - $_" }
    Write-Warning "Run the matching concordance/_data-prep-*.R scripts after staging the framework graph."
    throw "Aborting due to missing precomputed data."
}

# Build the Concordance subsite.
Write-Host "==> Rendering Concordance subsite..." -ForegroundColor Cyan
Push-Location (Join-Path $repoRoot "concordance")
try {
    & quarto render
    if ($LASTEXITCODE -ne 0) {
        throw "Quarto render failed."
    }
} finally {
    Pop-Location
}

$siteIndex = Join-Path $repoRoot "concordance/_site/index.html"
if (-not (Test-Path $siteIndex)) {
    throw "Quarto render did not produce concordance/_site/index.html."
}

if ($DryRun) {
    Write-Host "==> Dry run requested. Site at concordance/_site/. Skipping deploy." -ForegroundColor Yellow
    exit 0
}

# Deploy via temporary git worktree on gh-pages.
Push-Location $repoRoot
$worktreeBase = [System.IO.Path]::GetTempPath()
$worktreeName = "cybedtools-gh-pages-" + [System.IO.Path]::GetRandomFileName()
$worktreePath = Join-Path $worktreeBase $worktreeName

try {
    Write-Host "==> Fetching gh-pages from origin..." -ForegroundColor Cyan
    & git fetch origin gh-pages
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch origin gh-pages failed. Does the gh-pages branch exist on origin?"
    }

    Write-Host "==> Adding worktree at $worktreePath..." -ForegroundColor Cyan
    & git worktree add -B gh-pages $worktreePath origin/gh-pages
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree add failed."
    }

    # Replace concordance/ on gh-pages with the freshly-rendered _site contents.
    $dest = Join-Path $worktreePath "concordance"
    if (Test-Path $dest) {
        Write-Host "==> Clearing existing concordance/ on gh-pages..." -ForegroundColor Cyan
        Remove-Item -Recurse -Force $dest
    }

    Write-Host "==> Copying rendered site to gh-pages/concordance/..." -ForegroundColor Cyan
    Copy-Item -Recurse -Path (Join-Path $repoRoot "concordance/_site") -Destination $dest

    Push-Location $worktreePath
    try {
        & git add concordance

        $status = & git status --porcelain
        if (-not $status) {
            Write-Host "==> No changes on gh-pages. Skipping commit and push." -ForegroundColor Yellow
            return
        }

        & git commit -m $Message
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed."
        }

        Write-Host "==> Pushing gh-pages to origin..." -ForegroundColor Cyan
        & git push origin gh-pages
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed. Check for non-fast-forward (pkgdown deploy may have just run); rerun the script."
        }

        Write-Host "==> Live at https://ryanstraight.github.io/cybedtools/concordance/" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path $worktreePath) {
        Write-Host "==> Removing worktree..." -ForegroundColor Cyan
        & git worktree remove --force $worktreePath 2>$null
    }
    Pop-Location
}
