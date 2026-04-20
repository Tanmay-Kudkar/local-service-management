FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app

COPY pom.xml ./
RUN mvn -B -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B -DskipTests clean package
RUN set -eux; JAR_PATH=$(find target -maxdepth 1 -name "*.jar" | head -n 1); cp "$JAR_PATH" target/app.jar

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

COPY --from=build /app/target/app.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]