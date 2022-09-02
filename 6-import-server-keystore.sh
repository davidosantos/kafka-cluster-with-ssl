sudo keytool -importkeystore \
    -deststorepass test1234 \
    -destkeystore kafka.server.keystore.pkcs12 \
    -srckeystore kafka-server.p12 \
    -deststoretype PKCS12  \
    -srcstoretype PKCS12 \
    -noprompt \
    -srcstorepass test1234