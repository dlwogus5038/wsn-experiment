#! /usr/bin/env python
# -*- coding: utf-8 -*-
import os
os.environ['MOTECOM'] = 'serial@/dev/ttyUSB0:115200'
import dash
from dash.dependencies import Input, Output
import dash_core_components as dcc
import dash_html_components as html
import plotly
import plotly.graph_objs as go
from Queue import Queue, Empty
from threading import Thread
import tos
import time
import datetime

AM_CONTROLMSG = 6
AM_RECORDMSG = 7

READ_TIMEOUT = 0.01

class RecordMsg(tos.Packet):
    def __init__(self, packet=None):
        tos.Packet.__init__(self, [
            ('nodeid', 'int', 1),
            ('count', 'int', 2),
            ('time', 'int', 4),
            ('temperature', 'int', 2),
            ('humidity', 'int', 2),
            ('light', 'int', 2)
        ], packet)

class ControlMsg(tos.Packet):
    def __init__(self, packet=None):
        tos.Packet.__init__(self, [
            ('frequency', 'int', 4)
        ], packet)

record_queue = Queue()
control_queue = Queue()

intro_text = u'''
### 多跳WSN数据采集可视化
'''

def start_server():
    # {nodeid: {
    #     count: num
    #     time_delta: time
    #     data: [(time, temperature, humidity, light), ...]
    # }, ...}
    nodes_data = dict()
    nodes_data_beautify = [
        lambda data, item: datetime.datetime.fromtimestamp(data['time_delta'] + item / 1e3)
    ]

    app = dash.Dash()

    app.layout = html.Div(children=[
        html.Div([dcc.Markdown(intro_text)]),
        dcc.Graph(
            id='graph'
        ),
        dcc.Interval(
            id='interval-component',
            interval=1 * 1000
        )
    ])

    def update_data():
        try:
            while True:
                packet = record_queue.get_nowait()
                data = nodes_data.get(packet[0])
                if data is None:
                    data = {
                        'count': packet[1],
                        'time_delta': time.time() - packet[2] / 1e3,
                        'data': [packet[2:]],
                        'duplicated': 0,
                        'lost': 0
                    }
                    nodes_data[packet[0]] = data
                elif packet[1] > data['count']:
                    data['lost'] += packet[1] - data['count'] - 1
                    data['count'] = packet[1]
                    data['data'].append(packet[2:])
                else:
                    data['duplicated'] += 1
        except Empty:
            pass

    @app.callback(Output('graph', 'figure'),
                  [Input('interval-component', 'n_intervals')])
    def update_graph_live(n):
        update_data()
        traces = []

        for nodeid in nodes_data:
            data = nodes_data[nodeid]
            traces.append({
                'x': [nodes_data_beautify[0](data, i[0]) for i in data['data']],
                'y': [i[3] for i in data['data']],
                'name': 'Node %d Light' % nodeid,
                'mode': 'lines+markers',
                'type': 'scatter'
            })

        return {
            'data': traces,
            'layout': {
                'margin': {'l': 30, 'r': 10, 'b': 30, 't': 10},
                'legend': {'x': 0, 'y': 1, 'xanchor': 'left'}
            }
        }
    app.run_server()

def start_serial():
    am = tos.AM()
    while True:
        p = am.read(timeout=READ_TIMEOUT)
        try:
            while True:
                data = control_queue.get_nowait()
                msg = ControlMsg()
                msg.frequency = data[0]
                am.write(msg, AM_CONTROLMSG)
                print('Sent: ' + str(msg))
        except Empty:
            pass
        if p and p.type == AM_RECORDMSG:
            msg = RecordMsg(p.data)
            record_queue.put((msg.nodeid, msg.count, msg.time,
                msg.temperature, msg.humidity, msg.light))
            print('Received: ' + str(msg))


if __name__ == '__main__':
    thread = Thread(target=start_serial)
    thread.start()
    start_server()
    thread.join()
