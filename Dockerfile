# FILE:  Dockerfile
#
# DESCR: Creates Alluxio Enterprise 3.x image 
#
# USAGE: docker build -t myalluxio/alluxio-enterprise:3.2.0-beta . 2>&1 | tee  ./build-log.txt
#    OR: docker build --no-cache -t myalluxio/alluxio-enterprise:3.2.0-beta . 2>&1 | tee  ./build-log.txt
#

FROM centos:centos8
MAINTAINER gregpalmr

USER root

# Password to use for various users, including root user
ENV NON_ROOT_PASSWORD=changeme123

# Copy the local Alluxio installer tarball into the container 
RUN mkdir /tmp/local-files
COPY README.md local-files* /tmp/local-files/

# Setup yum repo mirror list
RUN sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# Install required packages (including openjdk 11)
RUN yum clean all; \
    rpm --rebuilddb; \
    yum install -y curl which tar sudo sed \ 
        net-tools vim rsyslog unzip initscripts \
        openssh-clients java-11-openjdk

# update libselinux. see https://github.com/sequenceiq/hadoop-docker/issues/14
RUN yum update -y libselinux

RUN echo 'alias ll="ls -alF"' >> /root/.bashrc

# Setup passwordless ssh
RUN    ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key \
    && ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key \
    && ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa \
    && /bin/cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# Create Java Environment
RUN if [ ! -d /usr/lib/jvm/jre-11-openjdk ]; then \
       echo " ERROR - Unable to create Java environment because Java directory not found at '/usr/lib/jvm/java-11-openjdk'. Skipping."; \
    else \
      java_dir=$(ls /usr/lib/jvm/ | grep java-11); \
      export JAVA_HOME=/usr/lib/jvm/${java_dir}; \
      echo "#### Java Environment ####" >> /etc/profile.d/java-env.sh; \
      echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile.d/java-env.sh; \
      echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/profile.d/java-env.sh; \
    fi 

#
# Install Alluxio Enterprise
#
# NOTE: You must first download the Alluxi Enterprise tar.gz file
#       and place it in the ./local-files directory

# Create an alluxio user (to run the Alluxio daemons)
RUN groupadd --gid 1005 alluxio \
    && useradd -d /opt/alluxio --no-create-home --password $NON_ROOT_PASSWORD --uid 1005 --gid root alluxio 

# Create an Alluxio test user
RUN groupadd --gid 1006 user1 \
    && useradd --password $NON_ROOT_PASSWORD --uid 1006 --gid user1 user1 

# Install the alluxio binaries
ARG DOCKER_ALLUXIO_HOME=/opt/alluxio
RUN export ALLUXIO_HOME=$DOCKER_ALLUXIO_HOME \
    && tar xzvf /tmp/local-files/alluxio-enterprise-*.tar.gz -C /opt \
    && rm -f /tmp/local-files/alluxio-enterprise-*.tar.gz \
    && ln -s /opt/alluxio-enterprise-* $ALLUXIO_HOME \
    && ln -s $ALLUXIO_HOME/conf /etc/alluxio \
    && echo "#### Alluxio Environment ####" >> /etc/profile.d/alluxio-env.sh \
    && echo "export ALLUXIO_HOME=/opt/alluxio" >> /etc/profile.d/alluxio-env.sh \
    && echo "export PATH=\$PATH:\$ALLUXIO_HOME/bin" >> /etc/profile.d/alluxio-env.sh 

# Install default alluxio config files
ADD config-files/alluxio/alluxio-site.properties $DOCKER_ALLUXIO_HOME/conf/alluxio-site.properties

# Change the owner of the alluxio files
RUN chown -R alluxio:root /opt/alluxio-enterprise-*

# Clean up /tmp/local-files directory
RUN rm -rf /tmp/local-files

# end of file
