function show_list()
{
	local title="$1"
	local column="$2"
	local list="$3"
	local extra_name="$4"
	local extra_cmd="$5"
	
	echo -e "$list" > list
	
	column=`echo -e "$column" | sed -r "s/\t/ --column /g"`
	
	if [[ -z "$extra_name" ]]
	then
		choice=`python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py LIST --title "$title" --column $column < list`
	else
		choice=`python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py LIST --title "$title" --column $column --extra "$extra_name" "$extra_cmd" < list`
	fi
	ret=$?
	echo "$choice"
	return $ret 
}

function get_password ()
{
        title="$1"
        msg="$2"
        pin=`python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py GET_PASS --title "$title" --text "$msg"`;
        ret=$?
	echo $pin
	return $ret
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
	return $?
}

function show_wait_dialog()
{
        title="$1"
        text="$2"
        python3 $TWO_FA_LIB_DIR/python_utils/gui_dialog.py SHOW_WAIT --title "$title" --text "$text"
}

function dialog_manager_enabeled()
{
	python3 -c "import tkinter" 2> /dev/null	
	return $?
}
