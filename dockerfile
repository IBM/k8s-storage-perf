FROM registry.access.redhat.com/ubi8/ubi-minimal
FROM quay.io/operator-framework/ansible-operator:v1.17.0

LABEL name="k8s-storage-perf" \
      maintainer="Nathan Brophy <nathan.brophy@ibm.com>" \
      vendor="IBM" \
      version="v1.0.0" \
      release="Version 1.0.0 containerized packaging for the K8s sotrage performance ansible playbooks" \
      summary="This is a containerized version of the k8s-storage-perf ansible playbooks" \
      description="This image contains the ansible playbooks for running the storage test execution suite"

USER 0

ENV USER_UID=1001
ENV ANSIBLE_PYTHON_INTERPRETER /usr/local/bin/python
ENV PATH ${PATH}:${HOME}/bin

RUN mkdir /licenses
COPY LICENSE /licenses

COPY . ${HOME}
COPY cleanup.sh /usr/local/bin/cleanup.sh
COPY roles/* ${HOME}/roles/

RUN ln -fs ${HOME}/bin/entrypoint /usr/local/bin/entrypoint

# In order for the 'module/action 'community.kubernetes.k8s_log' to
# be resolved, we must pin to a minimum version of teh ansible runtime.
#
# We build from the uib8-minimal and ansible controller base layers
# to setup the required filesystem and OS settings, and then 
# remove the ansible runtime in the controller for the version of
# ansible that supports the module/action. 
RUN python3 -m pip install --upgrade pip;  pip3 uninstall -y ansible \
    && rm -rf /usr/local/lib/python3.8/site-packages/ansible* \
    && rm -f /usr/local/bin/ansible* \
    && pip3 install ansible-base~=2.10  \
    && pip3 install openshift && pip3 install Jinja2 && pip3 install yasha && pip3 install argparse \
    && ln -s /usr/bin/python3 /usr/local/bin/python \
    && pip3 install "oauthlib>=3.2.0" \
    && ansible-galaxy collection install operator_sdk.util \
    && ansible-galaxy collection install community.kubernetes  \
    && curl -sL https://github.com/openshift/okd/releases/download/4.8.0-0.okd-2021-11-14-052418/openshift-client-linux-4.8.0-0.okd-2021-11-14-052418.tar.gz | tar xvz --directory /usr/local/bin/. \
    && chown -R ${USER_UID}:0 ${HOME} && chmod -R ug+rwx ${HOME}

USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/entrypoint"]

