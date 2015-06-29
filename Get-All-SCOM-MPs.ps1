############################################################################################################################################################################# 
# Version 1.0:                                                                                                                                                              # 
# Get list of all Management packs and their links from Technet Wiki                                                                                                        # 
# Thanks to Stefan Stranger http://blogs.technet.com/b/stefan_stranger/archive/2013/03/13/finding-management-packs-from-microsoft-download-website-using-powershell.aspx    # 
############################################################################################################################################################################# 
 
############################################################################################################################################################################# 
# Version 2.0 Changes:                                                                                                                                                      # 
# - Microsoft change the layout of the MP download pages so the script was changed to get data from the new layout                                                          # 
############################################################################################################################################################################# 
 
############################################################################################################################################################################# 
# Version 2.1 Changes:                                                                                                                                                      # 
# modifications contributed by Anthony Bailey:                                                                                                                              # 
# - checks if MP is already downloaded                                                                                                                                      # 
# - writes a success log in a file                                                                                                                                          # 
# - you can set the script to run as a scheduled task and SCOM can monitor the log file and alert you if new MP version is downloaded.                                      # 
############################################################################################################################################################################# 
 
############################################################################################################################################################################# 
# Version 2.2 Changes:                                                                                                                                                      # 
# - Microsoft has made some changes to the code of the download pages again so the script was not able to get the version of the MP. Made changes to work with the new code # 
# - The script now checks if MP web pages is invoked successfully                                                                                                           # 
# - If MP Page is not invoked successfully error appears. Error is also written in a Error Log.                                                                             # 
# - Improvements on check if MP is already downloaded                                                                                                                       # 
# - MP download links are displayed on separate lines                                                                                                                       # 
# - Changes section was made more readable format                                                                                                                           # 
############################################################################################################################################################################# 
 
############################################################################################################################################################################# 
# Version 2.3 Changes:                                                                                                                                                      # 
# modifications contributed by Anthony Bailey:                                                                                                                              # 
# - Improvements on getting the confirmation link for each MP.                                                                                                              # 
# - The script now also grabs the date the MP was added to Microsoft's catalog and adds this to the logs/screen output                                                      # 
# - Any duplicate download links are removed before downloading as some download pages have duplicate files in the html                                                     # 
# - Improvements on check if MP is already downloaded                                                                                                                       # 
############################################################################################################################################################################# 
############################################################################################################################################################################# 
# Version 2.4 Changes:                                                                                                                                                      # 
# - Removed -and ($_.InnerHTML -like "*This link*") as some people experienced errors                                                                                       # 
############################################################################################################################################################################# 
############################################################################################################################################################################# 
# Version 2.5 Changes:                                                                                                                                                      # 
# - Using invoke-webrequest was causing cookie prompt dialog to appear due to changes on Microsoft download pages. Replaced it with .net framework function. Thanks to my   #  
#   co-worker Georgi Ivanov for helping me in this                                                                                                                          # 
# - Replaced Write-Host with Write-Output. Accodring to Jeffrey Snover and Don Jones a puppy dies every time someone is using Write-Host :)                                 # 
# - Added additional logic to check every file if exists not only the version folder                                                                                        # 
# - MP version, Published date and download links are now being get by different way as invoke-webrequest is not used                                                       # 
############################################################################################################################################################################# 
 
############################################################################################################################################################################# 
# Version 3.0 Changes:                                                                                                                                                      # 
# - Edits: @Damain_Flynn                                                                                                                                                    # 
# - Date: 24 Aug 2014                                                                                                                                                       # 
# - Refactored the script to a powershell module, and split the code into functions to ease support and prepare for some automation ;)                                      # 
# - added Write-CMTraceLog - to enabled it execute   Get-SCOMManagementPacks -CMTrace                                                                                       # 
# - removed two download links that are incorrectly gathered at the beginning                                                                                               # 
############################################################################################################################################################################# 
 
 ############################################################################################################################################################################# 
# Version 3.0.1 Changes:                                                                                                                                                    # 
# - Date: 28 Aug 2014 - Added Date to the Output object as requested                                                                                                        # 
# - Date: 28 Aug 2014 - Changed the behavious for the Write-CMTrace function to actually use the supplied log path, and not just the default (Sorry that was a bug)         # 
# - Date: 28 Aug 2014 - Added a switch to flag that MSI files should be extracted, based on a script from Cameron Fuller. Just add -Extract and enjoy.                      # 
############################################################################################################################################################################# 

function Write-CMTraceLog 
{ 
    param ( 
        [Parameter(Mandatory=$true)] 
        $Type, 
        [Parameter(Mandatory=$true)] 
        $Component, 
        [Parameter(Mandatory=$true)] 
        $Message, 
        [Parameter(Mandatory=$false)] 
        $ModuleName = "Get-SCOMManagementPacks", 
        [Parameter(Mandatory=$false)] 
        $LogFile = "D:\MPs\MPUpdates.log" 
    ) 
 
    switch ($Type) 
    { 
        1 { $Type = "Info" } 
        2 { $Type = "Warning" } 
        3 { $Type = "Error" } 
        4 { $Type = "Verbose" } 
    } 
 
    $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($Type + ":" + $Message), ($ModuleName + ":" + $Component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid 
 
    $toLog | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $LogFile) 
}  
 
 
function Get-URIData{ 
     
    param ( 
        [Parameter(Mandatory=$true)] 
        $URI 
    ) 
 
    process 
    { 
        $request = [System.Net.httpWebRequest]::Create($URI) 
        try { 
            $response = $request.GetResponse() 
 
            $responseStream = $response.GetResponseStream() 
            $responseStreanData = New-Object -TypeName System.IO.StreamReader -ArgumentList $responseStream 
            $responseData = $responseStreanData.ReadToEnd() 
            $status = "Success" 
        } 
        catch [System.Exception] { 
            $status       = "Error" 
            $responseData = $_.Exception.Message 
        } 
     
        New-Object PSObject -Property @{  
            URI      = $URI 
            PageData = $responseData 
            Status   = $status 
        } 
    }  
} 
 
 
 
function Get-MSDownloadVersionDetails{ 
    param ( 
        [Parameter(Mandatory=$true)] 
        $URI 
    ) 
 
    process 
    { 
        $HTTPData = Get-URIData -URI $URI 
         
        if (!($HTTPData.Status -eq "Error")) 
        {    
            $Status = "Success" 
                     
            if ($HTTPData -match 'Version:</span></div><p>(.+?)</p></div>') 
            { 
                $MPVersion=$matches[1].Replace("?","").Trimend() 
            } 
 
 
            if ($HTTPData -match 'Date Published:</span></div><p>(.+?)</p></div>') 
            { 
                $MPPublishDate=$matches[1].Replace("/","-").Trimend() 
            } 
 
        } else { 
            $MPVersion = "" 
            $MPPublishDate = "" 
            $Status = "Error: " + $HTTPData.PageData 
        } 
 
        New-Object PSObject -Property @{  
            MSDLVersion     = $MPVersion 
            MSDLReleaseDate = $MPPublishDate 
            Status          = $Status 
        }              
 
    } 
} 
             
   
           
function Get-MSDownloadObjects{ 
    param ( 
        [Parameter(Mandatory=$true)] 
        $URI 
    ) 
 
    process 
    { 
        $HTTPData = Get-URIData -URI $URI 
         
        if (!($HTTPData.Status -eq "Error")) 
        {    
            $Status = "Success" 
            #Find the Download Links 
         
            $DLURISet = $HTTPData | Select-String -AllMatches '{url:"(.+?)"' | select -ExpandProperty Matches | select -ExpandProperty Value 
         
            foreach($DLURIPath in $DLURISet) 
            { 
                $DLURIPath = $DLURIPath.Replace('{url:"','').trimend() 
                New-Object PSObject -Property @{  
                    FileURI  = $DLURIPath.Substring(0,$DLURIPath.Length-1) 
                    Status   = "Success" 
                } 
            } 
        } else { 
            New-Object PSObject -Property @{  
                FileURI = "" 
                Status  = "Error: " + $HTTPData.PageData 
            }              
        } 
 
    } 
} 
 
 
function Get-MSDownloadFile{ 
    param ( 
        [Parameter(Mandatory=$true)] 
        $URI, 
        [Parameter(Mandatory=$true)] 
        $Path 
    ) 
     
    process 
    { 
        $URISegments = $URI.split("/") 
        $FileName = $URISegments[($URISegments).Count - 1] 
 
        if (Test-Path -path "$Path\$Filename") { 
            $status = "File Already Exists" 
        } else { 
            $FileName=$FileName.Replace("[","(") 
            $FileName=$FileName.Replace("]",")") 
 
            $webClient = Invoke-WebRequest -Uri $URI -OutFile $Path\$FileName -PassThru 
 
            if($webClient.StatusCode -eq 200) { 
                $status = "File Downloaded" 
            } else { 
                $status = "Download Failed" 
            } 
        } 
         
        # Report status 
        New-Object PSObject -Property @{  
            "File URI" = $URI 
            "Filename" = $FileName 
            "Status" = $status 
        }  
    } 
 
} 
 
 
 
function Get-SCOMManagementPacks{ 
<#
.Synopsis
   Get-SCOMManagementPacks is a PowerShell function to enumerate and download all currently available MPs from Microsoft Download servers.
.DESCRIPTION
   Get-SCOMManagementPacks is a PowerShell function which connected to the Microsoft SCOM Wiki Page on Technet, to determine the list of currently
   available managmenent packs. This list is then parsed and downloaded to your local system using a structured folder layout, based on the name
   and version of the management pack. 
   Optionally, the download packaged will also be extracted into a subfolder of the current version.
   This function provides feedback on progress, and supplies an object based output which you can feed to other commands to determine what occured during processing
   The only pre-requesite for this script is internet access, and permission to save files on the destination

   Status options include Unchanged, New, Updated, Extracted, New and Extracted, Updated and Extracted
.EXAMPLE
   Get-SCOMManagementPacks -Extract

   Download and extract the management packs which are not currently on our system, ready for use with SCOM and SCCM
.EXAMPLE
   Get-SCOMManagementPacks -CMTrace

   Output all logging information from the funcation in CMTrace friendly format
.EXAMPLE
    Get-SCOMManagementPacks -MPPath C:\MPs\Microsoft -CMTrace -Extract | ? {$_.status -notlike "Unchanged"} | sort status 

    Download, Extract and Log, reporting on all Management Packs which have changed since the previsous execution
.NOTES
   For more information, see the related blog post at www.cloudadministrator.com and www.damianflynn.com
.FUNCTIONALITY
   Provides an automated delivery mechanism to maintain a local repository of current Managment Packs issued by Microsoft.
#>
    param ( 
        [Parameter(Mandatory=$false)] 
        $MPPath = "C:\MPs\", 
        [Parameter(Mandatory=$false)] 
        $MPLogfile = "MPUpdates.log", 
        [Parameter(Mandatory=$false)] 
        $MPErrorLogfile = "MPErrorLog.log", 
        [Switch]$CMTrace,
        [Switch]$Extract 
    ) 
 
    begin 
    { 
        if(!(Test-Path -path "$MPPath")) 
        { 
            New-Item -ItemType directory -Path $MPPath -force | Out-Null  
        } 
             
    } 
    process 
    { 
 
        $allmpspage = Invoke-WebRequest -Uri "http://social.technet.microsoft.com/wiki/contents/articles/16174.microsoft-management-packs.aspx" 
        $mpslist = $allmpspage.Links | Where-Object {($_.href -like "*http://www.microsoft.com/*download*") -and $_.outerText -notlike "*Link to download page*" -and $_.outerText -notlike "Microsoft Download Center" -and $_.outerText -notlike "Drivers" } |  
        Select @{Label="Management Pack";Expression={$_.InnerText}}, @{Label="Download Link";Expression={$_.href}} 
 
        $mpTotal = ($mpslist).count 
        $mpCurrent = 0 
        $Date = Get-Date -format MM-dd-yy 
     
        #go though every MP 
        foreach ($mp in $mpslist) 
        { 
             
            #get MP link and transpose the confirmation link 
            $mppagelink = $mp.'Download Link' 
            $mpconflink = $mppagelink -replace "details","confirmation" 
 
            #get MP name and Remove '/' character from MP name if contains it beacuse can create unneeded directories 
            $mpname = $mp.'Management Pack' 
            $mpname = $mpname.Replace("/"," ").Trimend() 
 
            # Report Progress 
            $mpCurrent ++ 
            Write-Progress "SCOM MP: $mpname" "Processing $mpCurrent of $mpTotal" -id 0 -percentComplete (($mpCurrent/$mpTotal)*100) 
 
            # Get the Details from the Download Pages for the MPs 
            $MPDetails = Get-MSDownloadVersionDetails -URI $mppagelink 
            if ($MPDetails.Status -eq "Success") 
            { 
                # Download details were retrived sucessfully 
                # Get the list of file resources to retrieve 
                $MPDownloadObjects = Get-MSDownloadObjects -URI $mpconflink 
 
 
                # Check if we need to process this MP 
                $MPVer = $MPDetails.MSDLVersion 
                $MPDate = $MPDetails.MSDLReleaseDate 
 
                if(!(Test-Path -Path "$MPPath\$mpname")) 
                { 
                    # New Management Pack 
                    $status = "New" 
                    if ($CMTrace) { 
                        Write-CMTraceLog -Type 1 -Component $mpname -Message "New Management Pack '$mpname'; Version '$MPVer' Released on '$MPDate'" -LogFile "$MPPath\$MPLogFile"
                    } else { 
                        $Date = Get-Date -format MM-dd-yy 
                        "Success,$Date,$mpname,$MPVer,$MPDate" |Out-File "$MPPath\$MPLogfile" -Append 
                    } 
 
                    # Create the folder for the New Pack and its initial version 
                    New-Item -ItemType directory -Path $MPPath\$mpname\$MPVer -force | Out-Null 
                } else { 
                    if(!(Test-Path -path "$MPPath\$mpname\$MPVer")) 
                    { 
                        # Management Pack Version Update 
                        $status = "Updated" 
                        if ($CMTrace) { 
                            Write-CMTraceLog -Type 1 -Component $mpname -Message "Updated Management Pack '$mpname'; Version '$MPVer' Released on '$MPDate'" -LogFile "$MPPath\$MPLogFile"
                        } else { 
                            $Date = Get-Date -format MM-dd-yy 
                            "Success,$Date,$mpname,$MPVer,$MPDate" |Out-File "$MPPath\$MPLogfile" -Append 
                        } 
 
                        # Create the folder for the New Pack version 
                        New-Item -ItemType directory -Path $MPPath\$mpname\$MPVer -force | Out-Null 
                    } else { 
                        # Management Pack Version Update 
                        $status = "Unchanged" 
                        if ($CMTrace) { 
                            Write-CMTraceLog -Type 1 -Component $mpname -Message "Existing Management Pack '$mpname'; Version '$MPVer' Released on '$MPDate'" -LogFile "$MPPath\$MPLogFile"
                        } 
                    } 
                } 
 
 
                # Regardless of the status, check see if we need to re-download a file for this Management Pack 
                $DLInfo=@() 
                foreach ($DLResource in $MPDownloadObjects) 
                { 
                    $DLDetails = Get-MSDownloadFile -URI $DLResource.FileURI -Path $MPPath\$mpname\$MPVer 
                    $DLInfo += $DLDetails 
                    $DLStatus = $DLDetails.Status 
                    $DLFileURI = $DLResource.FileURI 
 
                    if ($CMTrace) { 
                        Write-CMTraceLog -Type 4 -Component $mpname -Message "$mpname : Version '$MPVer' Released on '$MPDate'; $DLStatus '$DLFileURI' --> '$MPPath\$mpname\$MPVer'" -LogFile "$MPPath\$MPLogFile"
                    }
                    
                    if ($Extract) {
                        $MPFilename = $DLDetails.FileName
                        if ($MPFilename -like "*.msi") {
	                        &cmd /c "msiexec /a `"$MPPath\$mpname\$MPVer\$MPFilename`" /quiet TARGETDIR=`"$MPPath\$mpname\$MPVer\Extracted\`"" 

                            if ($CMTrace) { 
                                Write-CMTraceLog -Type 4 -Component $mpname -Message "$mpname : $MPFilename extracted to '$MPPath\$mpname\$MPVer\Extracted'" -LogFile "$MPPath\$MPLogFile"
                            }

                            if ($status = "Unchanged") {
                                $status = "Extracted"
                            } else {
                                $status = $status + " and Extracted"
                            }
                        }
                    } 
                } 
 
 
                # Report status 
                New-Object PSObject -Property @{  
                    "MP Name"   = $mpname 
                    "Version"   = $MPDetails.MSDLVersion 
                    "Published" = $MPDetails.MSDLReleaseDate 
                    "Resources" = $DLInfo 
                    "Status"    = $status
					"Date"      = Get-Date
                } 
                 
            } else { 
 
                #Report Error Status 
                New-Object PSObject -Property @{  
                    "MP Name"   = $mpname 
                    "Version"   = $MPDetails.Status 
                    "Published" = "" 
                    "Resources" = $mppagelink 
                    "Status"    = "Failed" 
					"Date"      = Get-Date
                } 
 
                $DLStatus = $MPDetails.Status 
                if ($CMTrace) { 
                    Write-CMTraceLog -Type 3 -Component $mpname -Message "$mpname : $DLStatus @ $mppagelink " -LogFile "$MPPath\$MPLogFile"
                } else { 
                    $Date = Get-Date -format MM-dd-yy 
                    "Failure,$Date,$mpname" |Out-File "$MPPath\$MPErrorLogfile" -Append 
                } 
            } 
        } 
    }  
} 
 
 
# Make it happen 
Get-SCOMManagementPacks -MPPath C:\MPs\Microsoft -CMTrace | ? {$_.status -notlike "Unchanged"} | sort status 