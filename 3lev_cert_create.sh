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
echo "basicConstraints=CA:TRUE" > cansign.ext

# Sign INT with CA.  The extension is needed so that clients will be able
# to trust that B is also able to sign certificates.
openssl x509 -req -days 3650 -in INT.csr -CA CA.crt -CAkey CA.key \
        -CAcreateserial \
        -extfile cansign.ext \
        -out INT.crt

# Now lets generate a user certificate we can use to sign images.
# openssl genrsa -out USER.key 2048
openssl ecparam -name $curve -genkey -out USER.key
openssl req -new -key USER.key -out USER.csr \
        -subj "/O=Linaro/CN=User Certificate"

openssl x509 -req -days 3650 -in USER.csr -CA INT.crt -CAkey INT.key \
        -set_serial 101 \
        -out USER.crt

# Remove the certificate request files, as they aren't particularly
# useful.
rm INT.csr USER.csr cansign.ext
