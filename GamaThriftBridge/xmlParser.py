#!/usr/bin/env python3
from xml.etree import ElementTree
import re

def toXML(data_string):
    #find the index of the first < that signalizes the start of the xml
    pos = -1
    for i,x in enumerate(data_string):
        if x == '<':
            pos = i 
            break
    #remove characters from string until the first <
    if pos >= 0:
        data_string = data_string[pos:]
    else:
        return "", -1
    #continue parsing string as xml
    root = ElementTree.fromstring(data_string)
    
    msg_content = ""
    msg_timestamp = -1
    #print(root.tag, root.attrib)
    for child in root:
        #print(child.tag, child.attrib)
        if child.tag == "contents":
            child_root = ElementTree.fromstring(child.text)
            msg_content = child_root.text
            #print(child_root.text)
        elif child.tag == "emissionTimeStamp":
            msg_timestamp = int(child.text)
    
    return msg_content, msg_timestamp

def toStringXML(content2send, timestep2send):
    return "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;"+content2send+"&lt;/string&gt;</contents>@n@  <emissionTimeStamp>"+str(timestep2send)+"</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n"

#string2send="hell"
#data = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;"+string2send+"&lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n"

#toXML("<root><a name=\"bo\">1</a><a name=\"bu\">2</a></root>")
#a, b = toXML(data)
#print(type(a))
#print(type(b))