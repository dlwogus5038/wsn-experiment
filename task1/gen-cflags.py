#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys, csv

with open('nodes.csv') as csvfile:
    reader = list(csv.DictReader(csvfile))

upstream, sensor, basestation = [(i['Father ID'], i['Sensor'], i['Base Station']) for i in reader if i['ID'] == sys.argv[1]][0]
downstream = ','.join([i['ID'] for i in reader if i['ID'] != sys.argv[1] and i['Father ID'] == sys.argv[1]])

print(('-DUPSTREAM=%s' % upstream) + (' -DDOWNSTREAM=%s' % downstream if downstream else '')
    + (' -DSENSOR' if sensor == '1' else '') + (' -DBASESTATION' if basestation == '1' else ''))
