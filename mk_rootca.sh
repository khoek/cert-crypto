#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR"/lib.sh

if [[ $# -ne 2 ]]; then
    echo "Wrong number of parameters, expected 2" >&2
    echo "Usage: $0 <root CA slug> <root CA common name (CN)>" >&2
    exit 2
fi

certSlug=$1
certCN=$2

read -r -s -p "Password for (NEW) $certSlug/privkey: " userPassword
echo
check_pw_len ${#userPassword}

mkdir -p cas
mkdir -p certs
mkdir "cas/$certSlug"
cd "cas/$certSlug"

privkeyDir=../../privkeys/$certSlug

mkdir newcerts
mkdir newcrls
touch index.txt
# Very weirdly, unlike the similar standard 'serial' file (which we don't use),
# this file has hex-encoded contents and not decimal. 0x64 = 100
echo '64' > crlnumber

(cd ../..; echo "$userPassword" | "$SCRIPT_DIR"/mk_privkey.sh "$certSlug")
echo "$userPassword" | openssl req -config "$SCRIPT_DIR"/openssl-ca.cnf -new -key "$privkeyDir/privkey.pem" -sha512 -passin stdin -out csr.pem -outform PEM -subj "/C=AU/O=hoek.io/CN=$certCN" -extensions extensions_cert_v3_ca_root -reqexts extensions_csr_v3_ca_root
echo "$userPassword" | openssl ca -batch -config "$SCRIPT_DIR"/openssl-ca.cnf -selfsign -keyfile "$privkeyDir/privkey.pem" -passin stdin -days 7300 -policy policy_ca -extensions extensions_cert_v3_ca_root -out cert.pem -infiles csr.pem

# Remove the text from the start of the file:
openssl x509 -outform pem -in cert.pem -out cert.pem
# Convert to DER
openssl x509 -outform der -in cert.pem -out cert.der

# Copy this file so that `mk_cert.sh` can treat us just like it would a normal (intermediate) CA
cp cert.pem cert.chain.pem
