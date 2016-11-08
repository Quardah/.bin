#taken from linrunner's TLP project https://github.com/linrunner/TLP
poweroff_drivebay () { # power off optical drive in drive bay
    # $1: 0=conditional+quiet mode, 1=force+verbose mode
    # Some code adapted from http://www.thinkwiki.org/wiki/How_to_hotswap_UltraBay_devices

    local optdrv syspath

    # Run only if either explicitly enabled or forced
    [ "$BAY_POWEROFF_ON_BAT" = "1" ] || [ "$1" = "1" ] || return 0

    get_drivebay_device
    if [ -z "$dock" ] || [ ! -d "$dock" ]; then
        echo_debug "pm" "poweroff_drivebay.no_bay_device"
        [ "$1" = "1" ] && echo "Error: cannot locate bay device." 1>&2
        return 1
    fi
    echo_debug "pm" "poweroff_drivebay: dock=$dock"

    # Check if bay is occupied
    if ! check_is_docked; then
        echo_debug "pm" "poweroff_drivebay.drive_already_off"
        [ "$1" = "1" ] && echo "No drive in bay (or power already off)."
    else
        # Check for optical drive
        optdrv=/dev/${BAY_DEVICE:=sr0}
        if [ ! -b "$optdrv" ]; then
            echo_debug "pm" "poweroff_drivebay.no_opt_drive: $optdrv"
            [ "$1" = "1" ] && echo "No optical drive in bay ($optdrv)."
            return 0
        else
            echo_debug "pm" "poweroff_drivebay: optdrv=$optdrv"

            echo -n "Powering off drive bay..."

            # Unmount media
            umount -l $optdrv > /dev/null 2>&1

            # Sync drive
            sync
            sleep 1

            # Power off drive
            $HDPARM -Y $optdrv > /dev/null 2>&1
            sleep 5

            # Unregister scsi device
            if syspath="$($UDEVADM info --query=path --name=$optdrv)"; then
                syspath="/sys${syspath%/block/*}"

                if [ "$syspath" != "/sys" ]; then
                    echo_debug "pm" "poweroff_drivebay: syspath=$syspath"
                    echo 1 > $syspath/delete
                else
                    echo_debug "pm" "poweroff_drivebay: got empty/invalid syspath for $optdrv"
                fi
            else
                echo_debug "pm" "poweroff_drivebay: failed to get syspath (udevadm returned $?)"
            fi

            # Turn power off
            echo 1 > $dock/undock
            [ "$1" = "1" ] && echo "done."
            echo_debug "pm" "poweroff_drivebay.bay_powered_off"
        fi
    fi

    return 0
}

# --- Drive Bay

get_drivebay_device () { # Find generic dock interface for drive bay
                         # rc: 0; retval: $dock
	dock=$(grep -l ata_bay $DOCKGLOB/type 2> /dev/null)
	dock=${dock%%/type}
	if [ ! -d "$dock" ]; then
		dock=""
	fi

    return 0
}

check_is_docked() { # check if $dock is docked;
                    # rc: 0 if docked, else 1

   local dock_status dock_info_file

   # return 0 if any sysfs file indicates "docked"
   for dock_info_file in docked firmware_node/status; do
        if [ -f $dock/$dock_info_file ] && \
            read -r dock_status < $dock/$dock_info_file 2>/dev/null; then
            # catch empty $dock_status (safety check, unlikely case)
            [ "${dock_status:-0}" != "0" ] && return 0
        fi
   done

   # otherwise assume "not docked"
   return 1
}