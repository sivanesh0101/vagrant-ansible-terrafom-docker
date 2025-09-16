#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Speedy mirrors & apt tuning
sudo sed -i 's|http://us.archive.ubuntu.com/ubuntu|http://mirror.cse.iitk.ac.in/ubuntu|g' /etc/apt/sources.list || true
sudo tee /etc/apt/apt.conf.d/99-speed >/dev/null <<'EOF'
Acquire::Retries "5";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::ForceIPv4 "true";
Acquire::Languages "none";
APT::Install-Recommends "false";
Dpkg::Use-Pty "0";
Acquire::Queue-Mode "host";
EOF
sudo apt-get clean
sudo apt-get update -y

# Fastest: no PPA
sudo apt-get install -y ansible-core

# Optional SSH key, inventory, etc… (your existing content)

# # SSH key for Ansible ## added in docker
#sudo -u vagrant ssh-keygen -t rsa -b 2048 -N "" -f /home/vagrant/.ssh/id_rsa || true

# Create sample inventory and config
mkdir -p /home/vagrant/ansible

cat <<EOF | sudo tee /home/vagrant/ansible/inventory.ini
[runner]
localhost ansible_connection=local

[workers]
worker1 ansible_host=172.20.0.11 ansible_user=root
worker2 ansible_host=172.20.0.12 ansible_user=root

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

cat <<EOF | sudo tee /home/vagrant/ansible/ansible.cfg
[defaults]
inventory = ./inventory.ini
remote_user = root
host_key_checking = False
deprecation_warnings = False
interpreter_python = auto_silent

[privilege_escalation]
become = false

[ssh_connection]
ssh_args = -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

EOF

# Fix permissions
sudo chown -R vagrant:vagrant /home/vagrant/ansible

# Task 1 - Install Apache
cat <<EOF > /home/vagrant/ansible/install_nginx.yml
---
- name: Install nginx on workers
  hosts: workers
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
    - name: Install nginx
      apt:
        name: nginx
        state: present
    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: yes
EOF

# Task 2 - Create user
cat <<EOF >  /home/vagrant/ansible/user_add.yml
---
- name: Create DevOps user
  hosts: workers
  become: yes
  tasks:
    - name: Ensure user 'devops' exists
      user:
        name: devops
        shell: /bin/bash
        groups: sudo
        state: present
EOF

# Task 3 - Copy index.html
cat <<EOF >  /home/vagrant/ansible/copy_index.yml
---
- name: Deploy simple index.html and restart nginx
  hosts: workers
  become: yes
  tasks:
    - name: Place index.html
      copy:
        dest: /var/www/html/index.html
        content: |
          <h1>Welcome to Jeevi Academy</h1>
          <p>Deployed on {{ inventory_hostname }}</p>

    - name: Restart nginx
      service:
        name: nginx
        state: restarted
EOF

# Task 4 - Stop Apache
cat <<EOF >  /home/vagrant/ansible/stop_nginx.yml
---
- name: Stop nginx on workers
  hosts: workers
  become: yes
  tasks:
    - name: Stop nignx
      service:
        name: nginx
        state: stopped
EOF


# Playbook 5 - Health check
cat <<'EOF' > /home/vagrant/ansible/healthcheck.yml
---
- name: Check NGINX homepage
  hosts: workers
  become: yes
  tasks:
    - name: Request homepage
      uri:
        url: http://127.0.0.1/
        return_content: yes
      register: homepage
      changed_when: false

    - name: Show HTTP status
      debug:
        msg: "Status code from {{ inventory_hostname }} is {{ homepage.status }}"

    - name: Ensure status is 200 OK
      assert:
        that:
          - homepage.status == 200
        fail_msg: "Homepage is not reachable on {{ inventory_hostname }}"
        success_msg: "Homepage is up and returning 200 on {{ inventory_hostname }}"
EOF


# Task 5 - Install GitHub Runner
cat <<EOF >  /home/vagrant/ansible/install_github_runner.yml
---
- name: Install GitHub Actions Runner
  hosts: all
  become: yes

  vars:
   # github_repo: "deenamanick/vagrant-ansible-terrafom-docker"
    github_repo: "{{ lookup('env','GITHUB_REPO') }}"
    runner_version: "2.328.0"
    runner_dir: "/opt/actions-runner"
    github_pat: "{{ lookup('env','GITHUB_PAT') }}"

  tasks:
    - name: Install dependencies
      apt:
        name: [ "curl", "tar", "jq" ]
        state: present
        update_cache: yes

    - name: Create runner directory
      file:
        path: "{{ runner_dir }}"
        state: directory
        owner: vagrant
        group: vagrant
        mode: '0755'

    - name: Download GitHub Actions runner
      get_url:
        url: "https://github.com/actions/runner/releases/download/v{{ runner_version }}/actions-runner-linux-x64-{{ runner_version }}.tar.gz"
        dest: "{{ runner_dir }}/runner.tar.gz"
        mode: '0644'

    - name: Extract GitHub runner
      unarchive:
        src: "{{ runner_dir }}/runner.tar.gz"
        dest: "{{ runner_dir }}"
        remote_src: yes
        creates: "{{ runner_dir }}/config.sh"

    - name: Request registration token from GitHub API
      uri:
        url: "https://api.github.com/repos/{{ github_repo }}/actions/runners/registration-token"
        method: POST
        headers:
          Authorization: "token {{ github_pat }}"
          Accept: "application/vnd.github.v3+json"
        status_code: 201
      register: reg_token

    - name: Configure GitHub runner
      command: >
        ./config.sh --url https://github.com/{{ github_repo }}
        --token {{ reg_token.json.token }} --unattended
      args:
        chdir: "{{ runner_dir }}"
      become_user: vagrant

    - name: Install runner as service
      command: ./svc.sh install
      args:
        chdir: "{{ runner_dir }}"

    - name: Start runner service
      command: ./svc.sh start
      args:
        chdir: "{{ runner_dir }}"
EOF



