#!/bin/bash

#Determine the OS architecture (32/64bit) using 'uname -m', then run the required commands (see http://stackoverflow.com/a/106416/304330)
ourArch=$(uname -m)

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

#See http://www.mosync.com/content/what-missing-fully-functioning-linux-version-mosync-dev-tools-please-outline-issues & http://www.mosync.com/documentation/manualpages/building-mosync-source-linux

mosyncHomePage="http://www.mosync.com"
mosyncNightly="/nightly-builds"

#One-time 32/64-bit configurations
if [ $ourArch == 'x86_64' ]
then
	#64-bit
	mosyncGCCGitProjDirName=mosyn_gcc-64
	gccGitURL="git://github.com/fredrikeldh/MoSync-gcc3.git" 
else
	#32-bit
	mosyncGCCGitProjDirName=mosyn_gcc
	gccGitURL="git://github.com/MoSync/gcc.git"
fi

mosyncIDEGitURL="git://github.com/MoSync/MoSync.git"

#Various build and install directory definitions
installBaseDir="$HOME"
mosyncDirName=Mosync
eclipseDirName=eclipse
export MOSYNCDIR="$installBaseDir"/"$mosyncDirName"

mosyncSrcDir=/tmp/"$mosyncDirName"/src
gccBuildDir="$mosyncSrcDir"/gcc
installBinDir=$MOSYNCDIR/bin
installGCCDir=$MOSYNCDIR/libexec/gcc/mapip/3.4.6

selectedMoSyncSDKGitBranch="ThreeThreeOne"

toolsBuildUseGit=true


function funcInstallTools() {

	#Install any tools we need

	if [ -f /var/lib/dpkg/lock ]
	then
		echo "dpkg/apt database maybe locked or in use - please check/remove the '/var/lib/dpkg/lock' file"
		exit 1
	fi

	echo "updating apt software library references"
	#sudo apt-get update > /dev/null
	sudo apt-get update
	sudo apt-get -f install

	sudo apt-get --assume-yes install curl
	sudo apt-get --assume-yes install gcc g++
	sudo apt-get --assume-yes install bison flex ruby rake subversion rpm libgtk2.0-dev libexpat1-dev libbluetooth3-dev libsdl1.2-dev libsdl-image1.2-dev libsdl-ttf2.0-dev libfreeimage-dev gperf libssl-dev git p7zip-full html-xml-utils libwebkitgtk-1.0-0 build-essential libglew1.6-dev lib32z1-dev zlib1g-dev:i386

}

#Run the Tools install, early
funcInstallTools

function funcDownloadMosyncTools() {
	#Build Mosync tools, either from the nigtlys or git

	#Install Mosync main/tools
	pushd "$installBaseDir"

	if $toolsBuildUseGit
	then
		#Use the git-based tools repo
		if [ ! -d "$MOSYNCDIR" ]
		then
			#Get the selectedMoSyncSDKGitBranch for main Mosync tools project
			git clone -b $selectedMoSyncSDKGitBranch "$mosyncIDEGitURL" "$mosyncDirName"
		fi
	else
		#Download and build nightly version of MoSync/Eclipse
		#echo "Now we need to 'wget -c' and 'tar xjzf' $latestLinuxNightlyBundleURL
		wget -c "$latestLinuxNightlyBundleURL"

		#decompress the nightly, get the filename from the nightly URL
		local filename=$(echo "$latestLinuxNightlyBundleURL" | awk -F'/' '{print $NF}')
		#echo "$filename"
		tar xjf ./"$filename"

		#Rename the untarred directories
		mv ./MoSync-trunk ./"$mosyncDirName"
		mv ./Eclipse "$MOSYNCDIR"/"$eclipseDirName"

		#Git-initialise the bundle-extracted Eclipse directory, in case we need to Git-cherry-pick patches, later
		pushd "$MOSYNCDIR"/"$eclipseDirName"
		git init
	fi
}

#Function to determine FindLatestMoSyncNightlyBundleURL <nightly-page-url> <file-suffix>
function funcFindLatestMoSyncNightlyBundleURL() {
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

function funcInit() {

	#Do any initial config (other than software/package installs)
	echo
}

function funcInitDirs() {

	#pop all dirs
	dirs -c

	#Create MoSync Install/Build directories - See http://www.mosync.com/documentation/manualpages/building-mosync-source-linux	
	mkdir -p "$gccBuildDir"
	mkdir -p "$installBinDir"
	mkdir -p "$installGCCDir"
}

function funcBuildGCC() {

	if [ ! -d "$gccBuildDir"/"$mosyncGCCGitProjDirName" ]
	then
		pushd "$gccBuildDir"

		#Git clone the resolved 32/64bit GCC version
		git clone "$gccGitURL" "$mosyncGCCGitProjDirName"
	fi

	#---Start MoSync GCC build

	#Let's update and build MoSync GCC from GitHub
	pushd "$gccBuildDir"/"$mosyncGCCGitProjDirName"

	git pull

	#APPLY GCC PATCH (re: Sudarais)
	patch -p1 < "$SCRIPT_DIR"/patches/gcc_patch.txt
	./configure-linux.sh
	pushd build/gcc

	make

	#Move MoSync's built gcc etc. to the MoSync install
	#Compilation may have failed when trying to build libgcc - this *is* OK - for the build scripts to find MoSync GCC it has to be moved to the installation directory
	cp gcc/xgcc gcc/cpp "$installBinDir"
	cp gcc/cc1 gcc/cc1plus "$installGCCDir"

	#---End MoSync GCC build 
}

function funcBuildMoSyncTools() {
	#Build Mosync tools, either from the nigtlys or git
	pushd "$MOSYNCDIR"

	#APPLY SDK PATCH (re: Sudarais)
	patch -p1 < "$SCRIPT_DIR"/patches/mosync_patch.txt

	./workfile.rb CONFIG="debug"

	./workfile.rb CONFIG=""

	#if [ $ourArch == 'x86_64' ]; then
		# Any 64-bit tasks here
		# Any 32-bit tasks here
	#	echo about to build MoSync tools
	#fi

	

	#Continue standard/outlined MoSync-SDK-on-Ubuntu build steps

}

function funcBuildMoSyncEclipse() {

	pushd "$MOSYNCDIR"

	if $toolsBuildUseGit
	then
		#Git clone the required Eclipse MoSync branch
		git clone -b $selectedMoSyncSDKGitBranch git://github.com/MoSync/Eclipse.git $eclipseDirName
	fi

	#Change to the eclipse directory
	pushd ./"$eclipseDirName"

	if [ $ourArch == 'x86_64' ]; then
		#Any 64-bit tasks here
		#Apply 64-bit patch to mosync (https://github.com/fredrikeldh/Eclipse/commit/c059d516e0e89ed4308f27cdc03229ec01fde740)
		#See http://blog.mhartl.com/2008/07/01/using-git-to-pull-in-a-patch-from-a-single-commit

		#Add the Git remote we want the patch from, the update/fetch our local info about it
		git remote add fredrikeldh git://github.com/fredrikeldh/Eclipse.git
		git fetch fredrikeldh

		git cherry-pick c059d516e0e89ed4308f27cdc03229ec01fde740
	fi

	#Continue standard/outlined MoSync-Eclipse-on-Ubuntu build steps
	echo about to build MoSync Eclipse

	#Download http://www.mosync.com/down/target-platform.zip to directory 'com.mobilesorcery.sdk.product/build'
	pushd com.mobilesorcery.sdk.product/build

	wget -c http://www.mosync.com/down/target-platform.zip

	#ant build (java-make equivalent) MoSync-Eclipse
	ant release

	#Move to the ant build's output directory, then make the Eclipse binary executable
	pushd buildresult/I.MoSync/MoSync-linux.gtk.x86-unzipped/mosync

 	chmod +x mosync
}

function funcCleanUp() {

	#pop all dirs
	dirs -c

	#Open the MoSync install directory in file manager window
	xdg-open "$MOSYNCDIR"
}

#Resolve latest MoSync Linux (.b2z, sdk src code) and Windows (EXE, to extract profiles etc.) Nightly bundles
#bundle extension are '.exe'=>Windows, '.bz2'=>Linux '.dmg'=>Mac
latestWindowsNightlyBundleURL=$(funcFindLatestMoSyncNightlyBundleURL "$mosyncHomePage$mosyncNightly" ".exe")
latestLinuxNightlyBundleURL=$(funcFindLatestMoSyncNightlyBundleURL "$mosyncHomePage$mosyncNightly" ".bz2")

#echo $latestWindowsNightlyBundleURL
#echo $latestLinuxNightlyBundleURL
#exit 0

#Build MoSync GCC/SDK/Eclipse - call various functions
#We ran funcInstallTools() earlier
funcInit
funcDownloadMosyncTools
funcInitDirs
funcBuildGCC
funcBuildMoSyncTools
funcBuildMoSyncEclipse
funcCleanUp




