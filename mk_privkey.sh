#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR"/lib.sh

if [[ $# -ne 1 ]]; then
    echo "Wrong number of parameters, expected 1" >&2
    echo "Usage: $0 <slug>" >&2
    exit 2
fi

slug=$1

read -r -s -p "Password for (NEW) $slug/privkey: " privkeyPassword
echo
check_pw_len ${#privkeyPassword}

mkdir -p privkeys
mkdir "privkeys/$slug"
cd "privkeys/$slug"

printf "%s\n" "$privkeyPassword" | openssl genpkey -pass stdin -out privkey.pem -aes-256-cbc -algorithm RSA -pkeyopt rsa_keygen_bits:4096
printf "%s\n" "$privkeyPassword" | openssl rsa -passin stdin -in privkey.pem -pubout -out pubkey.pem