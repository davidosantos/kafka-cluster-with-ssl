openssl x509 -req \
    -days 365 \
    -in kafka-3.csr \
    -CA ca.crt \
    -CAkey ca.key \
    -CAcreateserial \
    -out kafka-3.crt \
    -extfile kafka-3.cfg \
    -extensions v3_req