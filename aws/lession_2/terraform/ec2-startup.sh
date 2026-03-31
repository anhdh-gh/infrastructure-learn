# Cập nhật hệ thống
sudo yum update -y

# Cài Docker
sudo amazon-linux-extras install docker -y

# Khởi động Docker
sudo systemctl start docker
sudo systemctl enable docker

# Đợi Docker sẵn sàng
sleep 10

# Thêm user ec2-user vào group docker
sudo usermod -aG docker ec2-user

# Kéo Docker image
sudo docker pull anhdhdocker/java-springboot-service:latest

# Xóa container cũ nếu có
sudo docker rm -f springboot-app || true

# Chạy container mới
sudo docker run -d \
  --name springboot-app \
  -p 8080:8080 \
  anhdhdocker/java-springboot-service:latest

echo "Ứng dụng đang chạy trên cổng 8080"