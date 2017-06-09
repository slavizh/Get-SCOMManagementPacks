<#
    .SYNOPSIS
    Script designed to enumerate and download currently available MPs from Microsoft Download servers.

    .DESCRIPTION
    Get-SCOMManagementPacks is a PowerShell script which is used to dynamically enumerate and download currently available SCOM management packs to a specified folder, organizing them by name and version.
    
    The script connects to the Microsoft SCOM Management Pack Wiki Page on Technet to determine the list of currently available management packs, their release date, and their download links, which it parses and uses to download the management packs.

    Optional controls exist which enable the extraction of the downloaded .msi files, the re-download of files which have been deleted or gone missing from the latest versions of the management packs, and the ability to skip management packs releases which are older than a specified age.

    This script provides progress output to the shell, logging, and an object-based output which can be fed to other commands to automate remediation.

    The only prerequisite for this script is internet access and permissions to save the files at the specified destination.

    Status outputs include  "New", "Unchanged", "Updated", "Extracted", "New and Extracted", and "Updated and Extracted"

    .PARAMETER MPPath
    Optional, default value: "C:\MPs". Specifies the path to the folder where management packs should be downloaded.

    .PARAMETER MPLogFileName
    Optional, default value: "MPUpdates.log". Specifies the name of the log file containing information about downloaded management packs. If the supplied value does not end in ".log", the file extension will be appended.

    .PARAMETER MPErrorLogFileName
    Optional, default value: "MPErrorLog.log". Specifies the name of the log file containing information about errors encountered during processing. If the supplied value does not end in ".log", the file extension will be appended.

    .PARAMETER ReDownloadMissingFiles
    Optional, boolean property, default value = "false". If "true", when processing management packs determined to have been downloaded previously, any files missing from the version folder for the management pack will be redownloaded. Otherwise, the script assumes files were deleted intentionally and does not re-download missing files. Note that, as the script only processes the latest version of a management pack, this only applies to the latest version - older versions will not be downloaded or assessed for missing files.

    .PARAMETER SkipMPsOlderThanDate
    Optional, datetime property, no default value. Use to supply a specific date as a filter for processing; any management packs released prior to the supplied date will not be processed. The parameter accepts a datetime object which can be retrieved via the "Get-Date" cmdlet or generated on the spot by entering the date in numeric fashion (e.g., "01-20-2010", "01/20/2010", etc.).

    .PARAMETER SkipMPsOlderThanMonths
    Optional, integer property, no default value. Use to supply a specific number of months as a filter for processing; any management packs released prior to the supplied number of months before the current date will not be processed.

    .PARAMETER CMTrace
    Optional, switch parameter. Enables logging in the CMTrace format for easy use in the CMTrace application.

    .PARAMETER Extract
    Optional, switch parameter. Enables the automatic extraction of any management packs processed by the script.

    .EXAMPLE
    This example specifies a target location on a network share as a destination for the management packs to be downloaded.

    Get-SCOMManagementPacks.ps1 -MPPath "\\SCOMShare\ManagementPacks"

    .EXAMPLE
    This example changes the default names of the log files and allows the management packs to be saved to the default location. As the file extension is not specified for one of the logs, the ".log" extension will be appended automatically.

    Get-SCOMManagementPacks.ps1 -MPLogFileName "MPUpdatesLog" -MPErrorLogFileName "MPUpdateErrors"

    .EXAMPLE
    This example downloads and extracts the management packs to the default location.

    Get-SCOMManagementPacks.ps1 -Extract

    .EXAMPLE
    This example specifies the location for management packs to be downloaded, enables the re-download of missing files, and extracts any MSI files contained in the management packs.

    Get-SCOMManagementPacks.ps1 -MPPath "E:\ManagementPacks" -ReDownloadMissingFiles $true -Extract

    .EXAMPLE
    This example outputs all logging information from the script into a CMTrace friendly format.

    Get-SCOMManagementPacks -CMTrace

    .EXAMPLE
    This example downloads the management packs to a specified location, extracts them, and logs output in a CMTrace friendly format, then filters and sorts the script's output for easy consumption.

    Get-SCOMManagementPacks -MPPath "C:\MPs\Microsoft" -CMTrace -Extract | ?{$_.Status -notlike "Unchanged"} | Sort Status

    .EXAMPLE
    This example passes a specific date into the script to prevent processing of any management packs released before that date.

    Get-SCOMManagementPacks -SkipMPsOlderThanDate "11/21/2013"

    .EXAMPLE
    This example passes a number of months into the script to prevent processing of any management packs released prior to that many months before the current date.

    Get-SCOMManagementPacks -SkipMPsOlderThanMonths 24

    .FUNCTIONALITY
    Provides an automated delivery mechanism to maintain a local repository of current Management Packs issued by Microsoft.

    .NOTES
    Authors and Contributors:
        Stefan Stranger
        Stanislav Zhelyazkov
        Anthony Bailey
        Georgi Ivanov
        Damian Flynn
        Gabriel Taylor

    Related URLs:
        Original Git Repo: https://github.com/slavizh/Get-SCOMManagementPacks
        v4 Git Repo: https://github.com/gabrieljtaylor/Get-SCOMManagementPacks
        Stanislav's blog post: https://cloudadministrator.wordpress.com/2014/08/26/version-3-0-of-damians-and-my-script-to-download-all-scom-management-packs-with-powershell/
        Damian Flynn's blog post: http://www.damianflynn.com/2014/08/26/downloading-scom-management-packs-using-powershell/
        Technet Gallery post (v3.0.1): https://gallery.technet.microsoft.com/scriptcenter/All-Management-Packs-for-37d37902
        Stefan Stranger's blog post which started it all: http://blogs.technet.com/b/stefan_stranger/archive/2013/03/13/finding-management-packs-from-microsoft-download-website-using-powershell.aspx

    Current Version: 4.3
    - Version 4.3 Changes
        - Edits: Gabriel Taylor
        - Date: 21 February 2017
        - Removed [parameter(Mandatory=$false)] statements (that's a bad practice, my bad)
        - Updated MP Wiki URL to HTTPS
        - Updated Switch parameter validation
        - Updated formatting
#>

[CmdletBinding(DefaultParameterSetName="AgeMonths")]
param
(
    [string]
    $MPPath = "C:\MPs\",

    [string]
    $MPLogFileName = "MPUpdates.log",

    [string]
    $MPErrorLogFileName = "MPErrorLog.log",

    [bool]
    $ReDownloadMissingFiles = $false,

    [parameter( ParameterSetName = "AgeDate" )]
    [datetime]
    $SkipMPsOlderThanDate,

    [parameter( ParameterSetName = "AgeMonths" )]
    [int]
    $SkipMPsOlderThanMonths,

    [switch]
    $CMTrace,

    [switch]
    $Extract
)

#region Variables
[string]$MPWikiUri = "https://social.technet.microsoft.com/wiki/contents/articles/16174.microsoft-management-packs.aspx"
[datetime]$StartTime = Get-Date
[string]$CurrentDate = $StartTime.ToString("yyyy-MM-dd")
#endregion

#region Functions
function Write-CMTraceLog
{
    [CmdletBinding()]
    param
    (
        [Parameter( Mandatory = $true )]
        [int]
        $Type,

        [Parameter( Mandatory = $true )]
        [string]
        $Component,

        [Parameter( Mandatory = $true )]
        [string]
        $Message,

        [string]
        $ModuleName = "Get-SCOMManagementPacks",

        [string]
        $LogFile = "D:\MPs\MPUpdates.log"
    )

    begin
    {}

    process
    {
        switch ($Type)
        {
            1 { $TypeLog = "Info" }
            2 { $TypeLog = "Warning" }
            3 { $TypeLog = "Error" }
            4 { $TypeLog = "Verbose" }
        }

        $LogEntry = "$($TypeLog + ":" + $Message) `$$<$($ModuleName + ":" + $Component)><$(Get-Date -Format "MM-dd-yyyy HH:mm:ss.ffffff")><thread=$pid>" 

        $LogEntry | Out-File -Append -Encoding UTF8 -FilePath "filesystem::$LogFile"
    }

    end
    {}
}

function Get-URIData
{
    [CmdletBinding()]
    param
    (
        [Parameter( Mandatory = $true )]
        [string]
        $URI
    )

    begin
    {}

    process
    {
        $request = [System.Net.httpWebRequest]::Create($URI)
        try
        {
            $response = $request.GetResponse()
            $responseStream = $response.GetResponseStream()
            $responseStreanData = New-Object -TypeName System.IO.StreamReader -ArgumentList $responseStream
            $responseData = $responseStreanData.ReadToEnd()
            $status = "Success"
        }
        catch
        {
            $status = "Error"
            $responseData = $_.Exception.Message
        }

        New-Object -TypeName PSObject -Property @{
            URI = $URI
            PageData = $responseData
            Status = $status
        }
    }

    end
    {}
}

function Get-MSDownloadVersionDetails
{
    [CmdletBinding()]
    param
    (
        [Parameter( Mandatory = $true )]
        [string]
        $URI
    )

    begin {}

    process
    {
        $HTTPData = Get-URIData -URI $URI

        if ($HTTPData.Status -ne "Error")
        {
            $Status = "Success"

            if ($HTTPData -match 'Version:</span></div><p>(.+?)</p></div>')
            {
                $MPVersion = $matches[1].Replace("?","").TrimEnd()
            }

            if ($HTTPData -match 'Date Published:</span></div><p>(.+?)</p></div>')
            {
                $MPPublishDate = $matches[1].Replace("/","-").TrimEnd()
            }

        }
        else
        {
            $MPVersion = ""
            $MPPublishDate = ""
            $Status = "Error: " + $HTTPData.PageData
        }

        New-Object -TypeName PSObject -Property @{
            MSDLVersion = $MPVersion
            MSDLReleaseDate = $MPPublishDate
            Status = $Status
        }
    }

    end
    {}
}

function Get-MSDownloadObjects
{
    [CmdletBinding()]
    param
    (
        [Parameter( Mandatory = $true )]
        [string]
        $URI
    )

    begin
    {}

    process
    {
        $HTTPData = Get-URIData -URI $URI

        if (!($HTTPData.Status -eq "Error"))
        {
            $Status = "Success"

            # Find the Download Links
            $DLURISet = $HTTPData | Select-String -Pattern '{url:"(.+?)"' -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value 

            foreach ($DLURIPath in $DLURISet)
            {
                $DLURIPath = $DLURIPath.Replace('{url:"','').TrimEnd()
                New-Object -TypeName PSObject -Property @{
                    FileURI  = $DLURIPath.Substring(0,$DLURIPath.Length-1)
                    Status   = "Success"
                }
            }
        }
        else
        {
            New-Object -TypeName PSObject -Property @{
                FileURI = ""
                Status = "Error: " + $HTTPData.PageData
            }
        }
    }

    end
    {}
}

function Get-MSDownloadFile
{
    [CmdletBinding()]
    param
    (
        [Parameter( Mandatory = $true )]
        [string]
        $URI,

        [Parameter( Mandatory = $true )]
        [string]
        $Path,

        [Parameter( Mandatory = $false )]
        [bool]
        $DownloadFiles = $true
    )

    process
    {
        $URISegments = $URI.split("/")
        $FileName = $URISegments[($URISegments).Count - 1]
        $FullPath = $Path + "\" + $FileName

        if ((Test-Path -Path $FullPath) -eq $true)
        {
            $status = "File Already Exists"
        }
        else
        {
            if ($DownloadFiles -eq $true)
            {
                $FileName = $FileName.Replace("[","(")
                $FileName = $FileName.Replace("]",")")

                $webClient = Invoke-WebRequest -Uri $URI -OutFile $FullPath -PassThru

                if ($webClient.StatusCode -eq 200)
                {
                    $status = "Download Succeeded"
                }
                else
                {
                    $status = "Download Failed"
                }
            }
            else
            {
                $status = "Download Skipped"
            }
        }

        # Output status
        New-Object -TypeName PSObject -Property @{
            "File URI" = $URI
            "Filename" = $FileName
            "Status" = $status
        }
    }
}
#endregion

#region Validate and Prepare the MPPath and Log File Paths
# Check whether or not the supplied path exists
if ((Test-Path -Path $MPPath) -eq $true)
{
    # Retrieve the FullName of the path to ensure consistent formatting
    [string]$MPPath = $MPPath.TrimEnd('\')
}
else
{
    # If it does not exist, create it
    [string]$MPPath = New-Item -ItemType Directory -Path $MPPath -Force -ErrorAction Stop |
        Select-Object -ExpandProperty FullName
}

# Format the log file names
[string]$MPLogFilePath = $MPPath + "\" + $MPLogFileName
[string]$MPErrorLogFilePath = $MPPath + "\" + $MPErrorLogFileName
#endregion

#region Determine the Max Age of MPs to Process in Days
# Convert both of the input filters to days
if ($PSBoundParameters.ContainsKey('SkipMPsOlderThanDate') -eq $true)
{
    # Filter date supplied, calculate the number of days between the supplied date and today
    [int]$AgeFilter = New-TimeSpan -Start $SkipMPsOlderThanDate -End $StartTime |
        Select-Object -ExpandProperty Days
}
elseif ($PSBoundParameters.ContainsKey('SkipMPsOlderThanMonths') -eq $true)
{
    # Filter months supplied, calculate the number of days between the supplied number of months ago and today
    [int]$AgeFilter = New-TimeSpan -Start ($StartTime.AddMonths(-$SkipMPsOlderThanMonths)) -End $StartTime |
        Select-Object -ExpandProperty Days
}
else
{
    # No filter supplied, calculate the number of days since January 1, 2000 (before SCOM existed)
    [int]$AgeFilter = New-TimeSpan -Start (Get-Date -Date "01-01-2000") -End $StartTime |
        Select-Object -ExpandProperty Days
}
#endregion

#region Retrieve the list of MPs from TechNet
# Pull and format the data from the website
$MPWikiPageData = Invoke-WebRequest -Uri $MPWikiUri
$MPList = $MPWikiPageData.Links |
    Where-Object {($_.href -like "*http*://www.microsoft.com/*download*") -and
        $_.outerText -notlike "*Link to download page*" -and
        $_.outerText -notlike "Microsoft Download Center" -and
        $_.outerText -notlike "Drivers" } |
    Select-Object -Property @{Label="Management Pack";Expression={$_.InnerText}},
        @{Label="Download Link";Expression={$_.href}}

[int]$MPTotalCount = $MPList | Measure-Object | Select-Object -ExpandProperty Count
[int]$MPCounter = 0
#endregion

#region Process Each MP
foreach ($MP in $MPList)
{
    # Increment the counter
    $MPCounter++

    # Get MP link and transpose the confirmation link
    [string]$MPPageLink = $MP.'Download Link'
    [string]$MPConfLink = $MPPageLink -replace "details","confirmation"

    # Get MP name and remove any '/' characters to avoid creating excess directories
    $MPName = $MP.'Management Pack'
    $MPName = $MPName.Replace("/"," ").TrimEnd()

    # Report Progress
    Write-Progress -Activity "SCOM MP: $MPName" -CurrentOperation "Processing $MPCounter of $MPTotalCount" -Id 0 -PercentComplete (($MPCounter/$MPTotalCount)*100)

    # Get the Details from the Download Pages for the MPs
    $MPDetails = Get-MSDownloadVersionDetails -URI $MPPageLink
    if ($MPDetails.Status -eq "Success")
    {
        # Download details were retrived sucessfully
        # Get the list of file resources to retrieve
        $MPDownloadObjects = Get-MSDownloadObjects -URI $MPConfLink

        # Check if we need to process this MP
        $MPVer = $MPDetails.MSDLVersion
        $MPDate = $MPDetails.MSDLReleaseDate

        # Only process the MP if it is not older than the supplied filters
        [int]$MPAgeInDays = New-TimeSpan -Start ([datetime]$MPDate) -End $StartTime | Select-Object -ExpandProperty Days
        if ($MPAgeInDays -le $AgeFilter)
        {
            # Prepare a folder for the MP release, should it not already exist
            if ((Test-Path -Path "$MPPath\$MPName") -eq $false)
            {
                # New Management Pack
                $MPStatus = "New"
                if ($PSBoundParameters.ContainsKey('CMTrace') -eq $true)
                {
                    Write-CMTraceLog -Type 1 -Component $MPName -Message "New Management Pack '$MPName'; Version '$MPVer' Released on '$MPDate'" -LogFile $MPLogFilePath
                }
                else
                {
                    "Success,$CurrentDate,$MPName,$MPVer,$MPDate" | Out-File -FilePath $MPLogFilePath -Append
                }

                # Create the folder for the New Pack and its initial version
                $MPFolder = New-Item -ItemType Directory -Path "$MPPath\$MPName\$MPVer" -Force -ErrorAction Stop

                # Set the DownloadFiles property to true
                $DownloadFiles = $true
            }
            else
            {
                if ((Test-Path -path "$MPPath\$MPName\$MPVer") -eq $false)
                {
                    # Management Pack Version Update
                    $MPStatus = "Updated"
                    if ($PSBoundParameters.ContainsKey('CMTrace') -eq $true)
                    {
                        Write-CMTraceLog -Type 1 -Component $MPName -Message "Updated Management Pack '$MPName'; Version '$MPVer' Released on '$MPDate'" -LogFile $MPLogFilePath
                    }
                    else
                    {
                        "Success,$CurrentDate,$MPName,$MPVer,$MPDate" | Out-File -FilePath $MPLogFilePath -Append
                    }

                    # Create the folder for the New Pack version
                    $MPFolder = New-Item -ItemType Directory -Path "$MPPath\$MPName\$MPVer" -Force -ErrorAction Stop

                    # Set the DownloadFiles property to true
                    $DownloadFiles = $true
                }
                else
                {
                    # Management Pack Version Already Downloaded
                    $MPStatus = "Unchanged"
                    if ($PSBoundParameters.ContainsKey('CMTrace') -eq $true)
                    {
                        Write-CMTraceLog -Type 1 -Component $MPName -Message "Existing Management Pack '$MPName'; Version '$MPVer' Released on '$MPDate'" -LogFile $MPLogFilePath
                    }

                    # Set the DownloadFiles property to the value of ReDownloadMissingFiles
                    $DownloadFiles = $ReDownloadMissingFiles
                }
            }

            # Download and process each of the files in the release
            $DLInfo = @()
            foreach ($DLResource in $MPDownloadObjects)
            {
                # Set DLDetails to Null in order to catch skipped downloads
                $DLDetails = $null
                $DLDetails = Get-MSDownloadFile -URI $DLResource.FileURI -Path "$MPPath\$MPName\$MPVer" -DownloadFiles $DownloadFiles

                # Only continue processing if the file was downloaded
                if ($DLDetails -ne $null)
                {
                    $DLInfo += $DLDetails
                    $DLStatus = $DLDetails.Status
                    $DLFileURI = $DLResource.FileURI

                    if ($CMTrace)
                    {
                        Write-CMTraceLog -Type 4 -Component $MPName -Message "$MPName : Version '$MPVer' Released on '$MPDate'; $DLStatus '$DLFileURI' --> '$MPPath\$MPName\$MPVer'" -LogFile $MPLogFilePath
                    }

                    if ($PSBoundParameters.ContainsKey('Extract') -eq $true)
                    {
                        # If Extract, then extract the files from the .msi
                        $MPFilename = $DLDetails.FileName
                        if ($MPFilename -like "*.msi")
                        {
	                        &cmd /c "msiexec /a `"$MPPath\$MPName\$MPVer\$MPFilename`" /quiet TARGETDIR=`"$MPPath\$MPName\$MPVer\Extracted\`""

                            # The extraction will leave a duplicate .msi file in the Extracted folder. Remove it to reduce file space and duplicate files
                            Get-ChildItem -Path "$MPPath\$MPName\$MPVer\Extracted\" -Filter "*.msi" | Remove-Item | Out-Null

                            if ($PSBoundParameters.ContainsKey('CMTrace') -eq $true)
                            {
                                Write-CMTraceLog -Type 4 -Component $MPName -Message "$MPName : $MPFilename extracted to '$MPPath\$MPName\$MPVer\Extracted'" -LogFile $MPLogFilePath
                            }

                            if ($MPStatus = "Unchanged")
                            {
                                $MPStatus = "Extracted"
                            }
                            else
                            {
                                $MPStatus = $MPStatus + " and Extracted"
                            }
                        }
                    }
                }
            }

            # Output status
            New-Object -TypeName PSObject -Property @{
                "MP Name" = $MPName
                "Version" = $MPDetails.MSDLVersion
                "Published" = $MPDetails.MSDLReleaseDate
                "Resources" = $DLInfo
                "Status" = $MPStatus
			    "Date" = $CurrentDate
            }
        }
    }
    else
    {
        # Output Error Status
        New-Object -TypeName PSObject -Property @{
            "MP Name" = $MPName
            "Version" = $MPDetails.Status
            "Published" = ""
            "Resources" = $MPPageLink
            "Status" = "Failed"
			"Date" = $CurrentDate
        }

        if ($PSBoundParameters.ContainsKey('CMTrace') -eq $true)
        {
            Write-CMTraceLog -Type 3 -Component $MPName -Message "$MPName : $($MPDetails.Status) @ $MPPageLink " -LogFile $MPLogFilePath
        }
        else
        {
            $CurrentDate = Get-Date -format MM-dd-yy
            "Failure,$CurrentDate,$MPName" | Out-File -FilePath "$MPPath\$MPErrorLogFileName" -Append
        }
    }
}
#endregion

#region Wrap-Up
$TimeSpan = New-TimeSpan -Start $StartTime -End (Get-Date)
if ($CMTrace)
{
    Write-CMTraceLog -Type 1 -Component "Script Status" -Message "Process complete; total time was $($TimeSpan)'" -LogFile $MPLogFilePath
}
else
{
    "Success,$CurrentDate,ScriptStatus,Process complete; total time was $($TimeSpan)" | Out-File -FilePath $MPLogFilePath -Append
}

Write-Output -Message "[$(Get-Date)] Script Complete! Process ran for $($TimeSpan)."
#endregion
