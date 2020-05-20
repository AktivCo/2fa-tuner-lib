#!/bin/bash

function token_present ()
{
	cnt=`lsusb | grep "0a89:0030" | wc -l`
	if [[ cnt -eq 0 ]]
		then echoerr "Устройство семейства Рутокен ЭЦП не найдено"
		return 1
	fi

	return 0
}

function check_pin()
{
	token=$1
	pin=$2
	out=`pkcs11-tool --module "$LIBRTPKCS11ECP" -l -p "$pin" --show-info --slot-description "$token" 2>&1`
	res=$?
	out=`echo -e "$out" | grep "CKR_PIN_LOCKED"`
	if ! [[ -z "$out" ]]
	then
		return 2
	fi	
	return $res
}

function check_admin_pin()
{
        token=$1
        pin=$2
        out=`pkcs11-tool --module "$LIBRTPKCS11ECP" -l --so-pin "$pin" --login-type so --show-info --slot-description "$token" 2>&1`
        res=$?
        out=`echo -e "$out" | grep "CKR_PIN_LOCKED"`
        if ! [[ -z "$out" ]]
        then
                return 2
        fi
        return $res
}

function get_cert_list ()
{
	cert_ids=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type cert 2> /dev/null | grep -Eo "ID:.*" |  awk '{print $2}'`;
	echo "$cert_ids";
	return 0
}

function create_key_and_cert ()
{
	cert_id=`gen_cert_id`
	out=`gen_key $cert_id`
	if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось создать ключевую пару: $out"
		return 1
	fi 
	
	C="/C=RU";
	ST=`$DIALOG --title 'Данные сертификата' --inputbox 'Регион:' 0 0 'Москва'`;
	if [[ -n "$ST" ]]; then ST="/ST=$ST"; else ST=""; fi

	L=`$DIALOG --title 'Данные сертификата' --inputbox 'Населенный пункт:' 0 0 ''`;
	if [[ -n "$L" ]]; then L="/L=$L"; else L=""; fi
	
	O=`$DIALOG --title 'Данные сертификата' --inputbox 'Организация:' 0 0 ''`;
	if [[ -n "$O" ]]; then O="/O=$O"; else O=""; fi
	
	OU=`$DIALOG --title 'Данные сертификата' --inputbox 'Подразделение:' 0 0 ''`;
	if [[ -n "$OU" ]]; then OU="/OU=$OU"; else OU=""; fi
	
	CN=`$DIALOG --stdout --title 'Данные сертификата' --inputbox 'Общее имя:' 0 0 ''`;
	if [[ -n "$CN" ]]; then CN="/CN=$CN"; else CN=""; fi
	
	email=`$DIALOG --stdout --title 'Данные сертификата' --inputbox 'Электронная почта:' 0 0 ''`;
	if [[ -n "$email" ]]; then email="/emailAddress=$email"; else email=""; fi
	
	choice=`$DIALOG --stdout --title "Создание сертификата" --menu "Укажите опцию" 0 0 0 1 "Создать самоподписанный сертификат" 2 "Создать заявку на сертификат"`
	
	openssl_req="engine dynamic -pre SO_PATH:$PKCS11_ENGINE -pre ID:pkcs11 -pre LIST_ADD:1  -pre LOAD -pre MODULE_PATH:$LIBRTPKCS11ECP \n req -engine pkcs11 -new -key \"0:$cert_id\" -keyform engine -passin \"pass:$PIN\" -subj \"$C$ST$L$O$OU$CN$email\""
	if [[ choice -eq 1  ]]
	then
		printf "$openssl_req -x509 -outform DER -out cert.crt "| openssl > /dev/null;
		
		if [[ $? -ne 0 ]]
		then
			echoerr "Не удалось создать сертификат открытого ключа"
			return 1
		fi 
	else
		printf "$openssl_req -out \"$CUR_DIR/cert.csr\" -outform PEM" | openssl > /dev/null;
		
		if [[ $? -ne 0 ]]
		then
			echoerr "Не удалось создать заявку на сертификат открытого ключа"
			return 1
		fi 
		
		$DIALOG --msgbox "Отправьте заявку на сертификат в УЦ для выпуска сертификата. После получение сертификата, запишите его на токен с помощью import_cert_to_token.sh под индентификатором $cert_id. И повторите запуск setup.sh" 0 0
		return 0
	fi

	
	pkcs11-tool --module $LIBRTPKCS11ECP -l -p "$PIN" -y cert -w cert.crt --id $cert_id > /dev/null 2> /dev/null;
	if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось загрзить сертификат на токен"
		return 1
	fi 
	echo $cert_id

	return 0
}

function import_cert_on_token ()
{
	cert=$1
	key=$2
	pkcs11-tool --module $LIBRTPKCS11ECP -l -p "$PIN" -y cert -w "$cert" --id "$key" > /dev/null 2> /dev/null;
	if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось загрзить сертификат на Рутокен"
		return 1
	fi

	return 0
}

function get_key_list ()
{
        key_ids=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type pubkey 2> /dev/null | grep -Eo "ID:.*" |  awk '{print $2}'`;
        echo "$key_ids";
	return 0
}

function get_cert_list ()
{
        cert_ids=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type cert 2> /dev/null | grep -Eo "ID:.*" |  awk '{print $2}'`;
        echo "$cert_ids";
	return 0
}

function gen_key ()
{
        key_id=$1
	out=`pkcs11-tool --module $LIBRTPKCS11ECP --keypairgen --key-type rsa:2048 -l -p "$PIN" --id "$key_id" 2>&1`;
	echo "$out"
	return 0
}

function pkcs11_create_cert_req ()
{
	cert_id=$1
	subj="$2"
	req_path="$3"
	choice=$4

        openssl_req="engine dynamic -pre SO_PATH:$PKCS11_ENGINE -pre ID:pkcs11 -pre LIST_ADD:1  -pre LOAD -pre MODULE_PATH:$LIBRTPKCS11ECP \n req -engine pkcs11 -new -key \"0:$cert_id\" -keyform engine -passin \"pass:$PIN\" -subj $subj"
        if [[ choice -eq 1  ]]
        then
                printf "$openssl_req -x509 -outform DER -out \"$req_path\""| openssl > /dev/null;

                if [[ $? -ne 0 ]]
		then
			echoerr "Не удалось создать сертификат открытого ключа"
			return 1
		fi
        	pkcs11-tool --module $LIBRTPKCS11ECP -l -p "$PIN" -y cert -w "$req_path" --id $cert_id > /dev/null 2> /dev/null;
        else
                printf "$openssl_req -out \"$req_path\" -outform PEM" | openssl > /dev/null;

                if [[ $? -ne 0 ]]
		then
			echoerr "Не удалось создать заявку на сертификат открытого ключа"
			return 1
		fi
        fi

	return 0
}

function get_token_list () 
{
	echo -e "`pkcs11-tool --module $LIBRTPKCS11ECP -T 2> /dev/null | grep "Slot *" | cut -d ":" -f2- | awk '$1=$1'`"
	return 0
}

function get_token_info ()
{
	token=$1
        token_info=`pkcs11-tool --module $LIBRTPKCS11ECP -T | awk -v token="$token" '$0 ~ token {print; for(i=1; i<=8; i++) { getline; print}}' | awk '{$1=$1;print}' | sed -E "s/[[:space:]]*:[[:space:]]+/\t/"`
        echo -e "$token_info"
	return 0
}

function get_token_objects ()
{
	token="$1"
	token_objs=`pkcs11-tool --module $LIBRTPKCS11ECP -O -l -p "$PIN" --slot-description "$token"`
        echo -e "$token_objs"
	return 0
}

function pkcs11_format_token ()
{
	local token="$1"
	local user_pin="$2"
	local admin_pin="$3"
	PIN=$user_pin
	
	$RTADMIN -z "$LIBRTPKCS11ECP" -f -u "$user_pin" -a "$admin_pin" -q
	return $?
}

function pkcs11_change_user_pin ()
{
	token=$1
	old_pin=$PIN
	new_pin=$2
	PIN=$new_pin
	pkcs11-tool --module "$LIBRTPKCS11ECP" --change-pin -l -p "$old_pin" --new-pin "$new_pin" --slot-description "$token"
	return $?
}

function pkcs11_change_admin_pin ()
{
	local token=$1
	local old_pin=$2
	local new_pin=$3
	pkcs11-tool --module "$LIBRTPKCS11ECP" -c --login-type so --so-pin "$old_pin" -l --new-pin "$new_pin"
	return $?
}

function pkcs11_unlock_pin ()
{
	local token=$1
	local so_pin=$2
	$RTADMIN -z "$LIBRTPKCS11ECP" -q -P -o "$so_pin"
	return $?
}

function import_object ()
{
	local token=$1
	local type=$2
	local id=$3
	local file=$4
	pkcs11-tool --module "$LIBRTPKCS11ECP" --slot-description "$token" -r --type "$type" --id "$id" -l -p "$PIN" > "$file"
	return $?
}

function remove_object ()
{
        local token=$1
        local type=$2
        local id=$3
        pkcs11-tool --module "$LIBRTPKCS11ECP" --slot-description "$token" -b --type "$type" --id "$id" -l -p "$PIN"
        return $?
}

