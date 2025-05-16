import sys

with open(sys.argv[1], 'rb') as fd:
    data = [ x for x in fd.read() ]

size = len(data)

sum = 0
for x in data:
    sum = (sum + x) & 0xff

fill  = 0x800 - (len(data))
data += [ 0x0 ] * fill

data[-1] = 0xff & (0x100 - sum)

with open(sys.argv[2], 'w') as fd:
    for x in data:
        print('{:02x}'.format(x), file=fd)
