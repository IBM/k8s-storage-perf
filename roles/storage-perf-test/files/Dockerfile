FROM registry.access.redhat.com/ubi8-minimal:latest

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN microdnf install -y sysbench python3
RUN mkdir /tmp/data

WORKDIR /tmp/data

COPY ./sysbench.py /tmp/

CMD ["/bin/bash","-c","sleep 3600"]
