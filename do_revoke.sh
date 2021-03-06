#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR"/lib.sh

if [[ $# -ne 2 ]]; then
    echo "Wrong number of parameters, expected 2" >&2
    echo "Usage: $0 <CA slug> <ca|cert>/<slug>" >&2
    exit 2
fi

caSlug=$1
prefixedRevokeeSlug=$2

# Test whether a full path was provided (including the 'cas/' or 'certs/') prefix
cd "$prefixedRevokeeSlug"
cd ../..

parentPrivkeyDir=../../privkeys/$caSlug

read -r -s -p "Password for (OLD) $caSlug/privkey: " userCaPassword
echo
check_pw_len ${#userCaPassword}

cd "cas/$caSlug"

# FIXME file a pull request against openssl to allow `-crl_reason privilegeWithdrawn`?
# Though I suppose in many cases "affiliationChanged" is really what we want anyway (see https://security.stackexchange.com/questions/174327/definitions-for-crl-reasons),
# which says "This revocation code is typically used when an individual is terminated or has resigned from an organization.".
#
# But just separately might be a fun project!
echo "$userCaPassword" | openssl ca -batch -config "$SCRIPT_DIR/openssl-ca.cnf" -keyfile "$parentPrivkeyDir/privkey.pem" -passin stdin -crl_reason affiliationChanged -revoke "../../$prefixedRevokeeSlug/cert.pem"
