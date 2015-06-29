# Get-SCOMManagementPacks
Just last week Daniel Savage published a list on [TechNet Wiki](http://social.technet.microsoft.com/wiki/contents/articles/16174.microsoft-management-packs.aspx) with all management packs for OpsMgr 2007, R2 and 2012. A couple of days later [Stefan Stranger](https://social.technet.microsoft.com/profile/stefan%20stranger/) wrote [Finding Management Packs from Microsoft Download website using PowerShell](http://blogs.technet.com/b/stefan_stranger/archive/2013/03/13/finding-management-packs-from-microsoft-download-website-using-powershell.aspx) and provided a small PowerShell script that provides a list with the management packs from that site and links to them. After reading that post I was wondering wouldn’t be cool if you get the names of all management packs and their links and download all of them with their guides also. And when you download them to be able to organize them in structure that includes the name of the MP and its version. Instead of writing to Stefan I’ve said to myself – What the hell I will try to make that script. I do not have any big experience with PowerShell and it was not easy to built the script but because I’ve managed to create this proves that PowerShell is easy to learn but you have to be persistent. During the creation of the script I’ve noticed that some of the links on the page were incorrect so I’ve corrected them. **The script requires PowerShell v3**.

In short the script grabs the names and the links for all management packs on the site. Than it goes trough every MP link. From every MP page gets the version of it and all download links (msi, guides and etc.). Than creates a directory for that MP and subdirectory with the version number and downloads all files in it.

##Update 1:

Not so long ago I’ve wrote a [script that can download all SCOM Management Packs](https://cloudadministrator.wordpress.com/2013/03/16/download-all-microsoft-management-packs-for-scom-2007-r2-and-2012-in-bulk-with-powershell/) released by Microsoft. Unfortunately Microsoft has decided to change the interface of their download pages and didn’t asked me for approval Smile. Because of that the script stopped to work as it was dependent on the layout of the download web pages. I’ve decided to give it a try to fix the script. Looked at the layout of the new download page. Change a bit the logic and some lines and viola the script is working again.

 

##Update 2:

Little improvements were made to this script. All of them were contributed by [AnthonyBailey](https://gallery.technet.microsoft.com/site/profile?userName=AnthonyBaileyCDW):

* The script now checks if the folder for the version already exists and if only there is not such folder than downloads the MP;
* When MP is downloaded successfully it is written in a log file; 

With these improvements you can run the script with schedule task and configure SCOM to monitor the log that way you can get alerted when new MP is available. All thanks to [AnthonyBailey](https://gallery.technet.microsoft.com/site/profile?userName=AnthonyBaileyCDW).

##Update 3:

* Microsoft has made some changes to the code of the download pages again so the script was not able to get the version of the MP. Made changes to work with the new code.
* The script now checks if MP web pages is invoked successfully  
* If MP Page is not invoked successfully error appears. Error is also written in a Error Log.
* Improvements on check if MP is already downloaded 
* MP download links are displayed on separate lines
* Changes section was made more readable format 

##Update 4:

* Improvements on getting the confirmation link for each MP.
* The script now also grabs the date the MP was added to Microsoft's catalog and adds this to the logs/screen output 
* Any duplicate download links are removed before downloading as some download pages have duplicate files in the html 
* Improvements on check if MP is already downloaded  

##Update: 5:

* Removed -and ($_.InnerHTML -like "*This link*") as some people experienced errors 

##Update 6:

* For some people v2.3 is working fine and v.2.4 not and vise versa. Beacuse of that I've attached v2.3 as download and v2.4 you can copy directly from below. That way you have both version available in the Gallery. 

##Update 7:

* Using invoke-webrequest was causing cookie prompt dialog to appear due to changes on Microsoft download pages. Replaced it with .net framework function. Thanks to my co-worker Georgi Ivanov for helping me in this.
* Replaced Write-Host with Write-Output. Accodring to Jeffrey Snover and Don Jones a puppy dies every time someone is using Write-Host :)  
* Added additional logic to check every file if exists not only the version folder 
* MP version, Published date and download links are now being get by different way as invoke-webrequest is not used 

##Update 8:

* [Damian Flynn](http://www.damianflynn.com/) is now author of teh script also
* Refactored the script to a powershell module, and split the code into functions to ease support and prepare for some automation ;) 
* added Write-CMTraceLog - to enabled it execute   Get-SCOMManagementPacks -CMTrace
* removed two download links that are incorrectly gathered at the beginning 

##Update 9:

* Added Date to the Output object as requested
* Changed the behavious for the Write-CMTrace function to actually use the supplied log path, and not just the default (Sorry that was a bug)
* Added a switch to flag that MSI files should be extracted, based on a script from Cameron Fuller. Just add -Extract and enjoy. 