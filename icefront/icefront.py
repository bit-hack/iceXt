#!/usr/bin/env python

from __future__ import print_function
import argparse
import json
import os
import sys


script_dir  = os.path.dirname(os.path.realpath(__file__))
pcf_dir     = os.path.join(script_dir, 'pcf')
boards_file = os.path.join(script_dir, 'boards.json')
stats_cmd   = 'yosys -p "synth_ice40 -top %top%" -p "stat" %files%'


def message(x):
    print(x)
    sys.stdout.flush()

def try_remove(paths):
    for x in paths:
        try:
            os.remove(x)
            message('removing {}'.format(x))
        except FileNotFoundError:
            pass

def line_break():
    message('-' * 79)

def extract_file(path):
    root = os.path.split(path)
    with open(path, 'r') as fd:
        lines = fd.readlines()
    return [ os.path.join(root[0], l.strip()) for l in lines ]

def file_list(files):
    out = []
    for f in files:
        if f.endswith('.f'):
            out += extract_file(f)
        else:
            out += [ f ]
    return out

def run_commands(board, args, commands):
    pcf_path  = os.path.join(pcf_dir, board['pcf'])
    json_path = 'temp.json'
    asc_path  = 'temp.asc'
    bin_path  = args.output

    # remove all artifacts
    try_remove([json_path, asc_path, bin_path])

    # print speed target
    speed = args.speed or board['speed']
    message('targeting speed {}'.format(speed))

    # file list
    files = file_list(args.files)

    # replacements
    repl = {
        '%package%': board['package'],
        '%device%' : board['device'],
        '%speed%'  : speed,
        '%pcf%'    : pcf_path,
        '%json%'   : json_path,
        '%asc%'    : asc_path,
        '%bin%'    : bin_path,
        '%top%'    : args.top,
        '%files%'  : ' '.join(files)}

    # issue commands as needed
    for cmd in commands:
        # replace all substitutes
        for k, v in repl.items():
            cmd = cmd.replace(k, v)
        message(cmd)
        # execute the command
        ret = os.system(cmd)
        message('return code: {}'.format(ret))
        line_break()

    # remove intermediate files
    try_remove([json_path, asc_path, 'abc.history'])

def args_parse():
    p = argparse.ArgumentParser()
    p.add_argument('board', help='development board')
    p.add_argument('-v', '--verbose', help='increase output verbosity', action='store_true')
    p.add_argument('-o', '--output', help='output file', default='out.bin')
    p.add_argument('-t', '--top', help='top level module', default='top')
    p.add_argument('-s', '--speed', help='desired frequency contraint', default=None)
    p.add_argument('--tools', help='path to oss cad suite', default=None)
    p.add_argument('--stats', help='print stats', action='store_true')
    p.add_argument('files', nargs='+', help='source input files')
    args = p.parse_args()
    return args

def list_boards(boards):
    message('Supported boards:')
    for board in boards:
        message('  {}'.format(board))

def main():
    # parse arguments
    args = args_parse()
    # put oss cad suite on the path
    if args.tools:
        sep = ':'
        os.environ['PATH'] += sep + os.path.join(args.tools, 'bin')
        os.environ['PATH'] += sep + os.path.join(args.tools, 'lib')
    # open board config file
    boards = json.load(open(boards_file))
    # access board
    try:
        board = boards[args.board]
    except KeyError:
        message('unknown board type: {}'.format(args.board))
        list_boards(boards)
        return
    # run compilation phase
    if args.stats:
        run_commands(board, args, [stats_cmd])
    else:
        run_commands(board, args, board['cmd'])

if __name__ == '__main__':
    main()
