TF-M Provisioning Sample App
############################

These notes describe some requirements for a sample application integrating
TF-M and Zephyr, with late-stage binding to web or other key/certificate
based services to verify device identify and message authenticity.

Private Key Provisioning
************************

TF-M's persistent key storage mechanism should be used to store one or more
private keys for signing data packets, authenticating the device to third-party
services (AWS, Google IoT Cloud, custom servers), encrypting and decrypting
data, etc.

Private keys will be securely held in the secure processing environment and
inaccessible once the initial key generation process is complete. Public keys
are always accessible, and derived from the securely-stored private key data.

Provisioning Key Data
=====================

The `mcumgr`_ interface on Zephyr can be used to expose a means to work with
keys over a serial connection, BLE, from the Zephyr shell, or over a
user-defined transport, providing the maximum flexibility and usability in the
device provisioning process in the factory (via serial and HW test points),
in the field (via a mobile application), or during the development phase
(Zephyr shell).

A new mcumgr command to generate and store the private key should be
implemented, returning the public key and the key ID associated with
the new key in persistent key storage as a response. It should also be
possible to retrieve the public key of any previously stored persistent key
value, or to replace an existing key with a new private key value.

Private key values can either be randomly generated (with a sufficient HW
entropy source), or a known-value provided during the provisioning process,
allowing fixed key IDs to be associated with specific services.

.. _mcumgr: https://github.com/zephyrproject-rtos/mcumgr

Requirements
------------

- Private keys can be randomly generated or a pre-determined value can be used.
- Key IDs (used by TF-M to access keys in persistent storage) can be
  auto-assigned or specified as a known 32-bit integer.
- Private keys can be replaced for a specific key ID.
- Public keys can be requested for a specific 32-bit key ID.
- The presence of a specific key ID can be verified.

Certificate Signing Process
===========================

In situations where you wish not only to make use of a private key, but also
need the additional reliability of making the key part of a certificate chain,
verifying the identify and validity of the key through one or more trusted
intermediaries with their own known key data integrated into the certificate
chain, additional requirements will be imposed during the provisioning process.

When a certificate chain is required, a certificate signing request (CSR) will
be generated with the private key data, and returned as part of the mcumgr
certificate chain provisioning command response. This CSR blob then needs to be
forwarded to the certificate authority (CA) to be signed. The signed
certificate from the CA will be returned, passed on to the end device, and
stored via persistent storage.

This signed certificate does not need to be stored securely, and is similar to
the public key (and contains the public key data), but adds an additional level
of confidence in the public key since knowledge of it is also being attested to
by the CA as a known or valid device, signed with the CA's private key and
verifiable with the CA or by checking the certificate signature with the CA's
public key.

NOTE: Since the certificate generation and signing process requires access to
the new private key to generate the certificate signing request (CSR). This
process MUST take place during the initial key provisioning stage, since once
the private key is added to persistent storage we no longer have direct access
to the private key value, and TF-M does not currently support generating CSRs.
Generating a new certificate will require the generation of a new persistent
key record, or replacing the existing value with a new one.

Requirements
------------

- Add support for generating a certificate signing request (CSR).
- The application sending the mcumgr command must act as an intermediary with
  the CA during the provisioning process.
- Storage of the signed certificate in persistent storage.
- Retrieval of the signed certificate on demand in lieu of the bare public key.

NOTE: TF-M's persistent key storage mechanism includes a RAW option where the
signed certificate can be stored under a separate key ID. It isn't necessary to
securely store the signed certificate since it contains no sensitive
information, but this does provide a convenient storage and retrieval
mechanism.


Sample App Proposal
===================

The sample application will need to include support for mcumgr, and allow
the use of private keys and certificate chains with pre-determined KEY IDs
to access a custom server.

The sample will be provisioned with:

- A prime256v1 key with a random key value
- A prime256v1 key with a pre-determined value
- A prime256v1 key with a pre-determined value to be integrated into a
  2-level certificate chain.

In addition to the sample Zephyr app, and the missing mcumgr commands, the
following additional components are required:

CA Server Script
----------------

A script behaving as a CA to sign incoming CSRs, generate the signed
certificate, and log the device as known based on it's public key value and
a unique device ID.

The UART or BLE-based application implementing the mcumgr command(s) will
communicate with this script or server.

Data Aggregation Server
-----------------------

A script starting a server which performs the following operations:

- Allows registration of devices, with a unique device ID, accepting a valid
  certificate chain for the public key used by that device. This certificate
  chain must be signed by the CA above, and the CA signature verified as
  valid before the device will be registered.
- Accepts data packets that are hashed and signed with a prime256v1
  (ecdsa-with-SHA256) key, and accepting or rejecting them based on the
  validity of the signature, using previously registered public key data
  from the certificate chain. COSE `SIGN1`_ is proposed as a means of encoding
  this data in a standard format.
- An MQTT broker is proposed as the middle component between the end device
  and the data aggregation server, where the end device writes the hashed and
  signed payloads to the MQTT broker, and the server scans the broker for
  incoming packets asynchronously. An error channel can be used to indicate
  to the end device when a packet is rejected.

.. _SIGN1: https://tools.ietf.org/html/rfc8152#section-4.2
