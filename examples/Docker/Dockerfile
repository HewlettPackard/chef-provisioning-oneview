# Docker file to build ChefDK with HPE OneView provisioning driver
FROM centos:latest
MAINTAINER <daniel.jam.finneran@hpe.com>

RUN curl -L https://www.opscode.com/chef/install.sh | bash -s -- -P chefdk
RUN chef gem install chef-provisioning-oneview
