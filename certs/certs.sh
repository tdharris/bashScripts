#!/bin/bash
#
# Simple certificate management utility relying on openssl cli.
# Deprecated in favor of https://github.com/tdharris/openssl-toolkit
# Created by Tyler Harris (github.com/tdharris)
function askYesOrNo {
    REPLY=""
    while [ -z "$REPLY" ] ; do
        read -ep "$1 $YES_NO_PROMPT" REPLY
        REPLY=$(echo ${REPLY}|tr [:lower:] [:upper:])
        case $REPLY in
            $YES_CAPS ) return 0 ;;
            $NO_CAPS ) return 1 ;;
            * ) REPLY=""
        esac
    done
}

# Initialize the yes/no prompt
YES_STRING=$"y"
NO_STRING=$"n"
YES_NO_PROMPT=$"[y/n]: "
YES_CAPS=$(echo ${YES_STRING}|tr [:lower:] [:upper:])
NO_CAPS=$(echo ${NO_STRING}|tr [:lower:] [:upper:])

# Certificate functions
function certPath {
    while [ true ];do
        read -ep "Enter path to store certificate files: " certPath;
        if [ ! -d $certPath ]; then
            if askYesOrNo $"Path does not exist, would you like to create it now?"; then
                mkdir -p $certPath;
                break;
            fi
        else break;
        fi
    done
}

function newCertPass {
    while :
        do
            read -p "Enter password for private key: " -s -r pass;
            printf "\n";
            read -p "Confirm password: " -s -r passCompare;
            if [ "$pass" = "$passCompare" ]; then
                echo
                break;
            else
                    echo -e "\nPasswords do not match.\n";
            fi
        done
}

function createCSRKey { 
    #Start of Generate CSR and Key script.
    certPath
        cd $certPath;
        echo -e "\nGenerating a Key and CSR";
        newCertPass
        
    echo ""                                                                                                                                                                                            1,1           Top
    openssl genrsa -passout pass:${pass} -des3 -out server.key 2048;
    openssl req -new -key server.key -out server.csr -passin pass:${pass};
    key=${PWD##&/}"/server.key";
    csr=${PWD##&/}"/server.csr";

    echo -e "\nserver.key can be found at "$key;
    echo -e "server.csr can be found at "$csr;
}

function signCert {
    # Presuming we are in the certPath directory
    isSelfSigned=true
    crt=${PWD##&/}"/server.crt"
    echo -e "\nSigning certificate."
    if [ -f $key ] && [ -f $csr ];then
        read -ep "Enter amount of days certificate will be valid for(ie. 730): " certDays;
        if [[ -z "$certDays" ]]; then
            certDays=730;
        fi
        openssl x509 -req -days $certDays -in $csr -signkey $key -out $crt -passin pass:${pass} 2>/dev/null;
        echo -e "Server certificate created at $crt";
        else 
            echo "Could not find server.key or server.csr in "${PWD##&/};
    fi
}
# TODO: fix password prompts, error checking...
function createPEM {
    echo -e "\nCreating PEM..."
    
    # Ask for files/path if not self-signed
    if (! $isSelfSigned); then
        echo -e "Please provide the private key, the public key or certificate, and any intermediate CA or bundles.\n"
        read -ep "Enter the full path for certificate files (ie. /root/certificates): " path;
        if [ -d $path ];then 
            cd $path;
            ls --format=single-column | column
            if [ $? -eq 0 ]; then
                echo ""
                while true;
                do
                    read -ep "Enter private key filename (key): " key;
                    read -ep "Enter public key filename (crt): " crt;
                    if [ -f "$key" ] && [ -f "$crt" ];then
                        break
                    else echo -e "Invalid filename.\n";
                    fi
                done
                grep -iq "ENCRYPTED" $key
                if [ $? -eq 0 ]; then
                    newCertPass
                fi
            else
                echo -e "Cannot find any or all certificates files.";
            fi
        else echo "Invalid file path.";
        fi 
    fi

    # Create PEM
    if [ -f "$key" ] && [ -f "$crt" ];then
        # Removing password from Private Key, if it contains one
        echo "running openssl..."
        openssl rsa -in $key -out nopassword.key -passin pass:${pass} 2>/dev/null;
        if [ $? -eq 0 ]; then
            cat  nopassword.key > server.pem;
            rm -f nopassword.key;
            cat $crt >> server.pem;
            
            if (! $isSelfSigned); then
                while [ true ];
                do
                crtName=""
                echo
                if askYesOrNo $"Add intermediate certificate?";then
                    ls --format=single-column | column
                    read -ep "Intermediate filename: " crtName;
                    if [ ! -z "$crtName" ];then
                        cat $crtName >> server.pem;
                    fi
                else
                    break;
                fi
                done
            fi
            echo -e "Creating server.pem at "${PWD##&/}"/server.pem\n";
        else echo "Invalid pass phrase.";
        fi
    else echo "Invalid file input.";
    fi
}

function verify {
    echo -e "\nPlease provide the private key and the public key/certificate\n"
    read -ep "Enter the full path for certificate files (ie. /root/certificates): " path;
    if [ -d $path ];then 
        cd $path;
    echo "Listing certificate files..."
        ls -l *.key *.crt 2>/dev/null;
        if [ $? -ne 0 ]; then
            echo -e "Could not find any certificate files (.key, .crt).";
        else
            echo
            read -ep "Enter the private key (.key): " key;
            # read -ep "Enter the CSR: " csr;
            read -ep "Enter the public key (.crt): " crt;
            if [ -f ${PWD}"/$key" ]  && [ -f ${PWD}"/$crt" ]; then
                echo
                crt=`openssl x509 -noout -modulus -in $crt | openssl md5`
                key=`openssl rsa -noout -modulus -in $key | openssl md5`
                # csr=`openssl req -noout -modulus -in $csr | openssl md5`
                echo
                if [ "$crt" == "$key" ]; then
                    echo "Certificates have been validated."
                else echo "Certificate mismatch!"
                fi
                echo "key: " $key
                # echo "csr: " $csr
                echo "crt: " $crt
            else
                echo -e "Invalid file input.";
            fi
        fi
    fi
    echo -e "\nDone."
    read -p "Press [Enter] to continue."
}

while :
do
 clear
cd $cPWD; isSelfSigned=false
echo '                                                        
          ___  ____  ____  ____  ____    ____  ____  __   
         / __)(  __)(  _ \(_  _)/ ___)  / ___)/ ___)(  )  
        ( (__  ) _)  )   /  )(  \___ \  \___ \\___ \/ (_/\
         \___)(____)(__\_) (__) (____/  (____/(____/\____/                                                                             
'
 echo -e "\n\t1. Generate self-signed certificate"
    echo -e "\n\t2. Create CSR + private key"
    echo -e "\t3. Configure certificate from 3rd party"
    echo -e "\n\t4. Verify certificate/key pair"
 echo -e "\n\t0. Back"
 echo -n -e "\n\tSelection: "
 read opt
 a=true;
 case $opt in
 1) # Self-Signed Certificate
    clear; echo -e "\nNote: The following will create a CSR, private key and generate a self-signed certificate.\n"
    createCSRKey
    signCert
    createPEM
    echo -e "Done."; read -p "Press [Enter] to continue";
    ;;

 2) # CSR/KEY
    clear;
    createCSRKey;
    echo; read -p "Press [Enter] to continue.";;

  3) # Create PEM
    clear;
    createPEM;
    echo -e "\nDone."; read -p "Press [Enter] to continue";;

  4) # Verify Certificates: Private Key, CSR, Public Certificate
    clear;
    verify
    echo -e "Done."; read -p "Press [Enter] to continue";;

/q | q | 0)break;;
  *) ;;
esac
done
