openssl pkcs12 -export \
    -in kafka-server.crt \
    -inkey kafka-server.key \
    -chain \
    -CAfile ca.pem \
    -name kafka-server \
    -out kafka-server.p12 \
    -password pass:test1234