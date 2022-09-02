sudo keytool -importkeystore \
    -deststorepass test1234 \
    -destkeystore kafka.server.keystore.pkcs12 \
    -srckeystore kafka-3.p12 \
    -deststoretype PKCS12  \
    -srcstoretype PKCS12 \
    -noprompt \
    -srcstorepass test1234