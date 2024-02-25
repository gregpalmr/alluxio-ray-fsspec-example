# alluxio-ray-fsspec-example

### A demonstration of Alluxio Enterprise 3.x serving data using the Filesystem Spec (fsspec) for Python on a Ray cluster.

## INTRODUCTION

In the rapidly-evolving field of artificial intelligence (AI) and machine learning (ML), the efficient handling of large datasets during training is becoming more and more pivotal. Ray has emerged as a key player, enabling large-scale dataset training through effective data streaming. By breaking down large datasets into manageable chunks and dividing training jobs into smaller tasks, Ray circumvents the need for local storage of the entire dataset on each training machine. However, this innovative approach is not without its challenges.

Although Ray facilitates training with large datasets, data loading remains a significant bottleneck. The recurrent reloading of the entire dataset from remote storage for each epoch can severely hamper GPU utilization and escalate storage data transfer costs. This inefficiency calls for a more optimized approach to managing data during training.

Alluxio accelerates large-scale dataset training by smartly and efficiently leveraging unused disk capacity on GPU and adjacent CPU machines for distributed caching. This innovative approach significantly accelerates data loading performance, crucial for training on large-scale datasets, while concurrently reducing dependency and data transfer costs associated with remote storage.

Integrating Alluxio brings a suite of benefits to Ray’s data management capabilities:

- Scalability
     - Highly scalable data access and caching
- Enhanced Data Access Speed
     - Leverage high performance disk for caching
     - Optimized for high concurrent random reads for columnar format like Parquet
     - Zero-copy
- Reliability and Availability
     - No single point of failure
     - Robust remote storage access during faults
- Elastic Resource Management
     - Dynamically allocate and de-allocate caching resources as per the demands of the workload

### Ray and Alluxio Integration Internals

Ray efficiently orchestrates machine learning pipelines, integrating seamlessly with frameworks for data loading, pre-processing, and training. Alluxio serves as a high-performance data access layer, optimizing AI/ML training and inference workloads, especially when there is a need for repeated access to data stored remotely.

Ray utilizes PyArrow to load and convert data formats into Arrow format, which will be further consumed by the next stages in the Ray pipeline. PyArrow delegates storage connection issues to the fsspec framework. Alluxio functions as an intermediary caching layer between Ray and underlying storage systems like S3, Azure blob storage, and Hugging Face.

![alt Alluxio Enterprise with Ray ](images/alluxio-with-ray-diagram.png?raw=true)

This git repo provides an example environment where Alluxio Enterprise 3.x with its fsspec implementation allows Python based workloads running on Ray to access model training data much more efficiently.

NOTE: This git repo environment is for educational purposes only and should not be use for any kind of real or production deployments.

### Alluxio Enterprise fsspec implementation

Fsspec is a Python filesystem interface that well-known storage system vendors have implemented to interact with the Python ecosystem. Alluxio Enterprise 3.x also implements the fsspec access method and integrates with Ray cluster like this:

![alt Alluxio Enterprise Fsspec implementation ](images/alluxio-fsspec-diagram.png?raw=true)

#### Alluxio Fsspec Design & Limitations

The Alluxio Enterprise fsspec implementation is designed with Alluxio caching capabilities on top of an existing underlying storage fsspec. 

- All operations that are not fully supported by Alluxio (e.g. write operations) will fallback to the underlying storage fsspec implementation. 
- All operations that are failed in Alluxio will fallback to the underlying storage fsspec
- All operations that can leverage Alluxio caching capabilities will go to Alluxio (e.g. read operations)

Current limitations

- The read operations can only be guaranteed succeed
     - If the dataset is read-only and will not be changed in the underlying storage system.
     - If the dataset is fully loaded into Alluxio servers via Alluxio load operation and the dataset is not evicted.
- The fallback operations have only been fully tested against local and S3 underlying storage fsspec.

## Using this Git Repo

### Step 1. Install Prerequisites 

#### a. Install Docker desktop 

Install Docker desktop on your laptop, including the docker-compose command.

     See: https://www.docker.com/products/docker-desktop/

#### b. Install required utilities, including:

- wget or curl utility
- tar utility

#### c. (Optional) Have access to a Docker registry such as Artifactory

### Step 2. Clone this repo

Use the git command to clone this repo (or download the zip file from the github.com site).

     git clone https://github.com/gregpalmr/alluxio-ray-fsspec-example

     cd alluxio-ray-fsspec-example

### Step 3. Download the Alluxio Enterprise 3.x installation tar file

#### a. Request a trial version

Contact your Alluxio account representative at sales@alluxio.com and request a trial version of Alluxio Enterprise 3.x. Follow their instructions for downloading the installation tar file.

#### b. Copy the tar file

Put the Alluxio Enterprise 3.x installation tar file into the "local-files" directory, using the command:

     cp ~/Downloads/alluxio-enterprise-3.2.0-beta-bin-17a5dff6e9.tar.gz ./local-files/

### Step 4. Create the Alluxio configuration files

Alluxio Enterprise 3.x is designed cache data from under storage envrionments and make it available to Python based workloads via the fsspec access method. In this step you create the Alluxio configuration files.

#### a. Create the Alluxio Enterprise 3.x properties file

Alluxio uses a file to configure the deployment. Since this deployment is going to use a local MinIO instance as the persistent under store, and will use a local RAM disk as the cache medium, we will setup the Alluxio properties file using this command:

```
cat << EOF > config-files/alluxio/alluxio-site.properties
# FILE: alluxio-site.properties
#
# DESC: This is the main Alluxio Enterprise 3.x properties file and should
#       be placed in:
#          /opt/alluxio/conf/alluxio-site.properties
#

# Alluxio master node properties
alluxio.master.hostname=alluxio-master-1
alluxio.master.worker.register.lease.enabled=false
alluxio.master.scheduler.initial.wait.time=10s
alluxio.master.journal.type=NOOP

# Alluxio Dora root under-store properties
alluxio.dora.client.ufs.root=s3://minio-bucket1/
s3a.accessKeyId=minio
s3a.secretKey=minio123
alluxio.underfs.s3.endpoint=http://minio:9000
alluxio.underfs.s3.inherit.acl=false
alluxio.underfs.s3.disable.dns.buckets=true

alluxio.dora.client.read.location.policy.enabled=true
alluxio.underfs.io.threads=50

# Alluxio worker node properties
alluxio.worker.hostname=localhost
alluxio.worker.membership.manager.type=ETCD
alluxio.etcd.endpoints=http://etcd:2379

# Alluxio worker node cache properties
alluxio.worker.block.store.type=PAGE
alluxio.worker.page.store.type=LOCAL
alluxio.worker.page.store.sizes=1.5GB
alluxio.worker.page.store.dirs=/dev/shm/alluxio_page_cache
alluxio.worker.page.store.page.size=1MB

# Alluxio user properties
alluxio.user.short.circuit.enabled=false
alluxio.user.netty.data.transmission.enabled=true
alluxio.user.consistent.hash.virtual.node.count.per.worker=5

# Alluxio Job Service properties
alluxio.job.batch.size=200

# General Alluxio properties
alluxio.network.netty.heartbeat.timeout=5min

# end of file
EOF
```

If you were going to use AWS S3 buckets as your persistent under store, you would include a section like this in the properties file:

     # Alluxio under file system setup (AWS S3)
     #
     s3a.accessKeyId=<PUT_YOUR_AWS_ACCESS_KEY_ID_HERE>
     s3a.secretKey=<PUT_YOUR_AWS_SECRET_KEY_HERE>
     alluxio.underfs.s3.region=<PUT_YOUR_AWS_REGION_HERE> # Example: us-east-1  

If you were to change where Alluxio stores cache files, you would replace the "Worker node cache properties" section of the properties file like this example, where there are two NVMe volumes of different sizes available:

     # Alluxio worker node cache properties
     alluxio.worker.block.store.type=PAGE
     alluxio.worker.page.store.type=LOCAL
     alluxio.worker.page.store.sizes=1024GB,3096GB
     alluxio.worker.page.store.dirs=/mnt/nvme0/alluxio_cache,/mnt/nvme1/alluxio_cache
     alluxio.worker.page.store.page.size=1MB

#### b. Create the Alluxio metrics configuration file

Alluxio can generate metrics using several different methods including Prometheus formatted metrics. Create a metrics.properties file to enable Alluxio to generate Prometheus metrics using the command:

```
cat <<EOF > config-files/alluxio/metrics.properties
#
# FILE:    metrics.properties
#
# DESC:    This properties file enables the Alluxio to generate metrics.
#          It should be placed in:
#               /opt/alluxio/conf/metrics.properties

# Enable the Alluxio Prometheus Sink
sink.prometheus.class=alluxio.metrics.sink.PrometheusMetricsServlet

EOF
```

### Step 5. Build a custom Alluxio Enterprise 3.x docker image

Alluxio Enterprise can run with multiple masters and with multiple workers. In this non-production implementation, we will only have a single master node and a single worker node.

#### a. Create the Dockerfile build spec file

To build a new Docker image file, the Docker build utility requires a specification file named "Dockerfile".  Create this file and include the steps needed to copy the Alluxio Enterprise installation files and configuration files into the Docker image. For this deployment, create the Dockerfile with these commands:

```
cat <<EOF > Dockerfile
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
# NOTE: You must first download the Alluxio Enterprise tar.gz file
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

EOF
```

#### b. Build the Docker image

Build the Docker image using the "docker build" command:

     docker build -t myalluxio/alluxio-enterprise:3.2.0-beta . 2>&1 | tee  ./build-log.txt

#### c. (Optional) Upload image to a Docker image registry

If you intend to deploy Alluxio Enterprise 3.x on a Kubernetes cluster, then you will have to upload the Docker image to a repository that can respond to a "docker pull" request. Usually the repository is hosted inside of your network firewall with products such as Artifactory, JFrog or a self hosted Docker registry.

If you are using DockerHub as your docker registry, Use the "docker push" command to upload the image, like this:

    docker login --username=<PUT_YOUR_DOCKER_HUB_USER_ID_HERE>
    
    docker tag <PUT_YOUR_NEW_IMAGE_ID_HERE> <PUT_YOUR_DOCKER_HUB_USER_ID_HERE>/alluxio-enterprise:3.2.0-beta
    
    docker push <PUT_YOUR_DOCKER_HUB_USER_ID_HERE>/alluxio-enterprise:3.2.0-beta
    
    docker pull <PUT_YOUR_DOCKER_HUB_USER_ID_HERE>/alluxio-enterprise:3.2.0-beta

### Step 6. Launch the docker containers with Docker Compose

In this simple non-prod deployment, we will be using the Docker Compose utility to launch Alluxio Enterprise 3.x with the newly built Alluxio Docker image. Later, if you intend to launch the Alluxio Enterprise Docker image on a Kubernetes cluster, then you would follow the instructions provided Alluxio here:

    https://docs.alluxio.io/ee-ai/user/stable/en/kubernetes/Install-Alluxio-On-Kubernetes.html

a. Remove any previous docker volumes that may have been used by the containers, using the command:

    docker volume prune

b. Launch the containers defined in the docker-compose.yml file using the command:

    COMPOSE_HTTP_TIMEOUT=300 docker-compose up -d

The command will create the network object and the docker volumes, then it will take some time to pull the various docker images. When it is complete, you see this output:

     $ docker-compose up -d
     Creating network "alluxio-fsspec-example_custom" with driver "bridge"
     Creating volume "alluxio-fsspec-example_alluxio-master-1-metastore-data" with local driver
     Creating volume "alluxio-fsspec-example_etcd-1-data" with local driver
     Creating volume "alluxio-fsspec-example_minio-data" with local driver
     Creating volume "alluxio-fsspec-example_etcd-data" with local driver
     Creating volume "alluxio-fsspec-example_prometheus-data" with local driver
     Creating grafana-qvn              ... done
     Creating prometheus-qvn           ... done
     Creating minio-qvn      ... done
     Creating etcd-1-qvn     ... done
     Creating minio-create-buckets-qvn ... done
     Creating alluxio-master-1-qvn     ... done
     Creating alluxio-worker-1-qvn     ... done
     
If you experience errors for not enough CPU, Memory or disk resources, use your Docker console to increase the resource allocations. You may need up to 4 CPUs, 8 GB of Memory and 200 GB of disk image space in your Docker resource settings.

### Step 7. Open two shell sessions 

Open two shell sessions - one into the alluxio-master-1-qvn Docker container and one into the alluxio-worker-1-qvn Docker container. Run the following command to launch a shell session in the master container:

    docker exec -it alluxio-master-1-qvn bash

Run the following command to launch a shell session in the worker container:

    docker exec -it alluxio-worker-1-qvn bash

### Step 8. Check the status of the Alluxio Enterprise cluster

a. In the Alluxio master alluxio-master-1-qvn shell session window, run the command to check the status of the cluster, including information about the Alluxio master and the worker. Run the command:

    alluxio info report

You should see the output that shows the status of the masters and workers. Like this:

     $ alluxio info report
     {
          "version": "enterprise-3.2.0-beta",
          "start": "2024-02-24T19:42:06Z",
          "rpcPort": 19998,
          "webPort": 19999,
          "masterAddress": "alluxio-master-1:19998",
          "masterVersions": [
             {
                 "state": "PRIMARY",
                 "port": 19998,
                 "host": "alluxio-master-1",
                 "version": "enterprise-3.2.0-beta"
             }
          ],
          "safeMode": false,
          "totalCapacityOnTiers": {},
          "usedCapacityOnTiers": {},
          "uptime": "0d 00h02m54s",
          "zookeeperAddress": [],
          "useZookeeper": false,
          "raftJournalAddress": [],
          "useRaftJournal": false,
          "liveWorkers": 1,
          "lostWorkers": 0,
          "freeCapacity": "1.5G"
     }

Use the following Alluxio CLI command to list the worker nodes and status:

    alluxio info nodes

It will show a single worker node with a status of ONLINE:

    $ alluxio info nodes
    WorkerId  Address   Status
    worker-25a2f9ac-87b1-445f-880f-8688567ee153  alluxio-worker-1:29999   ONLINE

If you want to see detailed log message from the Alluxio master node, you can run the command:

    view /opt/alluxio/logs/master.log

### Step 9. Load a test data set into the Alluxio cache

For machine learning and training workloads, Alluxio Enterprise allows you to pre-load data from your training data sets into the Alluxio cache. For this non-prod example environment, a portion of the NYC taxi ride data set has been staged in the MinIO S3 bucket. View the NYC taxi ride data set using the Alluxio CLI command:

    alluxio fs ls -R /data/nyc-taxi-csv

Alluxio will show the contents of the test data set directory in the S3 bucket:

    $ alluxio fs ls -R /data/nyc-taxi-csv
    drwx------          0                 01-01-1970 00:00:00:000  DIR /data/nyc-taxi-csv/green-tripdata
    -rwx------     6912251 02-25-2024 21:22:15:742 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-01.csv
    -rwx------    10464188 02-25-2024 21:22:18:980 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-12.csv
    -rwx------     7558871 02-25-2024 21:22:15:840 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-03.csv
    -rwx------     9894572 02-25-2024 21:22:18:738 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-09.csv
    -rwx------     7980769 02-25-2024 21:22:16:203 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-05.csv
    -rwx------     7591709 02-25-2024 21:22:16:355 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-07.csv
    -rwx------    11250176 02-25-2024 21:22:18:918 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-11.csv
    -rwx------    11500622 02-25-2024 21:22:18:774 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-10.csv
    -rwx------     5835331 02-25-2024 21:22:15:845 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-02.csv
    -rwx------     7843615 02-25-2024 21:22:15:840 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-04.csv
    -rwx------     8585288 02-25-2024 21:22:16:441 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-08.csv
    -rwx------     7878004 02-25-2024 21:22:16:443 FILE /data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-06.csv

Now, load that data into the Alluxio cache using the commands:

     alluxio job load --path s3://minio-bucket1/data/nyc-taxi-csv --submit

It will show the job being submitted like this:

     $ alluxio job load --path s3://minio-bucket1/data/nyc-taxi-csv --submit
     Load 's3://minio-bucket1/data/nyc-tax-csv' is successfully submitted. 
     JobId: 722a2cc2-7b98-429f-a72d-68ea30c20cfa

Then you can monitor the progress of the batch load job with the command:

     alluxio job load --path s3://minio-bucket1/data/nyc-taxi-csv --progress

Which will show you the progress of the load job:

    $ alluxio job load --path s3://minio-bucket1/data/nyc-taxi-csv --progress
    Progress for loading path 's3://minio-bucket1/data/nyc-taxi-csv':
         Settings: bandwidth: unlimited     verify: false  metadata-only: false
         Time Elapsed: 00:00:02
         Job State: SUCCEEDED
         Inodes Scanned: 13
         Inodes Processed: 13
         Bytes Loaded: 98.51MB out of 98.51MB
         Throughput: 49.26MB/s
         File Failure rate: 0.00%
         Subtask Failure rate: 0.00%
         Files Failed: 0
         Subtask Retry rate: 0.00%
         Subtasks on Retry Dead Letter Queue: 0

### Step 10. Load data from the fsspec implementation on a Ray cluster node

For this non-prod environment, a Ray Docker container has been pre-launched and the Alluxio fsspec components have been installed using the commands:

     # Install the Alluxio Python modules for the fsspec implementation
     mkdir alluxio-fsspec-env && cd alluxio-fsspec-env
     git clone  https://github.com/Alluxio/alluxio-py.git && cd alluxio-py
     python3 setup.py bdist_wheel && pip3 install dist/alluxio-0.3-py3-none-any.whl
     pip install s3fs
     cd ..
     git clone https://github.com/fsspec/alluxiofs.git  && cd alluxiofs
     python3 setup.py bdist_wheel && pip3 install dist/alluxiofs-0.1-py3-none-any.whl
     cd $HOME
     
     # Install Ray Python modules (if not already installed)
     pip install "ray[data,train]"

You can use this pre-launch container to experiment with the ray.data.* methods as they use the Alluxio fsspec implementation and access the very small Alluxio cluster (1 worker node with 1.5GB of cache).

a. Open a shell session into the Ray container with the command:

     docker exec -it ray-qvn bash

The "-qvn" suffice is just a unique identifier.

b. Launch a Python session and run some commands to read the NYC taxi ride data that is stored in the local MinIO S3 compatible storage and cached by Alluxio. Launch a Python session:

     python

Then run some Python commands to access Alluxio via the fsspec implementation:

    import fsspec
    import ray
    from alluxiofs import AlluxioFileSystem
    
    # Register the Alluxio fsspec implementation
    fsspec.register_implementation("alluxio", AlluxioFileSystem, clobber=True)
    alluxio = fsspec.filesystem(
      "alluxio", etcd_hosts="etcd-1", target_protocol="s3"
    )
    
    # Pass the initialized Alluxio filesystem to Ray and read the NYC taxi ride data set
    ds = ray.data.read_csv("s3://minio-bucket1/data/nyc-taxi-csv/green-tripdata/green_tripdata_2021-01.csv", filesystem=alluxio)
    
    # Get a count of the number of records in the single CSV file
    ds.count()
    
    # Display the schema derived from the CSV file header record
    ds.schema()
    
    # Display the header record
    ds.take(1)
    
    # Display the first data record
    ds.take(2)
    
    # Read multiple CSV files:
    ds2 = ray.data.read_csv("s3://minio-bucket1/data/nyc-taxi-csv/green-tripdata/", filesystem=alluxio)
    
    # Get a count of the number of records in the twelve CSV files
    ds2.count()
      
    # End of Python example
    

You can view the Ray dashboard by pointing your web browser to this address:

    http://localhost:8265

### Step 11. Explore the Alluxio Enterprise 3.x Dashboard

a. Display the Prometheus Web console

Point your Web browser to the Prometheus docker container at:

     http://localhost:9090

b. Display the Grafana Web console

Point your Web browser to the Grafana docker container at:

     http://localhost:3000

When prompted, sign in with the user "admin" and the password "admin". When you see a message asking you to change the password, you can click on the "Skip" link to keep the same password.

In the upper left side of the dashboard, click on the drop down menu (just to the left of the "Home" label).

Then click on the "Dashboards" link to display the folders and dashboards and then click on the "Alluxio" folder link to view the "Alluxio AI Enterprise Edition Dashboard" dashboard. Click on the link for that dashboard to view the panels.

In the Alluxio dashboard you will see metrics around the Alluxio cluster status and the cache statistics and storage usages.

### Step 11. Destroy the docker containers and volumes

Run the following commands to destroy the Docker containers and the volumes that were created.

    docker-compose down

and

    docker volume prune

--

Please direct questions or comments to greg.palmer@alluxio.com
