data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "my_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id              = aws_subnet.my_subnet.id

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
                ...
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

output "instance_ip" {
  value = aws_instance.my_instance.public_ip
}
