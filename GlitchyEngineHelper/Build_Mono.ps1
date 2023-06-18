param(
    [switch] $UpdateRepo,
    [switch] $CleanBuild,
    [switch] $Rebuild
)

$RepositoryPath = "./vendor/mono/repo"
# Directory which will contain the final build output
$TargetDirectory = Join-Path $PSScriptRoot "vendor/mono/lib/Windows"

if ((-Not $UpdateRepo) -and (-Not $CleanBuild) -and (-Not $Rebuild)) {
    $DebugLibMono = Join-Path $TargetDirectory "Debug/libmono-static-sgen.lib";
    $ReleaseLibMono = Join-Path $TargetDirectory "Release/libmono-static-sgen.lib";

    # We assume, that everything exists, when libmono-static-sgen.lib exists and don't invoke devenv
    # because devenv is slow as heck!
    # Updates/Rebuilds and Cleans will issue a build
    if ((Test-Path $DebugLibMono) -and (Test-Path $ReleaseLibMono)) {
        Write-Output "Mono already build and ready."
        exit
    }
}

function Clone-GitRepoIfDestEmpty {
    $RepoUrl = "https://github.com/mono/mono.git"

    # Check if the destination directory is empty or does not exist
    if ((-Not (Test-Path $RepositoryPath)) -or ((Get-ChildItem $RepositoryPath).Count -eq 0)) {
        # If the directory does not exist or is empty, clone the repository
        git clone $RepoUrl $RepositoryPath
    } else {
        Write-Output "Destination directory is not empty. Git repository will not be cloned."
    }
}

function Update-GitRepo {
    # Call Update-GitRepo function only if -Update switch is provided
    if (-Not $UpdateRepo) {
        Write-Output "Repository will not be updated. (Use -UpdateRepo if you want to update the repository)"
        return
    }

    Write-Output "Pulling repository..."
    git pull
}

function Patch-Mono {
    # applies the patch that sets mono to statically link the clib
    Write-Output "Patching..."
    git apply ../patch.txt
}

function Build-Mono {
    if ($CleanBuild) {
        Write-Output "Cleaning Debug..."
        devenv msvc/mono.sln /Clean "Debug|x64"
        Write-Output "Cleaning Release..."
        devenv msvc/mono.sln /Clean "Release|x64"
    }

    $BuildOption = if ($Rebuild) { "/Rebuild" } else { "/Build" }

    Write-Output "Building Debug..."
    devenv msvc/mono.sln $BuildOption "Debug|x64" /Project "libmono-static"
    #Write-Output "Building Release..."
    #devenv msvc/mono.sln $BuildOption "Release|x64" /Project "libmono-static"
}

function Copy-BuildResults {
    $SourceDirectory = "msvc/build/sgen/x64/lib"
    
    # Create the target directory if it does not exist
    if (-Not (Test-Path $TargetDirectory)) {
        New-Item -ItemType Directory -Force -Path $TargetDirectory
    }

    # Copy all files from source to target directory
    Copy-Item -Path "$SourceDirectory\*" -Destination $TargetDirectory -Force -Recurse
}

# Switch working directory to directory containing the script (allows calling the script from anywhere)
Push-Location $PSScriptRoot

# Clone the git-repository, if necessary.
Clone-GitRepoIfDestEmpty

# Change into repository
Set-Location $RepositoryPath

Update-GitRepo

Patch-Mono

Build-Mono

Copy-BuildResults

# Return to the original directory
Pop-Location
