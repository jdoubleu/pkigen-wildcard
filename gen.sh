#!/usr/bin/env bash
# Generate PKI with leaf certificates
set -e

# Log function
:: ()
{
    echo -e "\033[36m#\033[0m \033[1;36m$*\033[0m"
}

# Vars
VERBOSE=""
BASE=$PWD
BUILD_DIR=$PWD/build

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
        --verbose)
            VERBOSE=1
            set -x
            ;;
        *)
            NAME="$1"
            DOMAIN="$2"
            shift
            ;;
    esac
    shift
done

# Check
if [[ -z "$DOMAIN" || -z "$NAME" ]]; then
    :: "No DOMAIN or NAME given!"
    exit 1
fi

# Setup
DOMAIN_SLUGGED=$(echo $DOMAIN | sed s/\\./_/g)

:: "Preparing directory structure"
# cleanup first
rm -rf $BUILD_DIR

CA_BASE=$BUILD_DIR/ca
mkdir -p $CA_BASE
cd $CA_BASE
mkdir certs csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

sed \
    -e "s/%DOMAIN_BASE%/${DOMAIN}/" \
    -e "s/%DOMAIN_WILDCARD%/*.${DOMAIN}/" \
    $BASE/files/openssl.cnf.tmpl > $BUILD_DIR/openssl.cnf
OPENSSL_CONFIG=$BUILD_DIR/openssl.cnf

:: "CA: creating key"
openssl genrsa -out private/ca.key 2048
chmod 400 private/ca.key

:: "CA: creating certificate"
openssl req -config $OPENSSL_CONFIG \
    -key private/ca.key \
    -new -x509 -days 3650 -sha256 -extensions v3_ca \
    -subj "/CN=${NAME} Development CA" \
    -out certs/ca.pem
chmod 444 certs/ca.pem

:: "Server: creating private key"
openssl genrsa -out private/${DOMAIN_SLUGGED}.key 2048
chmod 400 private/${DOMAIN_SLUGGED}.key

:: "Server: creating certificate signing request"
openssl req -config $OPENSSL_CONFIG \
    -key private/${DOMAIN_SLUGGED}.key \
    -new -sha256 \
    -subj "/CN=*.${DOMAIN}" \
    -out csr/${DOMAIN_SLUGGED}.csr

:: "CA: signing server certificate"
openssl ca -config $OPENSSL_CONFIG \
    -extensions server_cert -batch -days 2830 -notext -md sha256 \
    -in csr/${DOMAIN_SLUGGED}.csr \
    -out certs/${DOMAIN_SLUGGED}.pem
chmod 444 certs/${DOMAIN_SLUGGED}.pem

:: "Preparing export"
cd $BUILD_DIR
mkdir export/

cp $CA_BASE/certs/*.pem export/
cp $CA_BASE/private/${DOMAIN_SLUGGED}.key