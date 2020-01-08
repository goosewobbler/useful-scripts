# Development Certificate Update Script - Mac only
# This script automates cert conversion and backup for SSH and Morph/Mozart development.
#
# ---
# Usage: 
# 
# sh ~/Scripts/cert-update.sh ~/your-cert.p12 [your@email.com]
# ---
#
# Resulting files:
#
# /etc/pki
#     certificate.p12
#     certificate.pem
#     cloud-ca.pem
# /etc/pki/tls/certs
#     ca-bundle.crt
# ~/.ssh
#     id_rsa
#     id_rsa.pub
#
# Backups of these files are created and stored in ~/Certs/backups by default.
# The certificate is also imported to your login Keychain.
# The private key (~/.ssh/id_rsa) is protected with the certificate export password if none is specified.

#!/bin/bash
KEYSTORE_DIR='/etc/pki'
TMP_DIR='/tmp'
CA_BUNDLE_DIR="$KEYSTORE_DIR/tls/certs"
MORPH_NPM_COMMAND="npm --registry https://npm.morph.int.tools.bbc.co.uk --cert=\"$(cat $KEYSTORE_DIR/certificate.pem)\" --key=\"$(cat $KEYSTORE_DIR/certificate.pem)\" --cafile=$CA_BUNDLE_DIR/ca-bundle.crt"
MORPH_NPM_COMMAND_STRING='npm --registry https://npm.morph.int.tools.bbc.co.uk --cert=\"$(cat /etc/pki/certificate.pem)\" --key=\"$(cat /etc/pki/certificate.pem)\" --cafile=/etc/pki/tls/certs/ca-bundle.crt'
BACKUP_ROOT_DIR="$HOME/Certs/backups"
BACKUP_DIR="$BACKUP_ROOT_DIR/$(date +"%d%m%Y-%H%M%S")"
SSH_CONFIG_DIR="$HOME/.ssh"
WORKSPACE_DIR="$HOME/workspace"
REQUIRED_DIRS=($KEYSTORE_DIR $TMP_DIR $BACKUP_ROOT_DIR $SSH_CONFIG_DIR $WORKSPACE_DIR)
green=`tput setaf 2`
magenta=`tput setaf 5`
reset=`tput sgr0`

function politeSudo() { 
    sudo -p "Sudo required for this step, please enter your password: " "$@"
}

function politeMkdir() {
    if [ ! -d $1 ]; then
        read -p "Required directory does not exist. Will create ($1), press enter to continue or CTRL-C to exit: " 
        mkdir -p $1
    fi
}

function backup() {
    ORIGINAL="$1/$2"
    BACKUP="$BACKUP_DIR/$2"
    if [ -f $ORIGINAL ]; then
        politeSudo echo "$ORIGINAL -> $BACKUP"; politeSudo mv $ORIGINAL $BACKUP
    fi
}

echo 'Checking for required directories...'
for DIR in "${REQUIRED_DIRS[@]}"; do
    politeMkdir $DIR
done

echo 'Creating backup directory...'
mkdir $BACKUP_DIR

echo 'Backing up existing files...'
backup $KEYSTORE_DIR 'certificate.p12'
backup $KEYSTORE_DIR 'certificate.pem'
backup $KEYSTORE_DIR 'cloud-ca.pem'
backup $SSH_CONFIG_DIR 'id_rsa'
backup $SSH_CONFIG_DIR 'id_rsa.pub'
backup $WORKSPACE_DIR 'dev.bbc.co.uk.p12'
backup $CA_BUNDLE_DIR 'ca-bundle.crt'
 
read -sp $'\nPlease enter your certificate password: ' CERT_PASSWORD

echo "\nImporting ($1) to cert store and Keychain..."
politeSudo cp $1 "$KEYSTORE_DIR/certificate.p12"
security import $1 -k "$HOME/Library/Keychains/login.keychain" -P $CERT_PASSWORD
 
echo "\nConverting ($1) to PEM..."
politeSudo openssl pkcs12 -in $1 -out "$WORKSPACE_DIR/certificate.pem" -nodes -clcerts -passin "pass:$CERT_PASSWORD"
politeSudo cp "$WORKSPACE_DIR/certificate.pem" "$KEYSTORE_DIR/certificate.pem"
 
read -sp $'\nPlease enter your private key password (or enter to use your certificate password): ' PRIVATE_KEY_PASSWORD
PRIVATE_KEY_PASSWORD=${PRIVATE_KEY_PASSWORD:-$CERT_PASSWORD}
 
echo "\nCreating SSH config..."
politeSudo openssl pkcs12 -in $1 -nodes -clcerts -nocerts -passin "pass:$CERT_PASSWORD" | openssl rsa -passout "pass:$PRIVATE_KEY_PASSWORD" > "$SSH_CONFIG_DIR/id_rsa"
chmod 400 "$SSH_CONFIG_DIR/id_rsa"
ssh-keygen -y -f "$SSH_CONFIG_DIR/id_rsa" > "$SSH_CONFIG_DIR/id_rsa.pub"
echo "$(cat "$SSH_CONFIG_DIR/id_rsa.pub") $2" > "$SSH_CONFIG_DIR/id_rsa.pub"
 
echo "\nDownloading cloud CA..."
curl https://ca.dev.bbc.co.uk/cloud-ca.pem > "$TMP_DIR/cloud-ca.pem"
politeSudo mv "$TMP_DIR/cloud-ca.pem" "$KEYSTORE_DIR/ca-bundle.crt"
 
echo "\nExporting system CAs..."
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > "$TMP_DIR/root-cas.pem"
 
echo 'Creating CA bundle...'
politeSudo mkdir -p $CA_BUNDLE_DIR
cat "$TMP_DIR/root-cas.pem" "$TMP_DIR/cloud-ca.pem" > "$TMP_DIR/ca-bundle.crt"
politeSudo mv "$TMP_DIR/ca-bundle.crt" "$CA_BUNDLE_DIR/ca-bundle.crt"
politeSudo chmod og+r "$CA_BUNDLE_DIR/ca-bundle.crt"
 
echo 'Removing temporary files...'
rm "$TMP_DIR/root-cas.pem" "$TMP_DIR/cloud-ca.pem"

echo "\nCertificates updated."

read -p $'\nPlease enter an alias for morph npm (press enter if you do not wish to set an alias): ' MORPH_NPM_ALIAS

if [ $MORPH_NPM_ALIAS ]; then
    alias $MORPH_NPM_ALIAS="$MORPH_NPM_COMMAND"
    echo "Alias set for '$MORPH_NPM_ALIAS'.  You should add the following command to your shell config in order to persist the alias:"
    echo "\n${magenta}alias $MORPH_NPM_ALIAS=\"$MORPH_NPM_COMMAND_STRING\""
fi

echo "\n${green}Complete.${reset}"
