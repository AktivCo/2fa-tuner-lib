function show_list()
{
	local title="$1"
	local column="$2"
	local list="$3"
	local extra_cmd="$4"
	
	echo -e "$list" > list
	
	if [[ -z "$extra_cmd" ]]
	then
		choice=`python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" LIST --title "$title" --column "$column" < list`
	else
		choice=`python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" LIST --title "$title" --column "$column" --extra "$extra_cmd" < list`
	fi
	ret=$?
	echo "$choice"
	return $ret 
}

function get_string ()
{
        title="$1"
        msg="$2"
	default="$3"
        
	string=`python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" GET_STRING --title "$title" --text "$msg" --default "$default"`;
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
        checks="$5"
	checksDefault="$6"
	form=`python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" SHOW_FORM --title "$title" --text "$msg" --asks "$asks" --default="$default" --checks="$checks" --checks-default="$checksDefault"`;
        ret=$?
	echo -e "$form"
        return $ret
}

function get_password ()
{
        title="$1"
        msg="$2"
        pin=`python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" GET_PASS --title "$title" --text "$msg"`;
        ret=$?
        echo -e "$pin"
        return $ret
}

function show_text_dialog ()
{
	title="$1"
	text="$2"
        python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" SHOW_TEXT --title "$title" --text "$text"
}

function yesno ()
{
	title="$1"
	text="$2"
	python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" YESNO --title "$title" --text "$text"
	return $?
}

function show_wait_dialog()
{
        title="$1"
        text="$2"
        python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" SHOW_WAIT --title "$title" --text "$text"
}

function save_file_dialog()
{
	title="$1"
	text="$2"
	start_dir="$3"
	python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" SAVE_FILE --title "$title" --text "$text" --start_dir "$start_dir"
	return $?
}

function open_file_dialog()
{
        title="$1"
        text="$2"
        start_dir="$3"
        python3 "$TWO_FA_LIB_DIR/python_utils/gui_dialog.py" OPEN_FILE --title "$title" --text "$text" --start_dir "$start_dir"
        return $?
}

function dialog_manager_enabeled()
{
	python3 -c "import tkinter" 2> /dev/null	
	return $?
}
