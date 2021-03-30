#!/bin/bash

function check_pkgs ()
{
        pkgs=$@
	echolog "Rosa. check_pkgs pkgs: $pkgs"
        for pkg in $pkgs
        do
                if [[ "`rpm -q -i $pkg 2>&1 | grep "не установлен"`" ]]
                then
			echolog "new packages found"
                        return 1
                fi
        done
	echolog "No new packages found"
        return 0
}

function _install_packages ()
{
        local pkgs="ccid opensc p11-kit rpmdevtools dialog lib64p11-devel engine_pkcs11 pam_pkcs11 pam_pkcs11-tools tkinter3 pcsc_tools gettext"
        check_update="$1"

        if [[ "$check_updates" ]]
        then
                 echolog "Rosa. check common packages"
		check_pkgs $pkgs
                return $?
        fi

	echolog "Rosa. install common packages"
	# rosa2019.1+ uses dnf as the main package manager,
	# but urpmi command may be available from dnf-URPM converter;
	# dnf is never available on platforms where urpmi is the only package manager.
	if command -v dnf >/dev/null 2>&1
	then
		INSTALLCMD="dnf install -y"
	else
		INSTALLCMD="urpmi --force"
	fi
	sudo $INSTALLCMD $pkgs
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
	echolog "Rosa. setup local authentication for user: $user by cert: $cert on token: $token"
	
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

	pam_pkcs11_insert="NR == 2 {print \"auth sufficient pam_pkcs11.so pkcs11_module=$LIBRTPKCS11ECP\" } {print}"

	sys_auth="/etc/pam.d/system-auth"
	if ! [ "$(sudo cat $sys_auth | grep 'pam_pkcs11.so')" ]
	then
		echolog "Update pam.d file $sys_auth"
		awk "$pam_pkcs11_insert" $sys_auth | sudo tee $sys_auth  > /dev/null
	fi

	return 0
}

function _setup_autolock ()
{
	echolog "Rosa. setup_autolock"
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	return 0
}

function _setup_freeipa_domain_authentication ()
{
	echolog  "Rosa. There is no additional action required to setup freeipa domain auth"
        return 0
}

function _setup_ad_domain_authentication ()
{
	echolog  "Rosa. There is no additional action required to setup AD domain auth"
        return 0
}

