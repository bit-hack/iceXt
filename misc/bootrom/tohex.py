import sys

with open(sys.argv[1], 'rb') as fd:
    data = [ x for x in fd.read() ]

fill  = 0x1ff0 - (len(data))
data += [ 0x90 ] * fill

data += [ 0xea, 0x00, 0x00, 0x00, 0xfe ]

fill  = 0x2000 - (len(data))
data += [ 0x90 ] * fill


with open('program.hex', 'w') as fd:
    for x in data:
        print('{:02x}'.format(x), file=fd)
