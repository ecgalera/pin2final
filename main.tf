# Configuración de la VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

# Gateway de Internet
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyInternetGateway"
  }
}

# Subnet pública
resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "MySubnet"
  }
}

# Tabla de rutas pública
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "MyPublicRouteTable"
  }
}

# Asociación de la tabla de rutas a la subnet
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Grupo de seguridad para la instancia EC2
resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Puertos abiertos para los servicios
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9113
    to_port     = 9113
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Acceso SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MySecurityGroup"
  }
}

# Instancia EC2 con Docker y Docker Compose
resource "aws_instance" "my_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id              = aws_subnet.my_subnet.id

  # Script de configuración de usuario para instalar Docker y correr Docker Compose
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -aG docker ec2-user
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              cat <<EOF2 > /home/ec2-user/docker-compose.yml
              version: '3'
              services:
                nginx:
                  image: nginx:latest
                  ports:
                    - "80:80"
                  volumes:
                    - ./nginx.conf:/etc/nginx/nginx.conf
                grafana:
                  image: grafana/grafana:latest
                  ports:
                    - "3000:3000"
                prometheus:
                  image: prom/prometheus:latest
                  ports:
                    - "9090:9090"
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml
                nginx-exporter:
                  image: nginx/nginx-prometheus-exporter:latest
                  ports:
                    - "9113:9113"
                  command: ["-nginx.scrape-uri=http://localhost/stub_status"]
              EOF2
              cat <<EOF3 > /home/ec2-user/nginx.conf
              server {
                location /stub_status {
                    stub_status on;
                    access_log off;
                    allow 127.0.0.1;
                    deny all;
                }
              }
              EOF3
              cat <<EOF4 > /home/ec2-user/prometheus.yml
              global:
                scrape_interval: 15s
              scrape_configs:
                - job_name: 'nginx'
                  static_configs:
                    - targets: ['nginx-exporter:9113']
              EOF4
              docker-compose -f /home/ec2-user/docker-compose.yml up -d
              EOF

  tags = {
    Name = "MyEC2Instance"
  }
}

# Salida con la IP pública de la instancia
output "instance_ip" {
  value = aws_instance.my_instance.public_ip
}
