#!/bin/bash

TWO_FA_LIB_DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd`
. "$TWO_FA_LIB_DIR/pkcs11_utils.sh"

NUMBER_REGEXP='^[0123456789abcdefABCDEF]+$'
CUR_DIR=`pwd`
DIALOG="dialog --keep-tite --stdout"
YAD="yad --center --width=400 --height=400"
SIMPLE_YAD="yad --center "

function init() 
{ 
	source /etc/os-release
	OS_NAME=$NAME
	
	if [ -f "/etc/debian_version" ]; then
		LIBRTPKCS11ECP=/usr/lib/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
                IPA_NSSDB_DIR=/etc/pki/nssdb
                IMPL_DIR="$TWO_FA_LIB_DIR/implementation/debian"
	fi

	if [ -f "/etc/redhat-release" ]; then
        	LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib64/engines-1.1/pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
                IPA_NSSDB_DIR=/etc/pki/nssdb
                IMPL_DIR="$TWO_FA_LIB_DIR/implementation/redhat/"
	fi

	case $OS_NAME in
        "RED OS") 
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib64/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/redos/"
		;;
        "Astra Linux"*)
		LIBRTPKCS11ECP=/usr/lib/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/astra"
		;;
	*"ALT"*)
		LIBRTPKCS11ECP="" # Defined later
		PKCS11_ENGINE=/usr/lib64/openssl/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/security/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/alt"
		;;
	*"ROSA"*)
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib64/openssl-1.0.0/engines//pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/rosa"
		;;
	esac
	. "$IMPL_DIR/setup.sh"

	ENGINE_DIR=`openssl version -a | grep "ENGINESDIR" | cut -d ":" -f 2 | tr -d '"' | awk '{$1=$1};1'`
	if ! [[ -z "$ENGINE_DIR" ]]
	then
		PKCS11_ENGINE=`echo "${ENGINE_DIR}/pkcs11.so"`
	fi

	case $XDG_CURRENT_DESKTOP in
	"MATE")
		SCREENSAVER_NAME="mate-screensaver"
		LOCK_SCREEN_CMD="mate-screensaver-command --lock"
		;;
	"X-Cinnamon")
		SCREENSAVER_NAME="cinnamon-screensaver"
		LOCK_SCREEN_CMD="cinnamon-screensaver-command --lock"
		;;
	"fly")
		SCREENSAVER_NAME=""
		LOCK_SCREEN_CMD="fly-wmfunc FLYWM_LOCK"
		;;
	"KDE")
		SCREENSAVER_NAME="kde"
		LOCK_SCREEN_CMD="qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock"
		;;
	esac

	SCRIPT=`realpath -s $0`
	SCRIPT_DIR=`dirname $SCRIPT`

	cd $(mktemp -d);
}

function set_dialog_manager ()
{
	echo
	manager=$1
	case $manager in 
	"yad")
		DIALOG_MANAGER="$YAD"
		. "$TWO_FA_LIB_DIR/yad.sh"
		;;
	*)
		DIALOG_MANAGER="$DIALOG"
		. "$TWO_FA_LIB_DIR/dialog.sh"
		;;
	esac
}

function cleanup() { rm -rf `pwd`; cd "$CUR_DIR"; }

echoerr() { echo -e "Ошибка: $@" 1>&2; cleanup; exit; }

function install_common_packages ()
{
	_install_common_packages
}

function install_packages_for_local_auth ()
{
	install_common_packages
        _install_packages_for_local_auth
}

function install_packages_for_domain_auth ()
{
	install_common_packages
        _install_packages_for_domain_auth
}


function setup_local_authentication ()
{
	_setup_local_authentication "$1" "$2"
}

function setup_autolock ()
{
	LIBRTPKCS11ECP="$LIBRTPKCS11ECP" LOCK_SCREEN_CMD="$LOCK_SCREEN_CMD" envsubst < "$TWO_FA_LIB_DIR/common_files/pkcs11_eventmgr.conf" | sudo tee "$PAM_PKCS11_DIR/pkcs11_eventmgr.conf" > /dev/null
	_setup_autolock
	sudo systemctl daemon-reload
}

function setup_domain_authentication ()
{
	sssd_conf=/etc/sssd/sssd.conf
	sudo mkdir $IPA_NSSDB_DIR 2> /dev/null;
	if ! [ "$(ls -A $IPA_NSSDB_DIR)" ]
	then
	sudo certutil -N -d "$IPA_NSSDB_DIR"
	fi

	CA_path=`$DIALOG --title "Укажите путь до корневого сертификата" --fselect "$HOME" 0 0`;
	if ! [ -f "$CA_path" ]; then echoerr "$CA_path doesn't exist"; fi

	sudo certutil -A -d $IPA_NSSDB_DIR -n 'IPA CA' -t CT,C,C -a -i "$CA_path"
	sudo modutil -dbdir "$IPA_NSSDB_DIR" -add "My PKCS#11 module" -libfile librtpkcs11ecp.so 2> /dev/null;
	if ! [ "$(sudo cat "$sssd_conf" | grep 'pam_cert_auth=True')" ]
	then
		sudo sed -i '/^\[pam\]/a pam_cert_auth=True' "$sssd_conf"
		if ! [[ -z "$SCREENSAVER_NAME" ]]
		then
			sudo sed -i "/^\[pam\]/a pam_p11_allowed_services = +$SCREENSAVER_NAME" "$sssd_conf"
		fi
	fi
	
	_setup_domain_authentication

	sudo systemctl restart sssd
}

function choose_cert ()
{
	cert_ids=`get_cert_list`
	if [[ -z "$cert_ids" ]]
	then
		echo "None"
		exit
	fi

	cert_ids=`echo -e "$cert_ids\n\"Новый сертификат\""`;
	cert_ids=`echo "$cert_ids" | awk '{printf("%s\t%s\n", NR, $0)}'`;
	cert_id=`echo $cert_ids | xargs $DIALOG --title "Выбор сертификата" --menu "Выбeрите сертификат" 0 0 0`;
	cert_id=`echo "$cert_ids" | sed "${cert_id}q;d" | cut -f2 -d$'\t'`;
	echo "$cert_id"
}

function choose_user ()
{
	UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)
	users=`awk -F: -v UID_MIN=$UID_MIN '($3>=UID_MIN){print $1}' /etc/passwd | sort | sed "s/^/$USER\n/"  | uniq | awk '{printf("%s\t%s\n", NR, $0)}'`
	if [[ -z "$users" ]]
	then
		user=`$DIALOG --title 'Введите имя настраиваемого пользователя' --inputbox 'Пользователь:' 0 0 ''`;
	else
		user=`echo $users | xargs $DIALOG --title "Выбор пользователя" --menu "Выбeрите пользователя" 0 0 0`;
		user=`echo "$users" | sed "${user}q;d" | cut -f2 -d$'\t'`;
	fi
	echo "$user"
}

function choose_key ()
{
	key_ids=`get_key_list`
	if [[ -z "$key_ids" ]]
	then
		echo "Нет ключей"
	exit;
	fi

	key_ids=`echo -e "$key_ids\n\"Новый ключ\""`;
	key_ids=`echo "$key_ids" | awk '{printf("%s\t%s\n", NR, $0)}'`;
	key_id=`echo $key_ids | xargs $DIALOG --title "Выбор ключа" --menu "Выберите ключ" 0 0 0`;
	key_id=`echo "$key_ids" | sed "${key_id}q;d" | cut -f2 -d$'\t'`;
	echo "$key_id"
}

function gen_cert_id ()
{
	res="1"
	while [[ -n "$res" ]]
	do
		cert_ids=`get_cert_list`
		rand=`echo $(( $RANDOM % 10000 ))`
		res=`echo $cert_ids | grep -w $rand`
	done
	
	echo "$rand"
}

function gen_key_id ()
{
	res="1"
	while [[ -n "$res" ]]
	do
		cert_ids=`get_key_list`
		rand=`echo $(( $RANDOM % 10000 ))`
		res=`echo $cert_ids | grep -w $rand`
	done

	echo "$rand"
}

function import_cert ()
{
	cert_path=`$DIALOG --title "Укажите путь до сертификата" --fselect $HOME 0 0`;
	key_ids=`get_key_list`
	if [[ -z "$key_ids" ]]
	then
		echoerr "На Рутокене нет ключей";
	fi

	key_ids=`echo "$key_ids" | awk '{printf("%s\t%s\n", NR, $0)}'`;
	key_id=`echo $key_ids | xargs $DIALOG --title "Выбор ключа" --menu "Выберите ключ для которого выдан сертификат" 0 0 0`;
	key_id=`echo "$key_ids" | sed "${key_id}q;d" | cut -f2 -d$'\t'`;

	openssl x509 -in $cert_path -out cert.crt -inform PEM -outform DER;
	import_cert_on_token cert.crt $key_id
}

function get_token_password ()
{
	get_password "Ввод PIN-кода" "Введите PIN-код от Рутокена:"
}

function get_cert_subj ()
{
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

	
	echo "\"$C$ST$L$O$OU$CN$email\""
}

function create_cert_req ()
{
	cert_id=$1
	
	req_path=`$DIALOG --title "Куда сохранить заявку" --fselect "$CUR_DIR/cert.csr" 0 0`
	
	subj=`get_cert_subj`

	pkcs11_create_cert_req $cert_id "$subj" "$req_path" 0

	if [[ $? -ne 0 ]]; then echoerr "Не удалось создать заявку на сертификат открытого ключа"; fi
}

function create_key_and_cert ()
{
        cert_id=`gen_cert_id`
        out=`gen_key $cert_id`
        if [[ $? -ne 0 ]]; then echoerr "Не удалось создать ключевую пару: $out"; fi

        choice=`$DIALOG --stdout --title "Создание сертификата" --menu "Укажите опцию" 0 0 0 1 "Создать самоподписанный сертификат" 2 "Создать заявку на сертификат"`
        
	subj=`get_cert_subj`
	
	pkcs11_create_cert_req $cert_id "$subj" "$req_path" $choice
	
        if [[ $? -ne 0 ]]; then echoerr "Не удалось загрзить сертификат на токен"; fi
        echo $cert_id
}

function choose_token ()
{
        token_list=`get_token_list`
        token_list=`echo -e "${token_list}\nОбновить список"`
	choice=`show_list "Выбор токена" "Name" "$token_list"`
        
	if [ $? -ne 0 ]
        then
                return 1
        fi

        if [ "$choice" == "Обновить список" ] || [ -z "$choice" ]
        then
                choose_token
                return $?
        fi

        echo "$choice"
        return 0
}

function show_token_info ()
{
        token=$1
        token_info=`get_token_info $token`
	show_text "$token" "Информация об устройстве:\n$token_info" 
}

function show_token_object ()
{
	token="$1"
	objs=`get_token_objects "$token"`	
	objs=`python3 "$TWO_FA_LIB_DIR/python_utils/parse_objects.py" "$objs"`
	header=`echo -e "$objs" | head -n 1`
	objs=`echo -e "$objs" | tail -n +2`
	echo -e "$header"
	show_list "Объекты на токене $token" "$header" "$objs"
}

function show_wait ()
{
	pid="$1"
	title="$2"
	text="$3"

	show_text "$text" "$title" &

	dialog_pid=$!
	
	wait $pid
	pkill -P $dialog_pid
}
