#! /usr/bin/env python
# -*- coding: utf-8 -*-
import os
os.environ['MOTECOM'] = 'serial@/dev/ttyUSB0:115200'
import tos

AM_ID = 0

class RecordMsg(tos.Packet):
    def __init__(self, packet=None):
        tos.Packet.__init__(self, [
            ('group_id', 'int', 1),
            ('max', 'int', 4),
            ('min', 'int', 4),
            ('sum', 'int', 4),
            ('average', 'int', 4),
            ('median', 'int', 4)
        ], packet)

am = tos.AM()

while True:
    p = am.read()
    print(p)
    if p and p.type == AM_ID:
        print(RecordMsg(p.data))
