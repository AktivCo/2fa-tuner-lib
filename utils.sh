#!/bin/bash

TWO_FA_LIB_DIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd`
. "$TWO_FA_LIB_DIR/pkcs11_utils.sh"

NUMBER_REGEXP='^[0123456789abcdefABCDEF]+$'
CUR_DIR=`pwd`
DIALOG="dialog --keep-tite --stdout"
YAD="yad --center --width=400 --height=400"
SIMPLE_YAD="yad --center "
RTADMIN=rtAdmin

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
	TMP_DIR=`pwd`
	
	return 0
}

function set_dialog_manager ()
{
	echo
	manager=$1
	case $manager in 
	"yad")
		. "$TWO_FA_LIB_DIR/yad.sh"
		;;
	"python")
                . "$TWO_FA_LIB_DIR/python_gui.sh"
                ;;

	*)
		. "$TWO_FA_LIB_DIR/dialog.sh"
		;;
	esac

	return 0
}

function cleanup() { rm -rf $TMP_DIR; cd "$CUR_DIR"; return 0; }

echoerr() { echo -e "Ошибка: $@" 1>&2; return 0; }

function install_common_packages ()
{
	check_updates=$1
	rtadmin_path=/usr/bin/rtAdmin

        if ! [[ -z "$check_updates" ]]
        then
                if ! [[ -f $rtadmin_path ]]
		then
			return 1
        
		fi
	else
		wget -q --no-check-certificate "https://download.rutoken.ru/Rutoken/Utilites/rtAdmin/1.3/linux/x86_64/rtAdmin";
		if [[ $? -ne 0 ]]
        	then
                	echoerr "Не могу загрузить утилиту rtAdmin"
                	return 1
        	fi
		
		sudo mv rtAdmin $rtadmin_path
		chmod +x $rtadmin_path
	fi
	
	_install_common_packages $check_updates
	
	return $?
}

function install_packages_for_local_auth ()
{
	check_updates=$1
	install_common_packages $check_updates
	if [[ $? -eq 1 ]]
	then
		echoerr "can't install common packages"
		return 1
	fi

        _install_packages_for_local_auth $check_updates
	
	return $?
}

function install_packages_for_domain_auth ()
{
	check_updates=$1
	install_common_packages  $check_updates
	if [[ $? -eq 1 ]]
        then
		echoerr "can't install common packages"
                return 1
        fi

        _install_packages_for_domain_auth  $check_updates
	
	return $?
}


function setup_local_authentication ()
{
	_setup_local_authentication "$1" "$2"
	return $?
}

function setup_autolock ()
{
	LIBRTPKCS11ECP="$LIBRTPKCS11ECP" LOCK_SCREEN_CMD="$LOCK_SCREEN_CMD" envsubst < "$TWO_FA_LIB_DIR/common_files/pkcs11_eventmgr.conf" | sudo tee "$PAM_PKCS11_DIR/pkcs11_eventmgr.conf" > /dev/null
	_setup_autolock
	sudo systemctl daemon-reload
	return $?
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
	if ! [ -f "$CA_path" ]
	then 
		echoerr "$CA_path doesn't exist"
		return 1
	fi

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
	
	return 0
}

function choose_cert ()
{
	cert_ids=`get_cert_list`
	if [[ -z "$cert_ids" ]]
	then
		echo "None"
		return 0
	fi

	cert_ids=`echo -e "$cert_ids\n\"Новый сертификат\""`;
	cert_ids=`echo "$cert_ids" | awk '{printf("%s\t%s\n", NR, $0)}'`;
	cert_id=`echo $cert_ids | xargs $DIALOG --title "Выбор сертификата" --menu "Выбeрите сертификат" 0 0 0`;
	cert_id=`echo "$cert_ids" | sed "${cert_id}q;d" | cut -f2 -d$'\t'`;
	echo "$cert_id"

	return 0
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

	return 0
}

function choose_key ()
{
	key_ids=`get_key_list`
	if [[ -z "$key_ids" ]]
	then
		echo "Нет ключей"
		return 0
	fi

	key_ids=`echo -e "$key_ids\n\"Новый ключ\""`;
	key_ids=`echo "$key_ids" | awk '{printf("%s\t%s\n", NR, $0)}'`;
	key_id=`echo $key_ids | xargs $DIALOG --title "Выбор ключа" --menu "Выберите ключ" 0 0 0`;
	key_id=`echo "$key_ids" | sed "${key_id}q;d" | cut -f2 -d$'\t'`;
	echo "$key_id"

	return 0
}

function gen_cert_id ()
{
	res="1"
	cert_ids=`get_cert_list`
	
	while [[ -n "$res" ]]
	do
		rand=`echo $(( $RANDOM % 10000 ))`
		res=`echo $cert_ids | grep -w $rand`
	done
	
	echo "$rand"

	return 0
}

function gen_key_id ()
{
	res="1"
	key_ids=`get_key_list`
	while [[ -n "$res" ]]
	do
		rand=`echo $(( $RANDOM % 10000 ))`
		res=`echo $key_ids | grep -w $rand`
	done

	echo "$rand"

	return 0
}

function import_cert ()
{
	cert_path=`$DIALOG --title "Укажите путь до сертификата" --fselect $HOME 0 0`;
	key_ids=`get_key_list`
	if [[ -z "$key_ids" ]]
	then
		echoerr "На Рутокене нет ключей";
		return 1
	fi

	key_ids=`echo "$key_ids" | awk '{printf("%s\t%s\n", NR, $0)}'`;
	key_id=`echo $key_ids | xargs $DIALOG --title "Выбор ключа" --menu "Выберите ключ для которого выдан сертификат" 0 0 0`;
	key_id=`echo "$key_ids" | sed "${key_id}q;d" | cut -f2 -d$'\t'`;

	openssl x509 -in $cert_path -out cert.crt -inform PEM -outform DER;
	import_cert_on_token cert.crt $key_id

	return $?
}

function get_token_password ()
{
	token=$1
	res=1
	while [[ $res -ne 0 ]]
	do
		pin=`get_password "Ввод PIN-кода" "Введите PIN-код Пользователя:"`
		res=$?
		
		if [[ $res -ne 0 ]]
		then
			return $res 
		fi

		check_pin "$token" "$pin" &
		show_wait $! "Подождите" "Идет проверка PIN-кода"
		res=$?

		if [[ $res -eq 2 ]]
		then
			yesno "PIN-код заблокирован" "`echo -e \"PIN-код Пользователя заблокирован.\nРазблокировать его с помощью PIN-кода Администратора?\"`"

			res=$?
			if [[ $res -ne 0 ]]
			then
				return $res
			fi

			unlock_pin "$token"
			res=$?
		else
			if [[ $res -ne 0 ]]
			then
				show_text "Ошибка" "Неправильный PIN-код"
			fi
		fi
	done

	echo "$pin"
	return 0
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
	return 0
}

function create_cert_req ()
{
	cert_id=$1
	
	req_path=`$DIALOG --title "Куда сохранить заявку" --fselect "$CUR_DIR/cert.csr" 0 0`
	
	subj=`get_cert_subj`

	pkcs11_create_cert_req $cert_id "$subj" "$req_path" 0

	if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось создать заявку на сертификат"
		return 1
	fi

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

        choice=`$DIALOG --stdout --title "Создание сертификата" --menu "Укажите опцию" 0 0 0 1 "Создать самоподписанный сертификат" 2 "Создать заявку на сертификат"`
        
	subj=`get_cert_subj`
	
	pkcs11_create_cert_req $cert_id "$subj" "$req_path" $choice
	
        if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось записать сертификат на Рутокен"
		return 1
	fi
        
	echo $cert_id
	return 0
}

function choose_token ()
{
        get_token_list > get_token_list_res &
	show_wait $! "Подождите" "Подождите, идет получение списка Рутокенов"
        token_list=`cat get_token_list_res`
	choice=`show_list "Выберите Рутокен" "Подключенные устройства" "$token_list" "Обновить список" "Обновить список"`
        
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
        get_token_info "$token" > get_token_info_res &
	show_wait $! "Подождите" "Подождите, идет получение информации"
	token_info=`cat get_token_info_res`
	show_list "Информация об устройстве $token" "Атрибут\tЗначение" "$token_info"
	return 0
}

function show_token_object ()
{
	token="$1"
	get_token_objects "$token" > get_token_object_res &
	show_wait $! "Подождите" "Подождите, идет поиск объектов"
	objs=`cat get_token_object_res`
	objs=`python3 "$TWO_FA_LIB_DIR/python_utils/parse_objects.py" "$objs"`
	header=`echo -e "$objs" | head -n 1`
	objs=`echo -e "$objs" | tail -n +2`
	
	obj=`show_list "Объекты на Рутокене $token" "$header" "$objs"`
	
	if [[ -z "$obj" ]]
	then
		return 0
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

	if  [[ $type == "cert" ]]
	then
		actions=`echo -e "Удалить\nПросмотр"`
		act=`show_list "Выберите действие" "Действия" "$actions"`
	else
		act=`show_list "Выберите действие" "Действия" "Удалить"`
	fi

	case "$act" in
	"Покaзать")
		import_object "$token" "$type" "$id" "cert.crt" &
		show_wait $! "Подождите" "Подождите, идет чтение объекта"
		xdg-open "cert.crt"
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

	show_token_object $token
	return $?
}

function format_token ()
{
	token="$1"
	old_admin_pin=`get_password "Ввод текущего PIN-кода" "Введите текущий PIN-код Администратора:"`
	if [[ $? -ne 0 ]]
        then
                return 0
        fi

	user_pin=`get_password "Ввод нового PIN-кода" "Введите новый PIN-код Пользователя:"`
        if [[ $? -ne 0 ]]
        then
                return 0
        fi

	admin_pin=`get_password "Ввод текущего PIN-кода" "Введите новый PIN-код Администратора:"`
        if [[ $? -ne 0 ]]
        then
                return 0
        fi

	check_admin_pin "$token" "$old_admin_pin"&
	show_wait $! "Подождите" "Идет проверка PIN-кода Администратора"
	res=$?

	if [[ $res -ne 0 ]]
	then
		show_text "Ошибка" "Введен неправильный текущий PIN-код Администратора"
		return $res
	fi

	pkcs11_format_token "$token" "$user_pin" "$admin_pin" &
	show_wait $! "Подождите" "Подождите, идет форматирование"
        res=$?

        if [[ $res -ne 0 ]]
        then
                show_text "Ошибка" "Не удалось отформатировать Рутокен"
        fi
        return $res
}

function change_user_pin ()
{
	token="$1"
        new_user_pin=`get_password "Ввод нового PIN-кода" "Введите новый PIN-код Пользователя:"`
        if [[ $? -ne 0 ]]
        then
                return 0
        fi

	pkcs11_change_user_pin "$token" "$new_user_pin"	&
	show_wait $! "Подождите" "Подождите, идет смена PIN-кода"
        res=$?

        if [[ $res -ne 0 ]]
        then
                show_text "Ошибка" "Не удалось сменить PIN-код Пользователя"
        fi
        return $res
}

function change_admin_pin ()
{
	token="$1"
	old_admin_pin=`get_password "Ввод текущего PIN-кода" "Введите текущий PIN-код Администратора:"`
        if [[ $? -ne 0 ]]
        then
                return 0
        fi

	local admin_pin=`get_password "Ввод нового PIN-кода" "Введите новый PIN-код Администратора:"`
        if [[ $? -ne 0 ]]
        then
                return 0
        fi

	pkcs11_change_admin_pin "$token" "$old_admin_pin" "$admin_pin" &
        show_wait $! "Подождите" "Подождите, идет смена PIN-кода"
        res=$?

        if [[ $res -ne 0 ]]
        then
                show_text "Ошибка" "Не удалось изменить PIN-код Администратора"
        fi
        return $res
}

function unlock_pin ()
{
	token="$1"
        admin_pin=`get_password "Ввод PIN-кода" "Введите PIN-код Администратора:"`
	if [[ $? -ne 0 ]]
	then
		return 0
	fi

	pkcs11_unlock_pin "$token" "$admin_pin" &
        show_wait $! "Подождите" "Подождите, идет разблокировка PIN-кода"
	res=$?

	if [[ $res -ne 0 ]]
	then
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
		zenity --info --text="$text" --title="$title" &
		dialog_pid=$!
	else
		show_wait_dialog "$title" "$text" &
		dialog_pid=$!
	fi
	
	wait $pid
	ret_code=$?
	pkill -P $dialog_pid
	kill $dialog_pid
	return $ret_code
}

function show_menu ()
{
        token="$1"
        menu_list="$2"
        cmd_list="$3"

	choice=`show_list "Меню" "Выберите действие" "$menu_list"`
	
	if [[ -z "$choice" ]]	
	then
		return 1
	fi

	choice_id=`echo -e "$menu_list" | sed -n "/$choice/=" `
	
	cmd=`echo -e "$cmd_list" | sed "${choice_id}q;d"`
	$cmd "$token"
	
	return 0
}

function follow_token()
{
	menu_pid=$1
	token="$2"

	token_present=1
	while  [[ "$token_present" -eq 1 ]]
	do
		echo > pcsc_scan_res
		pcsc_scan > pcsc_scan_res &
		pcsc_pid=$!
		sleep 1
		pkill $pcsc_pid

		if ! ps -p $menu_pid > /dev/null
		then
   			return 0
		fi

		if [[ -z "`cat pcsc_scan_res | grep \"$token\"`" ]]
		then
			token_present=0
		fi
	done
	
	kill -- -$(ps -o pgid= $menu_pid | grep -o [0-9]*)	
	return 1
}
