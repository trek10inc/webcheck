FROM alpine:latest

USER root
WORKDIR /

RUN apk update && \
    apk add bash && \
    apk add curl && \
    apk add jq && \
    rm -rf /var/cache/apk/*

COPY run.sh /tmp

RUN chmod 0755 /tmp/run.sh

# what do?
CMD [ "/tmp/run.sh" ]
