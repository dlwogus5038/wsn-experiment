#! /usr/bin/env python
# -*- coding: utf-8 -*-
import os
os.environ['MOTECOM'] = 'serial@/dev/ttyUSB0:115200'
import dash
from dash.dependencies import Input, Output, State
import dash_core_components as dcc
import dash_html_components as html
import plotly
import plotly.graph_objs as go
from Queue import Queue, Empty
from threading import Thread, Lock
import tos
import time
import datetime
import calendar

AM_CONTROLMSG = 6
AM_RECORDMSG = 7

READ_TIMEOUT = 0.01
PACKET_DUPLICATED_THRESHOLD = 16
PACKET_LOST_THRESHOLD = 16
MOVING_AVERAGE_R = 0.9

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

control_queue = Queue()

# {nodeid: {
#     count: num
#     time_delta: time
# }, ...}
nodes_data_lock = Lock()
nodes_data = dict()


intro_text = u'''
# 多跳WSN数据采集可视化

如果收到的包的序列号很接近上一次的序列号时，我们会依照序列号计算**包丢失数**或**包重复数**；如果序列号差别很大，我们会认为节点重启了或离开网络很久，计入**重置数**，并重新同步时间，重新计算**真实采样间隔**。

**真实采样间隔**是通过系数为 %.2f 的指数移动平均（EMA）计算的。

对于显示的数据，我们依照[TinyOS的教程](http://tinyos.stanford.edu/tinyos-wiki/index.php/Boomerang_ADC_Example)进行了一些处理。
''' % MOVING_AVERAGE_R

def generate_table(dataframe):
    return ([html.Tr([html.Th(col) for col in dataframe[0]])] +
        [html.Tr([html.Td(col) for col in row]) for row in dataframe[1:]])

def update_info_table():
    table = [
        [u'节点编号'],
        [u'包收到数'],
        [u'包丢失数'],
        [u'包重复数'],
        [u'重置数'],
        [u'真实采样间隔 (ms)']
    ]
    nodes_data_lock.acquire()
    for nodeid in nodes_data:
        data = nodes_data[nodeid]
        table[0].append(u'%d' % nodeid)
        table[1].append(u'%d' % len(data['time_data']))
        table[2].append(u'%d' % data['lost'])
        table[3].append(u'%d' % data['duplicated'])
        table[4].append(u'%d' % data['reset'])
        sample_rate = data.get('sample_rate')
        table[5].append(u'' if sample_rate is None else u'%d' % int(sample_rate * 1000 + 0.5))
    nodes_data_lock.release()
    return generate_table(table)

def update_graphs(display_range):
    nodes_data_lock.acquire()
    if len(nodes_data) == 0:
        nodes_data_lock.release()
        return []

    temperature_traces = []
    humidity_traces = []
    light_traces = []
    now = datetime.datetime.now()
    display_range = datetime.timedelta(seconds=60 * display_range)
    for nodeid in nodes_data:
        data = nodes_data[nodeid]
        filtered = [i for i in range(len(data['time_data'])) if now - data['time_data'][i] < display_range]
        time_data = [data['time_data'][i] for i in filtered]
        temperature_traces.append({
            'x': time_data,
            'y': [data['temperature_data'][i] for i in filtered],
            'name': '节点 %d' % nodeid,
            'mode': 'lines+markers',
            'type': 'scatter'
        })
        humidity_traces.append({
            'x': time_data,
            'y': [data['humidity_data'][i] for i in filtered],
            'name': '节点 %d' % nodeid,
            'mode': 'lines+markers',
            'type': 'scatter'
        })
        light_traces.append({
            'x': time_data,
            'y': [data['light_data'][i] for i in filtered],
            'name': '节点 %d' % nodeid,
            'mode': 'lines+markers',
            'type': 'scatter'
        })
    nodes_data_lock.release()

    return [
        dcc.Graph(figure={
            'data': temperature_traces,
            'layout': {
                'title': u'各节点温度数据',
                'xaxis': {'title': '时间', 'range': [now - display_range, now]},
                'yaxis': {'title': '温度 (℃)'},
                'showlegend': True,
                'legend': {'x': 0, 'y': 1}
            }
        }, id='temperature-traces'),
        dcc.Graph(figure={
            'data': humidity_traces,
            'layout': {
                'title': u'各节点湿度数据',
                'xaxis': {'title': '时间', 'range': [now - display_range, now]},
                'yaxis': {'title': '湿度'},
                'showlegend': True,
                'legend': {'x': 0, 'y': 1}
            }
        }, id='humidity-traces'),
        dcc.Graph(figure={
            'data': light_traces,
            'layout': {
                'title': u'各节点光照数据',
                'xaxis': {'title': '时间', 'range': [now - display_range, now]},
                'yaxis': {'title': '光强 (Lux)'},
                'showlegend': True,
                'legend': {'x': 0, 'y': 1}
            }
        }, id='light-traces')
    ]

def start_server():
    sample_interval=100

    app = dash.Dash()

    app.layout = html.Div(children=[
        html.Div([dcc.Markdown(intro_text)]),
        html.Table(update_info_table(), id='info-table', style={'float': 'right', 'width': '50%'}),
        html.Div([
            html.Label([u'刷新间隔 ', html.Span('1', id='refresh-interval-text'), u's']),
            dcc.Input(id='refresh-interval', type='number', value=1, min=1, max=3600),
            html.Label([u'显示时长 ', html.Span('1', id='display-range-text'), u'min']),
            dcc.Input(id='display-range', type='number', value=1, min=1, max=60),
            html.Label([u'采样间隔 ', html.Span(str(sample_interval), id='sample-interval-text'), u'ms']),
            dcc.Input(id='sample-interval', type='number', value=sample_interval, min=10, max=10000, step=50),
            html.Button(u'发送', id='send-button'),
            html.Div([
                html.Button(u'手动刷新', id='refresh-button'),
                html.Button(u'同步时间', id='sync-time-button'),
                html.Button(u'清空数据', id='clear-data-button')
            ], style={'margin-top': 32})
        ]),
        html.Div([], id='graphs', style={'clear': 'both'}),
        dcc.Interval(
            id='refresh',
            interval=1 * 1000
        )
    ], style={'padding': 16, 'margin': '0 auto', 'max-width': 960})

    @app.callback(Output('refresh-interval-text', 'children'),
                  [Input('refresh-interval', 'value')])
    def update_refresh_interval_text(n):
        return str(max(min(n, 120), 1))

    @app.callback(Output('refresh', 'interval'),
                  [Input('refresh-interval', 'value')])
    def update_refresh_interval(n):
        return max(min(n, 120), 1) * 1000

    @app.callback(Output('sample-interval-text', 'children'),
                  [Input('send-button', 'n_clicks')],
                  [State('sample-interval', 'value')])
    def update_sample_interval(_, n):
        sample_rate = max(min(n, 10000), 10)
        control_queue.put((sample_rate,))
        return str(sample_rate)


    @app.callback(Output('info-table', 'children'),
                  [Input('refresh', 'n_intervals'),
                   Input('refresh-button', 'n_clicks'),
                   Input('display-range', 'value')])
    def refresh_info_table(x, y, z):
        return update_info_table()

    @app.callback(Output('display-range-text', 'children'),
                  [Input('refresh', 'n_intervals'),
                   Input('refresh-button', 'n_clicks'),
                   Input('display-range', 'value')])
    def update_display_range_text(x, y, n):
        return str(max(min(n, 60), 1))

    @app.callback(Output('graphs', 'children'),
                  [Input('refresh', 'n_intervals'),
                   Input('refresh-button', 'n_clicks'),
                   Input('display-range', 'value')])
    def refresh_graphs(x, y, display_range):
        display_range = max(min(display_range, 60), 1)
        return update_graphs(display_range)

    @app.callback(Output('sync-time-button', 'children'),
                  [Input('sync-time-button', 'n_clicks')])
    def sync_time(n):
        nodes_data_lock.acquire()
        for nodeid in nodes_data:
            nodes_data[nodeid]['time_sync'] = True
        nodes_data_lock.release()
        return u'同步时间'

    @app.callback(Output('clear-data-button', 'children'),
                  [Input('clear-data-button', 'n_clicks')])
    def clear_data(n):
        nodes_data_lock.acquire()
        nodes_data.clear()
        nodes_data_lock.release()
        return u'清除数据'

    app.css.append_css({"external_url": "https://codepen.io/chriddyp/pen/bWLwgP.css"})
    app.run_server()

def start_serial():
    am = tos.AM()
    while True:
        p = am.read()
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
            with open('result.txt', 'a') as f:
                f.write('\t'.join([str(i) for i in [
                    msg.nodeid, msg.count, msg.temperature,
                    msg.humidity, msg.light, msg.time
                ]]) + '\n')
            print('Received: ' + str(msg))
            nodes_data_lock.acquire()
            data = nodes_data.get(msg.nodeid)
            now = time.time()
            if data is None:
                temperature = -39.6 + 0.01 * msg.temperature
                temperature = (temperature - 32) / 1.8
                humidity = -4 + 0.0405 * msg.humidity + (-2.8 * 1e-6) * (msg.humidity ** 2)
                data = {
                    'count': msg.count,
                    'time_delta': now - msg.time / 1e3,
                    'duplicated': 0,
                    'lost': 0,
                    'reset': 0,
                    'time_data': [datetime.datetime.fromtimestamp(now)],
                    'temperature_data': [temperature],
                    'humidity_data': [humidity],
                    'light_data': [0.625 * 10 * msg.light * 1.5 / 4.096],
                    'sample_rate': None,
                    'time_sync': False
                }
                nodes_data[msg.nodeid] = data
            else:
                ahead = (msg.count + 0x10000 - data['count']) % 0x10000
                behind = (data['count'] + 0x10000 - msg.count) % 0x10000
                if 0 <= behind < PACKET_DUPLICATED_THRESHOLD:
                    data['duplicated'] += 1
                else:
                    if 0 < ahead < PACKET_LOST_THRESHOLD:
                        data['lost'] += ahead - 1
                        if data['time_sync']:
                            print('sync')
                            data['time_delta'] = now - msg.time / 1e3
                            data['time_data'].append(datetime.datetime.fromtimestamp(now))
                            data['time_sync'] = False
                        else:
                            data['time_data'].append(datetime.datetime.fromtimestamp(data['time_delta'] + msg.time / 1e3))
                        sample_rate = data['sample_rate']
                        new_sample_rate = (data['time_data'][-1] - data['time_data'][-2]).total_seconds() / ahead
                        if sample_rate is None:
                            data['sample_rate'] = new_sample_rate
                        else:
                            data['sample_rate'] = new_sample_rate * MOVING_AVERAGE_R + sample_rate * (1 - MOVING_AVERAGE_R)
                    else:
                        data['reset'] += 1
                        data['time_delta'] = now - msg.time / 1e3
                        data['time_data'].append(datetime.datetime.fromtimestamp(now))
                        data['sample_rate'] = None
                    data['count'] = msg.count
                    temperature = -39.6 + 0.01 * msg.temperature
                    temperature = (temperature - 32) / 1.8
                    humidity = -4 + 0.0405 * msg.humidity + (-2.8 * 1e-6) * (msg.humidity ** 2)
                    data['temperature_data'].append(temperature)
                    data['humidity_data'].append(humidity)
                    data['light_data'].append(0.625 * 10 * msg.light * 1.5 / 4.096)
            nodes_data_lock.release()


if __name__ == '__main__':
    thread = Thread(target=start_serial)
    thread.start()
    start_server()
    thread.join()
