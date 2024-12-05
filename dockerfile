ARG architecture
FROM --platform=linux/${architecture} cp.stg.icr.io/cp/cpd/ansible-operator-base:latest

LABEL name="k8s-storage-perf" \
      maintainer="IBM" \
      vendor="IBM" \
      version="CP4D_VERSION" \
      release="Containerized packaging for the K8s storage performance ansible playbooks" \
      summary="This is a containerized version of the k8s-storage-perf ansible playbooks" \
      description="This image contains the ansible playbooks for running the storage test execution suite"

ARG architecture

USER 0

ENV HOME=/opt/ansible \
    USER_NAME=ansible \
    USER_UID=1001

RUN echo "${USER_NAME}:x:${USER_UID}:0:${USER_NAME} user:${HOME}:/sbin/nologin" >> /etc/passwd \
    && mkdir -p ${HOME}/.ansible/tmp \
    && chown -R ${USER_UID}:0 ${HOME} \
    && chmod -R ug+rwx ${HOME}
  
ENV ANSIBLE_PYTHON_INTERPRETER /usr/local/bin/python
ENV PATH ${PATH}:${HOME}/bin
ENV ARCHITECTURE=${architecture}

RUN mkdir -p /licenses
COPY --chown=${USER_UID}:0 LICENSE /licenses

COPY bin ${HOME}/bin
COPY roles ${HOME}/roles
COPY *.yml LICENSE *.py *.sh ${HOME}
COPY cleanup.sh /usr/local/bin/cleanup.sh

RUN mkdir /tmp/data
COPY roles/storage-perf-test/files/sysbench.py /tmp/
RUN ln -fs ${HOME}/bin/entrypoint /usr/local/bin/entrypoint \
    && ln -s /usr/bin/python3 /usr/local/bin/python

# EPEL8 has sysbench for: x86_64, s390x, ppc64le
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# reinstall pip for additional packages, from: https://github.ibm.com/PrivateCloud-analytics/shared-images-and-tools/blob/main/README.md
RUN microdnf install -y --nodocs python3.11-setuptools-wheel python3.11-pip-wheel tar gzip sysbench openssl \
    && export PIP_NO_CACHE_DIR=1 PIP_ROOT_USER_ACTION=ignore \
    && python3 -m ensurepip \
    && python3 -m pip install --upgrade pip setuptools \
    && python3 -m pip install openshift Jinja2 yasha argparse oauthlib \
    && python3 -m pip uninstall -y pip setuptools \
    && rpm --erase --nodeps python3.11-setuptools-wheel python3.11-pip-wheel \
    && microdnf clean all && rm -rf /var/cache/* /var/log/dnf* /var/log/yum.* /usr/share/zoneinfo

RUN curl -sL http://icpfs1.svl.ibm.com/zen/rebuild-binaries/oc/latest/${ARCHITECTURE}/go-latest/oc.tgz | tar xvz --directory /usr/local/bin/. \
    && chown -R ${USER_UID}:0 ${HOME} && chmod -R ug+rwx ${HOME}

WORKDIR ${HOME}
USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/entrypoint"]