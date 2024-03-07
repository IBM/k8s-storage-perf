FROM quay.io/operator-framework/ansible-operator:v1.31.0

LABEL name="k8s-storage-perf" \
      maintainer="IBM" \
      vendor="IBM" \
      version="CP4D_VERSION" \
      release="Containerized packaging for the K8s storage performance ansible playbooks" \
      summary="This is a containerized version of the k8s-storage-perf ansible playbooks" \
      description="This image contains the ansible playbooks for running the storage test execution suite"

USER 0

ENV USER_UID=1001
ENV ANSIBLE_PYTHON_INTERPRETER /usr/local/bin/python
ENV PATH ${PATH}:${HOME}/bin

RUN mkdir /licenses
COPY LICENSE /licenses

COPY bin ${HOME}/bin
COPY roles ${HOME}/roles
COPY paramFiles ${HOME}
COPY LICENSE ${HOME}
COPY scripts ${HOME}
COPY scripts/cleanup.sh /usr/local/bin/cleanup.sh

RUN ln -fs ${HOME}/bin/entrypoint /usr/local/bin/entrypoint

RUN python3 -m pip install --no-cache-dir --upgrade pip \
  && pip3 install --no-cache-dir openshift Jinja2 yasha argparse oauthlib \
  && ln -s /usr/bin/python3 /usr/local/bin/python \
  && ansible-galaxy collection install operator_sdk.util \
  && ansible-galaxy collection install kubernetes.core \
  && curl -sL https://github.com/okd-project/okd/releases/download/4.13.0-0.okd-2023-09-03-082426/openshift-client-linux-4.13.0-0.okd-2023-09-03-082426.tar.gz | tar xvz --directory /usr/local/bin/. \
  && chown -R ${USER_UID}:0 ${HOME} && chmod -R ug+rwx ${HOME}

USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/entrypoint"]