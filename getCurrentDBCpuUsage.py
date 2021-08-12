#!/usr/bin/python3

import subprocess
import re
import sqlite3
from datetime import datetime


contenedores = [
    'adhoc-pg-demo/postgres',
    'adhoc-pg-boggio/postgres',
    'adhoc-pg-nubeadhoc-2/postgres',
    'adhoc-pg12-demo/postgres',
    'adhoc-pg12-nubeadhoc/postgres'
    ]


def getCurrentCpuUsage(containerName: str):
    print('Cheking process on', containerName)
    p = subprocess.Popen('rancher1 exec -it %s /bin/bash -c \
        "ps --sort=-pcpu -Ao pcpu,pmem,args"' % containerName,
                         stdout=subprocess.PIPE,
                         shell=True)
    (output, err) = p.communicate()
    p_status = p.wait()
    pss = dict()
    if p_status == 0:
        lines = output.splitlines()
        for line in lines:
            line = line.decode().strip()
            # Eliminamos el final de la linea con informacion relativa a la conexion
            line = re.sub(r'(([0-9]{1,3}\.){3}.*)', ' ', line).strip()
            # Buscamos los CPU y MEM ( proc postgress)
            ps = re.findall(r'([0-9]{1,2}\.+[0-9]{1,2})|(postgres: .*)',
                            line, flags=re.IGNORECASE)
            if len(ps) != 3:
                continue
            try:
                cpu = float(ps[0][0])
                mem = float(ps[1][0])
                # postgres: odoo matelec
                # Proc      User DB
                proc = ps[2][1].strip().split(' ')
                if len(proc) < 3:
                    # print(proc)
                    continue
                proc = proc[2]
#                print("CPU: %1f MEM: %1f DB: %s" % (cpu, mem, proc))
                if proc in pss:
                    pss[proc] = [pss[proc][0] + cpu, pss[proc][1] + mem]
                else:
                    pss[proc] = [cpu, mem]
            except Exception as e:
                print('Something went wrong', e)
    else:
        print('Something went wrong', err, p_status, output)
    return pss


def checkDB():
    conn = sqlite3.connect('proc.sqlite')
    c = conn.cursor()
    # Create table
    c.execute('''CREATE TABLE IF NOT EXISTS proc
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
        c.execute("INSERT INTO proc VALUES (null, '%s','%s','%s',%s,%s)" % (
            currentDate,
            containerName,
            proc,
            ps[0],
            ps[1]
            ))

    conn.commit()
    conn.close()


def installps(containerName):
    p = subprocess.Popen('rancher1 exec -it %s /bin/bash -c \
        "apt-get update && apt-get install -y procps && rm -rf /var/lib/apt/lists/* && apt autoremove && apt clean"' % containerName,
                         stdout=subprocess.PIPE,
                         shell=True)
    (output, err) = p.communicate()
    p.wait()


checkDB()
currentDate = datetime.now()
for contenedor in contenedores:
    # installps(contenedor)
    ps = getCurrentCpuUsage(contenedor)
    save(contenedor, ps, currentDate)

