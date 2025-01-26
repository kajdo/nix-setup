//Modify this file to change what commands output to your statusbar, and recompile using the make command.
static const Block blocks[] = {
	/*Icon*/	/*Command*/		/*Update Interval*/	/*Update Signal*/
	/*{"Mem:", "free -h | awk '/^Mem/ { print $3\"/\"$2 }' | sed s/i//g",	30,		0},*/

	/*{"", "date '+%b %d (%a) %I:%M%p'",					5,		0},*/
	/*{"󰃭 ", "date '+%Y-%m-%d %H:%M'",					5,		0},*/
	{"", "get_battery_block",					1,		0},
	/*{"󰃭 ", "date '+%Y-%m-%d'",					5,		0},*/
	{"󰸗 ", "date '+%b %d'",					5,		0},
	{"󰥔 ", "date '+%H:%M'",					5,		0},
	{"", "get_volume_block",					1,		0},
	{"", "get_bluetooth_block",					5,		0},
	/*{"|", "",					0,		0},*/
	/*{"", "dwmblocks-wifi",				5,		0},*/
};

//sets delimiter between status commands. NULL character ('\0') means no delimiter.
/*static char delim[] = " | ";*/
static char delim[] = " ";
static unsigned int delimLen = 5;
