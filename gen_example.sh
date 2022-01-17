#!/bin/bash

set -e

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

mkdir example_certs
cd example_certs

pw_privkey=0000
pw_root=1111
pw_ca=2222
pw_cert=3333

printf "%s\n" "$pw_privkey"           | "$SCRIPT_DIR"/mk_privkey.sh 'thekey'

printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/mk_rootca.sh 'x1' 'Root X1'
printf "%s\n%s\n" "$pw_ca" "$pw_root" | "$SCRIPT_DIR"/mk_ca.sh     'x1' 'p1' 'Public API Client P1' 'URI:https://api.hoek.io/v1'
printf "%s\n%s\n" "$pw_cert" "$pw_ca" | "$SCRIPT_DIR"/mk_cert.sh   'p1' 'tester' '/O=test.hoek.io/OU=role1/OU=role2/CN=tester' 'email:tester@hoek.io'
printf "%s\n%s\n" "$pw_ca" "$pw_root" | "$SCRIPT_DIR"/mk_cert.sh   'x1' 'root-end5' '/O=wierdo.hoek.io/OU=role1/CN=root-end' 'email:root-end@hoek.io'

printf "%s\n%s\n" "$pw_cert" "$pw_ca" | "$SCRIPT_DIR"/mk_cert.sh   'p1' 'tester-bad' '/O=evil.hoek.io/OU=role1/OU=role2/CN=tester-bad' 'email:tester-bad@hoek.io'

printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/mk_crl.sh    'x1'
printf "%s\n" "$pw_ca"                | "$SCRIPT_DIR"/mk_crl.sh    'p1'
printf "%s\n" "$pw_ca"                | "$SCRIPT_DIR"/mk_crl.sh    'p1'
printf "%s\n" "$pw_ca"                | "$SCRIPT_DIR"/do_revoke.sh 'p1' 'certs/tester-bad'
printf "%s\n" "$pw_ca"                | "$SCRIPT_DIR"/mk_crl.sh    'p1'

printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/mk_rootca.sh 'x2' 'Root X2'
printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/mk_crl.sh    'x2'
printf "%s\n%s\n" "$pw_ca" "$pw_root" | "$SCRIPT_DIR"/mk_ca.sh     'x2' 'i1' 'I1 (Revoked)' 'DNS:i1.example.com'
printf "%s\n%s\n" "$pw_ca" "$pw_root" | "$SCRIPT_DIR"/mk_ca.sh     'x2' 'i2' 'I2' 'DNS:i2.example.com'
printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/mk_crl.sh    'x2'
printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/do_revoke.sh 'x2' 'cas/i1'
printf "%s\n" "$pw_root"              | "$SCRIPT_DIR"/mk_crl.sh    'x2'

