<#
    .DESCRIPTION
    This script generates markdown files for the development documentation based on the existing JSON files.
    Create table of content and archive any files in the dev folder not modified by this script.
    This script is not meant to be used manually, it is called by the github action workflow.
#>



#region Code Formatting Functions
function Invoke-Preprocessing {
    <#
    .SYNOPSIS
    Applies consistent code formatting standards to project files using RegEx patterns
    
    .DESCRIPTION
    This function processes all files in a directory (excluding specified paths/patterns),
    applying formatting rules like whitespace normalization and code structure consistency.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [switch]$SkipExcludedFilesValidation,

        [Parameter(Position=1)]
        [switch]$ThrowExceptionOnEmptyFilesList,

        [Parameter(Mandatory, Position=2)]
        [ValidateScript({
            if (-not [System.IO.Path]::IsPathRooted($_)) {
                throw "WorkingDir must be an absolute path"
            }
            if (-not (Test-Path -Path $_ -PathType Container)) {
                throw "Invalid directory path"
            }
            $true
        })]
        [string]$WorkingDir,

        [Parameter(Position=3)]
        [string[]]$ExcludedFiles = @(),

        [Parameter(Mandatory, Position=4)]
        [string]$ProgressStatusMessage,

        [Parameter(Position=5)]
        [string]$ProgressActivity = "Code Formatting"
    )

    try {
        # Initialize exclusion list
        $resolvedExclusions = [System.Collections.Generic.List[string]]::new()

        if (-not $SkipExcludedFilesValidation) {
            foreach ($pattern in $ExcludedFiles) {
                $fullPattern = Join-Path $WorkingDir $pattern
                try {
                    $resolved = Resolve-Path $fullPattern -ErrorAction Stop
                    $resolvedExclusions.AddRange($resolved.Path)
                }
                catch {
                    if ($ThrowExceptionOnEmptyFilesList) {
                        throw "Exclusion pattern invalid: $pattern"
                    }
                }
            }
        }

        # Get files with progress tracking
        $files = Get-ChildItem -Path $WorkingDir -Recurse -File -Force |
                 Where-Object { $resolvedExclusions -notcontains $_.FullName }

        if ($ThrowExceptionOnEmptyFilesList -and -not $files) {
            throw "No files found in directory: $WorkingDir"
        }

        # Formatting rules configuration
        $formatRules = @(
            @{ Pattern = '\t'; Replacement = '    ' }
            @{ Pattern = '\)\s*\{'; Replacement = ') {' }
            @{ Pattern = '(?<keyword>if|for|foreach)\s*(?<condition>\(.*?\))\s*\{'; 
              Replacement = '${keyword} ${condition} {' }
            # Add more rules here...
        )

        # Process files with progress
        $totalFiles = $files.Count
        $currentFile = 0
        
        foreach ($file in $files) {
            $currentFile++
            $percentComplete = ($currentFile / $totalFiles) * 100
            
            Write-Progress -Activity $ProgressActivity `
                -Status "$ProgressStatusMessage ($currentFile/$totalFiles)" `
                -PercentComplete $percentComplete `
                -CurrentOperation $file.Name

            try {
                $content = Get-Content $file.FullName -Raw
                
                # Apply formatting rules
                foreach ($rule in $formatRules) {
                    $content = $content -replace $rule.Pattern, $rule.Replacement
                }

                # Preserve BOM and encoding
                $encoding = [System.Text.Encoding]::UTF8
                if ($file.PSIsContainer -and $file.GetType().Name -eq 'FileInfo') {
                    $preamble = $file.GetEncoding().Preamble
                    if ($preamble) {
                        $encoding = [System.Text.UTF8Encoding]::new($true)
                    }
                }

                [System.IO.File]::WriteAllText($file.FullName, $content.TrimEnd(), $encoding)
            }
            catch {
                Write-Warning "Error processing $($file.FullName): $_"
            }
        }
    }
    catch {
        Write-Error "Preprocessing failed: $_"
        throw
    }
    finally {
        Write-Progress -Activity $ProgressActivity -Completed
    }
}
#endregion