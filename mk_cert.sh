#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR"/lib.sh

if [[ $# -ne 4 ]]; then
    echo "Wrong number of parameters, expected 4" >&2
    echo "Usage: $0 <CA slug> <slug> <distingished name (DN)> <subject alternative name (SAN)>" >&2
    exit 2
fi

caSlug=$1
certSlug=$2
certDN=$3
certSAN=$4

read -r -s -p "Password for (NEW) $certSlug/privkey: " userCertPassword
echo
check_pw_len ${#userCertPassword}

read -r -s -p "Password for (OLD) $caSlug/privkey: " userCaPassword
echo
check_pw_len ${#userCaPassword}

mkdir -p certs
mkdir "certs/$certSlug"
cd "cas/$caSlug"

certDir=../../certs/$certSlug
certPrivkeyDir=../../privkeys/$certSlug
parentPrivkeyDir=../../privkeys/$caSlug

#caSubjectKeyId=$(openssl x509 -in cert.pem -noout -text | grep -A1 "Subject Key Identifier" | tail -n +2 | xargs)
#caPkiId=$caSubjectKeyId
caPkiId=$caSlug

cat > openssl-ca.extras.cnf <<EOF
subjectAltName=$certSAN
authorityInfoAccess=caIssuers;URI:http://pki.hoek.io/ca/$caPkiId/crt.der
crlDistributionPoints=URI:http://pki.hoek.io/ca/$caPkiId/crl.der
EOF

# Note different `-policy`, `-extensions`, and `-reqexts` a CA cert.

(cd ../..; echo "$userCertPassword" | "$SCRIPT_DIR"/mk_privkey.sh "$certSlug")
echo "$userCertPassword" | openssl req -config "$SCRIPT_DIR"/openssl-ca.cnf -new -key "$certPrivkeyDir/privkey.pem" -sha512 -passin stdin -out "$certDir/csr.pem" -outform PEM -subj "$certDN" -extensions extensions_cert_v3_client -reqexts extensions_csr_v3_client
echo "$userCaPassword" | openssl ca -batch -config "$SCRIPT_DIR"/openssl-ca.cnf -keyfile "$parentPrivkeyDir/privkey.pem" -passin stdin -days 1000 -policy policy_client -extensions extensions_cert_v3_client -out "$certDir/cert.pem" -infiles "$certDir/csr.pem"

rm openssl-ca.extras.cnf

# Remove the text from the start of the file:
openssl x509 -outform pem -in "$certDir/cert.pem" -out "$certDir/cert.pem"
# Convert to DER
openssl x509 -outform der -in "$certDir/cert.pem" -out "$certDir/cert.der"

cat "$certDir/cert.pem" cert.chain.pem > "$certDir/cert.chain.pem"
