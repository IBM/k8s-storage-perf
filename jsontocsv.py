import csv, sys, json, os
from copy import deepcopy

throughput = '226'
latency = '18'

def toCsv(dict_data):
    columns = ['Cluster Name', 'PVC', 'Storage Type', 'Environment', 'Test Name','Thread Count', 'write Mb/s', 'Writes/s', 'read Mb/s', 'Reads/s', 'Total Time', 'Latency Min', 'Latency Avg', 'Latency Max', 'Latency 95th']
    summary = ['Summary', '', '', '', '','', '', '', '', '', '', '', '', '', '']
    summarycolumns = ['Cluster Name', 'PVC', 'Storage Type', 'Environment', 'Test Name','Thread Count', 'write Mb/s', 'Requirement']
    #summarycolumns = ['Cluster Name', 'PVC', 'Storage Type', 'Environment', 'Test Name','Thread Count', 'write Mb/s']
    detail = ['Detailed Measurements', '', '', '', '','', '', '', '', '', '', '', '', '', '']
    blank = ['', '', '', '', '','', '', '', '', '', '', '', '', '', '']
    csv_file = "result.csv"
    try:
        with open(csv_file, 'w') as csvfile:
            summarywriter = csv.DictWriter(csvfile, fieldnames=summary)
            summarywriter.writeheader()
            summarycolumnwriter = csv.DictWriter(csvfile, fieldnames=summarycolumns)
            summarycolumnwriter.writeheader()
            dict_copy = deepcopy(dict_data)
            for data in dict_copy:
                if data['Test Name'] == 'rndwr_4k_8' or data['Test Name'] == 'seqwr_1g_2':
                   minumum = throughput if (data['Test Name'] == 'seqwr_1g_2') else latency
                   data['Requirement'] = 'Recommended to meet the requirement of ' + minumum + ' Mb/s or higher'
                   del data['Latency Max']
                   del data['read Mb/s']
                   del data['Total Time']
                   del data['Latency 95th']
                   del data['Writes/s']
                   del data['Reads/s']
                   del data['Latency Avg']
                   del data['Latency Min']
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
    filenames=[x[2] for x in os.walk(folderPath)][0]
    allData = []
    for filename in filenames:
    # Opening JSON file
        with open(folderPath+filename) as json_file:
            data = json.load(json_file)
            dict_data = data['log_lines'][0]
            ddata = dict_data.replace("'", "\"")
            if ddata!="":
              allData += json.loads(ddata)
    toCsv(allData)
