#!/bin/bash

function check_pin()
{
	token=$1
	pin=$2
	echolog "check user pin for token:$token"
	
	out=`pkcs11-tool --module "$LIBRTPKCS11ECP" -l -p "$pin" --show-info --slot-description "$token" 2>&1`
	res=$?

	out=`echo -e "$out" | grep "CKR_PIN_LOCKED"`
	if [[ "$out" ]]
	then
		echoerr "pin locked"
		return 2
	fi

	if [[ $res -ne 0 ]]
	then
		echoerr "incorrect pin\n$out"
	else
		echolog "correct pin"
	fi

	return $res
}

function check_admin_pin()
{
        token=$1
        pin=$2
	echolog "check admin pin for token:$token"

        out=`pkcs11-tool --module "$LIBRTPKCS11ECP" -l --so-pin "$pin" --login-type so --show-info --slot-description "$token" 2>&1`
        res=$?
        out=`echo -e "$out" | grep "CKR_PIN_LOCKED"`
        if ! [[ -z "$out" ]]
        then
		echoerr "pin locked"
                return 2
        fi

	if [[ $res -ne 0 ]]
        then
                echoerr "incorrect pin\n$out"
        else
                echolog "correct pin"
        fi

        return $res
}

function import_obj_on_token ()
{
	token=$1
	type=$2
	path_to_obj=$3
	label=$4
	key_id=$5
	echolog "import object located by $path_to_obj with type: $type, id: $key_id, label:$label on token: $token "
	
	out=`pkcs11-tool --module "$LIBRTPKCS11ECP" -l -p "$PIN" -y "$type" -w "$path_to_obj" --id "$key_id" --label "$label" --slot-description "$token" 2>&1`
	if [[ $? -ne 0 ]]
	then
		echoerr "Can't import object on token:\n$out"
		return 1
	fi

	return 0
}

function get_key_list ()
{
	token="$1"
        echolog "get_key_list from token: $token"
	out=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type pubkey --slot-description "$token" 2>&1`
	if [[ $? -ne 0 ]]
        then
                echoerr "Error occured while getting key list:\n$out"
                return 1
        fi
        key_ids=`echo -e "$out" | grep -Eo "ID:.*" |  awk '{print $2}'`;
	echolog "Key list:\n$key_ids"
        echo "$key_ids";
	return 0
}

function get_cert_list ()
{
        token="$1"
        echolog "get_cert_list from token: $token"
        out=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type cert  --slot-description "$token" 2>&1`
        if [[ $? -ne 0 ]]
        then
                echoerr "Error occured while getting cert list:\n$out"
                return 1
        fi

        cert_ids=`echo -e "$out" | grep -Eo "ID:.*" |  awk '{print $2}'`;
        echo "$cert_ids";
        echolog "Cert list:\n$cert_ids"
        return 0
}

function pkcs11_gen_key ()
{
	token=$1
        key_id=$2
	type=$3
	label=$4

	echolog "pkcs11_gen_key of type: $type with id: $key_id and label: $label on token: $token"

	out=`pkcs11-tool --module "$LIBRTPKCS11ECP" --keypairgen --key-type "$type" -l -p "$PIN" --id "$key_id" --label "$label" --slot-description "$token" 2>&1`
	res=$?
	if [[ "`echo -e "$out" | grep "Unknown key type"`" ]]
	then
		echoerr "Тип ключа $type не поддерживается в системе"
		return 2
	fi

	if [[ $res -ne 0 ]]
	then
		echoerr "Error while creating key:\n$out"
	else
		echolog "Key is created successfully"
	fi
	
	return $res
}

function pkcs11_create_cert_req ()
{
	token="$1"
	key_id="$2"
	subj="$3"
	req_path="$4"
	selfsign="$5"
	key_usage="$6"

	echolog "pkcs11_create_cert_req for key_id: $key_id with subj: $subj by path: $req_path on token: $token. Cert is self_signed: $selfsign. keyUsage: $key_usage"

	key_id_ascii="`echo -e "$key_id" | sed 's/../%&/g'`"
	echolog "key_id in ascii encoding is $key_id_ascii"
	
	obj=`get_token_objects "$token" "privkey" "id" "$key_id"
	echolog "privkey for cert: $obj"`

	type=`get_object_attribute_value "$obj" "type"`
	echolog "privatekey type is $type"
	
	echolog "init pkcs11 engine for work"
	if [[ "$type" == "RSA"* ]]
	then
		engine_path="$PKCS11_ENGINE"
		engine_id=pkcs11
	else
		engine_path="$RTENGINE"
		engine_id=rtengine
	fi
	echolog "engine_path is $engine_path and engine_id is $engine_id"

	serial=`get_token_info "$token" "serial"`
	echolog "Token serial is $serial"
	
	keyUsage="$key_usage" envsubst < "$TWO_FA_LIB_DIR/common_files/openssl_ext.cnf" | tee openssl_ext.cnf > /dev/null

        openssl_req="engine dynamic -pre SO_PATH:"$engine_path" -pre ID:"$engine_id" -pre LIST_ADD:1  -pre LOAD -pre MODULE_PATH:$LIBRTPKCS11ECP \n req -engine $engine_id -new -utf8 -key \"pkcs11:serial=$serial;id=$key_id_ascii\" -keyform engine -passin \"pass:$PIN\" -subj $subj"

	if [[ "$key_usage" ]]
	then
		openssl_req="`echo -e "$openssl_req -config openssl_ext.cnf"`"
	fi
	
	if [[ $selfsign -eq 1  ]]
        then
                out=`echo -e "$openssl_req -x509 -outform DER -out \"$req_path\"" | $OPENSSL 2>&1`;

                if [[ $? -ne 0 ]]
		then
			echoerr "Can't create self signed cert:\n$out"
			return 1
		fi

		out=`pkcs11-tool --module $LIBRTPKCS11ECP -l -p "$PIN" -y cert -w "$req_path" --id $key_id 2>&1`;
		if [[ $? -ne 0 ]]
                then
                        echoerr "Can't move cert on token:\n$out"
                        return 1
                fi
	else
                out=`echo -e "$openssl_req -out \"$req_path\" -outform PEM" | $OPENSSL 2>&1`;
                if [[ "`echo -e "$out" | grep "error"`" ]]
		then
			echoerr "can't create cert req:\n$out"
			return 1
		fi
        fi

	return 0
}

function get_token_list () 
{
	echolog "get_token_lsit"
	out=`pkcs11-tool --module $LIBRTPKCS11ECP -T 2>&1`
	if [[ $? -ne 0 ]]
	then
		echoerr "Can't get token list:\n$out"
		return 1
	fi

	token_list=`echo -e "$out" | grep "Slot *" | cut -d ":" -f2- | awk '$1=$1'`
	echolog "Token list:\n$token_list"

	echo -e "$token_list"
	return 0
}

function get_token_info ()
{
	token=$1
	atr=$2
	echolog "get_token_info token: $token atr: $atr"

	out=`pkcs11-tool --module $LIBRTPKCS11ECP -T 2>&1`
	if [[ $? -ne 0 ]]
        then
                echoerr "Can't get token info:\n$out"
                return 1
        fi

        token_info="`echo -e "$out" | sed -n "/^.*$token.*$/,$ p" | awk '{$1=$1;print}' | sed -E "s/[[:space:]]*:[[:space:]]+/	/" | uniq | awk '/Slot /{++n} n<2'`"
        echolog "Token info:\n $token_info"

	if [[ "$atr" ]]
	then
		atr_val=`echo -e "$token_info" | grep "$atr" | cut -f 2`
		echolog "Atr: $atr frrom token info for token: $token is $atr_val"
		echo -e "$atr_val"
		return 0
	fi
	
	echo -e "$token_info"
	return 0
}

function get_token_objects ()
{
	token="$1"
	type="$2"
	attr="$3"
	val="$4"

	echolog "get_token_objects from token $token of type: $type with atr: $attr value: $val"

	if [[ "$type" ]]
	then
		type_arg="--type $type"
	fi

	objs=`pkcs11-tool --module $LIBRTPKCS11ECP -O -l -p "$PIN" $type_arg --slot-description "$token"`
	if [[ $? -ne 0 ]]
	then
		echoerr "Error while getting objects from token:\n$out"
		return 1
	fi

	echolog "Object list:\n$objs"

	if [[ "$attr" ]]
	then
		objs=`python3 "$TWO_FA_LIB_DIR/python_utils/parse_objects.py" "$objs" "$type" "$attr" "$val"`
		echolog "formated filtered objects:\n$objs"
	else
		objs=`python3 "$TWO_FA_LIB_DIR/python_utils/parse_objects.py" "$objs"`
		echolog "formated objects:\n$objs"
	fi
        
	echo -e "$objs"
	return 0
}

function get_object_attribute_value ()
{
	obj=$1
	attr=$2
	echolog "get object: $obj attribute: $attr"

	out=`echo -e "$obj" | python3 -c "import json,sys; obj=json.load(sys.stdin); print(obj[\"$attr\"])" 2>&1`

	if [[ $? -ne 0 ]]
	then
		echoerr "error occured while getting attr $attr of object $obj:\n$out"
		return 1
	fi

	echolog "Attr $attr value is $out"
	echo -e "$out"
	
	return $?
}

function pkcs11_format_token ()
{
	local token="$1"
	local user_pin="$2"
	local admin_pin="$3"
	echolog "pkcs11_format_token $token"	
	list=`get_token_list`		
	if  [[ "`echo -e "$list" | wc -l`" -ne 1 ]] 
	then
		echoerr "Вставленно более одного токена"
		return 2
	fi

	out=`$RTADMIN -z "$LIBRTPKCS11ECP" -f -u "$user_pin" -a "$admin_pin" -q`
	if [[ $? -ne 0 ]]
	then
		echoerr "Error occured during format token:\n$out"
		return 1
	fi
	
	echolog "Token formated"
	PIN=$user_pin
	return 0
}

function pkcs11_change_user_pin ()
{
	token=$1
	old_pin=$PIN
	new_pin=$2
	echolog "pkcs11_change_user_pin $token"
	out=`pkcs11-tool --module "$LIBRTPKCS11ECP" --change-pin -l -p "$old_pin" --new-pin "$new_pin" --slot-description "$token" 2>&1`
	if  [[ $? -ne 0 ]]
	then
		echoerr "Error occured during change user pin:\n$out"
		return 1
	fi

	echolog "user oin changed"
	PIN=$new_pin
	return 0
}

function pkcs11_change_admin_pin ()
{
	local token=$1
	local old_pin=$2
	local new_pin=$3
	echolog "pkcs11_change_admin_pin $token"
	out=`pkcs11-tool --module "$LIBRTPKCS11ECP" -c --login-type so --so-pin "$old_pin" -l --new-pin "$new_pin"`
	if  [[ $? -ne 0 ]]
        then
                echoerr "Error occured during change admin pin:\n$out"
                return 1
        fi

	echolog "admin pin changed"
	return 0
}

function pkcs11_unlock_pin ()
{
	local token=$1
	local so_pin=$2
	echolog "pkcs11_unlock_pin $token"

	list=`get_token_list`
        if  [[ "`echo -e "$list" | wc -l`" -ne 1 ]]
        then
                echoerr "Вставленно более одного токена"
                return 2
        fi
	
	out=`$RTADMIN -z "$LIBRTPKCS11ECP" -q -P -o "$so_pin"`
	if  [[ $? -ne 0 ]]
        then
                echoerr "Error occured during unlock user pin:\n$out"
                return 1
        fi
	echolog "User PIN unlocked"

	return 0
}

function export_object ()
{
	local token=$1
	local type=$2
	local id=$3
	local file=$4
	echolog "export_object of type:$type with id: $id from token:$token to file:$file"

	pkcs11-tool --module "$LIBRTPKCS11ECP" --slot-description "$token" -r --type "$type" --id "$id" -l -p "$PIN" > "$file"
	if [[ $? -ne 0 ]]
	then
		out=`cat "$file"`
		rm "$file"
		echoerr "Error occured while export object from token:\n$out"
		return 1
	fi
	
	return 0
}

function remove_object ()
{
        local token=$1
        local type=$2
        local id=$3
	echolog "remove_object of type:$type with id: $id from token:$token"

        out=`pkcs11-tool --module "$LIBRTPKCS11ECP" --slot-description "$token" -b --type "$type" --id "$id" -l -p "$PIN"`
        if [[ $? -ne 0 ]]
        then
                echoerr "Error occured during remove object from token:\n$out"
                return 1
        fi

	return 0
}

