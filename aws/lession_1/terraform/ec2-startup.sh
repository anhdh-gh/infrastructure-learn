# Cập nhật hệ thống
sudo yum update -y

# Cài Docker
sudo amazon-linux-extras install docker -y

# Khởi động Docker
sudo systemctl start docker
sudo systemctl enable docker

# Thêm user ec2 vào group docker để chạy docker không cần sudo
sudo usermod -aG docker ec2-user
newgrp docker

# Kéo Docker image public
docker pull anhdhdocker/java-springboot-service:latest

# Xoá container cũ nếu có
docker rm -f springboot-app || true

# Chạy container mới
docker run -d --name springboot-app -p 8080:8080 anhdhdocker/java-springboot-service:latest

echo "✅ Ứng dụng đang chạy trên cổng 8080"