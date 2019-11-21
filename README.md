# Digital Certificates

Certificates are issued by a **Certificate Authority** (CA), and are used to
certify that a public key belongs to a specific entity. They contain a
public key, and details on the CA that validated the key in question.

Certificate authorities acts as a trusted third party. If the
**user certificate** is signed by the CA, you have a reasonable degree of
confidence that the public key in the user certificate (provided by the device)
hasn't been replaced in a man-in-the-middle attack with another public key that
isn't known to the CA.

Multiple certificates can be connected together in something called a
**certificate chain**, where each subsequent certificate level is signed (or 
'certified') by the level above it, with the primary CA at the root of the
certificate chain.

## Certificate Contents

User certificates contain, at a minimum, the following information:

- The owner's public key 
- The owner's distinguished name
- The distinguished name of the CA that issued the certificate
- The initial and expiry date for the certificate's validity
- A unique serial number, assigned by the CA, which will never be reused by
  the CA when signing another certificate.

> **NOTE**: CAs also maintain certificates that contain their own public key.
  Normally the CA certificate will be held on the server or device that wishes
  to validate user certificates, ensuring that they have been properly signed
  by the trusted CA.

## X.509 Standard

Digital certificates are based on the X.509 standard:

- https://tools.ietf.org/rfc/rfc5280.txt

### `Subject` Distinguished Name

The subject is a **distinguished name** (DN) which can have a number of fields.

For full details on a certificate's `subject` field see **RFC5280 4.1.2.6**.

The following are some of the more common fields used in the subject:

| Field         | Description                   |
|---------------|-------------------------------|
| O             | Organisation name             |
| OU            | Organisational unit name      |
| CN            | Common name [1]               |
| SERIALNUMBER  | Certificate serial number     |
| UID           | User ID                       |
| DNQ           | Distinguished name qualifier  |
| C             | Country                       |
| ST            | State or province             |
| L             | Locality name                 |
| PC            | Postal code                   |
| MAIL          | E-mail address                |

[1] Technically, there should never exist two certificates with the same `CN`
and same serial number, and certs with the same `CN` and different serial
numbers should be updates of the same logical certificate.

## Generating a Certificate Chain

Be sure to assign a unique name to the `CN` fields in these examples!

`Root CA`, `Intermediate CA` and `User Certificate` are used solely to
distinguish the certificate types in this example, and shouldn't be used as-is
in the real world.

### Two-level certificate chain

You can generate a CA key and certificate as follows:
  
```bash
# Generate a root CA key
openssl ecparam -name secp256k1 -genkey -out CA.key

# Generate an X.509 certificate from CA.key assigning O and CN subject fields
openssl req -new -x509 -days 3650 -key CA.key -out CA.crt \
        -subj "/O=Linaro/CN=Root CA"
```

Now generate a user key, certificate signing request, and user certificate,
signing the user certificate with the CA certificate and key generated above:

> **NOTE**: The private key may be held on a secure-element on the end device,
  in which case you wouldn't want to generate a new key as in the example
  below. In this situation, the certificate signing request (USER.csr) will
  need to be generated on the device that holds the private key, and then sent
  to the signing engine that will generate the certificate based on the data
  in the generated .csr file.  The private key should never be exposed outside
  the device. This is also a good occasion to assign a HW-based unique ID to
  the user certificate's `CN` field since this needs to be unique per device.

```bash
# Generate a user key (if a key isn't available from a secure element, etc.)
openssl ecparam -name secp256k1 -genkey -out USER.key

# Generate a certificate signing request, containing the user public key
# and required details to be inserted into the user certificate.
openssl req -new -key USER.key -out USER.csr \
        -subj "/O=Linaro/CN=User Certificate"

# Now generate a user certificate, signed with the CA cert and private key
# This can be used to verify payloads signed with user's private key, etc.
openssl x509 -req -days 3650 -in USER.csr -CA CA.crt -CAkey CA.key \
        -set_serial 101 \
        -out USER.crt
```

You can also do some cleanup to remove unnecessary files:

```bash
# Remove the certificate request file (no longer useful)
rm USER.csr
```

### Three-level certificate chain

You can generate a **root** CA key and certificate as follows:
  
```bash
# Generate a root CA key
openssl ecparam -name secp256k1 -genkey -out CA.key

# Generate an X.509 certificate from CA.key assigning O and CN subject fields
openssl req -new -x509 -days 3650 -key CA.key -out CA.crt \
        -subj "/O=Linaro/CN=Root CA"
```

Then generate an **intermediate** CA key, certificate request, and certificate,
singing it with the root CA certificate and key:

```bash
# Generate an intermediate cert
openssl ecparam -name secp256k1 -genkey -out INT.key

# Generate a certificate signing request
openssl req -new -key INT.key -out INT.csr \
        -subj "/O=Linaro/CN=Intermediate CA"

# Create cansign.ext with "basicConstraints=CA:TRUE"
echo "basicConstraints=CA:TRUE" > cansign.ext

# Sign INT with CA.  The extension is needed so that clients will be able
# to trust that B is also able to sign certificates.
openssl x509 -req -days 3650 -in INT.csr -CA CA.crt -CAkey CA.key \
        -CAcreateserial \
        -extfile cansign.ext \
        -out INT.crt
```

Finally, you can generate a **user** key, certificate request, and user
certificate, signing it with the intermediate certificate and key:

> **NOTE**: See note on two-level certificate chains above for instances where
  the private key is held in a secure element on the HW device the certificate
  is being generated for.

```bash
# Generate a user key (if no secure element used for the key, etc.)
openssl ecparam -name secp256k1 -genkey -out USER.key

# Generate a certificate signing request
openssl req -new -key USER.key -out USER.csr \
        -subj "/O=Linaro/CN=User Certificate"

# Now generate a user certificate, signed with the INT cert and private key
# This can be used to verify payloads signed with user's private key, etc.
openssl x509 -req -days 3650 -in USER.csr -CA INT.crt -CAkey INT.key \
        -set_serial 101 \
        -out USER.crt

# Remove the certificate request files, as they aren't particularly useful.
rm *.csr cansign.ext
```

## Analysing Certificates

The contents of a certificate can be displayed as follows:

```bash
openssl x509 -in USER.crt -text
```

Which should giving something resembling the following results:

```
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 101 (0x65)
    Signature Algorithm: ecdsa-with-SHA1
        Issuer: O=Linaro, CN=Root CA
        Validity
            Not Before: Nov 20 21:43:12 2019 GMT
            Not After : Nov 17 21:43:12 2029 GMT
        Subject: O=Linaro, CN=User Certificate
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub: 
                    04:56:aa:6e:1f:63:62:19:6c:0f:cb:d4:4f:6e:67:
                    a6:e5:6e:bf:20:9d:da:6b:d3:76:fd:73:3f:5d:7e:
                    3e:b1:a5:41:32:26:4d:f1:c3:cd:21:be:54:0e:4c:
                    fb:20:49:e3:b3:53:83:d2:dd:96:89:86:4c:ff:a2:
                    88:10:ee:6e:da
                ASN1 OID: secp256k1
    Signature Algorithm: ecdsa-with-SHA1
         30:45:02:21:00:c7:b8:f5:e1:c9:ce:e0:07:03:79:29:68:77:
         54:e5:b4:2f:08:2b:81:d1:2c:7e:fe:ff:67:82:2e:68:6c:ee:
         fa:02:20:7d:9b:2c:82:36:76:14:3c:d6:d8:9e:24:eb:25:d2:
         cb:da:bc:bd:13:da:aa:7f:cf:cd:4e:50:ce:44:f7:35:e3
-----BEGIN CERTIFICATE-----
MIIBQDCB6AIBZTAJBgcqhkjOPQQBMCoxDzANBgNVBAoMBkxpbmFybzEXMBUGA1UE
AwwOTGluYXJvIFJvb3QgQ0EwHhcNMTkxMTIwMjE0MzEyWhcNMjkxMTE3MjE0MzEy
WjA0MQ8wDQYDVQQKDAZMaW5hcm8xITAfBgNVBAMMGExpbmFybyBJbWFnZSBDZXJ0
aWZpY2F0ZTBWMBAGByqGSM49AgEGBSuBBAAKA0IABFaqbh9jYhlsD8vUT25npuVu
vyCd2mvTdv1zP11+PrGlQTImTfHDzSG+VA5M+yBJ47NTg9LdlomGTP+iiBDubtow
CQYHKoZIzj0EAQNIADBFAiEAx7j14cnO4AcDeSlod1TltC8IK4HRLH7+/2eCLmhs
7voCIH2bLII2dhQ81tieJOsl0svavL0T2qp/z81OUM5E9zXj
-----END CERTIFICATE-----
```
