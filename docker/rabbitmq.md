~~~
version: '3'
    
services:
  rabbitmq:
    image: rabbitmq:management-alpine
    container_name: rabbitmq-server
    restart: always
    volumes:
      - ./data:/var/lib/rabbitmq
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=pass
    ports:
      - "15672:15672"
      - "5672:5672"
    network_mode: "host"
    logging:
      driver: "json-file"
      options:
        max-size: "200k"
        max-file: "10"

~~~
