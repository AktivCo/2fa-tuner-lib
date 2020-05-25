#!/bin/bash

function token_present ()
{
	cnt=`lsusb | grep "0a89:0030" | wc -l`
	if [[ cnt -eq 0 ]]; then echoerr "Устройство семейства Рутокен ЭЦП не найдено"; exit; fi
	if [[ cnt -ne 1 ]]; then echoerr "Найдено несколько устройств семейства Рутокен ЭЦП. Оставьте только одно"; exit; fi
}

function get_cert_list ()
{
	cert_ids=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type cert 2> /dev/null | grep -Eo "ID:.*" |  awk '{print $2}'`;
	echo "$cert_ids";
}

function create_key_and_cert ()
{
	cert_id=`gen_cert_id`
	out=`gen_key $cert_id`
	if [[ $? -ne 0 ]]; then echoerr "Не удалось создать ключевую пару: $out"; fi 
	
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
		
		if [[ $? -ne 0 ]]; then echoerr "Не удалось создать сертификат открытого ключа"; fi 
	else
		printf "$openssl_req -out \"$CUR_DIR/cert.csr\" -outform PEM" | openssl > /dev/null;
		
		if [[ $? -ne 0 ]]; then echoerr "Не удалось создать заявку на сертификат открытого ключа"; fi 
		
		$DIALOG --msgbox "Отправьте заявку на сертификат в УЦ для выпуска сертификата. После получение сертификата, запишите его на токен с помощью import_cert_to_token.sh под индентификатором $cert_id. И повторите запуск setup.sh" 0 0
		exit
	fi

	
	pkcs11-tool --module $LIBRTPKCS11ECP -l -p "$PIN" -y cert -w cert.crt --id $cert_id > /dev/null 2> /dev/null;
	if [[ $? -ne 0 ]]; then echoerr "Не удалось загрзить сертификат на токен"; fi 
	echo $cert_id
}

function get_token_password ()
{
	pin=`$DIALOG --title "Ввод PIN-кода"  --passwordbox "Введите PIN-код от Рутокена:" 0 0 ""`;
	echo $pin
}

function import_cert_on_token ()
{
	cert=$1
	key=$2
	pkcs11-tool --module $LIBRTPKCS11ECP -l -p "$PIN" -y cert -w "$cert" --id "$key" > /dev/null 2> /dev/null;
	if [[ $? -ne 0 ]]; then echoerr "Не удалось загрзить сертификат на Рутокен"; fi
}

function get_key_list ()
{
        key_ids=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type pubkey 2> /dev/null | grep -Eo "ID:.*" |  awk '{print $2}'`;
        echo "$key_ids";
}

function get_cert_list ()
{
        cert_ids=`pkcs11-tool --module $LIBRTPKCS11ECP -O --type cert 2> /dev/null | grep -Eo "ID:.*" |  awk '{print $2}'`;
        echo "$cert_ids";
}

function gen_key ()
{
        key_id=$1
	out=`pkcs11-tool --module $LIBRTPKCS11ECP --keypairgen --key-type rsa:2048 -l -p "$PIN" --id "$key_id" 2>&1`;
	echo "$out"
}


