with open('boot', 'rb') as fd:
    for x in fd.read():
        print('{:02x}'.format(x))
