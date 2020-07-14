#!/bin/bash

function check_pkgs ()
{
        pkgs=$@
	out=`apt-get --just-print install $pkgs`
        if [[ "`echo -e "$out" | grep "NEW\|НОВЫЕ"`" ]]
        then
                return 1
        fi
        return 0

}

function install_pkgs ()
{
	local pkgs="$@"
	local last_line=""
		
	while read line
	do
		if [[ "$last_line" == *"Смена носителя: вставьте диск с меткой"* ]]
		then
			show_text "Поменяйте диск" "Сменитель носитель на носитель с меткой $line"
			echo -e "\n" >> cmds
		fi
		last_line=$line
	done < <(script -c "(apt-get install -y $pkgs; apt-get -f -y install; apt-get install -y $pkgs)< <(tail --retry -f cmds 2> /dev/null )" -f)

	res=$?
	rm cmds
	return $res
	
}

function _install_common_packages ()
{
	local pkgs="libengine-pkcs11-openssl1.1 krb5-pkinit libengine-pkcs11-openssl opensc libccid pcscd libp11-2 libpam-p11 libpam-pkcs11 pcsc-tools libnss3-tools dnsutils python3-tk dialog"
        check_update="$1"

        if [[ "$check_updates" ]]
        then
                check_pkgs $pkgs
                return $?
        fi

	install_pkgs $pkgs;
	if [[ $? -ne 0 ]]
	then
		echoerr "Не могу установить один из пакетов: $pkgs из репозитория"
		return 1
	fi
	
	return 0
}

function _install_packages_for_local_auth ()
{
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
        home=`getent passwd $user | cut -d: -f6`

        export_object "$token" "cert" "$cert_id" "cert.crt"
        if [[ $? -ne 0 ]]
        then
                echoerr "Не удалось экспортировать сертификат с Рутокена"
                return 1
        fi
        openssl x509 -in cert.crt -out cert.pem -inform DER -outform PEM;
        mkdir "$home/.eid" 2> /dev/null;
        chmod 0755 "$home/.eid";
        cat cert.pem >> "$home/.eid/authorized_certificates";
        chmod 0644 "$home/.eid/authorized_certificates";
        LIBRTPKCS11ECP=$LIBRTPKCS11ECP envsubst < "$TWO_FA_LIB_DIR/common_files/p11" | sudo tee /usr/share/pam-configs/p11 > /dev/null;
        chown $user:$user -R $home/.eid

        sudo pam-auth-update --force --package --enable Pam_p11;

	return 0
}

function _setup_autolock ()
{
	sudo cp "$IMPL_DIR/smartcard-screensaver.desktop" /etc/xdg/autostart/smartcard-screensaver.desktop
	sudo systemctl daemon-reload
	return 0
}

function _setup_freeipa_domain_authentication ()
{
	sudo sed -i -e "s/^auth.*success=2.*pam_unix.*$/auth    \[success=2 default=ignore\]    pam_sss.so forward_pass/g" -e "s/^auth.*success=1.*pam_sss.*$/auth    \[success=1 default=ignore\]    pam_unix.so nullok_secure try_first_pass/g" /etc/pam.d/common-auth
	return 0
}

function _setup_ad_domain_authentication ()
{
	sudo sed -i -e "s/^auth.*success=2.*pam_unix.*$/auth    \[success=2 default=ignore\]    pam_sss.so forward_pass/g" -e "s/^auth.*success=1.*pam_sss.*$/auth    \[success=1 default=ignore\]    pam_unix.so nullok_secure try_first_pass/g" /etc/pam.d/common-auth
        return 0
}

