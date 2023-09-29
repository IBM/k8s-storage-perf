# K8s Storage Performance

Ansible playbooks to collect Storage performance metrics on an OpenShift cluster.

>**Note that: to assess if a storage provider, especially for new storage, is suitable to support `ReadWriteOnce` and `ReadWriteMany` volumes for your Cloud Pak workloads, check out this project at https://github.com/IBM/k8s-storage-tests, and perform the storage readiness tests from it. It will give you a good assessment of the particular storage.**

### Prerequisites

- Ensure you have python 3.6 or later and [pip](https://pip.pypa.io/en/stable/installation/) 21.1.3 or later installed

  `python --version`

  `pip --version`

  >NB: if your python interpreter is using `python3` or `python37` or other Python 3 executables, you can create a symlink for `python` using this command

  ```
  ln -s -f /usr/bin/python3 /usr/bin/python
 
  # OR depends on the Python 3 installation location
 
  ln -s -f /usr/local/bin/python3 /usr/local/bin/python
  ```

  >NB: if `pip` is not available or is an older version, run the command below to upgrade it, and then check its version again.
  
  `python -m pip install --upgrade pip`
  
- Install Ansible 2.10.5 or later
  
  `pip install ansible==2.10.5`

- Install ansible k8s modules

  `pip install openshift`
   
  `ansible-galaxy collection install operator_sdk.util`
  
  `ansible-galaxy collection install community.kubernetes`
  
   >NB: the `openshift` package installation requires PyYAML >= 5.4.1, and if the existing PyYAML is an older version, then PyYAML's 
   installation will fail. To overcome this issue, manually delete the exsiting PyYAML package as below (adjust the paths in the commands 
   according to the your host environment):
   
   ```
   rm -rf /usr/lib64/python3.6/site-packages/yaml
   rm -f  /usr/lib64/python3.6/site-packages/PyYAML-*
   ```
  
- Install [OpenShift Client 4.6 or later](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.6.31) based on your OS. 
  
- Access to the OpenShift Cluster (at least 3 compute nodes) setup with RWX and RWO storage classes with cluster admin access.

### Setup

 - Clone this git repo to your client

   ```
     git clone https://github.com/IBM/k8s-storage-perf
   ```

 - Select the appropriate parameter yaml file for the level of data collection you would like. There are three versions of the params file
    * `params.yml` - Default. Will only run selected write tests that are considered in the CP4D Knowledge Center.
    * `params-extended-metrics.yml` - Extended writes. Will run all write tests.
    * `params-all-metrics.yml` - All tests. Will run all combinations of read and write tests.
  
 - Update the `params.yml` file with your OCP URL and Credentials
 
   ```
    ocp_url: https://<required>:6443
    ocp_username: <required>
    ocp_password: <required>
    ocp_token: <required if user/password not available>
    ocp_apikey: <required if neither user/password or token not available>
   ```
  
  >NB: update only one of the three login formats, that is, either ocp_username/ocp_password, or ocp_token, or ocp_apikey. Leave other two choices' lines intact, i.e. do NOT change the lines for the login formats that are not chosen to be used.
  
 - Update the `params.yml` file for the required storage parameters
   
      ```
      run_storage_perf: true
      arch: amd64  # amd64, ppc64le
      ```
 
      ```
      storageClass_ReadWriteOnce: <required> 
      storageClass_ReadWriteMany: <required> 
      storage_validation_namespace: <required>
      ```
    
 - Optionally, you can set/modify these label parameters to display in the final CSV report
    
      ```
      cluster_infrastructure: "self-cpd-cli managed" # optional label eg ibmcloud, aws, azure, vmware
      cluster_name: storage-performance-cluster      # optional labels
      storage_type: <storage vendor>
      ```

 - Optionally you can run the tests with a "remote mode" where the performance jobs can run on a dedicated compute node. The compute node 
      should be labelled with a defined key and value for this purpose and set in the params file. 

      ```
      dedicated_compute_node:
        label_key: "<optional>"
        label_value: "<optional>"
      ```

      To label a node, you can use this command

      ```
      oc label node <node name> "<label_key>=<label_value>" --overwrite
      ```
  
### Running the Playbook

 - From the root of this repository, run:
  
  ```bash
    ansible-playbook main.yml --extra-vars "@./params.yml" | tee output.log
  ```

  >NB: if the playbook fails to run due to SSL verification error, you can disable it by setting this environment variable before running the playbook

  ```
  export K8S_AUTH_VERIFY_SSL=no
  ```

 - Storage performance role takes about an hour to run. When completed, a `storage-perf.tar` file will be generated for storage performance with
   the following contents
   - result.csv
   - nodes.csv
   - pods.csv
   - jobs.csv
   - params.log
 
### Pulling and loading the required image in airgap environment

This storage performance test suite relies on a container image: `quay.io/ibm-cp4d-public/xsysbench:1.1` This image may not be directly accessible on an aigap cluster. To resolve this, follow the steps below to download the image onto an intermediary host and then copy the image to the airgap cluster, and finally load it into the cluster's private registry.

```
 # on an intermediary host that can access the image
 podman pull quay.io/ibm-cp4d-public/xsysbench:1.1
 podman save -o xsysbench-1.1.tar quay.io/ibm-cp4d-public/xsysbench:1.1
 
 # copy the above .tar file onto the airgap cluster
 
 # on the airgap cluster
 podman load -i xsysbench-1.1.tar
 podman tag quay.io/ibm-cp4d-public/xsysbench:1.1 <private-registry>/ibm-cp4d-public/xsysbench:1.1
 podman tag quay.io/ibm-cp4d-public/xsysbench:1.1 <private-registry>/ibm-cp4d-public/xsysbench:1.1-amd64
 
 podman login -u <uaername> -p <password> <private-registry> --tls-verify=false
 
 podman push <private-registry>/ibm-cp4d-public/xsysbench:1.1
 podman push <private-registry>/ibm-cp4d-public/xsysbench:1.1-amd64
 ```
 
Next make sure that in the "params.yml" file, you modify the `imageurl` line to below:

```
imageurl: <private-registry>/ibm-cp4d-public/xsysbench:1.1
```

Finally just follow the previous sections to run the test suites.

### Running the Playbook with the Container

#### Environment Setup

```sh
export dockerexe=podman # or docker
export container_name=k8s-storage-perf
export docker_image=icr.io/cpopen/cpd/k8s-storage-perf:v1.0.0

alias k8s_storage_perf_exec="${dockerexe} exec ${container_name}"
alias run_k8s_storage_perf="k8s_storage_perf_exec ansible-playbook main.yml --extra-vars \"@/tmp/work-dir/params.yml\" | tee output.log"
alias run_k8s_storage_perf_cleanup="k8s_storage_perf_exec cleanup.sh -n ${NAMESPACE} -d"
```

#### Start the Container

```sh
mkdir -p /tmp/k8s_storage_perf/work-dir
cp ./params.yml /tmp/k8s_storage_perf/work-dir/params.yml

${dockerexe} pull ${docker_image}
${dockerexe} run --name ${container_name} -d -v /tmp/k8s_storage_perf/work-dir:/tmp/work-dir ${docker_image}
```

#### Run the Playbook

```sh
run_k8s_storage_perf
```

Then to view the results:

```
mkdir /tmp/k8s_storage_perf/work-dir/data
${dockerexe} cp ${container_name}:/opt/ansible/storage-perf.tar /tmp/k8s_storage_perf/work-dir/data/storage-perf.tar
tar -xvf /tmp/k8s_storage_perf/work-dir/data/storage-perf.tar -C /tmp/k8s_storage_perf/work-dir/data

ls -l /tmp/k8s_storage_perf/work-dir/data
-rw-r--r-- 1 1001 root   190 Aug  2 17:18 jobs.csv
-rw-r--r-- 1 1001 root  5615 Aug  2 17:18 nodes.csv
-rw-r--r-- 1 1001 root   952 Aug  2 17:18 params.log
-rw-r--r-- 1 1001 root   484 Aug  2 17:18 pods.csv
-rw-r--r-- 1 1001 root  1453 Aug  2 17:18 result.csv
-rw-r--r-- 1 root root 20480 Aug  2 17:18 storage-perf.tar
```

#### Optional Cleanup the Cluster

```sh
run_k8s_storage_perf_cleanup

[INFO ] running clean up for namespace storage-validation-1 and the namespace will be deleted
[INFO ] please run the following command in a terminal that has access to the cluster to clean up after the ansible playbooks

oc get job -n storage-validation-1 -o name | xargs -I % -n 1 oc delete % -n storage-validation-1 && \
oc get pvc -n storage-validation-1 -o name | xargs -I % -n 1 oc delete % -n storage-validation-1 && \
oc get cm -n storage-validation-1 -o name | xargs -I % -n 1 oc delete % -n storage-validation-1 && \
oc delete ns storage-validation-1 --ignore-not-found

[INFO ] cleanup script finished with no errors
```
 
### Clean-up Resources

With each run, delete the kuberbetes namespace that you created in [Setup](#setup), you can delete the project

```
oc delete project <storage_perf_namespace>
```

OR delete the resources in the project individually

```
oc delete job $(oc get jobs -n <storage_perf_namespace> | awk '{ print $1 }') -n <storage_perf_namespace>
oc delete cm $(oc get cm -n <storage_perf_namespace> | awk '{ print $1 }') -n <storage_perf_namespace>
oc delete pvc $(oc get pvc -n <storage_perf_namespace> | awk '{ print $1 }') -n <storage_perf_namespace>
```
