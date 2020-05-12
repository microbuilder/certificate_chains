#!/bin/bash

# Output Certificate Usage:
# Server will normally already have a copy of CA.crt, so devices can pass in
# USER.crt, which is signed by CA.crt, to verify identity.

# To see how a certificate chain is used by TLS in the real world, try:
# openssl s_client -connect volvocarfinancialservices.com:443 -showcerts
#
# Details:
# https://www.poftut.com/use-openssl-s_client-check-verify-ssltls-https-webserver/

# ecdsa-with-SHA256
curve=secp256r1

# Generate key for A, the root
openssl ecparam -name $curve -genkey -out CA.key
# openssl genrsa -out CA.key 4096

# Generate a cert for it
openssl req -new -x509 -days 3650 -key CA.key -out CA.crt \
        -subj "/O=Linaro/CN=Root CA"

# Generate a user key (if no secure element used for the key, etc.)
openssl ecparam -name $curve -genkey -out USER.key
# openssl genrsa -out USER.key 2048

# Generate a certificate signing request
# NOTE: You can view the contents of the X509 PKCS#10 CSR via:
# openssl asn1parse -i -in USER.csr
openssl req -new -key USER.key -out USER.csr \
        -subj "/O=Linaro/CN=User Certificate"

# Create a config snippet that includes the required extensions.
echo "subjectKeyIdentifier=hash" > exts$$.ext
echo "authorityKeyIdentifier=keyid,issuer" >> exts$$.ext

# Now generate a user certificate, signed with the CA cert and private key
# This can be used to verify payloads signed with user's private key, etc.
openssl x509 -req -days 3650 -in USER.csr -CA CA.crt -CAkey CA.key \
        -set_serial 101 \
	-extfile exts$$.ext \
        -out USER.crt

# Also generate a PKCS#7 output file
openssl crl2pkcs7 -nocrl -certfile USER.crt -out USER.p7b

rm exts$$.ext

# Remove the certificate request files, as they aren't particularly useful.
# rm USER.csr
