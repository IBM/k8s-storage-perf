import shutil, os.path, re, sys, subprocess, csv
from datetime import datetime, timezone

def getSysbenchVersion():
    """Get sysbench version information"""
    try:
        version_cmd = ["sysbench", "--version"]
        result = subprocess.run(version_cmd, capture_output=True, text=True)
        version_output = result.stdout.strip() if result.stdout else result.stderr.strip()
        # Extract just the version number (e.g., "1.0.20" from "sysbench 1.0.20")
        version = version_output.split()[-1] if version_output else "unknown"
        return version
    except Exception as e:
        return "unknown"

def printSysbenchVersion():
    """Print sysbench version information"""
    version = getSysbenchVersion()
    print(f"Sysbench Version: {version}")
    print("-" * 80)

def runSysbench(threads, fileTotalSize, fileTestMode, fileBlockSize, fileIoMode, fileFsyncFreq, fileExtraFlags):
    # Change to writable directory for sysbench temp files (readOnlyRootFilesystem compatibility)
    # /tmp/work is created in Dockerfile and mounted as emptyDir volume in pod
    work_dir = '/tmp/work'
    # Defensive check: ensure directory exists (should already exist from Dockerfile + volume mount)
    if not os.path.exists(work_dir):
        os.makedirs(work_dir, exist_ok=True)
    os.chdir(work_dir)
    
    prepare = ["sysbench", "--threads="+threads, "--file-num="+fileNum, "--test=fileio", "--file-total-size="+fileTotalSize, "--file-test-mode="+fileTestMode, "--file-block-size="+fileBlockSize, "--file-io-mode="+fileIoMode, "--file-fsync-freq="+fileFsyncFreq, "prepare"]
    runtest = ["sysbench", "--threads="+threads, "--file-num="+fileNum, "--test=fileio", "--file-total-size="+fileTotalSize, "--file-test-mode="+fileTestMode, "--file-block-size="+fileBlockSize, "--file-extra-flags="+fileExtraFlags, "run"]
    cleanup = ["sysbench", "--threads="+threads, "--file-num="+fileNum, "--test=fileio", "--file-total-size="+fileTotalSize, "--file-test-mode="+fileTestMode, "--file-block-size="+fileBlockSize, "--file-io-mode="+fileIoMode, "--file-fsync-freq="+fileFsyncFreq, "cleanup"]
    p1 = subprocess.Popen(prepare, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).wait()
    p2 = subprocess.Popen(runtest, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    out, err = p2.communicate()
    if err is None:
        return out.decode("utf-8")
    print(err)
    p3 = subprocess.Popen(cleanup, stdout=subprocess.PIPE).wait()
    return None

def getAvg(subDict):
    if subDict and len(subDict.values()) > 0:
        # Filter out non-numeric values (empty strings, None, etc.)
        numeric_values = [v for v in subDict.values() if isinstance(v, (int, float)) and v != '']
        if numeric_values:
            return round(sum(numeric_values) * 1.0 / len(numeric_values), 1)
    return 0

def computeAvgs(data, threads):
    dict_data = [
        {'Environment': data['environment'], 'Cluster Name': data['cluster_name'], 'Storage Type': data['storage_type'], 'PVC': data['pvc'], 'Test Name': data['test_name'], 'Thread Count': data['thread_count'],
        'Test Start Time': data['start_time'], 'Test End Time': data['end_time'], 'Sysbench Version': data['sysbench_version'],
        'Reads/s': getAvg(data['throughput_read']),
        'Writes/s': getAvg(data['throughput_write']), 'read MiB/s': getAvg(data['file_ops_read']), 'write MiB/s': getAvg(data['file_ops_write']), 'Total Time': getAvg(data['total_time']),
        'Latency Min': getAvg(data['latency_min']), 'Latency Avg': getAvg(data['latency_avg']), 'Latency Max': getAvg(data['latency_max']), 'Latency 95th': getAvg(data['latency_95th'])},
    ]
    return(dict_data)

def extractValue(text):
    if text:
        text = text[0].strip()
        values = text.split(' ')
        value = values[len(values)-1]
        if value[-1] == 's':
            value = value[:-1]
        try:
            return round(float(value), 1)
        except (ValueError, TypeError):
            return 0
    return 0

def runtest(numOfTests, thread, fileTotalSize, fileNum, fileTestMode, fbs, fileIoMode, fileFsyncFreq, fileExtraFlags, environment, clusterName, storageType, pvc):
    data={}
    keys=['throughput_read', 'throughput_write', 'file_ops_read', 'file_ops_write', 'total_time', 'latency_min', 'latency_avg', 'latency_max', 'latency_95th']
    for key in keys:
        data[key] = {}
    
    # Get sysbench version
    sysbench_version = getSysbenchVersion()
    
    # Capture test start time
    start_time = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    
    for i in range(numOfTests):
        result = runSysbench(thread, fileTotalSize, fileTestMode, fbs, fileIoMode, fileFsyncFreq, fileExtraFlags)
        if result is None:
            print(f"Test {i+1} failed, skipping...")
            continue
        
        data['throughput_read'][i] = extractValue(re.findall(r".*reads/s.*\n", result, re.MULTILINE))
        data['throughput_write'][i] = extractValue(re.findall(r".*writes/s.*\n", result, re.MULTILINE))
        data['file_ops_read'][i] = extractValue(re.findall(r".*read, MiB/s.*\n", result, re.MULTILINE))
        data['file_ops_write'][i] = extractValue(re.findall(r".*written, MiB/s.*\n", result, re.MULTILINE))
        data['total_time'][i] = extractValue(re.findall(r".*total time.*\n", result, re.MULTILINE))
        data['latency_min'][i] = extractValue(re.findall(r".*min.*\n", result, re.MULTILINE))
        data['latency_avg'][i] = extractValue(re.findall(r".*avg.*\n", result, re.MULTILINE))
        data['latency_max'][i] = extractValue(re.findall(r".*max.*\n", result, re.MULTILINE))
        data['latency_95th'][i] = extractValue(re.findall(r".*95th.*\n", result, re.MULTILINE))
    
    # Capture test end time
    end_time = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    
    data['thread_count'] = thread
    data['test_name'] = fileTestMode+"_"+fbs+"_"+thread
    data['environment'] = environment
    data['cluster_name'] = clusterName
    data['storage_type'] = storageType
    data['pvc'] = pvc
    data['start_time'] = start_time
    data['end_time'] = end_time
    data['sysbench_version'] = sysbench_version
    
    return computeAvgs(data, thread)

if __name__ == "__main__":
    thread = sys.argv[1]
    fileTotalSize = sys.argv[2]
    fileNum = sys.argv[3]
    fileTestMode = sys.argv[4]
    fbs = sys.argv[5]
    fileIoMode = sys.argv[6]
    fileFsyncFreq = sys.argv[7]
    fileExtraFlags = sys.argv[8]
    environment = sys.argv[9]
    clusterName = sys.argv[10]
    storageType = sys.argv[11]
    pvc = sys.argv[12]
    
    numOfTests = 3
    
    # Print sysbench version at the start of the test
    printSysbenchVersion()
    
    result = runtest(numOfTests, thread, fileTotalSize, fileNum, fileTestMode, fbs, fileIoMode, fileFsyncFreq, fileExtraFlags, environment, clusterName, storageType, pvc)
    print(result)
