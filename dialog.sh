DIALOG="dialog --keep-tite --stdout"

function show_list ()
{
        local title="$1"
        local columns="    #  $2"
        local list="$3"
	local extra="$4"
	if [[ "$list" && "$extra" ]] 
	then
		list=`echo -e "$list\n$extra"`
	fi

	if [[ -z "$list" && "$extra" ]]
	then
		list="$extra"
	fi

	echo -e "$list" > list
	END=`cat list | wc -l`
        for ((i=1;i<=END;i++)); do     echo $i; done > nums

	local id=`paste -d "\n" nums list | tr "\n" "\0" | xargs -0 $DIALOG --title "$title" --no-collapse --menu "$columns" 0 0 0`;
	if [[ -z "$id" ]]
	then
		return 255
	fi

	local elem=`echo -e "$list" | sed "${id}q;d"`;
	echo -e "$elem"
	return $res
}

function get_password ()
{
	title="$1"
	msg="$2"
	pin=`$DIALOG --title "$title"  --passwordbox "$msg" 0 0 ""`;
	res=$?
	echo "$pin"
	return $res
}

function show_text_dialog ()
{
	title="$1"
	text="$2"
	
	$DIALOG --title "$title" --no-nl-expand --msgbox "$text" 0 0
	return $?
}

function yesno ()
{
        title="$1"
        text="$2"

        $DIALOG --title "$title" --no-nl-expand --yesno "$text" 0 0

	return $?
}

function show_wait_dialog ()
{
        show_text "$1" "$2"
	return $?
}

function get_string ()
{
        title="$1"
        msg="$2"
	default="$3"
        string=`$DIALOG --title "$title"  --inputbox "$msg" 0 0 "$default"`;
        ret=$?
	echo -e "$string"
	return $ret
}

function show_form ()
{
        title="$1"
        msg="$2"
	asks="$3"
	default="$4"

	echo -e "$asks" > asks
	echo -e "$default" > defaults
	
	END=`cat asks | wc -l`
	
	for ((i=1;i<=END;i++)); do     echo $i; done > nums
	for ((i=1;i<=END;i++)); do     echo 1; done > ones
	for ((i=1;i<=END;i++)); do     echo 2; done > twoes
	for ((i=1;i<=END;i++)); do     echo 30; done > lens
	form=`paste asks nums ones defaults nums lens lens lens | tr '\n\t' '\0\0' | xargs -0 $DIALOG --title "$title" --form "$msg" 0 0 0`

	if [[ -z "$form" ]]
	then
		return 255
	fi

        ret=$?
	echo -e "$form"
        return $ret
}

function save_file_dialog()
{
	title="$1"
	text="$2"
	start_dir="$3"
	file=`$DIALOG  --title "$title" --fselect "$start_dir" 14 48`
	res=$?
	echo -e "$file"
	return $res
}

function open_file_dialog()
{
        title="$1"
        text="$2"
        start_dir="$3"
	file=`$DIALOG  --title "$title" --fselect "$start_dir" 14 48`
	res=$?
	echo -e "$file"
	return $res
}

function dialog_manager_enabeled()
{
	dialog --help > /dev/null
	return $?
}
