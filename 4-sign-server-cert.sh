openssl x509 -req \
    -days 365 \
    -in kafka-server.csr \
    -CA ca.crt \
    -CAkey ca.key \
    -CAcreateserial \
    -out kafka-server.crt \
    -extfile kafka-server.cfg \
    -extensions v3_req