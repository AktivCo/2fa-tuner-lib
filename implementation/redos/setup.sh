#!/bin/bash

function check_pkgs ()
{
        pkgs=$@
        echolog "Red OS. check_pkgs pkgs: $pkgs"
	out=`yum list available $pkgs`
        if [[ -z "`echo -e "$out" | grep "x86_64"`" ]]
        then
		cholog "new packages found"
                return 0
        fi
	echolog "No new packages found"
        return 1
}

function _install_packages ()
{
	local pkgs="ccid opensc gdm-plugin-smartcard pcsc-tools nss-tools libp11 engine_pkcs11 python3-tkinter p11-kit pam_pkcs11 rpmdevtools libsss_sudo krb5-pkinit dialog"
        check_update="$1"

        if [[ "$check_updates" ]]
        then
		echolog "Red OS. check common packages"
                check_pkgs $pkgs
                return $?
        fi
	
	echolog "Red OS. install common packages"
	sudo yum -q -y update
	sudo yum -q -y install $pkgs;
	if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi

	sudo systemctl restart pcscd
	echolog "new packages installed"
	return 0
}

function _setup_local_authentication ()
{
	token=$1
	cert_id=$2
	user=$3
	echolog "Red OS. setup local authentication for user: $user by cert: $cert on token: $token"

	DB=$PAM_PKCS11_DIR/nssdb
	echolog "DB path is $DB"
	sudo mkdir "$DB" 2> /dev/null;
	if ! [ "`ls -A "$DB"`" ]
	then
		sudo chmod 0644 "$DB"
		echolog "init DB"
		sudo certutil -d "$DB" -N --empty-password
	fi
	
	echolog "Add trusted lib to DB"
	echo -e "\n" | sudo modutil -dbdir "$DB" -add p11-kit-trust -libfile /usr/lib64/pkcs11/p11-kit-trust.so 2> /dev/null
	
	export_object "$token" "cert" "$cert_id" "cert${cert_id}.crt"
	if [[ $? -ne 0 ]]
        then
                echoerr "Cert $cert_id is not exported to cert${cert_id}.crt"
                return 1
        fi

	sudo cp "cert${cert_id}.crt" /etc/pki/ca-trust/source/anchors/
	if [[ $? -ne 0 ]]
        then
                echoerr "Can't copy cert${cert_id}.crt to /etc/pki/ca-trust/source/anchors/"
                return 1
        fi

	sudo update-ca-trust force-enable
	sudo update-ca-trust extract

	sudo mv "$PAM_PKCS11_DIR/pam_pkcs11.conf" "$PAM_PKCS11_DIR/pam_pkcs11.conf.default" 2> /dev/null;
	sudo mkdir "$PAM_PKCS11_DIR/cacerts" "$PAM_PKCS11_DIR/crls" 2> /dev/null;
	sudo mkdir "$PAM_PKCS11_DIR" 2> /dev/null
	LIBRTPKCS11ECP="$LIBRTPKCS11ECP" PAM_PKCS11_DIR="$PAM_PKCS11_DIR" envsubst < "$TWO_FA_LIB_DIR/common_files/pam_pkcs11.conf" | sudo tee "$PAM_PKCS11_DIR/pam_pkcs11.conf" > /dev/null
	echolog "Create $PAM_PKCS11_DIR/pam_pkcs11.conf"

	openssl dgst -sha1 "cert${cert_id}.crt" | cut -d" " -f2- | awk '{ print toupper($0) }' | sed 's/../&:/g;s/:$//' | sed "s/.*/\0 -> $user/" | sudo tee "$PAM_PKCS11_DIR/digest_mapping" -a  > /dev/null 
	echolog "update digest map file $PAM_PKCS11_DIR/digest_mapping"

	pam_pkcs11_insert="/pam_unix/ && x==0 {print \"auth sufficient pam_pkcs11.so pkcs11_module=$LIBRTPKCS11ECP\"; x=1} 1"
	
	sys_auth="/etc/pam.d/system-auth"
	if ! [ "$(sudo cat $sys_auth | grep 'pam_pkcs11.so')" ]
	then
		sys_auth="/etc/pam.d/system-auth"
		awk "$pam_pkcs11_insert" $sys_auth | sudo tee $sys_auth  > /dev/null  
	fi

	pass_auth="/etc/pam.d/password-auth"
        if ! [[ "$(sudo cat $pass_auth | grep 'pam_pkcs11.so')" ]]
        then
		echolog "Update pam.d file $pass_auth"
		awk "$pam_pkcs11_insert" $pass_auth | sudo tee $pass_auth  > /dev/null
        fi

	return 0
}

function _setup_autolock ()
{
	echolog "Red OS. setup_autolock"
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	return 0
}

function _setup_freeipa_domain_authentication ()
{
	echolog  "Red OS. There is no additional action required to setup freeipa domain auth"
	return 0
}

function _setup_ad_domain_authentication ()
{
	echolog  "Red OS. There is no additional action required to setup AD domain auth"
        return 0
}

