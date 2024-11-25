# NOTE: this dockerfile uses parts of: https://github.ibm.com/PrivateCloud-analytics/shared-images-and-tools/blob/main/scripts/build_operator_base_images/Dockerfile.operator
# and: https://github.ibm.com/PrivateCloud-analytics/shared-images-and-tools/blob/main/scripts/build_operator_base_images/setup_ansible_operator.sh

ARG architecture
FROM --platform=linux/${architecture} registry.access.redhat.com/ubi9/ubi-minimal:latest

LABEL name="k8s-storage-perf" \
      maintainer="IBM" \
      vendor="IBM" \
      version="CP4D_VERSION" \
      release="Containerized packaging for the K8s storage performance ansible playbooks" \
      summary="This is a containerized version of the k8s-storage-perf ansible playbooks" \
      description="This image contains the ansible playbooks for running the storage test execution suite"

ARG architecture

RUN mkdir -p /etc/ansible \
  && echo "localhost ansible_connection=local" > /etc/ansible/hosts \
  && echo '[defaults]' > /etc/ansible/ansible.cfg \
  && echo 'roles_path = /opt/ansible/roles' >> /etc/ansible/ansible.cfg \
  && echo 'library = /usr/share/ansible/openshift' >> /etc/ansible/ansible.cfg

ENV HOME=/opt/ansible \
    USER_NAME=ansible \
    USER_UID=1001

# Ensure directory permissions are properly set, as we will run with another user in openshift
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
RUN ln -fs ${HOME}/bin/entrypoint /usr/local/bin/entrypoint

# EPEL8 has sysbench for: x86_64, s390x, ppc64le
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

RUN microdnf upgrade --nodocs -y \
    && microdnf install --nodocs --setopt=install_weak_deps=0 -y python3.11 tar gzip sysbench openssl \
    && ln -sv $(type -p python3.11) /usr/bin/python3 \
    && ln -s /usr/bin/python3 /usr/local/bin/python \ 
    && export PIP_NO_CACHE_DIR=1 PIP_ROOT_USER_ACTION=ignore \
    && python3 -m ensurepip \
    && pip3 install --upgrade pip setuptools openshift Jinja2 yasha argparse oauthlib \
    && pip3 install --prefer-binary ansible-core~=2.17.4 ansible-runner-http~=1.0.0 ansible-runner~=2.3.3 kubernetes==28.1.0 urllib3~=1.26.19

# CVE-2024-35195 fix in requests 2.32.x breaks ansible-runner: "requests.exceptions.InvalidURL: Not supported URL scheme http+unix"
# - this stems from https://github.com/ansible/ansible-runner-http/blob/master/ansible_runner_http/events.py#L10
# - ansible-runner-http has been archived in May 2024 after 6 years of inactivity: https://github.com/ansible/ansible-runner-http
# - the method called by ansible-runner-http is from https://github.com/msabramo/requests-unixsocket which has been last updated 3 years ago
# - there is a maintained fork of requests-unixsocket on GitLab which has a fix: https://gitlab.com/thelabnyc/requests-unixsocket2/-/merge_requests/2/diffs
# => monkey patch requests-unixsocket which is installed as a dependency of ansible-runner-http until a true fix is available in upstream ansible-operator-plugins
#    tracked through https://github.com/operator-framework/ansible-operator-plugins/issues/86
# check upstream requests version: docker run --rm -it --entrypoint pip quay.io/operator-framework/ansible-operator:v1.35.0 list | grep requests
ENV site_packages=/usr/local/lib/python3.11/site-packages
RUN sed -i -e '/def get_connection/i\    def get_connection_with_tls_context(self, request, verify, proxies=None, cert=None):\n        return self.get_connection(request.url, proxies)\n' \
    ${site_packages}/requests_unixsocket/adapters.py

# install ansible galaxy packages
RUN ansible-galaxy collection install --no-cache -r ${HOME}/requirements.yml

# clean problematic items (i.e for example all tests) to keep scans happy
ENV ansible_collections=${HOME}/.ansible/collections
RUN rm -rf ${ansible_collections}/ansible_collections/*/*/tests && rm -rf ${site_packages}/*/tests

RUN curl -sL http://icpfs1.svl.ibm.com/zen/rebuild-binaries/oc/latest/${ARCHITECTURE}/go-latest/oc.tgz | tar xvz --directory /usr/local/bin/. \
    && chown -R ${USER_UID}:0 ${HOME} && chmod -R ug+rwx ${HOME}

# double check all is right && remove pip && remove wheel system packages -- they are a hard dependency of 'ensurepip' (and maybe others)
RUN pip3 check && python3 -m pip uninstall -y pip setuptools && rpm --erase --nodeps python3.11-setuptools-wheel python3.11-pip-wheel

# clean cache to save image space
RUN microdnf clean all && rm -rf /var/cache/* /var/log/dnf* /var/log/yum.* /usr/share/zoneinfo

WORKDIR ${HOME}
USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/entrypoint"]
