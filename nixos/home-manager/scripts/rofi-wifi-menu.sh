#!/usr/bin/env bash

MAX_SSID_LENGTH=20
TRUNCATE_LENGTH=$((MAX_SSID_LENGTH - 3))

nmcli -t d wifi rescan
LIST=$(nmcli --fields SSID,SECURITY,BARS device wifi list | sed '/^--/d' | sed 1d | sed -E "s/WPA*.?\S/~~/g" | sed "s/~~ ~~/~~/g;s/802\.1X//g;s/--/~~/g;s/  *~/~/g;s/~  */~/g;s/_/ /g" | awk -F'~' -v max_len="$MAX_SSID_LENGTH" -v trunc_len="$TRUNCATE_LENGTH" '{if(length($1)>max_len) $1=substr($1,1,trunc_len)"..."; printf "%-"max_len"s  %-1s %-6s\n", $1, $2, $3}')

# get current connection status
CONSTATE=$(nmcli -fields WIFI g)
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes" {print $2}')

ACTIVE_LINE=1
if [ -n "$CURRENT_SSID" ]; then
	LIST_LINE=$(echo "$LIST" | awk -v ssid="$CURRENT_SSID" 'BEGIN{found=0} $0 ~ "^" ssid {found=1; print NR; exit} END{if(!found) print 1}')
fi

HEADER_LINES=2
if [ -n "$CURRENT_SSID" ]; then
	HEADER_LINES=3
fi

ACTIVE_LINE=$((HEADER_LINES + LIST_LINE))

if [[ "$CONSTATE" =~ "enabled" ]]; then
	TOGGLE="Disable WiFi 睊"
	if [ -n "$CURRENT_SSID" ]; then
		DISCONNECT="Disconnect "
	fi
elif [[ "$CONSTATE" =~ "disabled" ]]; then
	TOGGLE="Enable WiFi 直"
fi

RESCAN="Rescan Networks "

echo "=== DEBUG: MENU CONTENTS ==="
echo -e "$TOGGLE\n$DISCONNECT\n$RESCAN\n$LIST" | uniq -u
echo "============================="

CHENTRY=$(echo -e "$TOGGLE\n$DISCONNECT\n$RESCAN\n$LIST" | uniq -u | rofi -dmenu -selected-row 1 -a "$ACTIVE_LINE" -config "./wifi-theme.rasi")
CHSSID=$(echo "$CHENTRY" | sed 's/\s\{2,\}/\|/g' | awk -F "|" '{print $1}')

if [ "$CHENTRY" = "" ]; then
	exit
elif [ "$CHENTRY" = "Enable WiFi 直" ]; then
	nmcli radio wifi on
elif [ "$CHENTRY" = "Disable WiFi 睊" ]; then
	nmcli radio wifi off
elif [ "$CHENTRY" = "Disconnect " ]; then
	nmcli con down "$CURRENT_SSID"
elif [ "$CHENTRY" = "Rescan Networks " ]; then
	echo "=== DEBUG: RECAN NETWORK TRIGGERED ===" >&2
	echo "=== DEBUG: Executing: nmcli -t d wifi rescan ===" >&2

	CURRENT_LIST=$(nmcli --fields SSID device wifi list | sed 1d)

	nmcli -t d wifi rescan
	EXIT_CODE=$?
	echo "=== DEBUG: nmcli rescan exit code: $EXIT_CODE ===" >&2

	echo "=== DEBUG: Polling for scan completion ===" >&2
	COUNT=0
	while [ $COUNT -lt 15 ]; do
		NEW_LIST=$(nmcli --fields SSID device wifi list | sed 1d)
		if [ "$NEW_LIST" != "$CURRENT_LIST" ]; then
			echo "=== DEBUG: Scan complete - list changed ===" >&2
			break
		fi
		sleep 1
		COUNT=$((COUNT + 1))
	done
	echo "=== DEBUG: Polling finished after $COUNT seconds ===" >&2

	notify-send "Wifi" "Scan finished"
else
	if [ "$CHSSID" = "*" ]; then
		CHSSID=$(echo "$CHENTRY" | sed 's/\s\{2,\}/\|/g' | awk -F "|" '{print $3}')
	fi

	if nmcli con up "$CHSSID" 2>/dev/null; then
		notify-send "Wifi" "Connected successfully"
		exit
	fi

	if [[ "$CHENTRY" =~ "" ]]; then
		WIFIPASS=$(echo "" | rofi -dmenu -p " WiFi Password: " -lines 1)
		if [ -n "$WIFIPASS" ]; then
			if nmcli dev wifi con "$CHSSID" password "$WIFIPASS"; then
				notify-send "Wifi" "Connection successful"
			else
				notify-send "Wifi" "Connection failed"
			fi
		else
			notify-send "Wifi" "Connection cancelled"
		fi
	fi
fi
