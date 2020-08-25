#!/bin/bash

function check_pkgs ()
{
	echolog "No new packages found"
	return 0
        
}

function _install_packages ()
{
	local pkgs="python3 openssl libp11 opensc pcsc-lite wget pstree zenity"
	check_update="$1"
	export PATH=$PATH:/usr/local/sbin
	
	if ! [[ -z "$check_updates" ]]
	then

		check_pkgs $pkgs
		return $?
	fi
	
	sudo -i -u "$ORIG_USER" brew install $pkgs
	
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

	export_object "$token" "cert" "$cert_id" "cert.crt"
	if [[ $? -ne 0 ]]
	then
		echoerr "Не удалось экспортировать сертификат с Рутокена"
		return 1
	fi

	CN="`openssl x509 -noout -subject -in cert.crt -inform DER | tr "/" $"\n" | awk '/CN=/{print $0}' | cut -c 4-`"
	echolog "Cert CN is $CN"
	hash="`sc_auth identities | grep -w "$CN" | cut -f1`"
	echolog "Cert hash is $hash"
	out="`sc_auth pair -u "$user" -h "$hash"`"
	if [[ $? -ne 0 ]]
	then
		echoerr "Can't pair user and this cert. Output: $out"
		return 1
	fi 
	
	launchctl asuser _securityagent pluginkit -a "/Applications/Рутокен для macOS.app/Contents/PlugIns/RutokenCTK.appex"/	
	
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


