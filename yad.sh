function show_list()
{
	local title="$1"
	local column="$2"
	local list="$3"
	echo -e "$list" > list
	choice=`$YAD --title "$title" --list --separator '' --column "$column" < list`
	ret=$?
	echo "$choice"
	return $ret 
}

function get_password ()
{
        title="$1"
        msg="$2"
        pin=`yad --title "$title" --text "$msg" --entry --hide-text `;
        echo $pin
}

function show_text ()
{
	title="$1"
	text="$2"
        $YAD --title "$title" --text "$text" --no-markup
}

