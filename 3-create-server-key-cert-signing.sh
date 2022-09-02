openssl req -new \
    -newkey rsa:2048 \
    -keyout kafka-3.key \
    -out kafka-3.csr \
    -config ca.cfg \
    -nodes