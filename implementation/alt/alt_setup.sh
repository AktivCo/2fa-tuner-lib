#!/bin/bash

function _install_common_packages ()
{
        sudo apt-get -qq update
	sudo apt-get -qq install openssl-engine_pkcs11 librtpkcs11ecp opensc ccid pcsc-lite libp11 dialog
	LIBRTPKCS11ECP=`whereis  librtpkcs11ecp | cut -d " " -f 2`
	if [[ $? -ne 0 ]]; then echoerr "Не могу установить один из пакетов: openssl-engine_pkcs11 librtpkcs11ecp opensc ccid pcsc-lite libp11 dialog из репозитория"; fi
	sudo systemctl restart pcscd
}


function _install_packages_for_local_auth ()
{
        sudo apt-get -qq install pam_pkcs11 pam_p11 nss-tools
        if [[ $? -ne 0 ]]; then echoerr "Не могу установить один из пакетов: pam_pkcs11 pam_p11 nss-tools из репозитория"; fi
        sudo systemctl restart pcscd
}

function _install_packages_for_domain_auth ()
{
        echo
}

function _setup_local_authentication ()
{
	user=$2
	DB=$PAM_PKCS11_DIR/nssdb
	sudo mkdir $DB 2> /dev/null;
	if ! [ "$(ls -A $DB)" ]
	then
		sudo chmod 0644 $DB
		sudo certutil -d $DB -N
	fi
	
	sudo modutil -dbdir $DB -add p11-kit-trust -libfile /usr/lib64/pkcs11/p11-kit-trust.so 2> /dev/null
	
	pkcs11-tool --module $LIBRTPKCS11ECP -l -r -y cert -d $1 -o cert$1.crt
	sudo cp cert$1.crt /etc/pki/ca-trust/source/anchors/
	sudo update-ca-trust force-enable
	sudo update-ca-trust extract

	sudo mv $PAM_PKCS11_DIR/pam_pkcs11.conf $PAM_PKCS11_DIR/pam_pkcs11.conf.default 2> /dev/null;
	sudo mkdir $PAM_PKCS11_DIR/cacerts $PAM_PKCS11_DIR/crls 2> /dev/null;
	sudo mkdir $PAM_PKCS11_DIR 2> /dev/null
	LIBRTPKCS11ECP=$LIBRTPKCS11ECP PAM_PKCS11_DIR=$PAM_PKCS11_DIR envsubst < "$TWO_FA_LIB_DIR/common_files/pam_pkcs11.conf" | sudo tee $PAM_PKCS11_DIR/pam_pkcs11.conf > /dev/null

	openssl dgst -sha1 cert$1.crt | cut -d" " -f2- | awk '{ print toupper($0) }' | sed 's/../&:/g;s/:$//' | sed "s/.*/\0 -> $user/" | sudo tee $PAM_PKCS11_DIR/digest_mapping -a  > /dev/null 

	pam_pkcs11_insert="NR == 2 {print \"auth sufficient pam_pkcs11.so pkcs11_module=$LIBRTPKCS11ECP\" } {print}"
	
	sys_auth="/etc/pam.d/system-auth"
	if ! [ "$(sudo cat $sys_auth | grep 'pam_pkcs11.so')" ]
	then
		awk "$pam_pkcs11_insert" $sys_auth | sudo tee $sys_auth  > /dev/null  
	fi
}

function _setup_autolock ()
{
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
}

function _setup_domain_authentication ()
{
        echo
}

