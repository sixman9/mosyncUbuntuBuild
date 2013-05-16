#!/bin/bash

#See http://www.mosync.com/content/what-missing-fully-functioning-linux-version-mosync-dev-tools-please-outline-issues
#http://www.mosync.com/nightly-builds

#Git clone directly into a particular named branch
#git clone -b <branch> <remote_repo>


#How to extract vender profiles from Mosync Windows Executable using 7Zip (thanks to PeaZip's script output, useful for DMG's, too)
#7z x -aos "-oC:/some/temporary/output/directory" -pdefault -sccUTF-8 "/path/to/MoSyncSDK-Windows-*.exe" -- "$_OUTDIR\profiles"

useNightlyNotGithub=true

sudo apt-get install p7zip-full html-xml-utils gcc g++ bison flex ruby rake subversion rpm libgtk2.0-dev libexpat1-dev libbluetooth3-dev libsdl1.2-dev libsdl-image1.2-dev libsdl-ttf2.0-dev libfreeimage-dev gperf libssl-dev git

mosyncHomePage="http://www.mosync.com"
mosyncNightly="/nightly-builds"

baseDir=/tmp
gccBuildDir="$baseDir"/mosyncBuild/gcc
mosyncBuildDir="$baseDir"/mosyncBuild/mosync
eclipeBuildDir="$baseDir"/mosyncBuild/eclipse
installDir="$baseDir"/mosyncInstall
installBinDir=$installDir/bin
installGCCDir=$installDir/libexec/gcc/mapip/3.4.6

mosyncGCCGitProjName=gcc_trunk

#Determine the OS architecture (32/64bit) using 'uname -m', then run the required commands (see http://stackoverflow.com/a/106416/304330)
ourArch=$(uname -m)

mosyncLinuxNightlys=$(curl -s "$mosyncHomePage$mosyncNightly" | hxnormalize -l 240 -x | hxselect -i -s '\n' 'a[href$=".bz2"]' | awk -F'"' '{print $2}')

lastVersion=-1

for linuxSourceURLSuffix in $mosyncLinuxNightlys
do
	#strip 'bz2' file extension
	srcFilePrefix=$(echo $linuxSourceURLSuffix | awk -F'.' '{print $1}')

	#use TR to strip out version digits - then store URL with greatest version number
	nextVersion=$(echo $srcFilePrefix | tr -cd [:digit:])
	#echo "last=$lastVersion & next=$nextVersion"
	if [ $nextVersion -gt $lastVersion ]; then
		latestmosynNightlyURL="$mosyncHomePage$linuxSourceURLSuffix"
		lastVersion=$nextVersion
	fi
done

#Create MoSync Install/Build directories - See http://www.mosync.com/documentation/manualpages/building-mosync-source-linux
mkdir -p "$installBinDir"
mkdir -p "$installGCCDir"

export MOSYNCDIR="$installDir"

#Let's build MoSync GCC from GitHub
mkdir -p "$gccBuildDir"
pushd "$gccBuildDir"
git clone git://github.com/MoSync/gcc.git "$mosyncGCCGitProjName"

pushd ./"$mosyncGCCGitProjName"
./configure-linux.sh
pushd build/gcc
make

#Move MoSync's built gcc etc. to the MoSync install 
#Compilation may have failed when trying to build libgcc - this *is* OK - for the build scripts to find MoSync GCC it has to be moved to the installation directory
cp gcc/xgcc gcc/cpp $MOSYNCDIR/bin
cp gcc/cc1 gcc/cc1plus $MOSYNCDIR/libexec/gcc/mapip/3.4.6/

#pop all dirs
dirs -c

if $useNightlyNotGithub ; then
	#Download and build nightly version of MoSync/Eclipse

	#echo "Now we need to 'wget -c' and 'tar xjzf' $latestmosynNightlyURL"
	pushd "$installDir"
	wget -c "$latestmosynNightlyURL"

	#decompress the binary
	tar xjzf "$latestmosynNightlyURL"
else
	#Download official MoSync Github repositories for MoSync/Eclipse

fi

if [ $ourArch == 'x86_64' ]; then
  # 64-bit tasks here
  #Apply 64-bit patch to mosync (https://github.com/fredrikeldh/Eclipse/commit/c059d516e0e89ed4308f27cdc03229ec01fde740)
  #See http://blog.mhartl.com/2008/07/01/using-git-to-pull-in-a-patch-from-a-single-commit

else
  # 32-bit tasks here
fi


######Ideas on getting Eclipse Profiles from a DMG #####
# curl -A "Mozilla/4.0" -L http://vu1tur.eu.org/tools/download.pl?dmg2img.tar.gz > dmg2img.tar.gz
# tar -zxvf ./dmg2img.tar.gz
# cd dmg2img
# make all

# sudo modprobe hfsplus

# ./dmg2img -i /path/to/inputfile.dmg -o /path/to/outputfile.img
####################################################


