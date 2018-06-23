# PKI Generator for Wildcard Certificates
Bash scripts for generating a PKI including a CA and leaf certificate.

The leaf certificate will be a wildcard certificate.

## Usage
Simply run `./gen.sh <general name> <domain>` in this folder, where
* `<general name>` is just a name for the CA prepended before "Development CA"
* `<domain>` is your base domain (e.g. `dev.local`, the wildcard will be prepended!)