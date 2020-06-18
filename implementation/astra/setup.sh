#!/bin/bash

function check_pkgs ()
{
        pkgs=$@
	out=`apt-get --just-print install $pkgs`
        if [[ -z "`echo -e "$out" | grep "NEW\|НОВЫЕ"`" ]]
        then
                return 0
        fi
        return 1

}

function _install_common_packages ()
{
	local pkgs="libengine-pkcs11-openssl1.1 opensc libccid pcscd libp11-2 pcsc-tools python3-tk dialog"
        check_update="$1"

        if ! [[ -z "$check_updates" ]]
        then
                check_pkgs $pkgs
                if  [[ $? -eq 0 && -f $LIBRTPKCS11ECP ]]
                then
                        return 0
                fi

                return 1
        fi

	sudo apt-get -qq update
	if ! [[ -f $LIBRTPKCS11ECP ]]
	then
		wget -q --no-check-certificate "https://download.rutoken.ru/Rutoken/PKCS11Lib/Current/Linux/x64/librtpkcs11ecp.so";
        	if [[ $? -ne 0 ]]
		then
			echoerr "Не могу загрузить пакет librtpkcs11ecp.so"
			return 1
		fi 
		sudo cp librtpkcs11ecp.so $LIBRTPKCS11ECP;
	fi

	sudo apt-get -qq install $pkgs;
	if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi
	
	return 0
}

function _install_packages_for_local_auth ()
{
        local pkgs="libpam-p11 libpam-pkcs11"
        if ! [[ -z "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi

        sudo apt-get -qq install $pkgs;
        if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi

	return 0
}

function _install_packages_for_domain_auth ()
{
	return 0
}

function _setup_local_authentication ()
{
	user=$2
	home=`getent passwd $user | cut -d: -f6`

	pkcs11-tool --module $LIBRTPKCS11ECP -r -y cert --id $1 > cert.crt 2> /dev/null;
	if [[ $? -ne 0 ]]; then echoerr "Не удалось экспортировать сертификат с Рутокена"; fi 
	openssl x509 -in cert.crt -out cert.pem -inform DER -outform PEM;
	mkdir "$home/.eid" 2> /dev/null;
	chmod 0755 "$home/.eid";
	cat cert.pem >> "$home/.eid/authorized_certificates";
	chmod 0644 "$home/.eid/authorized_certificates";
	LIBRTPKCS11ECP=$LIBRTPKCS11ECP envsubst < "$TWO_FA_LIB_DIR/common_files/p11" | sudo tee /usr/share/pam-configs/p11 > /dev/null;
	chown $user:$user -R $home/.eid
	read -p "ВАЖНО: Нажмите Enter и в следующем окне выберите Pam_p11"
	sudo pam-auth-update;

	return 0
}

function _setup_autolock ()
{
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	sudo systemctl daemon-reload
	return 0
}

function _setup_domain_authentication ()
{
	sudo sed -i -e "s/^auth.*success=2.*pam_unix.*$/auth    \[success=2 default=ignore\]    pam_sss.so forward_pass/g" -e "s/^auth.*success=1.*pam_sss.*$/auth    \[success=1 default=ignore\]    pam_unix.so nullok_secure try_first_pass/g" /etc/pam.d/common-auth
	return 0
}

