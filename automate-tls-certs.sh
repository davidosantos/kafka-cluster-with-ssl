#!/bin/bash

# Exit on error and don't allow unset (empty) variables
set -o nounset \
    -o errexit \
#    -o verbose
#    -o xtrace

#####
##### Initialize Variables #####
#####

SOURCE_DIR=/home/training/ldap/security/tls
mkdir -p $SOURCE_DIR
pushd $SOURCE_DIR

# Declare directories for keys, certs, truststores, and keystores
declare -A tlsdirs
tlsdirs[CA]="certificate-authority"
tlsdirs[DS]="directory-service"
tlsdirs[KAFKA]="kafka"
tlsdirs[MDS]="mds"
tlsdirs[CLIENT]="kafka-client"
tlsdirs[SR]="schema-registry"
tlsdirs[CC]="control-center"
tlsdirs[KSQL]="ksqldb-server"
tlsdirs[CONNECT]="kafka-connect"
tlsdirs[RP]="rest-proxy"

declare -A keystores
# directory service needs keystore for ldaps
keystores[DS]="directory-service"
# kafka needs keystore for TLS encrypted communication with clients
keystores[KAFKA]="kafka"
keystores[MDS]="mds"
# These components need keystores to secure their REST APIs with HTTPS
keystores[SR]="schema-registry"
keystores[CC]="control-center"
keystores[KSQL]="ksqldb-server"
keystores[CONNECT]="kafka-connect"
keystores[RP]="rest-proxy"

declare -A truststores
# kafka needs to trust directory service
truststores[KAFKA]="kafka"
# kafka client and CP components need to trust kafka
truststores[CLIENT]="kafka-client"
truststores[SR]="schema-registry"
truststores[CC]="control-center"
truststores[KSQL]="ksqldb-server"
truststores[CONNECT]="kafka-connect"
truststores[RP]="rest-proxy"
# MDS leader needs to trust MDS followers
truststores[MDS]="mds"

#####
##### Define Functions #####
#####

# Function to clean up files
function cleanup(){
    for dir in "${tlsdirs[@]}"; do
        echo "cleaning ${dir} directory"
        if [ ! -d "${dir}" ]; then
            echo "
            Creating directory ${dir}
            "
            mkdir ${dir}
        else
            echo "removing contents of ${dir}"
            rm -f ${dir}/*
        fi
    done
}

# Function to create configuration files in each directory
function create_cnf(){
    echo "creating config file"
    if [ $1 = "${tlsdirs[CA]}" ]
    then
        cp ../../scripts/san.cnf "$1"/ca.cnf
        sed -i -e "s/{}/ca.confluent.io/g" "$1"/ca.cnf
    else
        cp ../../scripts/san.cnf "$1"/"$1".cnf
        sed -i -e "s/{}/"$1"/g" "$1"/"$1".cnf
    fi   
}

# Function to create a certificate authority key and certificate
function create_ca(){
    echo "creating CA key and certificate"
    openssl req -new -newkey rsa:2048 -days 365 -extensions v3_ca \
        -subj '/CN=ca.confluent.io/OU=TEST/O=CONFLUENT/L=PaloAlto/S=Ca/C=US' \
        -addext "subjectAltName = DNS:ca.confluent.io" \
        -nodes -x509 -sha256 -set_serial 0 \
        -keyout "${tlsdirs[CA]}"/ca.key -out "${tlsdirs[CA]}"/ca.crt \
        -passin pass:confluent -passout pass:confluent
}

# Function to create a certificate signing request using a new service private key
# input: service private key
# output: certificate signing request
function create_csr(){
    echo "creating certificate signing request for $1"
    openssl req -newkey rsa:2048 \
        -subj "/C=US/ST=CA/L=PaloAlto/O=Confluent/OU=training/CN=$1" \
        -addext "subjectAltName = DNS:$1" \
        -nodes -sha256 \
        -keyout "${1}"/"${1}"-private.key \
        -out "${1}"/"${1}".csr \
        -config "${1}"/"${1}".cnf
}


# Function to create server certificate signed by certificate authority
# input: service's certificate signing request
# output: signed certificate for service
function sign_crt(){
    echo "creating signed certificate for $1"
    openssl x509 -req -CA "${tlsdirs[CA]}"/ca.crt -CAkey "${tlsdirs[CA]}"/ca.key \
        -in "${1}"/"${1}".csr \
        -out "${1}"/"${1}"-signed.crt \
        -extfile "${1}"/"${1}".cnf \
        -extensions req_ext \
        -days 365 -CAcreateserial -passin pass:confluent
}


# Function to make a certificate chain
# input: signed service certificate and CA certificate
function create_cert_chain(){
    echo "creating certificate chain for $1"
    cat "${1}"/"${1}"-signed.crt \
        "${tlsdirs[CA]}"/ca.crt > "${1}"/"${1}"-chain.crt
}


# Function to create a .p12 keystore file using cert chain and server private key
function create_keystore(){
    echo "creating keystore for $1"
    openssl pkcs12 -export -in "${1}"/"${1}"-chain.crt \
        -inkey "${1}"/"${1}"-private.key \
        -out "${1}"/"${1}".keystore.p12 \
        -name "${1}" -password pass:confluent
}

function create_truststore(){
    echo "creating truststore for $1"
        keytool -noprompt -keystore "${1}"/"${1}".truststore.jks \
            -alias CARoot -import -file "${tlsdirs[CA]}"/ca.crt \
            -storepass confluent -keypass confluent
}

#####
##### Main Program #####
#####

cleanup

for i in "${tlsdirs[@]}"; do
    create_cnf $i
done

create_ca

for i in "${keystores[@]}"; do
    create_csr $i
    sign_crt $i
    create_cert_chain $i
    create_keystore $i
done

for i in "${truststores[@]}"; do
    create_truststore $i
done


# Set proper permissions for keystores

chown cp-kafka:confluent $SOURCE_DIR/**/*.keystore*
chown training:training $SOURCE_DIR/directory-service/directory-service.keystore.p12
chmod 440 $SOURCE_DIR/**/*.keystore*

# Add ca.crt to system certs under /usr/share/ca-certificates/confluent
# Doing this makes it so the confluent CLI and ldap clients implicitly trust our CA

mkdir -p /usr/local/share/ca-certificates/confluent
chmod 777 /usr/local/share/ca-certificates/confluent
cp $SOURCE_DIR/certificate-authority/ca.crt /usr/local/share/ca-certificates/confluent/
chmod 644 /usr/local/share/ca-certificates/confluent/ca.crt
update-ca-certificates

# return to directory where script was invoked
popd