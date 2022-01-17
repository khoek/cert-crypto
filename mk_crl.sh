#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR"/lib.sh

if [[ $# -ne 1 ]]; then
    echo "Wrong number of parameters, expected 1" >&2
    echo "Usage: $0 <CA slug>" >&2
    exit 2
fi

caSlug=$1

read -r -s -p "Password for (OLD) $caSlug/privkey: " userCaPassword
echo
check_pw_len ${#userCaPassword}

cd "cas/$caSlug"

parentPrivkeyDir=../../privkeys/$caSlug
crlnum=$(cat crlnumber)

# Very weirdly, unlike the similar standard 'serial' file (which we don't use),
# this file has hex-encoded contents and not decimal, so we decode it when
# specifying the output file.
outfile_name=newcrls/$((16#$crlnum))
echo "$userCaPassword" | openssl ca -batch -config "$SCRIPT_DIR"/openssl-ca.cnf -keyfile "$parentPrivkeyDir/privkey.pem" -passin stdin -extensions extensions_crl -out "$outfile_name.pem" -crldays 365 -gencrl

# Remove the text from the start of the file:
openssl crl -outform pem -in "$outfile_name.pem" -out "$outfile_name.pem"
# Convert to DER
openssl crl -outform der -in "$outfile_name.pem" -out "$outfile_name.der"
