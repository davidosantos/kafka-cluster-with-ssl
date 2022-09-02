openssl req -new \
    -newkey rsa:2048 \
    -keyout kafka-server.key \
    -out kafka-server.csr \
    -config kafka-server.cfg \
    -nodes