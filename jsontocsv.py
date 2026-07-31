import csv, sys, json, os
from copy import deepcopy

throughput = '128'
latency = '11'

def toCsv(dict_data):
    columns = ['Cluster Name', 'PVC', 'Storage Type', 'Environment', 'Test Name', 'Thread Count', 'Test Start Time', 'Test End Time', 'write MiB/s', 'Writes/s', 'read MiB/s', 'Reads/s', 'Total Time', 'Latency Min', 'Latency Avg', 'Latency Max', 'Latency 95th', 'Sysbench Version', 'Image', 'Image Digest']
    summary = ['Summary', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
    summarycolumns = ['Cluster Name', 'PVC', 'Storage Type', 'Environment', 'Test Name', 'Thread Count', 'Test Start Time', 'Test End Time', 'write MiB/s', 'Requirement', 'Sysbench Version', 'Image Digest']
    detail = ['Detailed Measurements', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
    blank = ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
    csv_file = "result.csv"
    try:
        with open(csv_file, 'w') as csvfile:
            summarywriter = csv.DictWriter(csvfile, fieldnames=summary)
            summarywriter.writeheader()
            summarycolumnwriter = csv.DictWriter(csvfile, fieldnames=summarycolumns)
            summarycolumnwriter.writeheader()
            dict_copy = deepcopy(dict_data)
            for data in dict_copy:
                is_rndwr_8 = data['Test Name'].startswith('rndwr_') and data['Test Name'].endswith('_8')
                is_seqwr_2 = data['Test Name'].startswith('seqwr_') and data['Test Name'].endswith('_2')
                if is_rndwr_8 or is_seqwr_2:
                   minumum = throughput if is_seqwr_2 else latency
                   data['Requirement'] = 'Recommended to meet the requirement of ' + minumum + ' MiB/s or higher'
                   del data['Latency Max']
                   del data['read MiB/s']
                   del data['Total Time']
                   del data['Latency 95th']
                   del data['Writes/s']
                   del data['Reads/s']
                   del data['Latency Avg']
                   del data['Latency Min']
                   del data['Image']
                   summarycolumnwriter.writerow(data)
            blankwriter = csv.DictWriter(csvfile, fieldnames=blank)
            blankwriter.writeheader()
            blankwriter.writeheader()
            detailwriter = csv.DictWriter(csvfile, fieldnames=detail)
            detailwriter.writeheader()
            writer = csv.DictWriter(csvfile, fieldnames=columns)
            writer.writeheader()
            for data in dict_data:
                writer.writerow(data)
    except IOError:
        print("I/O error")

if __name__=='__main__':
    if len(sys.argv) < 2:
        print("Usage: python jsontocsv.py <folder_name>")
        sys.exit(1)
    folderPath = sys.argv[1]+"/"

    # Read image digest written by Ansible after each job completes.
    # The file contains just the sha256:... string (no trailing newline needed).
    digest_path = folderPath + "image_digest.txt"
    image_digest = "unknown"
    if os.path.exists(digest_path):
        with open(digest_path) as f:
            image_digest = f.read().strip() or "unknown"

    # Check if folder exists and has files (exclude image_digest.txt itself)
    walk_results = list(os.walk(folderPath))
    if not walk_results:
        print(f"Error: No log files found in {folderPath}")
        sys.exit(1)
    filenames = [f for f in walk_results[0][2] if f != "image_digest.txt"]
    if not filenames:
        print(f"Error: No log files found in {folderPath}")
        sys.exit(1)

    allData = []
    for filename in filenames:
        try:
            # Opening JSON file
            with open(folderPath+filename) as json_file:
                data = json.load(json_file)
                # Find the line with the actual results (list of dicts)
                dict_data = None
                for line in data['log_lines']:
                    if line.startswith('[{'):
                        dict_data = line
                        break

                if dict_data:
                    ddata = dict_data.replace("'", "\"")
                    ddata = ddata.replace("write Mb", "write MiB")
                    ddata = ddata.replace("read Mb", "read MiB")
                    if ddata != "":
                        rows = json.loads(ddata)
                        for row in rows:
                            row['Image Digest'] = image_digest
                        allData += rows
        except (KeyError, json.JSONDecodeError, IndexError) as e:
            print(f"Warning: Skipping {filename} due to error: {e}")
            continue

    if not allData:
        print("Error: No valid data found in log files")
        sys.exit(1)

    toCsv(allData)
