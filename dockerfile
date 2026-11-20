
FROM quay.io/operator-framework/ansible-operator:v1.42.3

ARG version
ARG architecture


LABEL name="k8s-storage-perf" \
      maintainer="IBM" \
      vendor="IBM" \
      version="${version}" \
      release="Containerized packaging for the K8s storage performance ansible playbooks" \
      summary="This is a containerized version of the k8s-storage-perf ansible playbooks" \
      description="This image contains the ansible playbooks for running the storage test execution suite"

USER 0

# Update all installed packages to get latest security patches
RUN microdnf update -y && microdnf clean all

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
ENV ANSIBLE_LOCAL_TEMP=/opt/ansible/.ansible/tmp
ENV ANSIBLE_REMOTE_TEMP=/opt/ansible/.ansible/tmp
ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections:~/.ansible/collections

RUN mkdir -p /licenses
COPY --chown=${USER_UID}:0 LICENSE /licenses

COPY bin ${HOME}/bin
COPY roles ${HOME}/roles
COPY *.yml LICENSE *.py *.sh ${HOME}
COPY cleanup.sh /usr/local/bin/cleanup.sh

RUN mkdir /tmp/data
COPY roles/storage-perf-test/files/sysbench.py /tmp/
RUN ln -fs ${HOME}/bin/entrypoint /usr/local/bin/entrypoint

RUN python3 -m pip install --no-cache-dir --upgrade pip \
  && pip3 install --no-cache-dir openshift Jinja2 yasha argparse oauthlib \
  && ln -s /usr/bin/python3 /usr/local/bin/python \
  && ansible-galaxy collection install operator_sdk.util \
  && ansible-galaxy collection install kubernetes.core \
  && curl -sL https://github.com/okd-project/okd/releases/download/5.0.0-okd-scos.8/openshift-client-linux-5.0.0-okd-scos.8.tar.gz | tar xvz --directory /usr/local/bin/. \
  && chown -R ${USER_UID}:0 ${HOME} && chmod -R ug+rwx ${HOME}

WORKDIR ${HOME}
USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/entrypoint"]