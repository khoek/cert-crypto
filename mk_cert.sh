#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

check_pw_len () {
  if (($1 >= 4 && $1 <= 1023)); then
    :
  else
    echo "Password must be between 4 and 1023 characters (inclusive)"
    exit 1
  fi
}



if [[ $# -ne 4 ]]; then
    echo "Wrong number of parameters, expected 4" >&2
    echo "Usage: $0 <CA slug> <slug> <distingished name (DN)> <subject alternative name (SAN)>" >&2
    exit 2
fi

caSlug=$1
certSlug=$2
certDN=$3
certSAN=$4

read -s -p "Password for (NEW) $certSlug/privkey: " userCertPassword
echo
check_pw_len ${#userCertPassword}

read -s -p "Password for (OLD) $caSlug/privkey: " userCaPassword
echo
check_pw_len ${#userCaPassword}



mkdir -p certs
mkdir "certs/$certSlug"
cd "cas/$caSlug"

certDir=../../certs/$certSlug

caSubjectKeyId=$(openssl x509 -in cert.pem -noout -text | grep -A1 "Subject Key Identifier" | tail -n +2 | xargs)
#caPkiId=$caSubjectKeyId
caPkiId=$caSlug

cat > openssl-ca.extras.cnf <<EOF
subjectAltName=$certSAN
authorityInfoAccess=caIssuers;URI:http://pki.hoek.io/ca/$caPkiId/crt.der
crlDistributionPoints=URI:http://pki.hoek.io/ca/$caPkiId/crl.der
EOF

# Note different `-policy`, `-extensions`, and `-reqexts` a CA cert.

echo $userCertPassword | openssl req -config $SCRIPT_DIR/openssl-ca.cnf -newkey rsa:4096 -sha512 -passout stdin -keyout "$certDir/privkey.pem" -out "$certDir/csr.pem" -outform PEM -subj "$certDN" -extensions extensions_cert_v3_client -reqexts extensions_csr_v3_client
echo $userCaPassword | openssl ca -batch -config $SCRIPT_DIR/openssl-ca.cnf -passin stdin -days 1000 -policy policy_client -extensions extensions_cert_v3_client -out "$certDir/cert.pem" -infiles "$certDir/csr.pem"

rm openssl-ca.extras.cnf

# Remove the text from the start of the file:
openssl x509 -outform pem -in "$certDir/cert.pem" -out "$certDir/cert.pem"
# Convert to DER
openssl x509 -outform der -in "$certDir/cert.pem" -out "$certDir/cert.der"

cat "$certDir/cert.pem" cert.chain.pem > "$certDir/cert.chain.pem"
