#!/usr/bin/env python

import tos

am = tos.AM()

while True:
    p = am.read()
    print(p)
