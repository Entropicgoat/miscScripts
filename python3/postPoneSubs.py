import re

def main():
    increaseByStr = input('How far should the subtitles be postponed by (ms)?')
    increaseBy = int(increaseByStr)
    file = input('Name of subtitle file:')
    backupFile = 'bak.' + file

    fin = open(file, 'r')
    fbackup = open(backupFile, 'w')
    lines = fin.readlines()
    count = 0
    # First we backup the file.
    for line in lines:
        print("Line B {}: {}".format(count, line))
        fbackup.write(line)
        count = count + 1
    fbackup.close()
    fin.close()

    fout = open(file, 'w')
    fin = open(backupFile, 'r')
    count = 0
    lines = fin.readlines()
    # Then we remake the original file with the postponed subtitles.
    for line in lines:
      if re.search('-->', line) is not None:
          print("Line O {}: {}".format(count, line.strip()))
          firstSub = int(line[6]+line[7])
          firstSubInc = str(firstSub + increaseBy)
          if len(firstSubInc) == 1:
              firstSubInc = '0' + firstSubInc
          secondSub = int(line[23]+line[24])
          secondSubInc = str(secondSub + increaseBy)
          if len(secondSubInc) == 1:
              secondSubInc = '0' + secondSubInc
          first = line.replace(line[6]+line[7], firstSubInc)
          second = first.replace(line[23]+line[24], secondSubInc)
          print("Line R {}: {}".format(count, second))
          fout.write(second)
      else:
          fout.write(line)

          count = count + 1

main()
