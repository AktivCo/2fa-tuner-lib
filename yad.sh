function show_list()
{
	local title="$1"
	local column="$2"
	local list="$3"
	
	list=`echo -e "$list" | sed -r "s/\t/\n/g"`
	echo -e "$list" > list
	
	column=`echo -e "$column" | sed -r "s/\t/ --column /g"`
	
	choice=`$YAD --title "$title" --list --separator '	' --column $column < list`
	ret=$?
	echo "${choice:0:-1}"
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
        $SIMPLE_YAD --title "$title" --text "$text" --no-markup
}

function yesno ()
{
	title="$1"
	text="$2"
	$SIMPLE_YAD --title "$title" --text "$text" --no-markup --button=gtk-yes:0 --button=gtk-no:1 
}
