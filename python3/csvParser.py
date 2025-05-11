import csv, os, codecs

BUFSIZE = 4096
BOMLEN = len(codecs.BOM_UTF8)

def integrate(y_vals, h):
    i = 1
    total = y_vals[0] + y_vals[-1]
    for y in y_vals[1:-1]:
        if i % 2 == 0:
            total += 2 * y
        else:
            total += 4 * y
        i += 1
    return total * (h / 3.0)

def getArea(values, times):
  i = 1
  area = 0
  for v in values:
      if len(values) > i:
          vpair = [v, values[i]]
          timeDiff = times[i] - times[i-1]
          areaSection = integrate(vpair, timeDiff)
          area += areaSection
          i += 1
  return area

inputFile = input('Enter the name of the input csv file (.csv will be appended): ')
inputFile += '.csv'
outputFile = input('Enter the name of the output csv file (.csv will be appended): ')
outputFile += '.csv'
delimiterCharacter = input('Enter the delimiter character or ; as default:')
if (delimiterCharacter == ''):
    delimiterCharacter = ';'

# https://stackoverflow.com/questions/8898294/convert-utf-8-with-bom-to-utf-8-with-no-bom-in-python
with open(inputFile, "r+b") as fp:
    chunk = fp.read(BUFSIZE)
    if (chunk.startswith(codecs.BOM_UTF8)):
        i = 0
        chunk = chunk[BOMLEN:]
        while chunk:
            fp.seek(i)
            fp.write(chunk)
            i += len(chunk)
            fp.seek(BOMLEN, os.SEEK_CUR)
            chunk = fp.read(BUFSIZE)
        fp.seek(-BOMLEN, os.SEEK_CUR)
        fp.truncate()
    fp.close()

with open (inputFile) as csvFile:
    print('Parsing', inputFile, 'with delimiter', delimiterCharacter)
    reader = csv.DictReader(csvFile, delimiter=delimiterCharacter)

    samples = []
    for name in reader.fieldnames:
        if (name != 'Time'):
            peak = None
            peaks = []
            peakTime = None
            peakTimes = []
            previous = None
            previousTime = None
            previouser = None
            trough = None
            troughs = []
            troughTime = None
            troughTimes = []

            times = []

            with open (inputFile) as csvFile:
                reader2 = csv.DictReader(csvFile, delimiter=delimiterCharacter)
                values = []
                peakValues = []
                for row in reader2:
                    times.append(float(row['Time']))
                    if (peak == None or float(row[name]) > peak):
                        peak = float(row[name])
                        peakTime = row['Time']
                    if ((previous != None or previouser != None) and previous < float(row[name]) and (previouser > previous or previous == 0)):
                        if (trough != None):
                            troughs.append(trough)
                            troughTimes.append(float(troughTime))
                        trough = previous
                        troughTime = previousTime
                        peaks.append(peak)
                        peakTimes.append(float(peakTime))
                        peak = 0
                        if (previous == 0):
                            peakValues.append(values)
                            values = [previous, float(row[name])]
                        else:
                            values.append(float(row[name]))
                            peakValues.append(values)
                            values = [float(row[name])]
                    else:
                        values.append(float(row[name]))
                    previouser = previous
                    previous = float(row[name])
                    previousTime = row['Time']
                peaks.append(peak)
                peakTimes.append(float(peakTime))
                peakValues.append(values)
                if (trough > -0.1):
                    troughs.append(trough)
                    troughTimes.append(float(troughTime))
                samples.append({
                    'sample': name,
                    'peaks': peaks,
                    'peakTimes': peakTimes,
                    'troughs': troughs,
                    'troughTimes': troughTimes,
                    'values': peakValues
                })
            csvFile.close()
    i = 0
    f = open(outputFile, 'w') 
    for sample in samples:
      areas = []
      deliminator = delimiterCharacter
      name = sample['sample'].split(' ')[1]
      f.write('Sample;' + name + '\n')
      f.write('Peaks;' + deliminator.join(map(str, sample['peaks'])) + '\n')
      f.write('PeakTimes;' + deliminator.join(map(str, sample['peakTimes'])) + '\n')
      for values in sample['values']:
          areas.append(getArea(values, times))
      f.write('Areas;' + deliminator.join(map(str, areas)) + '\n')
      i += 1
    f.close()
csvFile.close()
