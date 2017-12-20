#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys, csv

with open('nodes.csv') as csvfile:
    reader = list(csv.DictReader(csvfile))

master_send_id = [i['ID'] for i in reader if i['Role'] == 'Master' and 'send' in i['Task'].split(':')][0]
master_receive_id = [i['ID'] for i in reader if i['Role'] == 'Master' and 'receive' in i['Task'].split(':')][0]
slave_collect_id = [i['ID'] for i in reader if i['Role'] == 'Slave' and 'collect' in i['Task'].split(':')][0]
task = [i['Task'] for i in reader if i['ID'] == sys.argv[1]][0].split(':')
peers = ','.join([i['ID'] for i in reader if i['ID'] != sys.argv[1] and i['Role'] == 'Slave'])

print('-DMASTER_SEND_ID=%s -DMASTER_RECEIVE_ID=%s -DSLAVE_COLLECT_ID=%s' % (master_send_id, master_receive_id, slave_collect_id)
    + ''.join([' -DTASK_' + i.upper() for i in task]) + (' -DPEERS_ID=%s' % peers if peers else ''))
