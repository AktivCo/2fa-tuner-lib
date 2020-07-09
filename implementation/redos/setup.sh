#!/bin/bash

function check_pkgs ()
{
        pkgs=$@
        out=`yum list available $pkgs`
        if [[ -z "`echo -e "$out" | grep "x86_64"`" ]]
        then
                return 0
        fi
        return 1

}

function _install_common_packages ()
{
	local pkgs="ccid opensc gdm-plugin-smartcard pcsc-tools nss-tools libp11 engine_pkcs11 python3-tkinter dialog"
        check_update="$1"

        if [[ "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi
	
	sudo yum -q -y update

	sudo yum -q -y install $pkgs;
	if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi

	sudo systemctl restart pcscd
	return 0
}

function _install_packages_for_local_auth ()
{
        check_update="$1"
	local pkgs="p11-kit pam_pkcs11 rpmdevtools"
        if ! [[ -z "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi

        sudo yum -q -y install $pkgs;
        if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi

	return 0
}

function _install_packages_for_domain_auth ()
{
        check_update="$1"
	local pkgs="libsss_sudo"
        if ! [[ -z "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi

	sudo yum -q -y install libsss_sudo;
        if [[ $? -ne 0 ]]
        then
                echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
                return 1
        fi

        return 0
}

function _setup_local_authentication ()
{
	token=$1
	cert_id=$2
	user=$3

	DB=$PAM_PKCS11_DIR/nssdb
	sudo mkdir "$DB" 2> /dev/null;
	if ! [ "`ls -A "$DB"`" ]
	then
		sudo chmod 0644 "$DB"
		sudo certutil -d "$DB" -N --empty-password
	fi
	
	echo -e "\n" | sudo modutil -dbdir "$DB" -add p11-kit-trust -libfile /usr/lib64/pkcs11/p11-kit-trust.so 2> /dev/null
	
	export_object "$token" "cert" "$cert_id" "cert${cert_id}.crt"
	sudo cp "cert${cert_id}.crt" /etc/pki/ca-trust/source/anchors/
	sudo update-ca-trust force-enable
	sudo update-ca-trust extract

	sudo mv "$PAM_PKCS11_DIR/pam_pkcs11.conf" "$PAM_PKCS11_DIR/pam_pkcs11.conf.default" 2> /dev/null;
	sudo mkdir "$PAM_PKCS11_DIR/cacerts" "$PAM_PKCS11_DIR/crls" 2> /dev/null;
	sudo mkdir "$PAM_PKCS11_DIR" 2> /dev/null
	LIBRTPKCS11ECP="$LIBRTPKCS11ECP" PAM_PKCS11_DIR="$PAM_PKCS11_DIR" envsubst < "$TWO_FA_LIB_DIR/common_files/pam_pkcs11.conf" | sudo tee "$PAM_PKCS11_DIR/pam_pkcs11.conf" > /dev/null

	openssl dgst -sha1 "cert${cert_id}.crt" | cut -d" " -f2- | awk '{ print toupper($0) }' | sed 's/../&:/g;s/:$//' | sed "s/.*/\0 -> $user/" | sudo tee "$PAM_PKCS11_DIR/digest_mapping" -a  > /dev/null 

	pam_pkcs11_insert="/pam_unix/ && x==0 {print \"auth sufficient pam_pkcs11.so pkcs11_module=$LIBRTPKCS11ECP\"; x=1} 1"
	
	sys_auth="/etc/pam.d/system-auth"
	if ! [ "$(sudo cat $sys_auth | grep 'pam_pkcs11.so')" ]
	then
		awk "$pam_pkcs11_insert" $sys_auth | sudo tee $sys_auth  > /dev/null  
	fi

	pass_auth="/etc/pam.d/password-auth"
        if ! [[ "$(sudo cat $pass_auth | grep 'pam_pkcs11.so')" ]]
        then
		awk "$pam_pkcs11_insert" $pass_auth | sudo tee $pass_auth  > /dev/null
        fi

	return 0
}

function _setup_autolock ()
{
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	return 0
}

function _setup_freeipa_domain_authentication ()
{
	return 0
}

function _setup_ad_domain_authentication ()
{
        return 0
}

