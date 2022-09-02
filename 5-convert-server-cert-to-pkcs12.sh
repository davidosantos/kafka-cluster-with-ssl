openssl pkcs12 -export \
    -in kafka-3.crt \
    -inkey kafka-3.key \
    -chain \
    -CAfile ca.pem \
    -name kafka-3 \
    -out kafka-3.p12 \
    -password pass:test1234