#!/usr/bin/env python

import sys
import tos

am = tos.AM()

while True:
    p = am.read()
    print(p)
