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

:: "Creating Root CA"
# cleanup first
CA_BASE=$BUILD_DIR/ca
rm -rf $CA_BASE
mkdir -p $CA_BASE
cd $CA_BASE
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

:: "Create CA key"
openssl genrsa -out private/ca.key.pem 2048
chmod 400 private/ca.key.pem

:: "Create CA certificate"
openssl req -config $OPENSSL_CONFIG \
    -key private/ca.key.pem \
    -new -x509 -days 3650 -sha256 -extensions v3_ca \
    -subj "/CN=${NAME} Root CA" \
    -out certs/ca.cert.pem
chmod 444 certs/ca.cert.pem

:: "Creating Intermediate Certificate"
CA_INTERMEDIATE_BASE="$CA_BASE/intermediate"
mkdir -p $CA_INTERMEDIATE_BASE
cd $CA_INTERMEDIATE_BASE
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > crlnumber

:: "Create Intermediate Certificate private key"
cd $CA_BASE
openssl genrsa -out intermediate/private/intermediate.key.pem 2048
chmod 400 intermediate/private/intermediate.key.pem

:: "Create Intermediate CSR"
openssl req -config $OPENSSL_CONFIG \
    -new -sha256 \
    -subj "/CN=Local Development" \
    -key intermediate/private/intermediate.key.pem \
    -out intermediate/csr/intermediate.csr.pem

:: "Create Intermediate Certificate"
openssl ca -config $OPENSSL_CONFIG \
    -extensions v3_intermediate_ca \
    -batch -days 3195 -notext -md sha256 \
    -in intermediate/csr/intermediate.csr.pem \
    -out intermediate/certs/intermediate.cert.pem

chmod 444 intermediate/certs/intermediate.cert.pem

:: "Create SSL certificate private key"
openssl genrsa -out intermediate/private/${DOMAIN_SLUGGED}.key 2048
chmod 400 intermediate/private/${DOMAIN_SLUGGED}.key

:: " > Create SSL certificate CSR"
openssl req -config $OPENSSL_CONFIG \
    -key intermediate/private/${DOMAIN_SLUGGED}.key \
    -new -sha256 \
    -subj "/CN=*.${DOMAIN}" \
    -out intermediate/csr/${DOMAIN_SLUGGED}.csr.pem

:: " Sign SSL certificate CSR"
openssl ca -config $OPENSSL_CONFIG \
    -extensions server_cert -batch -days 2830 -notext -md sha256 \
    -in intermediate/csr/${DOMAIN_SLUGGED}.csr.pem \
    -out intermediate/certs/${DOMAIN_SLUGGED}.crt
chmod 444 intermediate/certs/${DOMAIN_SLUGGED}.crt