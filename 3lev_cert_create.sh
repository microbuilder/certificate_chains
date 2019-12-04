#!/bin/bash

curve=secp256k1

# Generate key for CA, the root
openssl ecparam -name $curve -genkey -out CA.key
# openssl genrsa -out CA.key 4096

# Generate a cert for it
openssl req -new -x509 -days 3650 -key CA.key -out CA.crt \
        -subj "/O=Linaro/CN=Root CA"

# Generate an intermediate cert
# openssl genrsa -out INT.key 4096
openssl ecparam -name $curve -genkey -out INT.key

openssl req -new -key INT.key -out INT.csr \
        -subj "/O=Linaro/CN=Intermediate CA"

        #-addext basicConstraints=CA:TRUE \

# Create cansign.ext with "basicConstraints=CA:TRUE"
echo "basicConstraints=CA:TRUE" > cansign$$.ext
echo "subjectKeyIdentifier=hash" > cansign$$.ext
echo "authorityKeyIdentifier=keyid,issuer" >> cansign$$.ext

# Sign INT with CA.  The extension is needed so that clients will be able
# to trust that B is also able to sign certificates.
openssl x509 -req -days 3650 -in INT.csr -CA CA.crt -CAkey CA.key \
        -CAcreateserial \
        -extfile cansign$$.ext \
        -out INT.crt

# Generate a user key (if no secure element used for the key, etc.)
openssl ecparam -name $curve -genkey -out USER.key
# openssl genrsa -out USER.key 2048

# Generate a certificate signing request
openssl req -new -key USER.key -out USER.csr \
        -subj "/O=Linaro/CN=User Certificate"

# Create a config snippet that includes the required extensions.
echo "subjectKeyIdentifier=hash" > exts$$.ext
echo "authorityKeyIdentifier=keyid,issuer" >> exts$$.ext

# Now generate a user certificate, signed with the CA cert and private key
# This can be used to verify payloads signed with user's private key, etc.
openssl x509 -req -days 3650 -in USER.csr -CA INT.crt -CAkey INT.key \
        -set_serial 101 \
	-extfile exts$$.ext \
        -out USER.crt

# Remove the certificate request files, as they aren't particularly
# useful.
rm INT.csr USER.csr cansign$$.ext exts$$.ext
