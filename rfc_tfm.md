# Certificate Chain Support in TF-M

|      |                                                          |
|:---- | -------------------------------------------------------- |
| URL | https://github.com/microbuilder/certificate_chains/blob/master/rfc_tfm.md |
| Editor | David Brown (Linaro), Kevin Townsend (Linaro) |
| Status | Draft |

# Goals

In order to add an additional level of 'trust' to TF-M devices that make use
of public key cryptography and signatures (Initial Attestation Service,
firmware verification at boot, etc.), this RFC presents some of the benefits
and requirements of migrating from a single unsigned public key to the use of a
two or three level certificate chain, where the device's public key is signed
by one or more trusted CAs.

Some of the key goals of this proposal are:

- Increase the level of trust in the provenance of the public key provided by
  a device during attestation or provisioning.
- Enable the manipulation, signing and use of X.509 certificate chains in TF-M.
- Allow multiple CAs to be involved in the certificate signing process,
  such as a Root CA from the device vendor, an intermediate CA from the
  manufacturer of OEM, etc.
- Allow firmware images to be signed by different OEMs, for example, based on
  a common parent image from a trusted source, knowing where the specific
  variant comes from at the root and intermediate (OEM) level.
- Enable the generation and secure storage of new private keys for use with
  cloud or device management services, including storage of signed certificate
  chains in secure storage.
- Generation of certificate signing requests (.csr), making secure use of the
  private keys to request the certificate chain for that key, based on a HW
  element (IAT, etc.) or a generated key pair (see previous point).

## Description

At present, TF-M makes use of two main key pairs:

- An **EC key pair** used in the **initial attestation service**, which is used
  to sign the SHA256 hashes of initial attestation tokens (IATs) to verify their
  authenticity. Devices receiving the attestation token require the public
  key from this key pair to 'validate' the attestation token.
- An **RSA2048/3072 byte key pair** used to **sign firmware images**, which are
  verified at boot by mcuboot. The public part of this key is held by
  mcuboot firmware, and used to verify the firmware image at boot.

There is no standard mechanism for verifying the validity of the public key,
however, or to know if it has expired, been black-listed, is a known-device,
etc., which are all left as an exercise for the reader/implementer.

By migrating from the current raw public key mechanism used to work with
attestation tokens and other key based systems, to a certificate chain, we
can increase the level of confidence in devices that we have in devices during
the initial attestation process, by having them be validating by one or more
external certificate authorities (CAs).

This requires the following changes to TF-M's secure firmware:

- **PKSC#10 (RFC2986) certificate signing request** (`.csr` file) generation
  on the secure side, which requires accessing the associated private key when
  generating the CSR binary blob. (NOTE: mbed-crypto currently has support for
  working with CSRs.)
- Once the CSR has been sent to the certificate authority, the returned
  (signed) certificate chain, which contains the end device's public key and
  details about the CA(s), must be stored on the TF-M device for later access.
- Instead of exposing the raw IAT public key, the binary blob certificate chain
  should be provided (stored in the requirement above).

In addition, support should be added for the following if possible:

- Generation of new private keys, generation of CSRs based on those private
  keys, and access to these supplementary (not IAT) certificate chains for
  use with non IAT services. This needs to happen in the secure processing
  environment, and with secure storage to protect the additional private keys
  to the greatest extent posible.

### Certificate Signing ('Provisioning') Process

The following sequence diagrams shows how certificate chains might be used
when provisioning devices into a device management system.

The following workflow assumes a provisioning device connecting to a new end
node device to be provisioned. The provisioning device uses the mcumgr
protocol that is understood by both mcuboot and Zephyr RTOS, and can
communicate over USART, IP and BLE at present, and can easily be extended to
SWD or other transports as required.

On BLE-enabled devices, for example, an app on a tablet or mobile phone could
connect to the end node over mcumgr, and communicate with the Root CA Server
when signing the certificate signing request and providing the certificate
chain.

![alt text][workflow-2lvl]

[workflow-2lvl]: img/workflow_2level.png

Part of the work to be done on the TF-M secure side is in the **Generate
certificate signing request (PKCS#10) on secure side** box.

### TF-M Requirements

- Secure functions to generate and store:
  - New private keys
  - Certificate signing requests based on a specific private key and meta-data
  - Storage and retrieval of signed certificate chains on request
- Private keys should never be accessible from the non-secure side.
- Certificate signing requests (CSRs) can be requested based on the ID of a
  specific, previously generated private key held securely in ITS.
- Binary blob certificate chains can be updated and retrieved from NS world.
- Support should be added to verify the certificate authority (CA) signatures
  in the certificate chains, based on the public CA key held on the device.
  This public CA key can also be held in ITS, but this isn't a security
  requirement.

## Key Concepts/Terms

### Certificate Authority (CA)

The certificate authority is a trusted signing authority that attests to having
knowledge of devices whoses lower level certificates it has 'signed'. The
process of what devices are accepted for signing purposes is user defined, but
the goal is to indicate that this lower level device is 'known' by the CA or
trusted by it, as long as the certificate itself is still valid and hasn't
been black-listed by the CA.

There are several potential CA levels of use with TF-M based devices:

- **Root CA**: The highest level **certificate authority (CA)**, which
  maintains it's own private key that is used to sign lower level certificates
  in the certificate chain. It's public key is available to verify signatures.
  An end device that is `certified` by the Root CA is generally considered
  trustworthy, and has been vetted in a user-defined process.
- **Intermediate CA**: This CA is one level lower than the **Root CA**, and
  may for example be an OEM vendor that itself attests to an **end device**
  that comes from the maintainer of the Root CA. The intermediate CA's
  certificate is signed by the Root CA, and the end device's certificate
  is signed by the intermediate CA.

### Certificate

Certificates are issued by a **certificate authority** and contain a public
key, and details on the CA that generated the certificate.

In the context of a TF-M device, there are likely to be either two or three
certificates that make up the certificate chain:

- **Root Certificate**: The Root CA maintains a certificate containing the
  Root CAs public key for verification purposes.
- **Intermediate Certificate**: The intermediate CA maintains a
  certificate containing the intermediate CAs public key, and details on the
  Root CA that signed the intermediate certificate.
- **Device Certificate**: Based on a securely-held private key on the end
  device. This can be sourced from a secure element, crypto cell, or from
  secure storage. The **end device** protects the private key in this key pair,
  and only ever exposes the public key in the device certificate, which is the
  final part of the **certificate chain** and signed by one or more
  known/trusted **certificate authorities (CAs)**.

## References

- [X.509 Certificate Generation](https://github.com/microbuilder/certificate_chains/blob/master/rfc_tfm.md)
A high-level overview of X.509 certificate chain generation in the context of
TF-M and how the signing process may work.
- [CBOR Profile of X.509 Certificates](https://datatracker.ietf.org/doc/draft-raza-ace-cbor-certificates/)
This IETF draft proposes a more compact representation of X.509 certificates
and may be relevant to the issues discussed here.
