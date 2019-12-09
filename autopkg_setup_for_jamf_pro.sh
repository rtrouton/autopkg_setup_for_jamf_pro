#!/bin/bash

# This script is designed to set up a Mac running macOS 10.13.x or later to be able to run the following:
#
# git
# AutoPkg
# JSSImporter
#
# It also installs the following Python tools and modules:
#
# pip
# cryptography
# requests (if not otherwise installed by AutoPkg or JSSImporter)
#
# Once these tools and modules are installed, the script configures AutoPkg 
# to use the recipe repos defined in the AutoPkg repos section.

# Original script credits below:

# AutoPkg_Setup_for_JSS
# by Graham Pugh

# AutoPkg_Setup_for_JSS automates the installation of the latest version of AutoPkg and prerequisites for using JSS_Importer

# Acknowledgements
# Excerpts from https://github.com/grahampugh/run-munki-run
# which in turn borrows from https://github.com/tbridge/munki-in-a-box
# JSSImporter processor and settings from https://github.com/sheagcraig/JSSImporter
# AutoPkg SubDirectoryList processor from https://github.com/facebook/Recipes-for-AutoPkg

# -------------------------------------------------------------------------------------- #
## Editable locations and settings

## AutoPkg repos:
#
# Enter the list of AutoPkg repos which need
# to be set up.
#
# All listed recipe repos should go between the two ENDMSG lines. 
# The list should look similar to the one shown below:
#
# read -r -d '' autopkg_repos <<ENDMSG
# recipes
# rtrouton-recipes
# jss-recipes
# additional recipe repo
# another recipe repo
# https://github.com/username/recipe-repo-name-here.git
# ENDMSG
#

read -r -d '' autopkg_repos <<ENDMSG

ENDMSG

# If you choose to hardcode API information into the script, uncomment the lines below
# and set one or more of the following values:
#
# The username for an account on the Jamf Pro server with sufficient API privileges
# The password for the account
# The Jamf Pro URL

#jamfproURL=""	## Set the Jamf Pro URL here if you want it hardcoded.
#apiUser=""		## Set the username here if you want it hardcoded.
#apiPass=""		## Set the password here if you want it hardcoded.

# Jamf Pro distribution point account name and password, used by
# file share distribution points.
# 
# In normal usage, this is sufficient to get access to the
# distribution point information stored in the Jamf Pro server.

#jamfdp_repo_name="" ## Set the distribution point repository name here if you want it hardcoded.
#jamfdp_repo_password="" ## Set the distribution point repository password here if you want it hardcoded.

# User Home Directory

userhome="$HOME"

# AutoPkg preferences file

autopkg_prefs="$userhome/Library/Preferences/com.github.autopkg.plist"

# Define log location

log_location="$userhome/Library/Logs/autopkg-setup-for-$(date +%Y-%m-%d-%H%M%S).log"

# If you're using a Jamf Pro cloud distribution point as your master distribution point, 
# the cloud_distribution_point variable should look like this:
#
# cloud_distribution_point="yes"
#
# Otherwise, it should look like this:
#
# cloud_distribution_point=""

cloud_distribution_point=""

# If you need to install JSSImporter 0.5.1 because you're supporting a Jamf Pro
# cloud distribution point, the jssimporter051 variable should look like this:
#
# jssimporter051="yes"
#
# Otherwise, it should look like this:
#
# jssimporter051=""

jssimporter051=""

# -------------------------------------------------------------------------------------- #
## No editing required below here

rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### AutoPkg's user-level processes should not be run as root," 
        echo "### so this script is NOT MEANT to run with root privileges."
        echo ""
        echo "### When needed, it will prompt for an admin account's password."
        echo "### This will allow sudo to run specific functions using root privileges."
        echo ""
        echo "### Script will now exit. Please try running it again without root privileges."
        echo ""
        exit 4 # Running as root.
    fi
}

adminCheck() {
    # Check that the script is being run by an account with admin rights
    if [[ -z $(id -nG | grep -ow admin) ]]; then
        echo "### This script may need to use sudo to run specific functions" 
        echo "### using root privileges. The $(id -nu) account does not have"
        echo "### administrator rights associated with it, so it will not be"
        echo "### able to use sudo."
        echo ""
        echo "### Script will now exit."
        echo "### Please try running this script again using an admin account."
        echo ""
        exit 4 # Running as root.
    fi
}

# define ScriptLogging behavior

ScriptLogging(){

    DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    LOG="$log_location"
    
    echo "$DATE" " $1" >> $LOG
}

installCommandLineTools() {
    # Installing the Xcode command line tools on 10.10 and later

    echo "### Installing git via installing the Xcode command line tools..."
    echo
    osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')
    cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

    # Installing the latest Xcode command line tools on 10.10.x or later.

    if [[ "$osx_vers" -ge 10 ]]; then
    
    	# Create the placeholder file which is checked by the softwareupdate tool 
    	# before allowing the installation of the Xcode command line tools.
    	
    	touch "$cmd_line_tools_temp_file"
    	
    	# Identify the correct update in the Software Update feed with "Command Line Tools" in the name for the OS version in question.
    	
    	if [[ "$os_vers" -ge 15 ]]; then
    	   cmd_line_tools=$(softwareupdate -l | awk '/\*\ Label: Command Line Tools/ { $1=$1;print }' | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 9-)	
    	elif [[ "$os_vers" -ge 10 ]] && [[ "$os_vers" -lt 14 ]]; then
    	   cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | grep "$os_vers" | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
    	fi
    	    	
    	# Check to see if the softwareupdate tool has returned more than one Xcode
    	# command line tool installation option. If it has, use the last one listed
    	# as that should be the latest Xcode command line tool installer.
    	
    	if (( $(grep -c . <<<"$cmd_line_tools") > 1 )); then
    	   cmd_line_tools_output="$cmd_line_tools"
    	   cmd_line_tools=$(printf "$cmd_line_tools_output" | tail -1)
    	fi
    	
    	# Install the command line tools
    	
    	sudo softwareupdate -i "$cmd_line_tools" --verbose >> "$log_location" 2>&1
    	
    	# Remove the temp file
    	
    	if [[ -f "$cmd_line_tools_temp_file" ]]; then
    	  rm "$cmd_line_tools_temp_file"
    	fi
    else
        echo "Sorry, this script is only for use on OS X/macOS >= 10.10"
    fi
}

installAutoPkg() {

    # Install the latest release of AutoPkg

    autopkg_location_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')
    /usr/bin/curl -L -s "${autopkg_location_LATEST}" -o "$userhome/autopkg-latest.pkg"

    ScriptLogging "Installing AutoPkg"
    sudo installer -verboseR -pkg "$userhome/autopkg-latest.pkg" -target / >> "$log_location" 2>&1

    ScriptLogging "AutoPkg Installed"
    echo
    echo "### AutoPkg Installed"
    echo
}

installJSSImporter() {

    # Install JSSImporter 

    if [[ "$jssimporter051" = "yes" ]]; then
    
        # JSSImporter 0.5.1 is needed for now for Jamf Pro cloud distribution point support.
        # Once JSSImporter 1.x is updated to support cloud DPs, this option will be removed.
    
         JSSIMPORTER_051=$(curl https://api.github.com/repos/jssimporter/jssimporter/releases/1892051 | awk '/browser_download_url/ {print $2}' | sed 's/\"//g')
         /usr/bin/curl -L -s "${JSSIMPORTER_051}" -o "$userhome/jssimporter.pkg"
         ScriptLogging "Installing JSSImporter"
         sudo installer -verboseR -pkg "$userhome/jssimporter.pkg" -target / >> "$log_location" 2>&1
         
    else
        
        # Install the latest release of JSSImporter by adding the
        # rtrouton-recipes AutoPkg recipe repo and installing JSSImporter
        # using the JSSImporter.install recipe available from that repo.
        #
        # Once installed, the rtrouton-recipes AutoPkg recipe repo is
        # deleted from the Mac to avoid possibly causing issues when adding
        # receipe repos later in the process.
    
         autopkg repo-add rtrouton-recipes >> "$log_location" 2>&1
         ScriptLogging "Installing JSSImporter"
         autopkg run JSSImporter.install >> "$log_location" 2>&1
         autopkg repo-delete rtrouton-recipes >> "$log_location" 2>&1

    fi
         



    ScriptLogging "JSSImporter Installed"
    echo
    echo "### JSSImporter Installed"
    echo
}

installPythonPip() {
    # Get Python Pip install tool
    
    ScriptLogging "Installing Python Pip install tool"
    sudo easy_install pip >> "$log_location" 2>&1

    ScriptLogging "Pip Installed"
    echo
    echo "### Pip Installed"
    echo
}

installPythonCryptographyModule() {
    # Install pyopenssl to add the cryptography module
    # needed by AutoPkg on macOS Sierra and later.
    
    ScriptLogging "Installing Python PyOpenSSL module to add the cryptography module."
    pip install -I --user pyopenssl >> "$log_location" 2>&1

    ScriptLogging "PyOpenSSL Installed"
    echo
    echo "### PyOpenSSL Installed"
    echo
}

installPythonRequestsModule() {
    # Install the Python requests module.
    
    ScriptLogging "Installing Python requests module."
    pip install -I --user requests >> "$log_location" 2>&1

    ScriptLogging "Requests Installed"
    echo
    echo "### Requests Installed"
    echo
}

## Main section

# Make sure that the script is not being run as root.

rootCheck

# Make sure that the script is being run by an admin account.

adminCheck

# If the log file is not available, create it

if [[ ! -r "$log_location" ]]; then
    touch "$log_location"
fi

# If the Jamf Pro URL, the account username or the account password aren't available
# otherwise, you will be prompted to enter the requested URL or account credentials.

if [[ -z "$jamfproURL" ]]; then
     read -p "Please enter your Jamf Pro server URL : " jamfproURL
fi

if [[ -z "$apiUser" ]]; then
     read -p "Please enter your Jamf Pro user account : " apiUser
fi

if [[ -z "$apiPass" ]]; then
     read -p "Please enter the password for the $apiUser account: " -s apiPass
     echo ""
     if [[ $cloud_distribution_point = "yes" ]]; then
        echo "Any follow-up password requests will be for sudo rights."
     fi
fi

if [[ $cloud_distribution_point != "yes" ]]; then

   if [[ -z "$jamfdp_repo_name" ]]; then
     read -p "Please enter your Jamf Pro distribution point repository name : " jamfdp_repo_name
   fi

   if [[ -z "$jamfdp_repo_password" ]]; then
     read -p "Please enter your Jamf Pro distribution point password : "  -s jamfdp_repo_password
     echo ""
     echo "Any follow-up password requests will be for sudo rights."
   fi
fi

echo ""

# Commands
autopkg_location="/usr/local/bin/autopkg"
defaults_location="/usr/bin/defaults"
jssimporter_location="/Library/AutoPkg/autopkglib/JSSImporter.py"
pip_location="/usr/local/bin/pip"
plistbuddy_location="/usr/libexec/PlistBuddy"

# Find git's installed location. There will be an executable stub
# binary available at /usr/bin/git, but that doesn't necessarily mean
# git is actually installed. Instead, without git installed, the stub
# binary will trigger a GUI window which requests the installation of
# install the Xcode command line tools.

# If Xcode.app is installed in /Applications, set /usr/bin/git as
# git's location.

if [[ -x "/Applications/Xcode.app/Contents/Developer/usr/libexec/git-core/git" ]]; then
   git_location="/usr/bin/git"

# If the Xcode command line tools are installed, set /usr/bin/git as
# git's location.

elif [[ -x "/Library/Developer/CommandLineTools/usr/libexec/git-core/git" ]]; then
   git_location="/usr/bin/git"

# If the standalone git is installed, set /usr/local/bin/git as
# git's location.

elif [[ -x "/usr/local/git/bin/git" ]]; then
   git_location="/usr/local/bin/git"

# Otherwise, explicitly set git_location to be a null value. 
# That will trigger the script to install the Xcode command line tools.

else
   git_location=""
fi



# Check for Xcode command line tools  and install if needed.
if [[ ! -x "$git_location" ]]; then
    installCommandLineTools
else
    ScriptLogging "Git installed"
    echo "### Git Installed"
fi

# Check for Python pip installer tool and install if needed.
if [[ ! -x "$pip_location" ]]; then
    installPythonPip
else
    ScriptLogging "Pip installed"
    echo "### Pip Installed"
fi

# Get AutoPkg if not already installed
if [[ ! -x ${autopkg_location} ]]; then
    installAutoPkg "${userhome}"
    
    # Clean up if necessary.
    
    if [[ -e "$userhome/autopkg-latest.pkg" ]]; then
        rm "$userhome/autopkg-latest.pkg"
    fi    
else
    ScriptLogging "AutoPkg installed"
    echo "### AutoPkg Installed"
fi

# Check for Python cryptography module and install if needed.

if [[ $(pip list | awk '/cryptography/ {print $1}') = "" ]]; then
    installPythonCryptographyModule
else
    ScriptLogging "Python cryptography module installed"
    echo "### PyOpenSSL Installed"
fi

# Check for Python requests module and install if needed.

if [[ $(pip list | awk '/requests/ {print $1}') = "" ]]; then
    installPythonRequestsModule
else
    ScriptLogging "Python requests module installed"
    echo "### Requests Installed"
fi

# Check for Python jss module and install if needed.

if [[ $(pip list | awk '/requests/ {print $1}') = "" ]]; then
    installPythonRequestsModule
else
    ScriptLogging "Python requests module installed"
    echo "### Requests Installed"
fi

# Check for JSSImporter and install if needed

if [[ ! -x "$jssimporter_location" ]]; then
    installJSSImporter
    # Clean up if necessary
    
    if [[ -e "$userhome/jssimporter.pkg" ]]; then
       rm "$userhome/jssimporter.pkg"
    fi
else
    ScriptLogging "JSSImporter installed"
    echo "### JSSImporter Installed"
fi

if [[ -x ${autopkg_location} ]] && [[ $(pip list | awk '/cryptography/ {print $1}') = "cryptography" ]] && [[ $(pip list | awk '/requests/ {print $1}') = "requests" ]] && [[ -x "$jssimporter_location" ]]; then

  ScriptLogging "AutoPkg and JSSImporter verified as installed. All necessary Python modules verified as installed."
  echo
  echo "### AutoPkg and JSSImporter verified as installed."
  echo "### All necessary Python modules verified as installed."

  # Add AutoPkg repos (checks if already added)

  ${autopkg_location} repo-add ${autopkg_repos} >> "$log_location" 2>&1

  # Update AutoPkg repos (if the repos were already there no update would otherwise happen)

  ${autopkg_location} repo-update ${autopkg_repos} >> "$log_location" 2>&1

  ScriptLogging "AutoPkg Repos Configured"
  echo
  echo "### AutoPkg Repos Configured"


  # Configure JSSImporter with the following information:
  #
  # Jamf Pro address
  # Jamf Pro API account username
  # Jamf Pro API account username

  ${defaults_location} write com.github.autopkg JSS_URL "${jamfproURL}" >> "$log_location" 2>&1
  ${defaults_location} write com.github.autopkg API_USERNAME ${apiUser} >> "$log_location" 2>&1
  ${defaults_location} write com.github.autopkg API_PASSWORD ${apiPass} >> "$log_location" 2>&1

  # Remove any existing Jamf Pro distribution point settings

  ${plistbuddy_location} -c "Delete :JSS_REPOS array" ${autopkg_prefs} >> "$log_location" 2>&1 
  
  if [[ "$cloud_distribution_point" = "yes" ]]; then
  
      # Add Cloud Distribution Point (CDP) to the JSSImporter settings.
  
      ${plistbuddy_location} -c "Add :JSS_REPOS array" ${autopkg_prefs} >> "$log_location" 2>&1
      ${plistbuddy_location} -c "Add :JSS_REPOS:0 dict" ${autopkg_prefs} >> "$log_location" 2>&1
      ${plistbuddy_location} -c "Add :JSS_REPOS:0:type string CDP" ${autopkg_prefs} >> "$log_location" 2>&1

  else
  
      # Add the distribution point repository name and repository password 
      # to the JSSImporter settings, which is necessary to access the file  
      # share distribution point info stored in your Jamf Pro server.
  
      ${plistbuddy_location} -c "Add :JSS_REPOS array" ${autopkg_prefs} >> "$log_location" 2>&1
      ${plistbuddy_location} -c "Add :JSS_REPOS:0 dict" ${autopkg_prefs} >> "$log_location" 2>&1
      ${plistbuddy_location} -c "Add :JSS_REPOS:0:name string ${jamfdp_repo_name}" ${autopkg_prefs} >> "$log_location" 2>&1
      ${plistbuddy_location} -c "Add :JSS_REPOS:0:password string ${jamfdp_repo_password}" ${autopkg_prefs} >> "$log_location" 2>&1
  fi
  
  ScriptLogging "AutoPkg and JSSImporter configured and ready for use."
  echo
  echo "### AutoPkg and JSSImporter configured and ready for use with the following repos. For setup details, please see $log_location."
  echo "$(autopkg repo-list)"

else
  ScriptLogging "AutoPkg and JSSImporter not installed properly."
  echo
  echo "### AutoPkg and JSSImporter not installed properly. For setup details, please see $log_location."
fi