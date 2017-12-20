#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys, csv

with open('nodes.csv') as csvfile:
    reader = list(csv.DictReader(csvfile))

print([i['Role'] for i in reader if i['ID'] == sys.argv[1]][0])
