#!/bin/bash

if [ `id -u` -ne 0 ]; then
  echo "  Run with SUDO."
  exit 1;
fi

## Install iptables. Disable firewalld.
yum install -y iptables-services && \
systemctl stop firewalld && \
systemctl mask firewalld && \
systemctl enable iptables && \
systemctl start iptables && \


## TODO: Change Firewalld backend to Iptables instead of disabling.
# sed -i s/^FirewallBackend=nftables$/FirewallBackend=iptables/ /etc/firewalld/firewalld.conf && \
# firewall-cmd --permanent --zone=trusted --change-interface=docker0 && \
# firewall-cmd --reload && \
# systemctl restart firewalld && \

## Install Docker
yum -y install \
        yum-utils \
        git \
        python3 \
        epel-release && \

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo && \

yum -y --nobest install \
            ansible \
            docker-ce \
            docker-ce-cli \
            containerd.io && \

systemctl start docker && \
systemctl enable docker && \


## Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
chmod +x /usr/local/bin/docker-compose && \

## Install Docker Compose module for Python 3
pip3 install \
        requests \
        docker \
        docker-compose && \

## Clone AWX Repo and install
sudo -u $SUDO_USER git clone https://github.com/ansible/awx && \

## Initialize passwords/secrets
# NOTE: Kubernetes requires postgres password to be 10 digit alphanumeric string
postgres_pw=$(openssl rand -base64 30 | tr -dc '[:alnum:]' | fold -w10 | head -n1) && \
admin_pw=$(openssl rand -base64 30 | tr -dc '[:alnum:]' | fold -w16 | head -n1) && \
secret=$(openssl rand -base64 100 | tr -dc '[:alnum:]' | fold -w30 | head -n1) && \

sudo -u $SUDO_USER sed -i "s/^pg_password=.*$/pg_password=$postgres_pw/" ./awx/installer/inventory && \
sudo -u $SUDO_USER sed -i "s/^admin_password=.*$/admin_password=$admin_pw/" ./awx/installer/inventory && \

## Only replace secret key if default values are in place.
## This value must persist across reinstalls!
sudo -u $SUDO_USER sed -i "s/^secret_key=awxsecret$/secret_key=$secret/" ./awx/installer/inventory && \

## Add current user to docker group
usermod -aG docker $SUDO_USER && \

## User must log-out because "docker" group addition doesn't take effect until after.
## TODO: Run playbook as user without requiring log out/in.
if [ $? -eq 0 ]; then
        echo ""
        echo "  Log out, then log in again, then run (as user):"
        echo "    DOCKER_API_VERSION=1.39 ansible-playbook -i ~/awx/installer/inventory ~/awx/installer/install.yml"

        ## TODO: Figure out why this is necessary!
        echo "  Then:"
        echo "    docker-compose -f ~/.awx/awxcompose/docker-compose.yml restart"
        echo ""
        echo "  Keep the inventory file!! It contains secrets that must persist across reinstalls to"
        echo "  avoid losing encrypted data."
        echo ""
        echo "  The credentials to log into the web interface will be:"
        echo "    Username: $(grep -oP "(?<=^admin_user=).+$" ./awx/installer/inventory)"
        echo "    Password: $(grep -oP "(?<=^admin_password=).+$" ./awx/installer/inventory)"
        echo ""

fi
