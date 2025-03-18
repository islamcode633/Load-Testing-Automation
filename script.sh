#!/bin/bash
###################################################################
# Name           :Gashimov Islam
# Version        :Linux 6.5.0-25-generic Ubunta 22.04 LTS
# Description    :Update/Install/CheckPacks/Logging about hardware
#                 Load test/output of init devices in stdout
# Email          :gashimov.islam@bk.ru
# Program version: v3.4
###################################################################

# -----------
# TABLE CODE:
# -----------
# Arguments were not passed -> exit 1
# Correctly completed mode -d -> exit 63
# Display_Help -> exit 64
# Script version -> eixt 65
# Script mode not selected -> exit 67
# ---
# sysbench() exit 68 -> Not Correct Flag
#                 70 -> passed cpu test
#                 71 -> passed memory test
#                 72 -> passed fileio test
#   END Block


SCRIPT_VERSION="$0 - ver: 3.4"
PACKAGES=(" lshw inxi stress-ng cpuid \
			p7zip-full p7zip-rar hwinfo \
			smartmontools sysbench mbw lsscsi ethtool" )


function Interrupt_Execution {
	echo " ---> Script terminated !"
	exit 1
}


function Update_Repository {
	## The function overwrites source.list and indexes packages
	## Global var: No                  Options: No
	## Local var: apt_source_list      Return object: No

	local apt_source_list=/etc/apt/sources.list
	{
		echo deb http://ru.archive.ubuntu.com/ubuntu/ jammy main restricted
		echo deb http://ru.archive.ubuntu.com/ubuntu/ jammy-updates main restricted
		echo deb http://ru.archive.ubuntu.com/ubuntu/ jammy universe
		echo deb http://ru.archive.ubuntu.com/ubuntu/ jammy multiverse
	} >"$apt_source_list" && apt update
} 2>/dev/null


function Install_Utils {
	## The function installs the necessary utilities
	## Additional hddtemp installation
	## Global var: No                  Options: "$@" - utils
	## Local var: No                   Return object: No

	apt install "$@" -y

	[[ ! -f hddtemp_0.3-beta15-53_amd64.deb ]] && {
		wget http://archive.ubuntu.com/ubuntu/pool/universe/h/hddtemp/hddtemp_0.3-beta15-53_amd64.deb
		apt install ./hddtemp_0.3-beta15-53_amd64.deb &&
			echo -ne "hddtemp		--------------------------------------------------	[ OK ] \n"
	}
}


function Checking_Installed_Packages {
	## The function checks whether all necessary packages have been installed
	## in the required directories
	## Global var: No                                                                    Options: "$@" - downloaded packages
	## Local var: count_packages, package, name_installed_package, path_to_binary_file   Return object: No

	local -i count_packages=0
	for package in "$@"; do
		name_installed_package="$(grep -i "$package" <(dpkg -l) | cut -d' ' -f3)"
		path_to_binary_file="$(command -v "$package")"
		[[ -n "$name_installed_package" || -n "$path_to_binary_file" ]] && {
			((count_packages += 1))
			echo "Package installed: $package"
			continue
		}
		echo "Package not installed: $package"
	done
	echo "[SUM] of $# packages installed $count_packages"
	echo ""

	unset -v "package" "count_packages" "name_installed_package" "path_to_binary_file"
}


function Update_Inst_CheckPack {
	# --- Update mode ---
	# Update/Install/Checking installed Packages

	Update_Repository
	Install_Utils ${PACKAGES[@]}
	Checking_Installed_Packages ${PACKAGES[@]} "hddtemp"
}


function Data_Formatting {

	local ALL_DEVICES_INIT
	ALL_DEVICES_INIT=" Number of Initialized Devices"

	local SOME_DEVICES_NOT_INIT
	SOME_DEVICES_NOT_INIT=" Initialization of Devices Failed"

	function Block_Print {
		## This function compares two numbers
		## Global var: No                              Options: Yes
		## Local var: block_name, separator_string     Return object: No

		block_name="$1"

		for ((i = 0; i <= (${#block_name} + 3); i++)); do
			separator_string+='*'
		done

		echo " $separator_string"
		printf " * %s *\n" "$block_name"
		echo " $separator_string"

		unset -v "block_name" "separator_string"
	}

	function Check_Equality_Numbers {
		## This function compares two numbers
		## Global var: ALL_DEVICES_INIT, SOME_DEVICES_NOT_INIT	                Options: Yes
		## Local var: count_initialized_devices, sum_initialized_devices       Return object: No

		count_initialized_devices=$1
		sum_initialized_devices=$2

		if ((count_initialized_devices = sum_initialized_devices)); then
			Color_Print "$ALL_DEVICES_INIT" "$count_initialized_devices" "of $sum_initialized_devices"
		else
			Color_Print "" "$SOME_DEVICES_NOT_INIT" "$count_initialized_devices" "of $sum_initialized_devices"
		fi
	}

	function Color_Print {
		## This function print data to stdout
		##                                          Options: YES
		## Local var: response, error_message      Return object: CodeError 1
		##            count, amount_init

		response="$1"
		if [[ "$response" != "" ]]; then
			printf "[ \e[32mOK\e[0m ] %s %s %s\n" "$1" "$2" "$3"
			return
		fi

		error_message="$2"
		count="$3"
		amount_init="$4"
		printf "[ \e[31mNO\e[0m ] %s %s %s\n" "$error_message" "$count" "$amount_init"
		return 1
	}

	function fmt_EthInterfaces {
		## This function parses network interface names and outputs metadata
		##                                                              Options: No
		## Local var: eth_devices, log_name, mac_addr, speed           Return object: No
		##            num_init_eth_devices, amount_eth_devices

		Block_Print Ethernet
		eth_devices=$(ls /sys/class/net/ | grep -v lo)

		for log_name in $eth_devices; do
			mac_addr="$(ethtool -P "$log_name" | cut -d' ' -f3)"
			speed="$(ethtool "$log_name" | grep -i speed | cut -d' ' -f2)"
			Color_Print "$log_name" "$mac_addr" "$speed"
			((num_init_eth_devices += 1))
			sleep 0.3
		done

		amount_eth_devices=$(ls /sys/class/net/ | grep -v lo | wc -w)
		Check_Equality_Numbers "$num_init_eth_devices" "$amount_eth_devices"

		echo
		unset -v "eth_devices" "logname" "mac_addr" "speed" "num_init_eth_devices" "amount_eth_devices"
	}

	function fmt_MemorySlots {
		## This function print initialized memory slots to stdout
		##                                                          Options: No
		## Local var: num_init_mem_slot, amount_mem_slots          Return object: No

		Block_Print Memory

		# AWK arg $8 for server!
		amount_mem_slots=$(awk \{'print $8'\} <(inxi -m | grep -i slots:))
		for ((num_init_mem_slot = 1; num_init_mem_slot <= amount_mem_slots; num_init_mem_slot++)); do
			Color_Print "$(inxi -m | grep -i "device-$num_init_mem_slot:")"
			sleep 0.3
		done
		((num_init_mem_slot -= 1))

		Check_Equality_Numbers "$num_init_mem_slot" "$amount_mem_slots"

		echo
		unset -v "num_init_mem_slot" "amount_mem_slots"
	}

	function fmt_Bios {
		## This function print the bios version

		Block_Print BIOS
		Color_Print "$(dmidecode -t 0 | grep -i "bios revision")"
		echo
	}

	function fmt_UsbDevices {
		## This function display the number of USB devices         Options: No
		## Local var: num_init_usb_devices, amount_usb_devices     Return object: No

		Block_Print USB

		while read -r; do
			Color_Print "$REPLY"
			sleep 0.3
			((num_init_usb_devices += 1))
		done < <(lsusb | grep -iE "bus [0-9]{3} device")

		amount_usb_devices=$(lsusb | wc -l)
		Check_Equality_Numbers "$num_init_usb_devices" "$amount_usb_devices"

		sleep 1
		lsusb -tv

		unset -v "num_init_usb_devices" "amount_usb_devices"
	}

	function fmt_PciDevices {
		## This function parses PCI devices names and outputs metadata
		## Global var: REPLY                                       Options: No
		## Local var: num_init_pci_devices, amount_pci_devices     Return object: No

		Block_Print PCI

		while read -r; do
			Color_Print "$REPLY"
			((num_init_pci_devices += 1))
			sleep 0.3
		done < <(lspci)

		amount_pci_devices=$(lspci | wc -l)
		Check_Equality_Numbers "$num_init_pci_devices" "$amount_pci_devices"

		unset -v "num_init_pci_devices" "amount_pci_devices"
	}

	function fmt_Disks {
		## This function parses the elements of the disk system
		## and outputs metadata
		## Global var: REPLY                                          Options: No
		## Local var: num_init_disks_devices,amount_disks_devices     Return object: No

		Block_Print Disk

		while read -r; do
			Color_Print "$REPLY"
			((num_init_disks_devices += 1))
			sleep 0.3
		done < <(lsblk -S)

		amount_disks_devices=$(ls /sys/class/block/ | grep -vE "sd[a-z][1-9]|nvme[0-9][a-z][1-9][a-z][1-9]|loop" | wc -w)
		Check_Equality_Numbers "$num_init_disks_devices" "$amount_disks_devices"

		unset -v "num_init_disks_devices" "amount_disks_devices"
	}

	fmt_EthInterfaces
	fmt_MemorySlots
	fmt_Bios
	fmt_UsbDevices
	fmt_PciDevices
	fmt_Disks
}


function System_Info {

	local PRODUCT_NAME
	PRODUCT_NAME="$(dmidecode -t baseboard | cut -d' ' -f3-4 <(grep -i "product name"))"

	local SERIAL_NUMBER
	SERIAL_NUMBER="$(dmidecode -t baseboard | cut -d' ' -f3 <(grep -i "serial number"))"

	local WORK_DIR
	WORK_DIR="$(pwd)/$PRODUCT_NAME/$SERIAL_NUMBER"

	if [[ -d "$WORK_DIR" ]]; then
		rm -f "$WORK_DIR/"*
	else
		mkdir -p "$WORK_DIR"
	fi

	function getinfo_fromDMItable {
		##	This function collects data about devices with DMI tables

		dmidecode >dmidecode.txt
		dmidecode -t 2 >serial.txt
		dmidecode | grep -i "bios revision" >>serial.txt
		dmidecode -t 16 -t 17 >memory.txt
	}

	function getinfo_Disks {
		## This function collects info about disks

		fdisk -x >disks.txt

		for logic_name_disk in $(ls /sys/block/ | grep -v loop*); do
			hddtemp /dev/"$logic_name_disk" | grep -v "not" >temp_disks.txt
			smartctl -a /dev/"$logic_name_disk" | grep -iE "device model|serial" >serial_disks.txt
		done 2>/dev/null

		unset "logic_name_disk"
	}

	function get_HWinfo {
		## This function collects info about hardware

		lshw >hardware_info.txt
		lsusb -v >usb.txt
		lspci -vvv >pci.txt
		cpuid >cpuid.txt
		lsscsi -d -s >lsscsi.txt
		sensors >sensors.txt

		for eth_interface in $(ls /sys/class/net/ | grep -v "lo"); do
			printf "%s -> %s\n" "$eth_interface" "$(ethtool -P "$eth_interface" | awk '{print $3}')"
		done >eth_mac.txt

		unset "eth_interface"
	}

	getinfo_fromDMItable
	getinfo_Disks
	get_HWinfo

	mv *.txt "$WORK_DIR"
}


function Garbage_Collector {
	## This function removes unnecessary files after
	## running sysbench/stress-ng utilities

	find . -maxdepth 1 -iname "test_file.*" -or -iname "tmp-stress-ng*" | xargs rm -rf
}


function Stress_Test {
	## The function conducts load tests of all system components
	## CPU/Memory/Disk/Bus/Network/IO
	## Global var: No                                               Options: No
	## Local var: size_ram=All RAM, half_usage_ram=50% of RAM,     Return object: No
	## ########## load=thread/system calls, time=sec

	local -i iter=1
	for ((i = 0; i < iter; i++)); do
		7z b -mm=*
	done

	local -i load=100
	local -i time=90
	stress-ng \
		-c 0 -m 0 -d 0 -i 0 \
		-f $load -u $load --pci $load --memcpy $load \
		--mcontend $load --matrix $load --malloc $load --kvm $load \
		--hash $load -C 0 -B 0 -t $time --tz --metrics-brief

	ping -c 15 ya.ru

	local -i size_ram
	local -i half_usage_ram
	size_ram=$(sudo hwinfo --memory | grep -i "memory size" | awk \{'print $3'\})
	((half_usage_ram = (((size_ram * 50) / 100) * 1000) / 2))
	mbw -n 10 "$half_usage_ram"

	sysbench cpu --threads=100 --cpu-max-prime=20000 --time=$time run
	sysbench memory --memory-block-size=16384 --time=$time run
	sysbench fileio --file-num=512 --file-block-size=65536 --file-test-mode=seqwr --time=$time run
	Garbage_Collector

	unset -v "iter" "size_ram" "half_usage_ram" "load" "time"
}


function Wrapp_Sysbench {
	##	The function performs load tests CPU/MEMORY/FILEIO
	##	Global var: $@

	device_class="$2"
	shift 2
	while getopts ":-:" OPTION; do
		# shellcheck disable=SC2220
		case "$OPTION" in
		-)
			case "$OPTARG" in
				# for cpu mode:
				threads=*) threads=${OPTARG#threads=} ;;
				cpu-max-prime=*) cpu_max_prime=${OPTARG#cpu-max-prime=} ;;
				# for memory mode:
				memory-block-size=*) memory_block_size=${OPTARG#memory-block-size=} ;;
				memory-total-size=*) memory_total_size=${OPTARG#memory-total-size=} ;;
				memory-operation=*) memory_operation=${OPTARG#memory-operation=} ;;
				# for fileio mode:
				file-num=*) file_num=${OPTARG#file-num=} ;;
				file-total-size=*) file_total_size=${OPTARG#file-total-size=} ;;
				file-test-mode=*) file_test_mode=${OPTARG#file-test-mode=} ;;
				time=*) time=${OPTARG#time=} ;;
				*)
					printf "[ \e[31mError:\e[0m ] Not Correct Flag!\n" 1>&2
					exit 68
					;;
			esac
			;;
		esac
	done

	[[ "$device_class" == "cpu" ]] && {
		sysbench cpu --threads="$threads" --cpu-max-prime="$cpu_max_prime" \
					 --time="$time" run
		exit 70
	}

	[[ "$device_class" == "memory" ]] && {
		sysbench memory --memory-block-size="$memory_block_size" \
						--memory-total-size="$memory_total_size" \
						--memory-oper="$memory_operation" --time="$time" run
		exit 71
	}

	[[ "$device_class" == "fileio" ]] && {
		sysbench fileio --file-num="$file_num" \
						--file-total-size="$file_total_size" \
						--file-test-mode="$file_test_mode" --time="$time" run
		Garbage_Collector
		exit 72
	}
}


function Display_Help {
	## This function displays information about script launch modes
	## load utilities launch rule.

	# Syntax and Mode support
	cat <<-EoH
		Options:
		     Usage syntax: script.sh [ -u/-t/-d ] The script must be passed the correct Arg
		        -u   Starting a repository update
		        -l   Collecting system information
		        -t   Launch load testing
		        -f   Output information about init devices
		        -d
		            runs in the following order:
		                1) system update/install and verification of packages
		                2) output of init devices
		                3) collection of info about the system(logs)
		                4) load tests

		        -h | Provides info about the script operation
		        -v | Output the current version of the script
		Example:
		        script.sh -u -l
		        script.sh -f -d
		        script.sh -u -l -t -f equality script.sh -d
		        Used separately from other flags script.sh -h/--help or -v/--version
	EoH
	echo
	# Rule of using sysbench
	cat <<-EoH
		Describe:
		    Usage syntax: script.sh [ sysbench cpu/memory/fileio --flags ] where flags must have. Key word
		    sysbench, device class [cpu/memory/fileio] must be specified,
		    to perform a load test!
		Example:
		    sysbench cpu --threads=100 --cpu-max-prime=10000 --time=180

		    sysbench memory --memory-block-size=128K --memory-total-size=1024G
                            --memory-oper={write,read,none} --time=360

		    sysbench fileio --file-num=512 --file-total-size=128G
                            --file-test-mode=seqwr --time=360
	EoH
}

	# No Args
	(($# < 1)) && {
		echo "Pass at least one Argument!"
		exit 1
	}

	printf -v start '%(%d-%m-%Y %H:%M:%S)T' '-1'
	### --- Abort work script --- ###
	trap Interrupt_Execution SIGINT

	# Parsing args
	for option in "$@"; do
		case $option in
			-u ) Update_Inst_CheckPack ;;
			-f ) Data_Formatting ;;
			-l ) System_Info ;;
			-t ) Stress_Test ;;
			sysbench ) Wrapp_Sysbench "$@" ;;
			-d )
				Update_Inst_CheckPack
				# --- Default mode ---
				### --- Formatting data in stdout --- ###
				Data_Formatting
				### --- Getting  about system info --- ###
				System_Info
				### --- Load tests --- ###
				Stress_Test
				exit 63
				;;
			-h )
				### --- Help about interfaces --- ###
				Display_Help
				exit 64
				;;
			-v )
				echo "$SCRIPT_VERSION"
				exit 65
				;;
			* )
				# code 67 indicates an invalid arg passed to the script
				echo "Script mode not selected !"
				exit 67
				;;
		esac
		shift
	done

	printf -v end '%(%H:%M:%S)T' '-1' ; echo "$start" "$end"
	unset -v "start" "end"
