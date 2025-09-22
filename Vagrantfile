Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.hostname = "devops-lab"
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
  config.ssh.insert_key = false
  config.ssh.private_key_path = "~/.vagrant.d/insecure_private_key"

  # Sync Terraform project & app code
  config.vm.synced_folder "./terraform-docker", "/home/vagrant/terraform-docker"
  config.vm.synced_folder "./terraform-deployment", "/home/vagrant/terraform-docker/terraform-deployment"
  config.vm.synced_folder "./Iac-deployment", "/home/vagrant/Iac-deployment"

  config.vm.provision "shell", inline: <<-SHELL
  set -e
  echo "Normalizing line endings (CRLF->LF) and fixing permissions..."
  for dir in /vagrant /home/vagrant/terraform-docker /home/vagrant/Iac-deployment; do
    if [ -d "$dir" ]; then
      echo " - Cleaning $dir"
      find "$dir" -type f ! -path "*/.git/*" -exec bash -c '
        for file; do
          if file "$file" | grep -q text; then
            sed -i "s/\\r//g" "$file"
          fi
        done
      ' bash {} +
    fi
  done
  # Ensure provision scripts are executable
  if [ -d /vagrant/provision ]; then
    chmod +x /vagrant/provision/*.sh || true
  fi
  SHELL

  # Create GitHub Actions workflow file
  config.vm.provision "shell", inline: <<-SHELL
    mkdir -p /home/vagrant/.github/workflows
    chown -R vagrant:vagrant /home/vagrant/.github

    cat <<'EOF' > /home/vagrant/.github/workflows/deploy.yml
name: CI/CD for Quiz App

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: self-hosted

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Init Terraform
        working-directory: Iac-deployment
        run: terraform init

      - name: Validate Terraform
        working-directory: Iac-deployment
        run: terraform validate

      - name: Run Terraform apply
        working-directory: Iac-deployment
        run: terraform apply -auto-approve
EOF
  SHELL

config.vm.provision "ansible",  type: "shell", path: "provision/install_ansible.sh"
config.vm.provision "docker",   type: "shell", path: "provision/install_docker.sh"
config.vm.provision "terraform",type: "shell", path: "provision/install_terraform.sh"


end
