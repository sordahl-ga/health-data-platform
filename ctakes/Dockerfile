FROM maven:3.5.3-jdk-8

COPY ctakes /ctakes

ENV MAVEN_OPTS=-Xmx3000m

WORKDIR /ctakes

EXPOSE 8080

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["mvn", "jetty:run"]
