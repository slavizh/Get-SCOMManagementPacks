# Get-SCOMManagementPacks
This is an updated version of the script started by Stanislav Zhelyazkov which is used to process and download all official SCOM management packs based on their presence on the Microsoft SCOM Management Pack Wiki.

I've made a number of changes to the script to make it easier to use, easier to read, and include additional functionality. I'm releasing this as version 4.0 here and will submit a pull request to Stanislav to have the changes merged into his primary repo.

The changes I've made in version 4.0 follow:
* Standardized PowerShell formatting to improve readability and consistency
* Moved the Help and version history into a comment block accessible via PowerShell's Get-Help cmdlet
* Expanded the Help to include parameter descriptions and more examples
* Refactored the script to be ran via the command line, thus removing any need to import it as a module or edit the script internals
* Applied numerous PowerShell best practices
* Renamed script file from "Get-All-SCOM-MPs.ps1" to "Get-SCOMManagementPacks.ps1" to align with the name of the Git repository
* Reduced the number of Get-Date calls in the Write-CMTraceLog function
* Updated the script and functions to support -Verbose
* Updated the "Extract" method to remove duplicate .msi files created by the .msi extraction
* Updated the script to make the re-download of deleted files optional
* Added the "SkipMPsOlderThanDate" and "SkipMPsOlderThanMonths" properties and logic to not process management packs older than the supplied date or age in months
* Updated the script to calculate the length of time it took to process and output that to the shell as well as save it to the log.

##Description:

Get-SCOMManagementPacks is a PowerShell script which is used to dynamically enumerate and download currently available SCOM management packs to a specified folder, organizing them by name and version.

The script connects to the Microsoft SCOM Management Pack Wiki Page on Technet to determine the list of currently available management packs, their release date, and their download links, which it parses and uses to download the management packs.

Optional controls exist which enable the extraction of the downloaded .msi files, the re-download of files which have been deleted or gone missing from the latest versions of the management packs, and the ability to skip management packs releases which are older than a specified age.

This script provides progress output to the shell, logging, and an object-based output which can be fed to other commands to automate remediation.

The only prerequisite for this script is internet access and permissions to save the files at the specified destination.

Status outputs include  "New", "Unchanged", "Updated", "Extracted", "New and Extracted", and "Updated and Extracted"

##Parameters:

MPPath - Optional, default value: "C:\MPs". Specifies the path to the folder where management packs should be downloaded.

MPLogFileName - Optional, default value: "MPUpdates.log". Specifies the name of the log file containing information about downloaded management packs. If the supplied value does not end in ".log", the file extension will be appended.

MPErrorLogFileName - Optional, default value: "MPErrorLog.log". Specifies the name of the log file containing information about errors encountered during processing. If the supplied value does not end in ".log", the file extension will be appended.

ReDownloadMissingFiles - Optional, boolean property, default value = "false". If "true", when processing management packs determined to have been downloaded previously, any files missing from the version folder for the management pack will be redownloaded. Otherwise, the script assumes files were deleted intentionally and does not re-download missing files. Note that, as the script only processes the latest version of a management pack, this only applies to the latest version - older versions will not be downloaded or assessed for missing files.

SkipMPsOlderThanDate - Optional, datetime property, no default value. Use to supply a specific date as a filter for processing; any management packs released prior to the supplied date will not be processed. The parameter accepts a datetime object which can be retrieved via the "Get-Date" cmdlet or generated on the spot by entering the date in numeric fashion (e.g., "01-20-2010", "01/20/2010", etc.).

SkipMPsOlderThanMonths - Optional, integer property, no default value. Use to supply a specific number of months as a filter for processing; any management packs released prior to the supplied number of months before the current date will not be processed.

CMTrace - Optional, switch parameter. Enables logging in the CMTrace format for easy use in the CMTrace application.

Extract - Optional, switch parameter. Enables the automatic extraction of any management packs processed by the script.

##Examples:
This example specifies a target location on a network share as a destination for the management packs to be downloaded.

>Get-SCOMManagementPacks.ps1 -MPPath "\\SCOMShare\ManagementPacks"

This example changes the default names of the log files and allows the management packs to be saved to the default location. As the file extension is not specified for one of the logs, the ".log" extension will be appended automatically.

>Get-SCOMManagementPacks.ps1 -MPLogFileName "MPUpdatesLog" -MPErrorLogFileName "MPUpdateErrors"

This example downloads and extracts the management packs to the default location.

>Get-SCOMManagementPacks.ps1 -Extract

This example specifies the location for management packs to be downloaded, enables the re-download of missing files, and extracts any MSI files contained in the management packs.

>Get-SCOMManagementPacks.ps1 -MPPath "E:\ManagementPacks" -ReDownloadMissingFiles $true -Extract

This example outputs all logging information from the script into a CMTrace friendly format.

>Get-SCOMManagementPacks -CMTrace

This example downloads the management packs to a specified location, extracts them, and logs output in a CMTrace friendly format, then filters and sorts the script's output for easy consumption.

>Get-SCOMManagementPacks -MPPath "C:\MPs\Microsoft" -CMTrace -Extract | ?{$_.Status -notlike "Unchanged"} | Sort Status

This example passes a specific date into the script to prevent processing of any management packs released before that date.

>Get-SCOMManagementPacks -SkipMPsOlderThanDate "11/21/2013"

This example passes a number of months into the script to prevent processing of any management packs released prior to that many months before the current date.

>Get-SCOMManagementPacks -SkipMPsOlderThanMonths 24

## Other Information and Version History
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

Current Version: 4.0
Version History:
- Version 1.0:
    - Initial version, gets list of all Management Packs and their links from the TechNet Wiki

- Version 2.0 Changes:
    - Microsoft changed the layout of the MP download pages, so the script was updated to get data from the new layout

- Version 2.1 Changes (Modifications contributed by Anthony Bailey):
    - Script now checks if MP is already downloaded
    - Script now writes successful updates to a log file
        - If the script is set to run as a scheduled task or via other automation, the log file can be monitored to trigger alerts if a new MP version is downloaded.

- Version 2.2 Changes:
    - Microsoft updated the code of the download pages again which broke the script. The script was updated to work with the new website code
    - The script now checks whether or not the Management Pack web pages are invoked successfully
        - If MP Page is not invoked successfully an error will be written to the output and to an Error Log.
    - The method of validation for whether or not an MP has already been downloaded has been improved
    - Script output updated for readability:
        - Management Pack download links are now displayed on separate lines in the output
        - Changes section formatting is now in a more readable format

- Version 2.3 Changes (Modifications contributed by Anthony Bailey):
    - The method of retrieving the confirmation link for each MP has been improved
    - The script now also captures the date the MP was added to Microsoft's catalog and adds this to the logs/screen output
    - Any duplicate download links are removed before downloading (introduced as some download pages have duplicate files in the html)
    - The method of validation for whether or not an MP has already been downloaded has been improved further

- Version 2.4 Changes:
    - Removed -and ($_.InnerHTML -like "*This link*") as some users experienced errors

- Version 2.5 Changes:
    - Microsoft updated their download pages in a way that now caused Invoke-WebRequest to trigger a cookie prompt dialog. Replaced usage of Invoke-WebRequest with a function leveraging .NET Framework objects to bypass the prompt. Credit to Georgi Ivanov for assistance in this change.
    - Implemented new method of retrieving MP version, Published date and download links as part of the removal of Invoke-WebRequest
    - Replaced Write-Host with Write-Output to conform to PowerShell best practices
    - Added additional logic to the method of validation for whether or not an MP has already been downloaded which checks the existence of each file in the MP release rather than just the version folder. Any files which do not exist will be re-downloaded.

- Version 3.0 Changes:
    - Edits: @Damain_Flynn
    - Date: 24 Aug 2014
    - Refactored the script to a PowerShell module and split the code into functions to ease support and enable automation
    - Added Write-CMTraceLog function and support for CMTrace logging
    - Removed two download links that were being incorrectly gathered at the beginning

- Version 3.0.1 Changes:
    - Date: 28 Aug 2014
    - Added Date to the Output object as requested
    - Changed the behaviour for the Write-CMTrace function to use the supplied log path, and not just the default (Sorry that was a bug)
    - Added a switch to flag that MSI files should be extracted, based on a script from Cameron Fuller. Just add -Extract and enjoy.

- Version 4.0 Changes
    - Edits: Gabriel Taylor
    - Date: 16 March 2016
    - Standardized PowerShell formatting to improve readability and consistency
    - Moved the Help and version history into a comment block accessible via PowerShell's Get-Help cmdlet
    - Expanded the Help to include parameter descriptions and more examples
    - Refactored the script to be ran via the command line, thus removing any need to import it as a module or edit the script internals
    - Applied numerous PowerShell best practices
    - Renamed script file from "Get-All-SCOM-MPs.ps1" to "Get-SCOMManagementPacks.ps1" to align with the name of the Git repository
    - Reduced the number of Get-Date calls in the Write-CMTraceLog function
    - Updated the script and functions to support -Verbose
    - Updated the "Extract" method to remove duplicate .msi files created by the .msi extraction
    - Updated the script to make the re-download of deleted files optional
    - Added the "SkipMPsOlderThanDate" and "SkipMPsOlderThanMonths" properties and logic to not process management packs older than the supplied date or age in months
    - Updated the script to calculate the length of time it took to process and output that to the shell as well as save it to the log.
