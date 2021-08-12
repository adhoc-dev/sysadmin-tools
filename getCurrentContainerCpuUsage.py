#!/usr/bin/python3

import subprocess
import sqlite3
from datetime import datetime


contenedores = [
    'ad-node4',
    'ad-node5',
    'ad-node6',
    'ad-node7',
    'ad-node11',
    'ad-node12',
    'ad-db'
    ]


def getCurrentCpuUsage(containerName: str):
    # docker stats --format 'table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}' --no-stream
    # docker stats --format \'table {{.Name}}\\t{{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\' --no-stream
    proc = 'ssh ' + containerName + r" docker stats --format \'table {{.Name}}\\t{{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\' --no-stream"
    print('Cheking process on', containerName)
    p = subprocess.Popen(proc, stdout=subprocess.PIPE, shell=True)
    (output, err) = p.communicate()
    p_status = p.wait()
    pss = dict()
    if p_status == 0:
        lines = output.splitlines()
        for line in lines:
            ps = line.decode().strip().split()
            if len(ps) < 3 or ps[0] == "NAME":
                continue
            try:
                cpu = float(ps[2][:-1])
                mem = float(ps[3][:-3])
                if ps[3][-3:] == 'MiB':
                    mem *= (1024*1024)
                elif ps[3][-3:] == 'GiB':
                    mem *= (1024*1024*1024)
                else:
                    # ps[3][-3:] == 'KiB'
                    mem *= 1024
                # postgres: odoo matelec
                # Proc      User DB
                proc = ps[0]
                pss[proc] = [cpu, mem]
            except Exception as e:
                print('Something went wrong', e, line)
    else:
        print('Something went wrong', err, p_status, output)
    return pss


def checkDB():
    conn = sqlite3.connect('proc.sqlite')
    c = conn.cursor()
    # Create table
    c.execute('''CREATE TABLE IF NOT EXISTS nodes
                    (id INTEGER PRIMARY KEY AUTOINCREMENT,
                    date timestamp,
                    container text,
                    proc text,
                    cpu real,
                    mem real)''')
    conn.commit()
    conn.close()


def save(containerName: str, pss: dict, currentDate: datetime):
    conn = sqlite3.connect('proc.sqlite')
    if not currentDate:
        currentDate = datetime.now()
    c = conn.cursor()
    for proc, ps in pss.items():
        c.execute("INSERT INTO nodes VALUES (null, '%s','%s','%s',%s,%s)" % (
            currentDate,
            containerName,
            proc,
            ps[0],
            ps[1]
            ))

    conn.commit()
    conn.close()


checkDB()
currentDate = datetime.now()
for contenedor in contenedores:
    ps = getCurrentCpuUsage(contenedor)
    save(contenedor, ps, currentDate)
