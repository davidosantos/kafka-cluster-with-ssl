#!/bin/bash

# This script does the following:
## Encrypt properties files with Confluent Secrets
## Updates Confluent systemd services so they can decrypt said properties files
## Creates a key for the MDS token service

# Exit on error
set -e

SOURCE_DIR=/home/training/ldap

# Link server properties files to files in $SOURCE_DIR/cp-properties.
# This allows systemd services to run without overriding ExecStart

echo "
Creating symbolic links from /etc/kafka/ to $SOURCE_DIR/cp-properties/
"

ln -sf $SOURCE_DIR/cp-properties/server.properties /etc/kafka/server.properties
ln -sf $SOURCE_DIR/cp-properties/zookeeper.properties /etc/kafka/zookeeper.properties
ln -sf $SOURCE_DIR/cp-properties/control-center.properties /etc/confluent-control-center/control-center-production.properties
ln -sf $SOURCE_DIR/cp-properties/schema-registry.properties /etc/schema-registry/schema-registry.properties
ln -sf $SOURCE_DIR/cp-properties/connect-avro-distributed.properties /etc/kafka/connect-distributed.properties
ln -sf $SOURCE_DIR/cp-properties/ksql-server.properties /etc/ksqldb/ksql-server.properties
ln -sf $SOURCE_DIR/cp-properties/kafka-rest.properties /etc/kafka-rest/kafka-rest.properties



# Create systemd override files for kafka <-> zookeeper SASL authentication.
# Systemd services must have access to the confluent secret master key to decrypt properties at runtime
# TODO: kafka <-> zookeeper mutual TLS instead of SASL

echo "
Modifying systemd unit files to include KAFKA_OPTS and CONFLUENT_SECURITY_MASTER_KEY variables
"

for i in zookeeper server schema-registry kafka-connect ksqldb kafka-rest control-center; do
    mkdir -p /etc/systemd/system/confluent-$i.service.d
done

cat << EOF > /etc/systemd/system/confluent-zookeeper.service.d/override.conf
[Service]
Environment="KAFKA_OPTS=-Djava.security.auth.login.config=$SOURCE_DIR/cp-properties/zookeeper.jaas"
EOF

cat << EOF > /etc/systemd/system/confluent-server.service.d/override.conf
[Service]
Environment="KAFKA_OPTS=-Djava.security.auth.login.config=$SOURCE_DIR/cp-properties/zookeeper-client.jaas"
Environment="CONFLUENT_SECURITY_MASTER_KEY=$CONFLUENT_SECURITY_MASTER_KEY"
EOF

for i in schema-registry kafka-connect ksqldb kafka-rest control-center; do
cat << EOF > /etc/systemd/system/confluent-$i.service.d/override.conf
[Service]
Environment="CONFLUENT_SECURITY_MASTER_KEY=$CONFLUENT_SECURITY_MASTER_KEY"
EOF
done

systemctl daemon-reload




# Create keypair for token service

echo "
Creating keypair for token authorization service with proper permissions
"

if [[ ! -f $SOURCE_DIR/security/token/tokenKeypair.pem ]]
then
    mkdir -p $SOURCE_DIR/security/token
    rm -rf $SOURCE_DIR/security/token/*
    openssl genrsa -out $SOURCE_DIR/security/token/tokenKeypair.pem 2048
    openssl rsa -in $SOURCE_DIR/security/token/tokenKeypair.pem \
        -outform PEM -pubout -out $SOURCE_DIR/security/token/public.pem

    chown cp-kafka:confluent $SOURCE_DIR/security/token/public.pem
    chown cp-kafka:confluent $SOURCE_DIR/security/token/tokenKeypair.pem 
    chmod 400 $SOURCE_DIR/security/token/tokenKeypair.pem
fi



echo "
Complete!
"

# Manual prerequisite steps needed after running this script:
## 1. Create ldap server in Apache Directory Studio
### a. Click New Server
### b. Select ApacheDS 2.0.0
### c. Assign a Name of "Directory Service"
### d. Click Finish
## 2. Right-click the server and select Open Configuration
### a. Select the LDAP/LDAPS tab, expand SSL/Start TLS Keystore, and complete the fields
#### 1) Keystore: /home/training/ldap/security/tls/directory-service/directory-service.keystore.p12
#### 2) Password: confluent
### b. Select the Partitions tab
#### 1) Click Add
#### 2) Set Partition Type to JDBM
#### 3) Set ID to confluent
#### 4) Set Suffix to dc=confluent,dc=io
### c. Click File > Save
## 3. Start the ldap server
### a. Click the Directory Service server
### b. Click the green start button
## 5. Create a new connection and start it
### a. Right-click the Directory Service server and select Create a new connection
### b. Click the Connections tab
### c. Click the Directory Service connection and click Rename Connection
### d. Enter "ldaps (LDAPS)" and click OK
### e. Click the ldaps (LDAPS) connection and click Open Connection
## 6. In the LDAP Browser pane, right-click the confluent partition and click Import > LDIF Import
## 7. Click Browse, navigate to and select ~/ldap/confluent.ldif, and click Open
## 8. Click Finish

# Encrypt Secrets
## 1. Execute script "encrypt-secrets.sh":  sudo /home/training/ldap/scripts/encrypt-secrets.sh

# Close everything
## 1. sudo systemctl stop confluent-server.service
## 2. sudo systemctl stop confluent-zookeeper.service
## 3. Click the red square to stop the Directory Service server