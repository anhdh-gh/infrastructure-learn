FROM eclipse-temurin:21-jre

# Đặt thư mục làm việc trong container
WORKDIR /opt/app

# Copy file vao file container
ARG JAVA_FILE=target/java-springboot-service-0.0.1-SNAPSHOT.jar

# Copy to container
COPY ${JAVA_FILE} app.jar

# Run
ENTRYPOINT ["java", "-jar", "app.jar"]