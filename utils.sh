#!/bin/bash

TWO_FA_LIB_DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd`
. "$TWO_FA_LIB_DIR/pkcs11_utils.sh"

NUMBER_REGEXP='^[0123456789abcdefABCDEF]+$'
CUR_DIR=`pwd`
if [[ -z "$LOG_FILE" ]]
then
	LOG_FILE="$CUR_DIR/log.txt"
fi
RTADMIN=rtAdmin

echolog()
{
	echo -e [`date` $USER $$] "$@" >> "$LOG_FILE"
}

function init() 
{ 
	echolog "init"

	source /etc/os-release
	OS_NAME=$NAME
	echolog "OS: $OS_NAME"

	if [ -f "/etc/debian_version" ]; then
		echolog "set env for debian impl"
		LIBRTPKCS11ECP=/usr/lib/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
                IPA_NSSDB_DIR=/etc/pki/nssdb
                IMPL_DIR="$TWO_FA_LIB_DIR/implementation/debian"
	fi

	if [ -f "/etc/redhat-release" ]; then
		echolog "set env for redhat impl"
        	LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib64/engines-1.1/pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
                IPA_NSSDB_DIR=/etc/pki/nssdb
                IMPL_DIR="$TWO_FA_LIB_DIR/implementation/redhat/"
	fi

	case $OS_NAME in
        "RED OS") 
		echolog "set env for red os impl"
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib64/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/redos/"
		;;
        "Astra Linux"*)
		echolog "set env for astra impl"
		LIBRTPKCS11ECP=/usr/lib/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib/x86_64-linux-gnu/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/astra"
		;;
	*"ALT"*)
		echolog "set env for alt impl"
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
		PKCS11_ENGINE=/usr/lib64/openssl/engines-1.1/pkcs11.so
		PAM_PKCS11_DIR=/etc/security/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/alt"
		;;
	*"ROSA"*)
		echolog "set env for rosa impl"
		LIBRTPKCS11ECP=/usr/lib64/librtpkcs11ecp.so
                PKCS11_ENGINE=/usr/lib64/openssl-1.0.0/engines//pkcs11.so
                PAM_PKCS11_DIR=/etc/pam_pkcs11
		IPA_NSSDB_DIR=/etc/pki/nssdb
		IMPL_DIR="$TWO_FA_LIB_DIR/implementation/rosa"
		;;
	esac
	echolog "setup impl"
	. "$IMPL_DIR/setup.sh"
	
	ENGINE_DIR=`openssl version -a | grep "ENGINESDIR" | tail -1 | cut -d ":" -f 2 | tr -d '"' | awk '{$1=$1};1'`
	echolog "auto setup engine dir: $ENGINE_DIR"
	if ! [[ -z "$ENGINE_DIR" ]]
	then
		PKCS11_ENGINE=`echo "${ENGINE_DIR}/pkcs11.so"`
	fi
	
	local GUESS_LIBRTPKCS11ECP=`whereis  librtpkcs11ecp | awk '{print $2}'`
	if ! [[ -z "$GUESS_LIBRTPKCS11ECP" ]]
	then
		echolog "auto setup pkcs11 lib: $GUESS_LIBRTPKCS11ECP"
		LIBRTPKCS11ECP="$GUESS_LIBRTPKCS11ECP"
	fi
	RTENGINE="`dirname "$PKCS11_ENGINE"`/librtengine.so"

	case $XDG_CURRENT_DESKTOP in
	"MATE")
		echolog "set env for mate"
		SCREENSAVER_NAME="mate-screensaver"
		LOCK_SCREEN_CMD="mate-screensaver-command --lock"
		;;
	"X-Cinnamon")
		echolog "set env for cinnamon"
		SCREENSAVER_NAME="cinnamon-screensaver"
		LOCK_SCREEN_CMD="cinnamon-screensaver-command --lock"
		;;
	"fly")
		echolog "set env for fly"
		SCREENSAVER_NAME=""
		LOCK_SCREEN_CMD="fly-wmfunc FLYWM_LOCK"
		;;
	"KDE")
		echolog "set env for kde"
		SCREENSAVER_NAME="kde"
		LOCK_SCREEN_CMD="qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock"
		;;
	esac

	echolog "init gui manager"
	init_gui_manager

	SCRIPT=`realpath -s "$0"`
	echolog "script path: $SCRIPT"
	SCRIPT_DIR=`dirname "$SCRIPT"`

	cd $(mktemp -d);
	TMP_DIR=`pwd`
	
	return 0
}

function init_gui_manager ()
{
	echolog "init gui manager"

	case "$GUI_MANAGER" in 
	"dialog")
		echolog "setup impl: dialog gui"
		. "$TWO_FA_LIB_DIR/dialog.sh"
		;;
	"python")
		echolog "setup impl: pathon gui"
                . "$TWO_FA_LIB_DIR/python_gui.sh"
                ;;

	*)
		echolog "setup impl: default(python)"
		. "$TWO_FA_LIB_DIR/python_gui.sh"
		;;
	esac

	return 0
}

function cleanup()
{
	echolog "cleanup"
	rm -rf $TMP_DIR
	cd "$CUR_DIR"
	return 0
}

echoerr()
{
	echolog "error $@"
	echo -e "Ошибка: $@" 1>&2
	return 0
}

function install_packages ()
{
	check_updates=$1
	rtadmin_path=/usr/bin/rtAdmin

	if [[ "$check_updates" ]]
	then
		echolog "check updates for common packages"
	else
		echolog "install common packages"
	fi

	if [[ "$check_updates" ]]
        then
		echolog "check rtengine"
                if ! [[ -f "$RTENGINE" ]]
		then
			echolog "rtengine not found"
			return 1
        
		fi
	else
		echolog "download rtengine\ndownload SDK"
		wget -q --no-check-certificate "https://download.rutoken.ru/Rutoken/SDK/rutoken-sdk-latest.zip";
		if [[ $? -ne 0 ]]
        	then
                	echoerr "Не могу загрузить rutoken SDK"
                	return 1
        	fi

		echolog "unzip SDK"
		unzip -q rutoken-sdk-latest.zip
		
		echolog "cp rtengine to $RTENGINE"
		cp sdk/openssl/rtengine/bin/linux_glibc-x86_64/lib/librtengine.so "$RTENGINE"
	fi


        if [[ "$check_updates" ]]
        then
		echolog "check updates for rtadmin"
                if ! [[ -f $rtadmin_path ]]
		then
			echolog "rtadmin not found"
			return 1
        
		fi
	else
		echolog "download rtadmin"
		wget -q --no-check-certificate "https://download.rutoken.ru/Rutoken/Utilites/rtAdmin/1.3/linux/x86_64/rtAdmin";
		if [[ $? -ne 0 ]]
        	then
                	echoerr "Не могу загрузить утилиту rtAdmin"
                	return 1
        	fi
		
		mv rtAdmin $rtadmin_path
		chmod +x $rtadmin_path
	fi

        if [[ "$check_updates" ]]
        then
		echolog "check updates for pkcs11 lib"
                if ! [[ -f $LIBRTPKCS11ECP ]]
                then
                        return 1
                fi
	else
		echolog "download pkcs11 lib"
        	wget -q --no-check-certificate "https://download.rutoken.ru/Rutoken/PKCS11Lib/Current/Linux/x64/librtpkcs11ecp.so";
               	if [[ $? -ne 0 ]]
               	then
                       	echoerr "Не могу загрузить пакет librtpkcs11ecp.so"
                        return 1
                fi
                cp librtpkcs11ecp.so $LIBRTPKCS11ECP;
	fi

	
	echolog "install common packages for specific OS"
	_install_packages $check_updates
	
	return $?
}

function setup_local_authentication ()
{
	local token=$1
	local cert_id=$2

	echolog "setup_local_auth token:$token cert_id:$cert_id"
	if [[ "$UID" -ne "0" ]]
        then
		echolog "setup local auth run not under root"
                sudo_cmd setup_local_authentication "$@"
        fi

	user=`choose_user`
	if [[ $? -ne 0 ]]
	then
		echolog "not user choosen"
		return 0
	fi
	echolog "choosen user is $user"

	_setup_local_authentication "$token" "$cert_id" "$user" &
	show_wait $! "Подождите" "Идет настройка"
	
	res=$?
	if [[ $res -ne 0 ]]
	then
		echolog "Error occured while setup local auth"
		show_text "Ошибка" "Во время настройки локальной аутентификации произошла ошибка"
		return $res
	fi

	setup_autolock
	res=$?
	if [[ $res -eq 0 ]]
        then
		echolog "local auth setuped sucessfully"
                show_text "Успех" "Локальная аутентификация настроена"
	else
		echolog "autolock settuped with error"
		show_text "Ошибка" "Во время настройки автоблокировки произошла ошибка"
	fi
	return $res
}

function setup_autolock ()
{
	echolog "setup auto lock"
	LIBRTPKCS11ECP="$LIBRTPKCS11ECP" LOCK_SCREEN_CMD="$LOCK_SCREEN_CMD" envsubst < "$TWO_FA_LIB_DIR/common_files/pkcs11_eventmgr.conf" | tee "$PAM_PKCS11_DIR/pkcs11_eventmgr.conf" > /dev/null
	_setup_autolock
	systemctl daemon-reload
	return $?
}

function setup_freeipa_domain_authentication ()
{
	token=$1
	sssd_conf=/etc/sssd/sssd.conf
	echolog "setup_freeipa_domain_authentication token:$token"
	
	if [[ "$UID" -ne "0" ]]
        then
		echolog "setup freeipa domain auth run not under root"
                sudo_cmd setup_freeipa_domain_authentication "$@"
        	return $?
	fi

	mkdir "$IPA_NSSDB_DIR" 2> /dev/null;
	if ! [ "$(ls -A "$IPA_NSSDB_DIR")" ]
	then
		echolog "creating database inside $IPA_NSSDB_DIR"
		certutil -N -d "$IPA_NSSDB_DIR" --empty-password
	fi

	CA_path=`open_file_dialog "Корневой сертификат" "Укажите путь до корневого сертификата" "$HOME"`;

	if [[ $? -ne 0 ]]
	then
		echolog "CA path choosen dialog was closed"
		return 0
	fi

	echolog "CA path is $CA_path"
	if ! [ -f "$CA_path" ]
	then 
		echoerr "$CA_path doesn't exist"
		return 1
	fi

	echolog "add ca cert to database"
	out=`certutil -A -d "$IPA_NSSDB_DIR" -n 'IPA CA' -t CT,C,C -a -i "$CA_path"`
	if [[ $? -ne 0 ]]
	then
		echoerr "Error occured during adding ca cert to db\n$out"
		return 1
	fi

	echolog "add token pkcs11 lib to database"
	out=`echo -e "\n" | modutil -dbdir "$IPA_NSSDB_DIR" -add "My PKCS#11 module" -libfile librtpkcs11ecp.so`
	if [[ $? -ne 0 ]]
        then
                echoerr "Error occured during adding pkcs11 lib to db\n$out"
                return 1
        fi
	
	if ! [ "$(cat "$sssd_conf" | grep 'pam_cert_auth=True')" ]
	then
		echolog "adding pam cert auth"
		sed -i '/^\[pam\]/a pam_cert_auth=True' "$sssd_conf"
		if [[ "$SCREENSAVER_NAME" ]]
		then
			echolog "modify trusted pam.d modules for sssd: $SCREENSAVER_NAME"
			sed -i "/^\[pam\]/a pam_p11_allowed_services = +$SCREENSAVER_NAME" "$sssd_conf"
		fi
	fi
	
	_setup_freeipa_domain_authentication

	systemctl restart sssd
	
	return 0
}

function setup_ad_domain_authentication ()
{
	token=$1
        sssd_conf=/etc/sssd/sssd.conf
        krb5_conf=/etc/krb5.conf

	echolog "setup_ad_domain_authentication token:$token"
	
	if [[ "$UID" -ne "0" ]]
        then
		echolog "setup ca domain auth run not under root"
                sudo_cmd setup_ad_domain_authentication "$@"
        	return $?
	fi

        domain_name=`dnsdomainname`
	if [[ -z "$domain_name" ]]
	then
		domain_name=`realm list | head -n 1`
	fi
	echolog "deteceted domain name: $domain_name"

	server_name=`dig "_kerberos._udp.${domain_name}" SRV | grep ^_kerberos | rev | cut  -d " " -f 1 | cut -c2- | rev`
	echolog "deteceted server name: $server_name"

	mkdir -p "$IPA_NSSDB_DIR" 2> /dev/null;
	if ! [ "$(ls -A "$IPA_NSSDB_DIR")" ]
	then
		echolog "creating database inside $IPA_NSSDB_DIR"
		certutil -N -d "$IPA_NSSDB_DIR" --empty-password
	fi

	CA_path=`open_file_dialog "Корневой сертификат" "Укажите путь до корневого сертификата" "$HOME"`;

	if [[ $? -ne 0 ]]
	then
		echolog "CA path choosen dialog was closed"
		return 0
	fi
	
	echolog "CA path is $CA_path"
	if ! [ -f "$CA_path" ]
	then 
		echoerr "$CA_path doesn't exist"
		return 1
	fi
	
	mkdir -p /etc/pki/tls/certs/
	cp "$CA_path" /etc/pki/tls/certs/

	echolog "add ca cert to database"
	out=`certutil -A -d "$IPA_NSSDB_DIR" -n 'AD CA' -t CT,C,C -a -i "$CA_path"`
        if [[ $? -ne 0 ]]
        then
                echoerr "Error occured during adding ca cert to db\n$out"
                return 1
        fi

	echolog "add token pkcs11 lib to database"
	out=`echo -e "\n" | modutil -dbdir "$IPA_NSSDB_DIR" -add "My PKCS#11 module" -libfile librtpkcs11ecp.so`
        if [[ $? -ne 0 ]]
        then
                echoerr "Error occured during adding pkcs11 lib to db\n$out"
                return 1
        fi

	echolog "init sssd.conf file"
	sed -i 's/use_fully_qualified_names.*/use_fully_qualified_names = False/g' "$sssd_conf"

	if [[ -z "$(cat "$sssd_conf" | grep '\[pam\]')" ]]
	then
		echo -e "\n[pam]" >> "$sssd_conf"
	fi

	if [[ -z "$(cat "$sssd_conf" | grep 'pam_cert_auth')" ]]
	then
		sed -i '/^\[pam\]/a pam_cert_auth = True' "$sssd_conf"
	fi
	sed -i "s/.*pam_cert_auth.*/pam_cert_auth = True/g" "$sssd_conf"

	if [[ "$SCREENSAVER_NAME" ]]
	then
		if [[ -z "$(cat "$sssd_conf" | grep 'pam_p11_allowed_services')" ]]
		then
			sed -i "/^\[pam\]/a pam_p11_allowed_services = +$SCREENSAVER_NAME" "$sssd_conf"
		fi
		sed -i "s/.*pam_p11_allowed_services.*/pam_p11_allowed_services = +$SCREENSAVER_NAME/g" "$sssd_conf"
	fi
	
	echolog "init krb5.conf file"	

	if [[ -z "`cat "$krb5_conf" | grep pkinit_anchors`" ]]
	then
		sed -i  "/^\[libdefaults\]/a pkinit_anchors = DIR:\/etc\/pki\/tls/certs\/" "$krb5_conf"
	fi
	sed -i "s/.*pkinit_anchors.*/pkinit_anchors = DIR:\/etc\/pki\/tls\/certs\//g" "$krb5_conf"

	if [[ -z "`cat "$krb5_conf" | grep pkinit_kdc_hostname`" ]]
	then
		sed -i "/^\[libdefaults\]/a pkinit_kdc_hostname = $server_name" "$krb5_conf"
	fi
	sed -i "s/.*pkinit_kdc_hostname.*/pkinit_kdc_hostname = $server_name/g" "$krb5_conf"
	
	if [[ -z "`cat "$krb5_conf" | grep pkinit_eku_checking`" ]]
	then
		sed -i "/^\[libdefaults\]/a pkinit_eku_checking = kpServerAuth" "$krb5_conf"
	fi
	sed -i "s/.*pkinit_eku_checking.*/pkinit_eku_checking = kpServerAuth/g" "$krb5_conf"

	if [[ -z "`cat "$krb5_conf" | grep default_ccache_name`" ]]
	then
		sed -i "/^\[libdefaults\]/a default_ccache_name = KEYRING:persistent:%{uid}" "$krb5_conf"
	fi
	sed -i "s/.*default_ccache_name.*/default_ccache_name = KEYRING:persistent:%{uid}/g" "$krb5_conf"

	if [[ -z "`cat "$krb5_conf" | grep default_realm`" ]]
	then
		sed -i "/^\[libdefaults\]/a default_realm = ${domain_name^^}" "$krb5_conf"
	fi
	sed -i "s/.*default_realm.*/default_realm = ${domain_name^^}/g" "$krb5_conf"

	if [[ -z "`cat "$krb5_conf" | grep pkinit_identities`" ]]
	then
		sed -i "/^\[libdefaults\]/a pkinit_identities = PKCS11:librtpkcs11ecp.so" "$krb5_conf"
	fi
	sed -i "s/.*pkinit_identities.*/pkinit_identities = PKCS11:librtpkcs11ecp.so/g" "$krb5_conf"

	if [[ -z "`cat "$krb5_conf" | grep canonicalize`" ]]
	then
		sed -i "/^\[libdefaults\]/a canonicalize = True" "$krb5_conf"
	fi
	sed -i "s/.*canonicalize.*/canonicalize = True/g" "$krb5_conf"

	_setup_ad_domain_authentication

	systemctl restart sssd
	if [[ $? -ne 0 ]]
	then
		ehcoerr "error occured while restart sssd. Status:\n`systemctl status sssd`"
		return 1
	fi

	return 0
}

function zenity_enable ()
{
	echolog "check zenity enability"
	zenity --help 2> /dev/null

	if [[ $? -ne 0 ]]
	then
		echolog "zenity not enabeled"
		return 1
	fi

	return 0
}

#currently unused function
function choose_cert ()
{
	token=$1
	get_token_objects "$token" "cert" > get_token_objects_res &
	show_wait $! "Подождите" "Идет получение списка сертификатов"
	res=$?

	if [[ $res -ne 0 ]]
	then
		show_text "Ошибка" "Не могу получить список сертификатов"
		return $res
	fi

	cert_ids=`cat get_token_objects_res`
	header=`echo -e "$cert_ids" | head -n 1`
        cert_ids=`echo -e "$cert_ids" | tail -n +2`

	if [[ -z "$cert_ids" ]]
	then
		echo "None"
		return 0
	fi

	cert=`show_list "Выберите сертификат" "$header" "$cert_ids" "Новый сертификат"`
	res=$?
	if [[ $res -ne 0 ]]
	then
		return $res
	fi

	if ! [[ $cert == "Новый сертификат" ]]
	then
        	cert_id=`echo "$cert" | cut -f2`
	fi

	echo "$cert_id"
	return 0
}

function choose_user ()
{
	echolog "choose_user"
	UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)
	res=$?
	echolog "UID_MIN: $UID_MIN"
	
	if [[ $res -eq 0 ]]
	then
		users=`awk -F: -v UID_MIN=$UID_MIN '($3>=UID_MIN){print $1}' /etc/passwd | sort | sed "s/^/$USER\n/"  | uniq`
		echolog "user list:\nusers"
	fi

	if [[ -z "$users" ]]
	then
		echolog "can't get user list. Get user from get string func"
		user=`get_string "Выбор пользователя" "Введите имя настраиваемого пользователя" "$USER"`;
	else
		user=`show_list "Выбор пользователя" "Пользователи" "$users"`;
	fi
	echolog "chosed user is $user"
	echo "$user"

	return 0
}

#currently unused function
function choose_key ()
{
	token=$1
	get_token_objects "$token" "privkey" > get_token_objects_res &
        show_wait $! "Подождите" "Идет получение списка ключей"
        res=$?

	if [[ $res -ne 0 ]]
        then
                show_text "Ошибка" "Не могу получить список ключей"
                return $res
        fi

        key_ids=`cat get_token_objects_res`
        header=`echo -e "$key_ids" | head -n 1`
        key_ids=`echo -e "$key_ids" | tail -n +2`

	if [[ -z "$key_ids" ]]
	then
		echo "None"
		return 0
	fi

	key=`show_list "Выберите ключ" "$header" "$key_ids" "Новый ключ"`
	res=$?
	if [[ $res -ne 0 ]]
	then
		return 0
	fi

	if [[ "$key" == "Новый ключ" ]]
	then
		key_id=`create_key "$token"`
		res=$?
		if [[ $res -ne 0 ]]
		then
			return $res
		fi
	else
		key_id=`echo "$key" | cut -f2`
	fi

	echo "$key_id"
	return 0
}

random-string()
{
    head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}

function gen_cert_id ()
{
	token=$1
	echolog "gen new cert id for token: $token" 
	get_cert_list "$token" > get_cert_list_res &
	show_wait $! "Подождите" "Идет получение списка существующих идентификаторов"
	cert_ids=`cat get_cert_list_res`

	local res=1
	while [[ -n "$res" ]]
	do
		rand=`random-string 8 | xxd -p`
		res=`echo $cert_ids | grep -w $rand`
	done
	
	echo "$rand"

	return 0
}

function gen_key_id ()
{
	token=$1
	echolog "gen new cert id for token: $token"
	get_key_list "$token" > get_key_list_res &
	show_wait $! "Подождите" "Идет получение списка существующих идентификаторов"
	key_ids=`cat get_key_list_res`
	
	local res=1
	while [[ -n "$res" ]]
	do
		rand=`random-string 8 | xxd -p`
		res=`echo "$key_ids" | grep -w "$rand"`
	done

	echo "$rand"

	return 0
}

function import_cert ()
{
	token=$1
	key_id=$2

	echolog "import cert for token: $token with key_id: $key_id"
	
	if [[ -z $key_id ]]
	then
		key_id=`gen_key_id "$token"`
		echolog "key_id not specifed. Generated is $key_id"
	fi

	cert_path=`open_file_dialog "Путь до сертификата" "Укажите путь до сертификата" "$HOME"`;

	if [[ $? -ne 0 ]]
	then
		echolog "cert path choosen dialog was closed"
		return 0
	fi

	if ! [[ -z "`cat "$cert_path" | grep '\-----BEGIN CERTIFICATE-----'`" ]]
	then
		echolog "convert cert from PEM to DER format"
		out=`openssl x509 -in "$cert_path" -out cert.crt -inform PEM -outform DER`;
		if [[ $? -ne 0 ]]
		then
			echoerr "Error occured while convert cert from PEM to DER format:\n$out"
		fi

		echolog "cert path changed to cert.crt"
		cert_path=cert.crt
	fi

        label=`get_string "Метка сертификата" "Укажите метку сертификата"`
        if [[ $? -ne 0 ]]
        then
		echolog "choose label dialog was closed"
                return 0
        fi
	echolog "choosen cert label is: $label"

	import_obj_on_token "$token" "cert" "$cert_path" "$label" "$key_id" &
	show_wait $! "Подождите" "Идет импорт сертификата"
        res=$?
	if [[ $res -ne 0 ]]
        then
		echoerr "Не удалось импортировать сертификат на токен"
                show_text "Ошибка" "Не удалось импортировать сертификат на токен"
                return $res
        fi

	return 0

}

function get_token_password ()
{
	token=$1
	echolog "get_token_password for token: $token"
	res=1
	while [[ $res -ne 0 ]]
	do
		pin=`get_password "Ввод PIN-кода" "Введите PIN-код Пользователя:"`
		res=$?
		
		if [[ $res -ne 0 ]]
		then
			echolog "get token PIN dialog was closed"
			return $res 
		fi

		check_pin "$token" "$pin" &
		show_wait $! "Подождите" "Идет проверка PIN-кода"
		res=$?
		echoerr "$res"

		if [[ $res -eq 2 ]]
		then
			echolog "User PIN was blocked"
			yesno "PIN-код заблокирован" "`echo -e \"PIN-код Пользователя заблокирован.\nРазблокировать его с помощью PIN-кода Администратора?\"`"

			res=$?
			if [[ $res -ne 0 ]]
			then
				echolog "User decides to not unlock pin"
				return $res
			fi

			unlock_pin "$token"
			res=$?
			if [[ $res -eq 0 ]]
			then
				echolog "User Pin was unlocked"
			else
				echolog "User Pin is still locked"
			fi
		else
			if [[ $res -ne 0 ]]
			then
				echoerr "Uncorrect pin"
				show_text "Ошибка" "Неправильный PIN-код"
			fi
		fi
	done

	echo "$pin"
	return 0
}

function get_cert_subj ()
{
	echolog "get_cert_cubj"
	form_atr="Регион
Населенный пункт
Организация
Подразделение
Общее имя
Электронная почта"
	default_content=`echo -e "Москва\n\n\n\n\n"`
	res=`show_form "Данные сертификата" "Укажите данные заявки" "$form_atr" "$default_content"`
        if [[ $? -ne 0 ]]
	then
		echolog "User close get form dialog"
		return 1
	fi
	
	C="/C=RU";
	ST="`echo -e "$res" | sed '1q;d'`"
	if [[ -n "$ST" ]]; then ST="/ST=$ST"; else ST=""; fi

	L="`echo -e "$res" | sed '2q;d'`"
	if [[ -n "$L" ]]; then L="/L=$L"; else L=""; fi

	O="`echo -e "$res" | sed '3q;d'`"
	if [[ -n "$O" ]]; then O="/O=$O"; else O=""; fi

	OU="`echo -e "$res" | sed '4q;d'`"
	if [[ -n "$OU" ]]; then OU="/OU=$OU"; else OU=""; fi
	
	CN="`echo -e "$res" | sed '5q;d'`"
	if [[ -n "$CN" ]]; then CN="/CN=$CN"; else CN=""; fi

	email="`echo -e "$res" | sed '6q;d'`"
	if [[ -n "$email" ]]; then email="/emailAddress=$email"; else email=""; fi

	local subj="\"$C$ST$L$O$OU$CN$email\""
	
	echolog "Cert subj is $subj"
	echo "$subj"
	return 0
}

function create_cert_req ()
{
	local token="$1"
	local key_id="$2"
	echolog "create_cert_req for key: $key_id on token: $token"
	
	subj=`get_cert_subj`
	if [[ $? -ne 0 ]]
	then
		echolog "subj is not specified"
		return 0
	fi

	yesno "Издатель сертификата" "Создать самоподписанный сертификат?"
	res=$?
	if [[ $res -eq 0 ]]
	then
		echolog "cert will be self signed"
		self_signed=1
		req_path=cert.crt
	elif [[ $res -eq 1 ]]
	then
		echolog "cert will be not self signed"
		self_signed=0
		req_path=`save_file_dialog "Сохранение заявки на сертификат" "Куда сохранить заявку" "$CUR_DIR"`
        	if [[ $? -ne 0 ]]
        	then
			echolog "User closes choose req path dialog"
                	return 0
        	fi
	else
		echolog "Users close choose self signed path dialog"
		return 0
	fi

	echolog "Cert req will be saved inside $req_path"
	
	pkcs11_create_cert_req "$token" "$key_id" "$subj" "$req_path" $self_signed &
	show_wait $! "Подождите" "Идет создание заявки"
	res=$?

	if [[ $res -ne 0 ]]
	then
		echoerr "Error occured whhile creating cert request"
		show_text "Ошибка" "Не удалось создать заявку на сертификат"
		return $res
	fi

	if [[ $self_signed -eq 1 ]]
	then
		ehcolog "Self signed cert will be imported on token with id: $kei_id"
	else
		echolog "Cert request will be created"
	fi

	return 0
}

function create_key ()
{
	token="$1"
	key_id="$2"
	echolog "Create key with id: $key_id on token: $token"

	if [[ -z "$key_id" ]]
	then
		key_id=`gen_key_id "$token"`
		echolog "Key id is not specified. Generated is $key_id"
	fi
	
	local types=`echo -e "RSA-2048\nГОСТ-2012 256\nГОСТ-2012 512"`
	type=`show_list "Укажите алгоритм ключевой пары" "Алгоритм" "$types"`
	
	if [[ $? -ne 0 ]]
	then
		echolog "User closes choose key alg dialog"
		return 0
	fi
	ehcolog "Choosen key alg is $type"

	case $type in
	"RSA-2048") type=rsa:2048;;
	"ГОСТ-2012 256") type=GOSTR3410-2012-256:B;;
	"ГОСТ-2012 512") type=GOSTR3410-2012-512:A;;
	esac

	label=`get_string "Метка ключевой пары" "Укажите метку ключевой пары"`
        if [[ $? -ne 0 ]]
        then
		echolog "User closes chooke key label dialog" 
                return 0
        fi

	echolog "Choosen key label is $label"

	pkcs11_gen_key "$token" "$key_id" "$type" "$label" &
	show_wait $! "Подождите" "Идет генерация ключевой пары"
	res=$?

	if [[ $res -eq 2 ]]
	then
		echoerr "Choosen key alg currently not supported inside your system"
		show_text "Ошибка" "Такой тип ключа пока не поддерживается в системе"
		return $res
	fi
	
	if [[ $res -ne 0 ]]
	then
		echoerr "Unknown error occured during creating key"
		show_text "Ошибка" "Во время генерации ключа произошла ошибка"
		return $res
	fi

	echo "$key_id"

	return 0
}

function import_key_and_cert()
{
	token=$1
	key_id=$2
	echoerr "import_key_and_cert with id: $key_id on token:$token"
	
	if [[ -z "$key_id" ]]
        then
                key_id=`gen_key_id "$token"`
		echoerr "Key_id is not specified. Generated is $key_id"
        fi

	pfx_path=`open_file_dialog "Путь до pdx файла" "Укажите путь до pfx файла" "$HOME"`;
	if [[ $? -ne 0 ]]
        then
                echolog "User closes choose pfx file path dialog"
                return 0
        fi
	ecilog "Choosen pfx file is $pfx_path"

	pass=`get_password "Пароль" "Введите пароль от pfx контейнера"`
        if [[ $? -ne 0 ]]
        then
		echolog "User closes getting pfx container password dialog"
                return 0
        fi

	echolog "Getting key from pfx file"
	openssl pkcs12 -in "$pfx_path" -nocerts -out encrypted.key -passin "pass:$pass" -passout "pass:$pass"
	if [[ $? -ne 0 ]]
        then
		echorrr "Error occured during getting key from pfx file"
		show_text "Ошибка" "Ошибка во время чтения закрытого ключа"
        	return 1
	fi

	echolog "Getting cert from pfx file"
	openssl pkcs12 -in "$pfx_path" -nokeys -out cert.pem -passin "pass:$pass"
	if [[ $? -ne 0 ]]
        then
                echorrr "Error occured during getting cert from pfx file"
                show_text "Ошибка" "Ошибка во время чтения сертификата"
                return 1
        fi
	
	echolog "Convert cert to DER format"
	openssl x509 -in cert.pem -out cert.crt -outform DER
	if [[ $? -ne 0 ]]
        then
                echorrr "Error occured during converting cert to DER format"
                show_text "Ошибка" "Ошибка во время конвертации сертфиката"
                return 1
        fi

	echolog "Getting public key from cert"
	openssl x509 -in cert.pem -pubkey -noout | openssl enc -base64 -d > publickey.der
	if [[ $? -ne 0 ]]
        then
                echorrr "Error occured during getting public key from cert"
                show_text "Ошибка" "Ошибка во время получения публичноо ключа из сертификата"
                return 1
        fi

	echolog "Converting key to DER format"
	openssl rsa -in encrypted.key -out key.der -outform DER -passin "pass:$pass"
	if [[ $? -ne 0 ]]
        then
                echorrr "Error occured during converting key to DER format"
                show_text "Ошибка" "Ошибка во время конвертации открытого ключа"
                return 1
        fi

	label=`get_string "Метка ключевой пары" "Укажите метку ключевой пары"`
        if [[ $? -ne 0 ]]
        then
                return 0
        fi

	import_obj_on_token "$token" "privkey" key.der "$label" "$key_id" &
	show_wait $! "Подождите" "Идет импорт закрытого ключа"
        res=$?
	if [[ $res -ne 0 ]]
	then
		echoerr "Error occured during import private key on token"
		show_text "Ошибка" "Не удалось импортировать закрытый ключ на токен"
		rm encrypted.key cert.pem cert.crt key.der publickey.der
		return $res
	fi

        import_obj_on_token "$token" "pubkey" publickey.der "$label" "$key_id" &
        show_wait $! "Подождите" "Идет импорт открытого ключа"
        res=$?
        if [[ $res -ne 0 ]]
        then
		echoerr "Error occured during import public key on token"
		show_text "Ошибка" "Не удалось импортировать закрытый ключ на токен"
                rm encrypted.key cert.pem cert.crt key.der publickey.der
                return $res
        fi

	import_obj_on_token "$token" "cert" cert.crt "$label" "$key_id" &
        show_wait $! "Подождите" "Идет импорт сертификата"
	res=$?
        if [[ $res -ne 0 ]]
        then
		echoerr "Error occured during import cert on token"
                show_text "Ошибка" "Не удалось импортировать сертификат на токен"
                rm encrypted.key cert.pem cert.crt key.der publickey.der
                return $res
        fi

	rm encrypted.key cert.pem cert.crt key.der publickey.der
	return $res
		
}

function choose_token ()
{
	echolog "choose_token"
        get_token_list > get_token_list_res &
	show_wait $! "Подождите" "Подождите, идет получение списка Рутокенов"
        token_list=`cat get_token_list_res`
	echolog "Token_list: $token_list"
	choice=`show_list "Выберите Рутокен" "Подключенные устройства" "$token_list" "Обновить список"`
        
	if [ $? -ne 0 ]
        then
		echolog "User closes choose token dialog"
                return 1
        fi

        if [ "$choice" == "Обновить список" ] || [ -z "$choice" ]
        then
		echolog "User requests update token list"
                choice=`choose_token`
                return $?
        fi
	echolog "User choise token: $choice"

        echo "$choice"
        return 0
}

function show_token_info ()
{
        token=$1
	echolog "show_token_info for token: $token"
        get_token_info "$token" > get_token_info_res &
	show_wait $! "Подождите" "Подождите, идет получение информации"
	token_info=`cat get_token_info_res`
	echolog "Token info:\n$token_info"
	show_list "Информация об устройстве $token" "`echo -e "Атрибут\tЗначение"`" "$token_info"
	return 0
}

function show_token_object ()
{
	token="$1"
	echolog "show_token_obj for token $token"
	get_token_objects "$token" > get_token_object_res &
	show_wait $! "Подождите" "Подождите, идет поиск объектов"
	objs=`cat get_token_object_res`
	echolog "Objects:\n$objs"
	header=`echo -e "$objs" | head -n 1`
	objs=`echo -e "$objs" | tail -n +2`
	
	extra=`echo -e "Импорт ключевой пары и сертификата\tГенерация ключевой пары\tИмпорт сертификата"`
	obj=`show_list "Объекты на Рутокене $token" "$header" "$objs" "$extra"`
	
	if [[ -z "$obj" ]]
	then
		return 0
	fi
	echolog "choosen object or function: $obj"

	extra=0
	case "$obj" in
	"Генерация ключевой пары")
		extra=1
		key_id=`create_key "$token"`
		;;
	"Импорт ключевой пары и сертификата")
		extra=1
		import_key_and_cert "$token"
		;;
	"Импорт сертификата")
		extra=1
		import_cert "$token"
		;;
	esac

	if [[ $extra -eq 1 ]]
	then
	        show_token_object "$token"
	        return $?
	fi
	
	type=`echo "$obj" | cut -f1`
	id=`echo "$obj" | cut -f2`

	case "$type" in
        "Закрытый ключ")
                type=privkey
		;;
        "Открытый ключ")
		type=pubkey
                ;;
        "Сертификат")
		type=cert
                ;;
        esac
	echorrr "Choosen object type: $type and id: $id"

	if  [[ $type == "cert" ]]
	then
		actions=`echo -e "Удалить\nПросмотр\nСохранить на диске\nНастроить локальную аутентификацию по данному сертификату"`
		act=`show_list "Выберите действие" "Действия" "$actions"`
	else
		actions=`echo -e "Удалить\nИмпорт сертификата ключа\nСоздать заявку на сертификат"`
		act=`show_list "Выберите действие" "Действия" "$actions"`
	fi
	echorrr "Choosen action under object is $act"

	case "$act" in
	"Просмотр")
		export_object "$token" "$type" "$id" "cert.crt" &
		show_wait $! "Подождите" "Подождите, идет чтение объекта"
		xdg-open "cert.crt"
		echorrr "open exported obj"
		;;
	"Сохранить на диске")
		export_object "$token" "$type" "$id" "cert.crt" &
                show_wait $! "Подождите" "Подождите, идет чтение объекта"
		target=`save_file_dialog "Сохранение сертификата" "Укажите, куда сохранить сертификат" "$CUR_DIR"`
		if [[ $? -eq 0 ]]
		then
			echolog "Object exported to $target"
			mv cert.crt "$target"
		else
			echolog "user closes save file dialog"
		fi
		;;
	"Импорт сертификата ключа")
			import_cert "$token" "$id"
		;;
	"Создать заявку на сертификат")
			create_cert_req "$token" "$id"
		;;
	"Настроить локальную аутентификацию по данному сертификату")
			sudo_cmd setup_local_authentication "$token" "$id"
		;;
	"Удалить")
		yesno "Удаление объекта" "Уверены, что хотите удалить объект?"
		if [[ $? -eq 0 ]]
		then
			remove_object "$token" "$type" "$id"&
			show_wait $! "Подождите" "Подождите, идет удаление"
		fi
		;;
	*)
		return 0
		;;
	esac

	show_token_object "$token"
	return $?
}

function format_token ()
{
	token="$1"
	echolog "Formatting token: $token"
	
	yesno "Форматирование Рутокена" "`echo -e "Вы действительно хотите отформатировать Рутокен?\nВ результате все ключи и сертификаты будут удалены."`"
	if [[ $? -ne 0 ]]
	then
		echolog "User doesn't accept formatting"
		return 0
	fi
	
	echolog "getting old admin pin"
	old_admin_pin=`get_password "Ввод текущего PIN-кода" "Введите текущий PIN-код Администратора:"`
	if [[ $? -ne 0 ]]
        then
		echolog "User closes getting old admin pin dialog"
                return 0
        fi
	
	echolog "getting new admin pin"
	admin_pin=`get_password "Ввод текущего PIN-кода" "Введите новый PIN-код Администратора:"`
        if [[ $? -ne 0 ]]
        then
		echolog "User closes getting new admin pin dialog"
                return 0
        fi
	echolog "getting new user pin"
	user_pin=`get_password "Ввод нового PIN-кода" "Введите новый PIN-код Пользователя:"`
        if [[ $? -ne 0 ]]
        then
		echolog "User closes getting new user pin dialog"
                return 0
        fi

	echolog "Checking old admin pin"
	check_admin_pin "$token" "$old_admin_pin"&
	show_wait $! "Подождите" "Идет проверка PIN-кода Администратора"
	res=$?

	if [[ $res -ne 0 ]]
	then
		echoerr "Checking old admin pin failed"
		show_text "Ошибка" "Введен неправильный текущий PIN-код Администратора"
		return $res
	fi

	pkcs11_format_token "$token" "$user_pin" "$admin_pin" &
	show_wait $! "Подождите" "Подождите, идет форматирование"
        res=$?

	if [[ $res -eq 2 ]]
	then
		echoerr "More then one token inserted while formatting token."
		show_text "Ошибка" "Подключено более одного Рутокена. Для форматирования оставьте только одно подключённое устройство"
		return $res
	fi
        
	if [[ $res -ne 0 ]]
        then
		echoerr "Can't formatting token. Unexpected error"
                show_text "Ошибка" "Не удалось отформатировать Рутокен"
        fi
        return $res
}

function change_user_pin ()
{
	token="$1"
	echolog "Getting new user pin"
        new_user_pin=`get_password "Ввод нового PIN-кода" "Введите новый PIN-код Пользователя:"`
        if [[ $? -ne 0 ]]
        then
		echolog "User closes getting new user pin dialog"
                return 0
        fi

	pkcs11_change_user_pin "$token" "$new_user_pin"	&
	show_wait $! "Подождите" "Подождите, идет смена PIN-кода"
        res=$?

        if [[ $res -ne 0 ]]
        then
		echoerr "Unknown error occured while change user pin dialog"
                show_text "Ошибка" "Не удалось сменить PIN-код Пользователя"
        fi
        return $res
}

function change_admin_pin ()
{
	token="$1"
	echolog "change_admin_pin token:$token"
	echolog "Getting old admin pin"
	old_admin_pin=`get_password "Ввод текущего PIN-кода" "Введите текущий PIN-код Администратора:"`
        if [[ $? -ne 0 ]]
        then
                echolog "User closes getting old admin pin dialog"
		return 0
        fi

	echolog "Getting new admin pin"
	local admin_pin=`get_password "Ввод нового PIN-кода" "Введите новый PIN-код Администратора:"`
        if [[ $? -ne 0 ]]
        then
		echolog "User closes getting new admin pin dialog"
                return 0
        fi

	pkcs11_change_admin_pin "$token" "$old_admin_pin" "$admin_pin" &
        show_wait $! "Подождите" "Подождите, идет смена PIN-кода"
        res=$?

        if [[ $res -ne 0 ]]
        then
		echoerr "Unknown error occured while change admin pin dialog"
                show_text "Ошибка" "Не удалось изменить PIN-код Администратора"
        fi
        return $res
}

function unlock_pin ()
{
	token="$1"
	echolog "unlock_pin token:$token"
	echolog "Getting admin pin"
        admin_pin=`get_password "Ввод PIN-кода" "Введите PIN-код Администратора:"`
	if [[ $? -ne 0 ]]
	then
		echolog "User closes getting admin pin dialog"
		return 0
	fi

	pkcs11_unlock_pin "$token" "$admin_pin" &
        show_wait $! "Подождите" "Подождите, идет разблокировка PIN-кода"
	res=$?

	if [[ $res -eq 2 ]]
        then
		echoerr "More then one token inserted while unblock pin"
                show_text "Ошибка" "Подключено более одного Рутокена. Для разблокировки ПИН-кода оставьте только одно подключённое устройство"
        	return $res
	fi

	if [[ $res -ne 0 ]]
	then
		echoerr "Unknown error occured while unlock user pin"
		show_text "Ошибка" "Не удалось разблокировать PIN-код Пользователя"
	fi
	return $res
}

function show_wait ()
{
	pid="$1"
	title="$2"
	text="$3"

	dialog_manager_enabeled
	if [[ $? -ne 0 ]]
	then
		zenity_enable
		if [[ $? -eq 0 ]]
		then
			zenity --info --text="$text" --title="$title" &
			dialog_pid=$!
		else
			fly-dialog --title "$title" --msgbox "$text" &
			dialog_pid=$!
		fi
	else
		show_wait_dialog "$title" "$text" &
		dialog_pid=$!
	fi
	
	wait $pid
	ret_code=$?
	rkill $dialog_pid
	return $ret_code
}

function show_text ()
{
	title="$1"
	text="$2"

	dialog_manager_enabeled
	if [[ $? -ne 0 ]]
	then
		zenity_enable
		if [[ $? -eq 0 ]]
		then
			zenity --info --text="$text" --title="$title"
			ret=$?
		else
			fly-dialog --title "$title" --msgbox "$text"
			ret=$?
		fi
	else
		show_text_dialog "$title" "$text"
		ret=$?
	fi

	return $ret
}

function show_menu ()
{
        token="$1"
        menu_list="$2"
        cmd_list="$3"
	echolog "show_menu token:$token menu_list:$menu_list cmd_list:$cmd_list"

	choice=`show_list "Меню" "Выберите действие" "$menu_list"`
	
	if [[ -z "$choice" ]]	
	then
		echolog "Menu closed"
		return 1
	fi
	echolog "choosen menu name: $choice"

	choice_id=`echo -e "$menu_list" | sed -n "/$choice/=" `
	
	cmd=`echo -e "$cmd_list" | sed "${choice_id}q;d"`
	echolog "choosen cmd: $cmd"
	$cmd "$token"
	
	return 0
}

function follow_token()
{
	menu_pid=$1
	token="$2"
	echolog "follow token: $token with menu_pid: $menu_pid"

	token_present=1
	while  [[ "$token_present" -eq 1 ]]
	do
		echo > pcsc_scan_res
		pcsc_scan > pcsc_scan_res &
		pcsc_pid=$!
		sleep 1
		kill $pcsc_pid

		if ! ps -p $menu_pid > /dev/null
		then
			echolog "menu closed. token following is stoped"
   			return 0
		fi

		if [[ -z "`cat pcsc_scan_res | grep \"$token\"`" ]]
		then
			echolog "token is not present now"
			token_present=0
		fi
	done

	rkill $menu_pid
	return 1
}

function rkill()
{
	kill `pstree -p $1 | sed 's/(/\n(/g' | grep '(' | sed 's/(\(.*\)).*/\1/' | tr "\n" " "`
}

function sudo_cmd()
{
	xhost_out=`xhost`
	if [[ -z "`echo -e \"$xhost_out\" | grep root`" && $UID -ne 0 ]]
	then
		echolog "Adding root to allowed x11 user"
		xhost +SI:localuser:root
	fi
	
	echolog "execute cmd $@ from sudo"
	pkexec env LOG_FILE="$LOG_FILE" DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" PIN="$PIN" GUI_MANAGER="$GUI_MANAGER" XDG_CURRENT_DESKTOP="$XDG_CURRENT_DESKTOP" "${BASH_SOURCE[0]}" "$@"
	
	if [[ -z "`echo -e \"$xhost_out\" | grep root`" && $UID -ne 0 ]]
	then
		echolog "remove root from allowed x11 user"
		xhost -SI:localuser:root
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
	init
	"$@"
	res=$?
	cleanup
	exit $res
fi
