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



if [[ $# -ne 2 ]]; then
    echo "Wrong number of parameters, expected 2" >&2
    echo "Usage: $0 <root CA slug> <root CA common name (CN)>" >&2
    exit 2
fi

certSlug=$1
certCN=$2

read -s -p "Password for (NEW) $certSlug/privkey: " userPassword
echo
check_pw_len ${#userPassword}



mkdir -p cas
mkdir -p certs
mkdir "cas/$certSlug"
cd "cas/$certSlug"

echo $userPassword | openssl req -x509 -config $SCRIPT_DIR/openssl-ca.cnf -newkey rsa:4096 -sha512 -new -passout stdin -keyout privkey.pem -out cert.pem -outform PEM -subj "/C=AU/O=hoek.io/CN=$certCN" -extensions extensions_cert_v3_ca_root -reqexts extensions_csr_v3_ca_root -days 7300

# Remove the text from the start of the file:
openssl x509 -outform pem -in cert.pem -out cert.pem
# Convert to DER
openssl x509 -outform der -in cert.pem -out cert.der

mkdir newcerts
mkdir newcrls
touch index.txt
# Very weirdly, unlike the similar standard 'serial' file (which we don't use),
# this file has hex-encoded contents and not decimal. 0x64 = 100
echo '64' > crlnumber

# Copy this file so that `mk_cert.sh` can treat us just like it would a normal (intermediate) CA
cp cert.pem cert.chain.pem
