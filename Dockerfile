FROM eclipse-temurin:21-jre
COPY target/*-runner.jar /app.jar
CMD ["java", "--add-opens", "java.base/java.lang=ALL-UNNAMED", "-jar", "/app.jar"]