import sys

with open(sys.argv[1], 'rb') as fd:
    data = [ x for x in fd.read() ]

size = len(data)

fill  = (8 * 1024) - (len(data))
data += [ 0x0 ] * fill

with open(sys.argv[2], 'w') as fd:
    for x in data:
        print('{:02x}'.format(x), file=fd)
