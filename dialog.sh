function show_list ()
{
        local title="$1"
        local columns="    #  $2"
        local list="$3"

	local list=`echo -e "$list" | awk '{printf("%s\t\"%s\"\n", NR, $0)}'`;
	local id=`echo -e "$list" | xargs $DIALOG --title "$title" --no-collapse --menu "$columns" 0 0 0`;
        local elem=`echo -e "$list" | sed "${id}q;d" | cut -f2 -d$'\t'`;
	echo `echo "${elem:1:-1}"`
	#TODO return code
	return 0
}

function get_password ()
{
	title="$1"
	msg="$2"
	pin=`$DIALOG --title "$title"  --passwordbox "$msg" 0 0 ""`;
	echo "$pin"
}

function show_text ()
{
	title="$1"
	text="$2"
	
	$DIALOG --title "$title" --no-nl-expand --msgbox "$text" 0 0
}
