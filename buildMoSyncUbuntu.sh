#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

#See http://www.mosync.com/content/what-missing-fully-functioning-linux-version-mosync-dev-tools-please-outline-issues & http://www.mosync.com/documentation/manualpages/building-mosync-source-linux

mosyncHomePage="http://www.mosync.com"
mosyncNightly="/nightly-builds"

mosyncGCCGitProjName=mosyn_gcc

mosyncIDEGitURL="git://github.com/MoSync/MoSync.git"

#Determine the OS architecture (32/64bit) using 'uname -m', then run the required commands (see http://stackoverflow.com/a/106416/304330)
ourArch=$(uname -m)

#Various build and install directory definitions
mosyncDir="$HOME"/mosync
mosyncSrcDir="$mosyncDir"/src
gccBuildDir="$mosyncSrcDir"/gcc
mosyncBuildDir="$mosyncSrcDir"/mosync
eclipeBuildDir="$mosyncSrcDir"/eclipse
installBinDir=$mosyncDir/bin
installGCCDir=$mosyncDir/libexec/gcc/mapip/3.4.6

selectedMoSyncSDKBranch="ThreeTwoOne"


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

	#Install any tools we need
	sudo apt-get install gcc g++ bison flex ruby rake subversion rpm libgtk2.0-dev libexpat1-dev libbluetooth3-dev libsdl1.2-dev libsdl-image1.2-dev libsdl-ttf2.0-dev libfreeimage-dev gperf libssl-dev git p7zip-full html-xml-utils libwebkitgtk-1.0-0 build-essential 

}

function funcInitDirs() {

	#pop all dirs
	dirs -c

	#Create MoSync Install/Build directories - See http://www.mosync.com/documentation/manualpages/building-mosync-source-linux	
	mkdir -p "$gccBuildDir"
	mkdir -p "$installBinDir"
	mkdir -p "$installGCCDir"
	mkdir -p "$mosyncBuildDir"
	mkdir -p "$eclipeBuildDir"

	export MOSYNCDIR="$mosyncDir"
}

function funcDownloadGCCSrc() {

	pushd "$gccBuildDir"
	git clone git://github.com/MoSync/gcc.git "$mosyncGCCGitProjName"
}

function funcBuildGCC() {
	#---Start MoSync GCC build

	#Let's build MoSync GCC from GitHub
	pushd "$gccBuildDir"/"$mosyncGCCGitProjName"
	#APPLY GCC PATCH (re: Sudarais)
	patch -p1 < "$SCRIPT_DIR"/patches/gcc_patch.txt
	./configure-linux.sh
	pushd build/gcc
	make

	#Move MoSync's built gcc etc. to the MoSync install
	#Compilation may have failed when trying to build libgcc - this *is* OK - for the build scripts to find MoSync GCC it has to be moved to the installation directory
	cp gcc/xgcc gcc/cpp $MOSYNCDIR/bin
	cp gcc/cc1 gcc/cc1plus $MOSYNCDIR/libexec/gcc/mapip/3.4.6/

	#---End MoSync GCC build 
}

function funcBuildMoSyncTools() {

	# Download mosync nightly build and extract mosync code to $MOSYNCDIR/src/mosync_trunk
	# Apply mosync patch	

	#Download and build nightly version of MoSync/Eclipse

	
	#git clone git://github.com/MoSync/MoSync.git mosync_trunk

	#echo "Now we need to 'wget -c' and 'tar xjzf' $latestLinuxNightlyBundleURL
	pushd "$mosyncBuildDir"
	wget -c "$latestLinuxNightlyBundleURL"

	#decompress the nightly, get the filename from the nightly URL
	local filename=$(echo "$latestLinuxNightlyBundleURL" | awk -F'/' '{print $NF}')
	echo "$filename"
	tar xjf ./"$filename" 

	pushd "$mosyncBuildDir"/MoSync-trunk/

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

function funcCleanUp() {

	#pop all dirs
	dirs -c
}

function funcBuildMoSyncEclipse() {
	if [ $ourArch == 'x86_64' ]; then
		#Any 64-bit tasks here
		#Apply 64-bit patch to mosync (https://github.com/fredrikeldh/Eclipse/commit/c059d516e0e89ed4308f27cdc03229ec01fde740)
		#See http://blog.mhartl.com/2008/07/01/using-git-to-pull-in-a-patch-from-a-single-commit
		echo about to build MoSync Eclipse
	fi

	#Continue standard/outlined MoSync-Eclipse-on-Ubuntu build steps
}

#Resolve latest MoSync Linux (.b2z, sdk src code) and Windows (EXE, to extract profiles etc.) Nightly bundles
#bundle extension are '.exe'=>Windows, '.bz2'=>Linux '.dmg'=>Mac
latestWindowsNightlyBundleURL=$(funcFindLatestMoSyncNightlyBundleURL "$mosyncHomePage$mosyncNightly" ".exe")
latestLinuxNightlyBundleURL=$(funcFindLatestMoSyncNightlyBundleURL "$mosyncHomePage$mosyncNightly" ".bz2")

#echo $latestWindowsNightlyBundleURL
#echo $latestLinuxNightlyBundleURL
#exit 0

#Build MoSync GCC/SDK/Eclipse - call various functions
#funcInit
funcInitDirs
#funcDownloadGCCSrc
#funcBuildGCC
funcBuildMoSyncTools
#funcBuildMoSyncEclipse
funcCleanUp




