#!/bin/bash

function _install_common_packages ()
{
	sudo apt-get -qq update
	if ! [[ -f $LIBRTPKCS11ECP ]]
	then
		wget -q --no-check-certificate "https://download.rutoken.ru/Rutoken/PKCS11Lib/Current/Linux/x64/librtpkcs11ecp.so";
        	if [[ $? -ne 0 ]]; then echoerr "Не могу скачать пакет librtpkcs11ecp.so"; fi 
		sudo cp librtpkcs11ecp.so $LIBRTPKCS11ECP;
	fi

	sudo apt-get -qq install libengine-pkcs11-openssl1.1 opensc libccid pcscd libp11-3 dialog;
	if [[ $? -ne 0 ]]; then echoerr "Не могу установить один из пакетов: libengine-pkcs11-openssl1.1 opensc libccid pcscd libp11-2 dialog из репозитория"; fi
}

function _install_packages_for_local_auth ()
{
        sudo apt-get -qq install libpam-p11 libpam-pkcs11;
        if [[ $? -ne 0 ]]; then echoerr "Не могу установить один из пакетов: libpam-p11 libpam-pkcs11 из репозитория"; fi
}

function _install_packages_for_domain_auth ()
{
	echo
}

function _setup_local_authentication ()
{
	user=$2
	home=`getent passwd $user | cut -d: -f6`

	pkcs11-tool --module $LIBRTPKCS11ECP -r -y cert --id $1 > cert.crt 2> /dev/null;
	if [[ $? -ne 0 ]]; then echoerr "Не удалось загрзить загрзить сертификат с Рутокена"; fi 
	openssl x509 -in cert.crt -out cert.pem -inform DER -outform PEM;
	mkdir "$home/.eid" 2> /dev/null;
	chmod 0755 "$home/.eid";
	cat cert.pem >> "$home/.eid/authorized_certificates";
	chmod 0644 "$home/.eid/authorized_certificates";
	LIBRTPKCS11ECP=$LIBRTPKCS11ECP envsubst < "$TWO_FA_LIB_DIR/common_files/p11" | sudo tee /usr/share/pam-configs/p11 > /dev/null;
	chown $user:$user -R $home/.eid
	read -p "ВАЖНО: Нажмите Enter и в следующем окне выберите Pam_p11"
	sudo pam-auth-update;
}

function _setup_autolock ()
{
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	sudo systemctl daemon-reload
}

function _setup_domain_authentication ()
{
	sudo sed -i -e "s/^auth.*success=2.*pam_unix.*$/auth    \[success=2 default=ignore\]    pam_sss.so forward_pass/g" -e "s/^auth.*success=1.*pam_sss.*$/auth    \[success=1 default=ignore\]    pam_unix.so nullok_secure try_first_pass/g" /etc/pam.d/common-auth
}

