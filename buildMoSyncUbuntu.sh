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
mosyncDir="$HOME"/mosync
mosyncSrcDir="$mosyncDir"/src
gccBuildDir="$mosyncSrcDir"/gcc
mosyncBuildDir="$mosyncSrcDir"/mosync
eclipeBuildDir="$mosyncSrcDir"/eclipse
installBinDir=$mosyncDir/bin
installGCCDir=$mosyncDir/libexec/gcc/mapip/3.4.6

selectedMoSyncSDKBranch="ThreeTwoOne"

toolsBuildUseGit=false


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
	sudo apt-get install gcc g++ bison flex ruby rake subversion rpm libgtk2.0-dev libexpat1-dev libbluetooth3-dev libsdl1.2-dev libsdl-image1.2-dev libsdl-ttf2.0-dev libfreeimage-dev gperf libssl-dev git p7zip-full html-xml-utils libwebkitgtk-1.0-0 build-essential libglew1.6-dev lib32z1-dev zlib1g-dev:i386

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
	cp gcc/xgcc gcc/cpp $MOSYNCDIR/bin
	cp gcc/cc1 gcc/cc1plus $MOSYNCDIR/libexec/gcc/mapip/3.4.6/

	#---End MoSync GCC build 
}

function funcBuildMoSyncTools() {
	#Build Mosync tools, either from the nigtlys or git

	pushd "$mosyncBuildDir"

	if [ ! "$toolsBuildUseGit" ]
	then 
		#Download and build nightly version of MoSync/Eclipse
		#echo "Now we need to 'wget -c' and 'tar xjzf' $latestLinuxNightlyBundleURL
		wget -c "$latestLinuxNightlyBundleURL"

		#decompress the nightly, get the filename from the nightly URL
		local filename=$(echo "$latestLinuxNightlyBundleURL" | awk -F'/' '{print $NF}')
		#echo "$filename"
		tar xjf ./"$filename"

		pushd "$mosyncBuildDir"/MoSync-trunk/
	else
		#Use the git-based tools repo
		if [ ! -d "$mosyncBuildDir"/MoSync-trunk-git ]
		then
			git clone git://github.com/MoSync/MoSync.git MoSync-trunk-git
		fi

		pushd "$mosyncBuildDir"/MoSync-trunk-git/
	fi

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
funcInit
funcInitDirs
funcBuildGCC
funcBuildMoSyncTools
#funcBuildMoSyncEclipse
funcCleanUp




