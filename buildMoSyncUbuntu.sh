#!/bin/bash

#See http://www.mosync.com/content/what-missing-fully-functioning-linux-version-mosync-dev-tools-please-outline-issues

mosyncHomePage="http://www.mosync.com"
mosyncNightly="/nightly-builds"

mosyncIDEGitURL="git://github.com/MoSync/MoSync.git"

#Install any tools we need
#sudo apt-get install gcc g++ bison flex ruby rake subversion rpm libgtk2.0-dev libexpat1-dev libbluetooth3-dev libsdl1.2-dev libsdl-image1.2-dev libsdl-ttf2.0-dev libfreeimage-dev gperf libssl-dev git p7zip-full html-xml-utils libwebkitgtk-1.0-0 build-essential 

#Determine the OS architecture (32/64bit) using 'uname -m', then run the required commands (see http://stackoverflow.com/a/106416/304330)
ourArch=$(uname -m)

#latestMoSyncNightlyBundleURL <nightly-page-url> <file-suffix>
function latestMoSyncNightlyBundleURL() {
	local mosyncNightlyURL=$1
	local mosyncBundleSuffix=$2

	#local srcFilePrefix
	local nextVersion
	local resolvedMosyncNightlyURL

	#Get a list of MoSync Linux Nightly's
	local mosyncLinuxNightlys=$(curl -s "$mosyncNightlyURL" | hxnormalize -l 240 -x | hxselect -i -s '\n' "a[href$=\"$mosyncBundleSuffix\"]" | awk -F'"' '{print $2}')

	#echo $mosyncLinuxNightlys

	#Determine the most up-to-date nightly MoSync bundle => $resolvedMosyncNightlyURL
	local lastVersion=-1
	for linuxSourceURLSuffix in $mosyncLinuxNightlys
	do
		#strip file extension
		#srcFilePrefix=$(echo $linuxSourceURLSuffix | awk -F'.' '{print $1}')

		#use TR to strip out version digits - then store URL with greatest version number
		nextVersion=$(echo $linuxSourceURLSuffix | tr -cd [:digit:])
		#echo "last=$lastVersion & next=$nextVersion"
		if [ $nextVersion -gt $lastVersion ]; then
			resolvedMosyncNightlyURL="$mosyncHomePage$linuxSourceURLSuffix"
			lastVersion=$nextVersion
		fi
	done

	#'return' the required value
	#echo ${#resolvedMosyncNightlyURL[@]}
	echo $resolvedMosyncNightlyURL
}


#Resolve the latest MoSync Windows Nightly bundle EXE (We'll extract device profiles from it, later)
#bundle extension are '.exe'=>Windows, '.b2z'=>Linux '.dmg'=>Mac
latestNightlyBundleURL=$(latestMoSyncNightlyBundleURL "$mosyncHomePage$mosyncNightly" ".exe")

#echo $latestNightlyBundleURL

#List remote Git branches
mosyncBranches=$(git ls-remote "$mosyncIDEGitURL" | grep -i heads | awk -F'/' '{print $NF}')

select chosenBranch in $mosyncBranches;
do
	echo You chose $chosenBranch
	break
done



