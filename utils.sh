#!/bin/bash

TWO_FA_LIB_DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd`
. "$TWO_FA_LIB_DIR/pkcs11_utils.sh"

NUMBER_REGEXP='^[0123456789abcdefABCDEF]+$'
CUR_DIR=`pwd`
DIALOG="dialog --keep-tite --stdout"

function init() { 
	source /etc/os-release
	OS_NAME=$NAME

	case $OS_NAME in
        "RED OS") 
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib64/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/pam_pkcs11
		IMPL_DIR=$TWO_FA_LIB_DIR/implementation/redos/
		. "$IMPL_DIR/redos_setup.sh"
		;;
        "Astra Linux"*)
		LIBRTPKCS11ECP=/usr/lib/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/pam_pkcs11
		IMPL_DIR=$TWO_FA_LIB_DIR/implementation/astra
		. "$IMPL_DIR/astra_setup.sh"
		;;
	*"ALT"*)
		LIBRTPKCS11ECP="" # Defined later
		PKCS11_ENGINE=/usr/lib64/openssl/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/security/pam_pkcs11
		IMPL_DIR=$TWO_FA_LIB_DIR/implementation/alt
		. "$IMPL_DIR/alt_setup.sh"
		;;
	*"ROSA"*)
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib64/openssl-1.0.0/engines//pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
		IMPL_DIR=$TWO_FA_LIB_DIR/implementation/rosa
                . "$IMPL_DIR/rosa_setup.sh"
		;;
        esac

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
		SCREENSAVER_NAME=""
		LOCK_SCREEN_CMD="qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock"
		;;
	esac

	SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

	cd $(mktemp -d);
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
	DB=/etc/pki/nssdb
	sssd_conf=/etc/sssd/sssd.conf
	sudo mkdir $DB 2> /dev/null;
	if ! [ "$(ls -A $DB)" ]
	then
	sudo certutil -N -d "$DB"
	fi

	CA_path=`$DIALOG --title "Укажите путь до корневого сертификата" --fselect "$HOME" 0 0`;
	if ! [ -f "$CA_path" ]; then echoerr "$CA_path doesn't exist"; fi

	sudo certutil -A -d /etc/pki/nssdb/ -n 'IPA CA' -t CT,C,C -a -i "$CA_path"
	sudo modutil -dbdir "$DB" -add "My PKCS#11 module" -libfile librtpkcs11ecp.so 2> /dev/null;
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

function create_cert_req ()
{
	key_id=$1
	C="/C=RU";
	ST=`$DIALOG --title 'Данные сертификата' --inputbox 'Регион:' 0 0 'Москва'`;
	if [[ -n "$ST" ]]; then ST="/ST=$ST"; else ST=""; fi

	L=`$DIALOG --title 'Данные сертификата' --inputbox 'Населенный пункт:' 0 0 ''`;
	if [[ -n "$L" ]]; then L="/L=$L"; else L=""; fi

	O=`$DIALOG --title 'Данные сертификата' --inputbox 'Организация:' 0 0 ''`;
	if [[ -n "$O" ]]; then O="/O=$O"; else O=""; fi

	OU=`$DIALOG --title 'Данные сертификата' --inputbox 'Подразделение:' 0 0 ''`;
	if [[ -n "$OU" ]]; then OU="/OU=$OU"; else OU=""; fi

	CN=`$DIALOG --title "Данные сертификата" --inputbox "Общее имя (должно совпадать с именем пользователя, для которого создается генерируется сертификат):" 0 0 ""`;
	if [[ -n "$CN" ]]; then CN="/CN=$CN"; else CN=""; fi

	email=`$DIALOG --stdout --title 'Данные сертификата' --inputbox 'Электронная почта:' 0 0 ''`;
	if [[ -n "$email" ]]; then email="/emailAddress=$email"; else email=""; fi

	req_path=`$DIALOG --title "Куда сохранить заявку" --fselect "$CUR_DIR/cert.csr" 0 0`

	openssl_req="engine dynamic -pre SO_PATH:$PKCS11_ENGINE -pre ID:pkcs11 -pre LIST_ADD:1  -pre LOAD -pre MODULE_PATH:$LIBRTPKCS11ECP \n req -engine pkcs11 -passin \"pass:$PIN\"-new -key 0:$key_id -keyform engine -out \"$req_path\" -outform PEM -subj \"$C$ST$L$O$OU$CN$email\""

	printf "$openssl_req" | openssl > /dev/null;

	if [[ $? -ne 0 ]]; then echoerr "Не удалось создать заявку на сертификат открытого ключа"; fi

	$DIALOG --msgbox "Отправьте заявку на получение сертификата в УЦ вашего домена. После получение сертификата, запустите setup.sh и закончите настройку." 0 0
	exit
}
