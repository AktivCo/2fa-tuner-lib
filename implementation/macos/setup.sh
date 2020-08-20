#!/bin/bash

function check_pkgs ()
{
	echolog "No new packages found"
	return 1
        
}

function _install_packages ()
{
	local pkgs="libengine-pkcs11-openssl1.1 python3-tk opensc libccid pcscd pcsc-tools libp11-3 libpam-p11 libpam-pkcs11 libnss3-tools dialog"
	check_update="$1"
	export PATH=$PATH:/usr/local/sbin
	
	if ! [[ -z "$check_updates" ]]
	then

		check_pkgs $pkgs
		return $?
	fi
	
	echo
	if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi

	echolog "new packages installed"
        return 0
}

function _setup_local_authentication ()
{
	token=$1
	cert_id=$2
	user=$3
	echolog "Debian. setup local authentication for user: $user by cert: $cert on token: $token"

	home=`getent passwd $user | cut -d: -f6`
        echolog "user home is $home"
	
	export_object "$token" "cert" "$cert_id" "cert.crt"
	if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось экспортировать сертификат с Рутокена"
		return 1
	fi

	out=`openssl x509 -in cert.crt -out cert.pem -inform DER -outform PEM`
	if [[ $? -ne 0 ]]
        then
                echoerr "can't convert cert to PEM format"
                return 1
        fi
        echolog "convert cert to DER format"
	
	mkdir "$home/.eid" 2> /dev/null;
	chmod 0755 "$home/.eid";
	cat cert.pem >> "$home/.eid/authorized_certificates";
	chmod 0644 "$home/.eid/authorized_certificates";
	
	LIBRTPKCS11ECP=$LIBRTPKCS11ECP PAM_P11=$PAM_P11 envsubst < "$TWO_FA_LIB_DIR/common_files/p11" | sudo tee /usr/share/pam-configs/p11 > /dev/null;
	chown $user:$user -R $home/.eid
	
	sudo pam-auth-update --force --enable Pam_p11;
	return 0
}

function _setup_autolock ()
{
	echolog "Debain. setup_autolock"
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	sudo systemctl daemon-reload
}

function _setup_freeipa_domain_authentication ()
{
	echolog "Debian update /etc/pam.d/common-auth for freeipa auth"
	sudo sed -i -e "s/^auth.*success=2.*pam_unix.*$/auth    \[success=2 default=ignore\]    pam_sss.so forward_pass/g" -e "s/^auth.*success=1.*pam_sss.*$/auth    \[success=1 default=ignore\]    pam_unix.so nullok_secure try_first_pass/g" /etc/pam.d/common-auth
}

function _setup_ad_domain_authentication ()
{
	echolog "Astra update /etc/pam.d/common-auth for ad auth"
	sudo sed -i -e "s/^auth.*success=2.*pam_unix.*$/auth    \[success=2 default=ignore\]    pam_sss.so forward_pass/g" -e "s/^auth.*success=1.*pam_sss.*$/auth    \[success=1 default=ignore\]    pam_unix.so nullok_secure try_first_pass/g" /etc/pam.d/common-auth
        return 0
}


