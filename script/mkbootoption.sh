#
#  File: mkbootoption.sh
#
#  bootoption © vulgo 2017 - A program to create / save an EFI boot
#  option - so that it might be added to the firmware menu later
#
#  mkbootoption.sh - script to add a boot option to firmware
#  * note 1: hardware syncs unreliably even with 'native' nvram
#  * note 2: nvram -s option may help with 1
#  * note 3: unrestricted nvram should be set in CSR flags
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

cd "$(dirname "$0")"
BOOTOPTION=./bootoption
EFI_GLOBAL_GUID="8BE4DF61-93CA-11D2-AA0D-00E098032B8C"
NVRAM=/usr/sbin/nvram
EMPTY_BOOT_VARIABLE_WITH_GUID="none"

function usage {
        echo "Usage: $(basename $0) \"path\" \"description\""
        echo "     required parameters:"
        echo "     path                  path to an EFI executable"
        echo "     description           description for the new boot menu entry"
}

function error {
        # error message exit_code
        echo
        printf "Error: $1 ($2)\n"
        usage
        exit 1
}

function on_error {
        # on_error message exit_code
        if [ $2 -ne 0 ]; then
                error "$1" $2
        fi
}

function silent {
        "$@" > /dev/null 2>&1
}

if [ "$(id -u)" != "0" ]; then
        printf "Run it as root: sudo $(basename $0) $@"
        exit 1
fi

if [ "$#" != "2" ]; then
        usage
        exit 1
fi

DATA=$($BOOTOPTION -p "$1" -d "$2" -f)
on_error "Failed to generate NVRAM variable as formatted string" $?
for i in $(seq 0 255); do
        EFI_VARIABLE_NAME=$(printf "Boot%04X\n" "$i")
        TEST="$EFI_GLOBAL_GUID:$EFI_VARIABLE_NAME"
        silent $NVRAM -p $TEST
        if [ "$?" != "0" ]; then
                EMPTY_BOOT_VARIABLE_WITH_GUID=$TEST
                break
        fi
done
if [ $EMPTY_BOOT_VARIABLE_WITH_GUID = "none" ]; then
        error "Couldn't find an empty boot variable to write to" 1; fi
$NVRAM -d "$EMPTY_BOOT_VARIABLE_WITH_GUID"
# Setting with -s option creates IONVRAM-FORCESYNCNOW
# -PROPERTY - storing the name of our variable
$NVRAM -s "$EMPTY_BOOT_VARIABLE_WITH_GUID=$DATA"
on_error "Failed to set boot variable" $?
# with -s as the only option, syncs the option named
# in IONVRAM-FORCESYNCNOW-PROPERTY - any difference?
$NVRAM -s
on_error "Error running nvram force-sync option" $?
echo "Variable $EMPTY_BOOT_VARIABLE_WITH_GUID was set."
echo "You can check if it really exists in firmware settings..."
exit 0
