<##################################################################################################

    Description
    ===========

    - This script does the following: 
        - installs chocolatey.
        - installs webpi (webpicmd) via chocolatey.
        - installs specified webpi products.

    - The following logs are generated on the machine - 
        - Chocolatey's log : %ALLUSERSPROFILE%\chocolatey\logs folder.
        - This script's log : $PSScriptRoot\InstallViaWebPICmd-{TimeStamp}\Logs folder.


    Usage examples
    ==============

    - Powershell -executionpolicy bypass -file InstallViaWebPICmd.ps1 -ProductId "your product ID"
    

    Pre-Requisites
    ==============

    - Please ensure that this script is run elevated.
    - Please ensure that the powershell execution policy is set to unrestricted or bypass.


    Known issues / Caveats
    ======================
    
    - No known issues.


    Coming soon / planned future work
    =================================

    - None

##################################################################################################>

#
# Arguments to this script file.
#

# The Id of the product to be installed from the WebPI catalog.
# More details: http://www.iis.net/learn/install/web-platform-installer/web-platform-installer-v4-command-line-webpicmdexe-rtw-release
$ProductId = $args[0]

# The location where this script resides. 
# Note: We cannot use $PSScriptRoot or $MyInvocation inside a script block. Hence passing 
# the location explicitly.
$ScriptRoot = $args[1]

##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "stop"

###################################################################################################

#
# Custom Configurations
#

# Language of installers that'll be used (english is default). 
# Note: You can run 'webpicmd /list /listoption:languages' to see list of supported languages. 
$Language = "en"

# Location of the log files
$InstallViaWebPICmdFolder = Join-Path $ScriptRoot -ChildPath $("InstallViaWebPICmd-" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))
$ScriptLog = Join-Path -Path $InstallViaWebPICmdFolder -ChildPath "InstallViaWebPICmd.log"
$ChocolateyInstallLog = Join-Path -Path $InstallViaWebPICmdFolder -ChildPath "ChocolateyInstall.log"

##################################################################################################

# 
# Description:
#  - Displays the script argument values (default or user-supplied).
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - Please ensure that the InitializeFolders() method has been called at least once before 
#    this method. Else this method can only write to console and not to log files. 
#

function DisplayArgValues
{
    WriteLog "========== Configuration =========="
    WriteLog $("ProductId : " + $ProductId)
    WriteLog $("ScriptRoot : " + $ScriptRoot)
    WriteLog "========== Configuration =========="
}

##################################################################################################

# 
# Description:
#  - Creates the folder structure which'll be used for dumping logs generated by this script and
#    the logon task.
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function InitializeFolders
{
    if ($false -eq (Test-Path -Path $InstallViaWebPICmdFolder))
    {
        New-Item -Path $InstallViaWebPICmdFolder -ItemType directory | Out-Null
    }
}

##################################################################################################

# 
# Description:
#  - Writes specified string to the console as well as to the script log (indicated by $ScriptLog).
#
# Parameters:
#  - $message: The string to write.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function WriteLog
{
    Param(
        <# Can be null or empty #> $message
    )

    $timestampedMessage = $("[" + [System.DateTime]::Now + "] " + $message) | % {  
        Out-File -InputObject $_ -FilePath $ScriptLog -Append
    }
}

##################################################################################################

# 
# Description:
#  - Installs the chocolatey package manager.
#
# Parameters:
#  - N/A.
#
# Return:
#  - If installation is successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - @TODO: Write to $chocolateyInstallLog log file.
#  - @TODO: Currently no errors are being written to the log file ($chocolateyInstallLog). This needs to be fixed.
#

function InstallChocolatey
{
    Param(
        [ValidateNotNullOrEmpty()] $chocolateyInstallLog
    )

    WriteLog "Installing Chocolatey..."

    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null

    WriteLog "Success."
}

##################################################################################################

#
# Description:
#  - Installs WebPICmd via chocolatey package manager.
#
# Parameters:
#  - N/A.
#
# Return:
#  - If installation is successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - N/A.
#

function InstallWebPICmd
{
    $package = "webpicmd"

    WriteLog $("Installing chocolatey package: " + $package)

    # install git via chocolatey
    choco install $package --force --yes --acceptlicense --verbose | Out-Null 

    if ($? -eq $false)
    {
        $errMsg = $("Error! Installation failed. Please see the chocolatey logs in %ALLUSERSPROFILE%\chocolatey\logs folder for details.")
        WriteLog $errMsg
        Write-Error $errMsg 
    }
    
    WriteLog "Success."
}

##################################################################################################

#
# Description:
#  - Installs the specified prodcut via WebPICmd.
#
# Parameters:
#  - $productId: A semi-colon or comma separated list of products to be installed via WebPI.
#  - $language: Language of installers that'll be used.
#
# Return:
#  - If installation is successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - @TODO: If a non-existent package is specified, WebPICmd still returns exit code 0 even though
#    nothing is installed. 
#

function InstallProducts
{
    Param(
        [ValidateNotNullOrEmpty()][string] $productId,
        [ValidateNotNullOrEmpty()][string] $language
    )

    WriteLog $("Installing product: " + $productId)
        
    # Prep to running WebPICmd
    $args = $("/Install /Products:`"" + $productId + "`" /AcceptEula /SuppressReboot /SuppressPostFinish /Language:" + $language)

    WriteLog $("WebPICmd " + $args)

    # Run WebPICmd
    $p = Start-Process -FilePath "WebPICmd" -ArgumentList $args -PassThru -Wait

    # check the exit code
    if (($p.ExitCode -ne 0) -and ($p.ExitCode -ne 3010))
    {
        $errMsg = $("Error! Installation failed with exit code " + $p.ExitCode + ". Please see the WebPI logs in the '%LOCALAPPDATA%\Microsoft\Web Platform Installer\logs' folder for details.")
        WriteLog $errMsg
        Write-Error $errMsg 
    }
    
    WriteLog $("Success. WebPICmd exited with " + $p.ExitCode + ".")
}

##################################################################################################

#
# 
#

try
{
    #
    InitializeFolders

    #
    DisplayArgValues
    
    # install the chocolatey package manager
    InstallChocolatey -chocolateyInstallLog $ChocolateyInstallLog

    # install WebPICmd via chocolatey.
    InstallWebPICmd

    # install the specified products via WebPICmd.
    InstallProducts -productId $ProductId -language $Language

    # all done. Let's return will exit code 0.
    return 0
}
catch
{
    if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
    {
        $errMsg = $Error[0].Exception.Message
        WriteLog $errMsg
        Write-Host $errMsg
    }

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The common recommendation is to use a try/catch block and return a 
    # non-zero exit code from the catch block. 
    exit -1
}