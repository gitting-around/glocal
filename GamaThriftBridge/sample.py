import xmlParser

from threading import Lock, Thread
import time, os
import sys

import socket

lock = Lock()
run = True
restart = False
def receiveFromGama():
    global handler, mission_done, run, restart, lock
    # Create a TCP/IP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Bind the socket to the port
    server_address = ('130.243.73.174', 10000)
    print 'starting up on port %s' % str(server_address)
    sock.bind(server_address)

    # Listen for incoming connections
    sock.listen(1)
    # Wait for a connection
    print 'waiting for a connection'  
    connection, client_address = sock.accept()
    
    print 'connection from %s' % str(client_address)
    while run:
        # Receive the data in small chunks
        data = connection.recv(2600).decode()
        if data:
            msg_content, msg_timestamp = xmlParser.toXML(data)
            print "I received:" + msg_content
            if msg_content == "Ping":
                pass


    connection.close()
    print("Shutting down gama connection")


try:
    thread = Thread(target = receiveFromGama)
    time.sleep(2)
    thread.start()
    while True:
        if restart:
            thread = Thread(target = receiveFromGama)
            #thread.start()
            with lock:
                restart =False
except KeyboardInterrupt:
    run = False
    print "Exiting..."
