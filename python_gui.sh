function show_list()
{
	local title="$1"
	local column="$2"
	local list="$3"
	
	echo -e "$list" > list
	
	column=`echo -e "$column" | sed -r "s/\t/ --column /g"`
	
	choice=`python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py LIST --title "$title" --column $column < list`
	ret=$?
	echo "$choice"
	return $ret 
}

function get_password ()
{
        title="$1"
        msg="$2"
        pin=`python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py GET_PASS --title "$title" --text "$msg"`;
        echo $pin
}

function show_text ()
{
	title="$1"
	text="$2"
        python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py SHOW_TEXT --title "$title" --text "$text"
}

function yesno ()
{
	title="$1"
	text="$2"
	python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py YESNO --title "$title" --text "$text"
}
