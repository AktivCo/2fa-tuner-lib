#!/bin/bash

function check_pkgs ()
{
        pkgs=$@
	upd_pkgs=`apt-indicator-checker`

        for pkg in $pkgs
	do
		if [[ "`rpm -q -i $pkg 2>&1 | grep "не установлен"`" ]]
		then
			return 1
		fi
		if [[ "`echo -e "$upd_pkgs" | grep -w $pkg`" ]]
		then
			return 1
		fi
	done

        return 0
}

function _install_common_packages ()
{
        check_update="$1"
        local pkgs="librtpkcs11ecp opensc pcsc-lite-ccid pcsc-lite libp11 pcsc-tools python3-modules-tkinter dialog"

        if ! [[ -z "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi
        
	apt-get -qq update
	apt-get -qq install $pkgs 
	if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi
	
	systemctl restart pcscd
	return 0
}


function _install_packages_for_local_auth ()
{
        check_updates=$1
	local pkgs="pam_pkcs11 pam_p11 nss-utils"
        if ! [[ -z "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi

        apt-get -qq install $pkgs;
        if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi

        systemctl restart pcscd
	return 0
}

function _install_packages_for_domain_auth ()
{
        return 0
}

function _setup_local_authentication ()
{
	token=$1
	cert_id=$2
	user=$3
	DB=$PAM_PKCS11_DIR/nssdb
	
	mkdir "$DB" 2> /dev/null;
	if ! [ "$`ls -A $DB`" ]
	then
		chmod 0644 "$DB"
		certutil -d "$DB" -N --empty-password
	fi
	
	echo -e "\n" | modutil -dbdir "$DB" -add p11-kit-trust -libfile /usr/lib64/pkcs11/p11-kit-trust.so 2> /dev/null
	
	export_object "$token" "cert" "$cert_id" "cert${cert_id}.crt"

	cp "cert${cert_id}.crt" /etc/pki/ca-trust/source/anchors/
	update-ca-trust force-enable
	update-ca-trust extract

	mv "$PAM_PKCS11_DIR/pam_pkcs11.conf" "$PAM_PKCS11_DIR/pam_pkcs11.conf.default" 2> /dev/null;
	mkdir "$PAM_PKCS11_DIR/cacerts" "$PAM_PKCS11_DIR/crls" 2> /dev/null;
	mkdir "$PAM_PKCS11_DIR" 2> /dev/null
	LIBRTPKCS11ECP="$LIBRTPKCS11ECP" PAM_PKCS11_DIR="$PAM_PKCS11_DIR" envsubst < "$TWO_FA_LIB_DIR/common_files/pam_pkcs11.conf" | tee "$PAM_PKCS11_DIR/pam_pkcs11.conf" > /dev/null

	openssl dgst -sha1 "cert${cert_id}.crt" | cut -d" " -f2- | awk '{ print toupper($0) }' | sed 's/../&:/g;s/:$//' | sed "s/.*/\0 -> $user/" | tee "$PAM_PKCS11_DIR/digest_mapping" -a  > /dev/null 

	
	sys_auth="/etc/pam.d/system-auth"
	if [[ -z "`cat "${sys_auth}-pkcs11" | grep "pkcs11_module=$LIBRTPKCS11ECP"`" ]]
	then
		cp "$sys_auth" "${sys_auth}.old"
		rm /etc/pam.d/system-auth
		sed -i "/^.*pam_pkcs11.*$/ s/$/ pkcs11_module=${LIBRTPKCS11ECP//\//\\/}/" "${sys_auth}-pkcs11"
		ln -s "${sys_auth}-pkcs11"  "$sys_auth"
	fi

	return 0
}

function _setup_autolock ()
{
	cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	return 0
}

function _setup_domain_authentication ()
{
        return 0
}

