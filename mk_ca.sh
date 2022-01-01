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
    echo "Usage: $0 <root slug> <slug> <common name (CN)> <subject alternative name (SAN)>" >&2
    exit 3
fi

rootSlug=$1
certSlug=$2
certCN=$3
certSAN=$4

read -s -p "Password for (NEW) $certSlug/privkey: " userCertPassword
echo
check_pw_len ${#userCertPassword}

read -s -p "Password for (OLD) $rootSlug/privkey: " userRootPassword
echo
check_pw_len ${#userRootPassword}



mkdir -p cas
mkdir "cas/$certSlug"
cd "cas/$rootSlug"

certDir=../$certSlug

rootSubjectKeyId=$(openssl x509 -in cert.pem -noout -text | grep -A1 "Subject Key Identifier" | tail -n +2 | xargs)
#rootPkiId=$rootSubjectKeyId
rootPkiId=$rootSlug

cat > openssl-ca.extras.cnf <<EOF
subjectAltName=$certSAN
authorityInfoAccess=caIssuers;URI:http://pki.hoek.io/ca/$rootPkiId/crt.der
crlDistributionPoints=URI:http://pki.hoek.io/ca/$rootPkiId/crl.der
EOF

# Note different `-policy`, `-extensions`, and `-reqexts` a non-CA cert.

echo $userCertPassword | openssl req -config $SCRIPT_DIR/openssl-ca.cnf -newkey rsa:4096 -sha512 -passout stdin -keyout "$certDir/privkey.pem" -out "$certDir/csr.pem" -outform PEM -subj "/C=AU/O=hoek.io/CN=$certCN" -extensions extensions_cert_v3_ca_intermediate -reqexts extensions_csr_v3_ca_intermediate
echo $userRootPassword | openssl ca -batch -config $SCRIPT_DIR/openssl-ca.cnf -passin stdin -days 1825 -policy policy_ca -extensions extensions_cert_v3_ca_intermediate -out "$certDir/cert.pem" -infiles "$certDir/csr.pem"

rm openssl-ca.extras.cnf

# Remove the text from the start of the file:
openssl x509 -outform pem -in "$certDir/cert.pem" -out "$certDir/cert.pem"

mkdir "$certDir/newcerts"
mkdir "$certDir/newcrls"
touch "$certDir/index.txt"
# Very weirdly, unlike the similar standard 'serial' file (which we don't use),
# this file has hex-encoded contents and not decimal. 0x64 = 100
echo '64' > "$certDir/crlnumber"

cat "$certDir/cert.pem" cert.pem > "$certDir/cert.chain.pem"
