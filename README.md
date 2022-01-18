# K8s Storage Performance

Ansible playbooks to collect Storage performance metrics on an OpenShift cluster.

### Prerequisites

- Ensure you have python 3.6 or later and [pip](https://pip.pypa.io/en/stable/installation/) 21.1.3 or later installed

  `python --version`

  `pip --version`

  Note: if your python interpreter is using `python3` or `python37` executable, you can create a symlink for `python` using this command

  `ln -s -f /usr/local/bin/python3 /usr/local/bin/python`

- Install Ansible 2.10.5 or later
  
  `pip install ansible==2.10.5`

- Install ansible k8s modules

  `pip install openshift`
   
  `ansible-galaxy collection install operator_sdk.util`
  
  `ansible-galaxy collection install community.kubernetes`
  
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
   ```
  
 - Update the `params.yml` file for the required storage parameters
   
      ```
      run_storage_perf: true
      arch: amd64 or ppc64le
      ```
 
      ```
      storageClass_ReadWriteOnce: <required> 
      storageClass_ReadWriteMany: <required> 
      storage_validation_namespace: <required>
      ```
    
      Optionally, you can set/modify these label parameters to display in the final CSV report
    
      ```
      cluster_infrastructure: eg, ibmcloud, aws, azure or vmware
      cluster_name: storage-performance-cluster
      storage_type: <storage vendor>
      ```

      You can run the tests with a "remote mode" where the performance jobs can run on a dedicated compute node. The compute node 
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

  If the playbook fails to run due to SSL verification error, you can disable it by setting this environment variable before running the playbook

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
