#!/bin/sh
# tlp - adjust power settings
#
# Copyright (c) 2016 Thomas Koch <linrunner at gmx.net>
# This software is licensed under the GPL v2 or later.

test_root () { # test root privilege -- rc: 0=root, 1=not root
    [ "$(id -u)" = "0" ]
}

check_root () { # show error message and exit when root privilege missing
    if ! test_root; then
        echo "Error: missing root privilege." 1>&2
        exit 1
    fi
}

get_drivebay_device () { # Find generic dock interface for drive bay
    # rc: 0; retval: $dock
    dock=$(grep -l ata_bay /sys/devices/platform/dock.?/type 2> /dev/null)
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

poweroff_drivebay () { # power off optical drive in drive bay
    local optdrv syspath

    get_drivebay_device
    if [ -z "$dock" ] || [ ! -d "$dock" ]; then
        echo "Error: cannot locate bay device." 1>&2
        return 1
    fi

    # Check if bay is occupied
    if ! check_is_docked; then
        echo "No drive in bay (or power already off)."
    else
        # Check for optical drive
        optdrv=/dev/${BAY_DEVICE:=sr0}
        if [ ! -b "$optdrv" ]; then
            echo "No optical drive in bay ($optdrv)."
            return 0
        fi

        echo -n "Powering off drive bay..."

        # Unmount media
        umount -l $optdrv > /dev/null 2>&1

        # Sync drive
        sync
        sleep 1

        # Power off drive
        hdparm -Y $optdrv > /dev/null 2>&1
        sleep 5

        # Unregister scsi device
        if syspath="$(udevadm info --query=path --name=$optdrv)"; then
            syspath="/sys${syspath%/block/*}"

            if [ "$syspath" != "/sys" ]; then
                echo 1 > $syspath/delete
            fi
        fi

        # Turn power off
        echo 1 > $dock/undock
        echo "done."
    fi

    return 0
}

check_root
poweroff_drivebay

exit 0