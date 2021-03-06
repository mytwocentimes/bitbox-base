#!/bin/bash

# BitBox Base: build Armbian base image
# 
# Script to automate the build process of the customized Armbian base image for the BitBox Base. 
# Additional information: https://digitalbitbox.github.io/bitbox-base
#
set -eu

# Settings
#
# VirtualBox Number of CPU cores
VIRTUALBOX_CPU="4"
# VirtualBox Memory in MB
VIRTUALBOX_MEMORY="8192"

function usage() {
	echo "Build customized Armbian base image for BitBox Base"
	echo "Usage: ${0} [update]"
}

function cleanup() {
	if [[ "${ACTION}" != "clean" ]]; then
		echo "Cleaning up by halting any running vagrant VMs.."
		vagrant halt
	fi
}

ACTION=${1:-"build"}

if ! [[ "${ACTION}" =~ ^(build|update|clean)$ ]]; then
	usage
	exit 1
fi

trap cleanup EXIT

case ${ACTION} in
	build|update)
		if ! which git >/dev/null 2>&1 || ! which vagrant >/dev/null 2>&1; then
			echo
			echo "Build environment not set up, please check documentation at"
			echo "https://digitalbitbox.github.io/bitbox-base"
			echo
			exit 1
		fi

		git log --pretty=format:'%h' -n 1 > ./base/config/latest_commit

		if [ ! -d "armbian-build" ]; then 
			git clone https://github.com/armbian/build armbian-build
			sed -i "s/#vb.memory = \"8192\"/vb.memory = \"${VIRTUALBOX_MEMORY}\"/g" armbian-build/Vagrantfile
			sed -i "s/#vb.cpus = \"4\"/vb.cpus = \"${VIRTUALBOX_CPU}\"/g" armbian-build/Vagrantfile
		fi
		cd armbian-build

		vagrant up
		mkdir -p output/
		mkdir -p userpatches/overlay
		cp -aR ../base/* userpatches/overlay/					# copy scripts and configuration items to overlay
		cp -aR ../../build/* userpatches/overlay/				# copy additional software binaries to overlay
		cp -a  ../base/build/customize-image.sh userpatches/	# copy customize script to standard Armbian build hook

		BOARD=${BOARD:-rockpro64}
		BUILD_ARGS="BOARD=${BOARD} KERNEL_ONLY=no KERNEL_CONFIGURE=no RELEASE=stretch BRANCH=default BUILD_DESKTOP=no WIREGUARD=no LIB_TAG=sunxi-4.20"
		if [ "${ACTION}" == "build" ]; then
			vagrant ssh -c "cd armbian/ && sudo time ./compile.sh ${BUILD_ARGS}"
		else
			BUILD_ARGS="${BUILD_ARGS} CLEAN_LEVEL=oldcache PROGRESS_LOG_TO_FILE=yes"
			vagrant ssh -c "cd armbian/ && sudo time ./compile.sh ${BUILD_ARGS}"
		fi
		;;

	clean)
		set +e
		if [ -d "armbian-build" ]; then
			cd armbian-build
			vagrant halt 
			vagrant destroy -f
			cd ..
			rm -rf armbian-build
		fi
		;;
esac
