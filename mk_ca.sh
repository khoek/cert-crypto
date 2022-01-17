#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR"/lib.sh

if [[ $# -ne 4 ]]; then
    echo "Wrong number of parameters, expected 4" >&2
    echo "Usage: $0 <parent slug> <slug> <common name (CN)> <subject alternative name (SAN)>" >&2
    exit 2
fi

parentSlug=$1
certSlug=$2
certCN=$3
certSAN=$4

read -r -s -p "Password for (NEW) $certSlug/privkey: " userCertPassword
echo
check_pw_len ${#userCertPassword}

read -r -s -p "Password for (OLD) $parentSlug/privkey: " userParentPassword
echo
check_pw_len ${#userParentPassword}

mkdir -p cas
mkdir "cas/$certSlug"
cd "cas/$parentSlug"

certDir=../$certSlug
certPrivkeyDir=../../privkeys/$certSlug
parentPrivkeyDir=../../privkeys/$parentSlug

#parentSubjectKeyId=$(openssl x509 -in cert.pem -noout -text | grep -A1 "Subject Key Identifier" | tail -n +2 | xargs)
#parentPkiId=$parentSubjectKeyId
parentPkiId=$parentSlug

cat > openssl-ca.extras.cnf <<EOF
subjectAltName=$certSAN
authorityInfoAccess=caIssuers;URI:http://pki.hoek.io/ca/$parentPkiId/crt.der
crlDistributionPoints=URI:http://pki.hoek.io/ca/$parentPkiId/crl.der
EOF

# Note different `-policy`, `-extensions`, and `-reqexts` a non-CA cert.

(cd ../..; echo "$userCertPassword" | "$SCRIPT_DIR"/mk_privkey.sh "$certSlug")
echo "$userCertPassword" | openssl req -config "$SCRIPT_DIR"/openssl-ca.cnf -new -key "$certPrivkeyDir/privkey.pem" -sha512 -passin stdin -out "$certDir/csr.pem" -outform PEM -subj "/C=AU/O=hoek.io/CN=$certCN" -extensions extensions_cert_v3_ca_intermediate -reqexts extensions_csr_v3_ca_intermediate
echo "$userParentPassword" | openssl ca -batch -config "$SCRIPT_DIR"/openssl-ca.cnf -keyfile "$parentPrivkeyDir/privkey.pem" -passin stdin -days 1825 -policy policy_ca -extensions extensions_cert_v3_ca_intermediate -out "$certDir/cert.pem" -infiles "$certDir/csr.pem"

rm openssl-ca.extras.cnf

# Remove the text from the start of the file:
openssl x509 -outform pem -in "$certDir/cert.pem" -out "$certDir/cert.pem"
# Convert to DER
openssl x509 -outform der -in "$certDir/cert.pem" -out "$certDir/cert.der"

mkdir "$certDir/newcerts"
mkdir "$certDir/newcrls"
touch "$certDir/index.txt"
# Very weirdly, unlike the similar standard 'serial' file (which we don't use),
# this file has hex-encoded contents and not decimal. 0x64 = 100
echo '64' > "$certDir/crlnumber"

cat "$certDir/cert.pem" cert.pem > "$certDir/cert.chain.pem"
