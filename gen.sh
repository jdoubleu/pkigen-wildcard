#!/usr/bin/env bash
# Generate PKI with leaf certificates

# Log function
:: ()
{
    echo -e "\033[36m#\033[0m \033[1;36m$*\033[0m"
}

set -e

# Vars
BASE=$PWD
BUILD_DIR=$PWD/build
OPENSSL_CONFIG=$BASE/files/openssl.cnf

# Read input
while [ "$#" -gt 0 ]; do
    key="$1"
    case "$key" in
        -d)
            DOMAIN="$2"
            shift
            ;;
        -n)
            NAME="$2"
            shift
            ;;
    esac
    shift
done

DOMAIN_SLUGGED=$(echo $DOMAIN | sed s/\\./_/g)

:: "Preparing directory structure"
# cleanup first
CA_BASE=$BUILD_DIR/ca
rm -rf $CA_BASE
mkdir -p $CA_BASE
cd $CA_BASE
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

:: "CA: creating key"
openssl genrsa -out private/ca.key.pem 2048
chmod 400 private/ca.key.pem

:: "CA: creating certificate"
openssl req -config $OPENSSL_CONFIG \
    -key private/ca.key.pem \
    -new -x509 -days 3650 -sha256 -extensions v3_ca \
    -subj "/CN=${NAME} Root CA" \
    -out certs/ca.cert.pem
chmod 444 certs/ca.cert.pem

:: "Server: creating private key"
openssl genrsa -out private/${DOMAIN_SLUGGED}.key 2048
chmod 400 private/${DOMAIN_SLUGGED}.key

:: "Server: creating certificate signing request"
openssl req -config $OPENSSL_CONFIG \
    -key private/${DOMAIN_SLUGGED}.key \
    -new -sha256 \
    -subj "/CN=*.${DOMAIN}" \
    -out csr/${DOMAIN_SLUGGED}.csr.pem

:: "CA: signing server certificate"
openssl ca -config $OPENSSL_CONFIG \
    -extensions server_cert -batch -days 2830 -notext -md sha256 \
    -in csr/${DOMAIN_SLUGGED}.csr.pem \
    -out certs/${DOMAIN_SLUGGED}.crt
chmod 444 certs/${DOMAIN_SLUGGED}.crt