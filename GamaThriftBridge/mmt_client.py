host = "localhost"
port = 9090

import sys

import socket
# your gen-py dir
sys.path.append('gen-py')

# GamaThrift files
from GamaThrift import MmtService
from GamaThrift import PlannerService
from GamaThrift import *
from GamaThrift.ttypes import *

# Thrift files
from thrift import Thrift
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol
from thrift.server import TServer

from thrift_server_class import Handler

import time
import os

from threading import Lock, Thread
import xmlParser
import json
import copy

path = os.getcwd() + "\ip_config.txt"

test_data = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;1;76.3275146484;38.3087158203;0,;0.0$2;97.2351074219;87.4938964844;3,1,;0.0$3;76.3275146484;38.3087158203;0,1,;0.0$4;76.3275146484;38.3087158203;3,;0.0$5;71.1517333984;8.80432128906;1,3,;0.0$6;71.1517333984;8.80432128906;1,0,;0.0$7;71.1517333984;8.80432128906;1,0,;0.0$8;71.1517333984;8.80432128906;3,;0.0$9;97.2351074219;87.4938964844;3,;0.0$10;97.2351074219;87.4938964844;1,0,3,;0.0$+29;15.0146484375;96.1303710938;3,;0.0;19;21;4$43;29.931640625;88.8519287109;3,;0.0;22;24;4$44;77.4658203125;23.9532470703;1,;0.0;1;3;5$45;3.88488769531;2.18811035156;3,;0.0;18;20;8$1;29.1931152344;32.5958251953;0,;0.0;9;11;7$27;32.7239990234;17.2760009766;3,;0.0;4;6;4$23;64.9108886719;52.2979736328;1,;0.0;6;8;5$20;39.1021728516;32.5500488281;0,;0.0;6;8;7$19;6.80541992188;5.908203125;3,;0.0;16;18;8$36;11.0870361328;85.3179931641;3,;0.0;15;17;5$2;42.5659179688;72.3480224609;1,;0.0;22;24;2$48;11.7248535156;70.6024169922;1,;0.0;12;14;6$3;80.4016113281;66.8487548828;1,;0.0;5;7;10$14;49.2218017578;52.0141601562;3,;0.0;11;13;9$42;37.5366210938;4.58984375;0,;0.0;7;9;3$12;89.1143798828;1.57470703125;1,;0.0;13;15;10$10;41.7510986328;32.8308105469;1,;0.0;3;5;7$0;25.4058837891;36.4990234375;3,;0.0;8;10;4$9;82.6446533203;79.6661376953;1,;0.0;7;9;2$32;25.3723144531;72.8637695312;0,;0.0;19;21;6$13;2.68249511719;98.7396240234;1,;0.0;20;22;5$8;0.302124023438;11.2091064453;0,;0.0;17;19;3$33;97.6806640625;89.2700195312;3,;0.0;0;2;2$26;16.7022705078;12.1490478516;0,;0.0;13;15;3$18;33.8043212891;2.40478515625;1,;0.0;9;11;3$6;7.83996582031;64.8956298828;0,;0.0;15;17;6$16;18.2769775391;63.1225585938;1,;0.0;9;11;6$21;32.0556640625;23.0255126953;3,;0.0;16;18;9$31;53.4912109375;11.7156982422;1,;0.0;3;5;3$46;71.6247558594;81.8084716797;3,;0.0;2;4;9$4;30.4138183594;65.6829833984;0,;0.0;21;23;1$41;85.7788085938;70.6878662109;1,;0.0;10;12;2$35;9.72595214844;28.7078857422;0,;0.0;21;23;3$24;95.2789306641;69.4091796875;1,;0.0;4;6;2$30;77.7862548828;64.4287109375;3,;0.0;6;8;9$5;21.4935302734;14.4622802734;3,;0.0;20;22;9$47;17.7093505859;41.8304443359;1,;0.0;12;14;7$22;60.1928710938;80.5633544922;3,;0.0;18;20;2$28;85.3820800781;68.5943603516;0,;0.0;13;15;1$40;80.7495117188;81.9122314453;0,;0.0;1;3;10$25;61.4959716797;49.1882324219;0,;0.0;8;10;1$15;91.9097900391;36.9689941406;0,;0.0;1;3;1$11;67.9870605469;61.5661621094;1,;0.0;14;16;2$17;29.6356201172;68.1976318359;3,;0.0;14;16;4$7;34.5581054688;40.5151367188;1,;0.0;4;6;6$49;1.49536132812;91.3208007812;1,;0.0;18;20;5$39;85.6964111328;56.0699462891;3,;0.0;4;6;8$37;85.0738525391;42.4987792969;0,;0.0;4;6;1$38;17.1691894531;83.1298828125;1,;0.0;22;24;6$34;66.5374755859;58.7677001953;1,;0.0;19;21;7$&lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n"
run_with_test_data = False
run = True
lock = Lock()


def waitOnPlanner_Thread(no_agents):
    try: 
        processor = MmtService.Processor(handler)
        port = 9999
        with open(path, 'r') as f:
            lines = f.readlines()
        transport = TSocket.TServerSocket(lines[1].strip('\n'), port)
        tfactory = TTransport.TBufferedTransportFactory()
        pfactory = TBinaryProtocol.TBinaryProtocolFactory()
        
        server = TServer.TSimpleServer(processor, transport, tfactory, pfactory)
        
        print "Starting thrift-based server in environment on port %d" % port
        server.serve()
        print "done!"
    except Thrift.TException, tx:
        print "%s" % (tx.message)

noag=10
handler = Handler()
waitonplanner_thread = Thread(target=waitOnPlanner_Thread, args=(noag,))
waitonplanner_thread.daemon = True
waitonplanner_thread.start()


def ping_planner(msg):
    try:

        with open(path, 'r') as f:
            lines = f.readlines()
        # Make socket
        transport = TSocket.TSocket(lines[3].strip('\n'), 9097)
        
        # Buffering is critical. Raw sockets are very slow
        transport = TTransport.TBufferedTransport(transport)
        
        # Wrap in a protocol
        protocol = TBinaryProtocol.TBinaryProtocol(transport)
        
        # Create a client to use the protocol encoder
        client = PlannerService.Client(protocol)
        
        # Connect!
        transport.open()
        print "trying to ping"
        client.ping()
        print msg
        
        transport.close()
        
    except Thrift.TException, tx:
        print "%s" % (tx.message)

def receiveFromGama():
    global handler
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
        #print(type(data))
        #print 'received "%s"' % data
        if data:
            print "Checking data from Gama"
            #print data
            msg_content, msg_timestamp = xmlParser.toXML(data)
            #print msg_content
            print msg_timestamp
            print msg_content
            if msg_content == "Mission Complete":
                # Make socket
                transport = TSocket.TSocket('localhost', 9097)
                # Buffering is critical. Raw sockets are very slow
                transport = TTransport.TBufferedTransport(transport)
                # Wrap in a protocol
                protocol = TBinaryProtocol.TBinaryProtocol(transport)
                # Create a client to use the protocol encoder
                client = PlannerService.Client(protocol)
                # Connect!
                transport.open()
                #send to planner mission complete
                if handler.currentPlan.vehicles:
                    handler.currentPlan.vehicles[0].onboardPlanner = True
                    client.send_computePlan(handler.currentPlan)
                transport.close()
                
            elif "replan" in msg_content:
                # Make socket
                transport = TSocket.TSocket('localhost', 9097)
                # Buffering is critical. Raw sockets are very slow
                transport = TTransport.TBufferedTransport(transport)
                # Wrap in a protocol
                protocol = TBinaryProtocol.TBinaryProtocol(transport)
                # Create a client to use the protocol encoder
                client = PlannerService.Client(protocol)
                # Connect!
                transport.open()
                #send to planner mission complete
                json_content = json.loads(msg_content)
                agents_alive = json_content['agents']
                completed_tasks = json_content['tasks']
                #TODO add for failed equipment
                #keep only alive agents in the request

                ag = [x.id for x in handler.currentPlan.vehicles]
                act = [x.actionId for x in handler.currentPlan.actions]

                dead =  [x for x in ag if not x in agents_alive]
                for d in dead:
                    for x in handler.currentPlan.vehicles:
                        if int(x.id) == int(d):
                            print handler.currentPlan.vehicles.index(x)
                            handler.currentPlan.vehicles.pop(handler.currentPlan.vehicles.index(x))
                            break
                #keep only uncompleted tasks in the request
                complete = [x for x in act if x in completed_tasks]
                for c in complete:
                    for x in handler.currentPlan.actions:
                        if int(x.actionId) == int(c):
                            handler.currentPlan.actions.pop(handler.currentPlan.actions.index(x))
                            break

                ag = [x.id for x in handler.currentPlan.vehicles]
                print ag
                act = [x.actionId for x in handler.currentPlan.actions]
                print act 

                print "Remaining agents: " + str(len(handler.currentPlan.vehicles))
                print "Remaining tasks: " + str(len(handler.currentPlan.actions))
                print "Ask for a new plan"
                client.send_computePlan(handler.currentPlan)
                
                transport.close()
            elif msg_content == "Ping":
                ping_planner("Hello blue monday")

        else:
            #print 'no more data from %s' % str(client_address)
            pass

    connection.close()
    with lock:
        mission_done = True
    print("Shutting down gama connection")
    
try:
    print("Running with test_data: ", run_with_test_data)

    if run_with_test_data:
        thread = Thread(target = receiveFromGama)
        thread.start()
        time.sleep(15)
        #send the saved string as an initial plan to the agents
        hostGama = 'localhost'
        portGama = 10002 #The same port as used by the server
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((hostGama, portGama))
        s.sendall(test_data.encode())
        print("Just sent dummy data to GAMA agents and exit")
        run = False
        s.close()
    else:
        thread = Thread(target = receiveFromGama)
        thread.start()
        #ping_planner("Hello blue monday")
        #time.sleep(5)
        print("Ready for Gama")
        #ping_planner("Hello blue monday")
        hostGama = '130.243.73.174'
        portGama = 10002 #The same port as used by the server
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((hostGama, portGama))
        while True:
            if handler.isPlanNew:
                print "New plan - Send to Gama agents"
                
                string2send = str(handler.currentPlan)
                agents = ''
                for x in handler.currentPlan.vehicles:
                    eq = ''
                    for e in x.equipments:
                        eq += str(e.type) + ","
                    #print eq
                    agents += str(x.id) + ';' + str(x.location.latitude) + ';' + str(x.location.longitude) + ';' + eq + ';' + str(x.currentSpeed) + '$'
                tasks = ''
                actions = 0
                for x in handler.currentPlan.actions:
                    actions = actions + 1
                    eqt = ''
                    for e in x.relatedTask.requiredTypes:
                        eqt += str(e) + ','
                    tasks += str(x.actionId) + ';' + str(x.area.area[0].latitude) + ';' + str(x.area.area[0].longitude) + ';' + str(eqt) + ';' +  str(x.speed) +  ';' + str(x.startTime) + ';' + str(x.endTime) + ';' + str(x.assignedVehicleId) + '$'
                #print agents
                #print tasks
                string2send = agents + "+" + tasks
                data = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;"+string2send+"&lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n"
                print "Below is example data"
                print "Number of actions to send %s " % str(actions)
                s.sendall(data.encode())
                handler.setPlanNewValue(False)

                ag = [x.id for x in handler.currentPlan.vehicles]
                print ag
                act = [x.actionId for x in handler.currentPlan.actions]
                print act
except KeyboardInterrupt:
    run = False
    print "Exiting..."
