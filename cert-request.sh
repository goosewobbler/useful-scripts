#!/bin/bash
# Cert Request Script
# This script automates creation of a CSR file for a given domain.
#
# ---
# Usage: 
# 
# sh ~/Scripts/cert-request.sh [your.domain]
# ---
#
# Resulting files:
#     your.domain.csr
#     your.domain.key
#     chain.pem
#

CERT_DOMAIN=$1
TMP_DIR='/tmp'

echo "Creating CSR for $1..."
openssl req -new -newkey rsa:2048 -nodes -sha256 -config /dev/stdin -keyout $CERT_DOMAIN.key -out $CERT_DOMAIN.csr <<CONF
[ req ]
x509_extensions = v3_req
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
 
[ req_distinguished_name ]
countryName = GB
stateOrProvinceName = London
localityName = London
0.organizationName = British Broadcasting Corporation
organizationalUnitName = DesignAndEngineering Sport OneWeb
commonName = $CERT_DOMAIN
emailAddress = ca-admin@bbc.co.uk
 
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
 
# all certificates now require a SAN field, even if there's only one host
subjectAltName = @alt_names
#
[ alt_names ]
DNS.1 = $CERT_DOMAIN
#add more if required
#DNS.2 = another.host.name
#...
 
CONF

echo "\nCreated CSR and private key..."
cat $CERT_DOMAIN.key

echo "\nDownloading Globalsign root cert..."
curl https://secure.globalsign.net/cacert/Root-R1.crt > "$TMP_DIR/root.der"

echo "\nDownloading Globalsign intermediate cert..."
curl https://secure.globalsign.com/cacert/gsorganizationvalsha2g2r1.crt > "$TMP_DIR/intermediate.der"

openssl x509 -in "$TMP_DIR/root.der" -inform der -outform pem -out "$TMP_DIR/root.pem"
openssl x509 -in "$TMP_DIR/intermediate.der" -inform der -outform pem -out "$TMP_DIR/intermediate.pem"
cat "$TMP_DIR/intermediate.pem" "$TMP_DIR/root.pem" > ./chain.pem

echo "\nCreated Certificate chain..."
cat ./chain.pem
