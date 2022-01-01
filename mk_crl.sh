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



if [[ $# -ne 1 ]]; then
    echo "Wrong number of parameters, expected 1" >&2
    echo "Usage: $0 <CA slug>" >&2
    exit 2
fi

caSlug=$1

read -s -p "Password for (OLD) $caSlug/privkey: " userCaPassword
echo
check_pw_len ${#userCaPassword}



cd "cas/$caSlug"

crlnum=$(cat crlnumber)

# Very weirdly, unlike the similar standard 'serial' file (which we don't use),
# this file has hex-encoded contents and not decimal, so we decode it when
# specifying the output file.
outfile=newcrls/$((16#$crlnum)).crl
echo $userCaPassword | openssl ca -batch -config $SCRIPT_DIR/openssl-ca.cnf -passin stdin -extensions extensions_crl -out "$outfile" -crldays 365 -gencrl

# Remove the text from the start of the file:
openssl crl -outform pem -in "$outfile" -out "$outfile"
