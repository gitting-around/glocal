// Server side C/C++ program to demonstrate Socket programming
#include <unistd.h>
#include <stdio.h>
#include <sys/socket.h>

#include <arpa/inet.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <string.h>
#include <thread>
#include <iostream>
#include "pugixml.hpp"
#include <vector>
#include <functional>
#include <algorithm>

#include "rapidjson/document.h"
#include "rapidjson/writer.h"
#include "rapidjson/stringbuffer.h"
#include <cstdio>

#define PORT 8080

using namespace std;

void eraseAllSubStr(std::string & mainStr, const std::string & toErase)
{
    size_t pos = std::string::npos;
    // Search for the substring in string in a loop untill nothing is found
    while ((pos  = mainStr.find(toErase) )!= std::string::npos)
    {
        // If found then erase it from string
        mainStr.erase(pos, toErase.length());
    }

}

// The server is always listening in the background
void server()
{
    int server_fd, new_socket, valread;
	struct sockaddr_in address;
	int opt = 1;
	int addrlen = sizeof(address);
	char buffer[4000] = {0};
	string hello = "Hello from server";
	
	// Creating socket file descriptor
	if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0)
	{
		perror("socket failed");
		exit(EXIT_FAILURE);
	}
	
	// Forcefully attaching socket to the port 8080
	if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR , &opt, sizeof(opt)))
	{
		perror("setsockopt");
		exit(EXIT_FAILURE);
	}
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = INADDR_ANY;
	address.sin_port = htons( PORT );
	
	// Forcefully attaching socket to the port 8080
	if (bind(server_fd, (struct sockaddr *)&address,
								sizeof(address))<0)
	{
		perror("bind failed");
		exit(EXIT_FAILURE);
	}
	if (listen(server_fd, 3) < 0)
	{
		perror("listen");
		exit(EXIT_FAILURE);
	}
	if ((new_socket = accept(server_fd, (struct sockaddr *)&address,
					(socklen_t*)&addrlen))<0)
	{
		perror("accept");
		exit(EXIT_FAILURE);
	}

	while (true){
		valread = read( new_socket , buffer, 4000);
		printf("Got %s\n",buffer );
		pugi::xml_document doc;
		std::string t(buffer);
		eraseAllSubStr(t, "@n@");
		std::cout << t.c_str() << std::endl;
		pugi::xml_parse_result result = doc.load_string(t.c_str());
		if (result)
		{
			// Parse xml sent by gama
			pugi::xml_node root = doc.child("ummisco.gama.network.common.CompositeGamaMessage");
			pugi::xml_node node = root.child("contents");
			std::string data(node.first_child().value());

			eraseAllSubStr(data, "<string> ");
			eraseAllSubStr(data, " </string>");
			std::cout << data.c_str() << std::endl;
			node = root.child("emissionTimeStamp");
			std::cout << node.first_child().value()<< std::endl;

			if (data.find("Ping") != std::string::npos){

				std::cout << "Planner pinged. Send plan to gama, same procedure as for replan" << std::endl;
			}
			else if (data.find("replan") != std::string::npos){

				std::cout << "Asked to replan. We get a list of completed tasks by id, and a list of alive agents by id" << std::endl;
				std::cout << "When new plan send to gama here: " << std::endl;

				const char * json = {data.c_str()};
				std::cout << json << std::endl;
				rapidjson::Document document;  // Default template parameter uses UTF8 and MemoryPoolAllocator.


				// "normal" parsing, decode strings to new buffers. Can use other input stream via ParseStream().
				if (document.Parse(json).HasParseError()){
					std::cout << "Parse error, go home." << std::endl;
				}
				assert(document.IsObject());    // Document is a JSON value represents the root of DOM. Root can be either an object or array.

				const rapidjson::Value& tasks = document["tasks"].GetArray();
				const rapidjson::Value& agents = document["agents"].GetArray();

				std::vector< int > task_ids, agent_ids; // these vectors contain the lists of interest, i.e. completed tasks, alive agents. 

				for (rapidjson::Value::ConstValueIterator itr = tasks.Begin(); itr != tasks.End(); ++itr){
					task_ids.push_back(itr->GetInt()); 
					std::cout << itr->GetInt() << std::endl;
				}
				for (rapidjson::Value::ConstValueIterator itr = agents.Begin(); itr != agents.End(); ++itr){
					agent_ids.push_back(itr->GetInt());
					std::cout << itr->GetInt() << std::endl;
				}

				// Re-planning happens here ...

				// Format reply according to 
				// "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;"+string2send+"&lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n"
				hello = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;";
				hello += "string to send"; // modify this string as follows
				/*
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
				*/
				hello += "&lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n";
				send(new_socket , hello.c_str() , hello.length() , 0 );
				printf("Server replied hello\n");
			}
			else if (data.find("Mission Complete") != std::string::npos){

				std::cout << "Notified of mission complete" << std::endl;
			}
		}
	}

	
}

void client(){
	int sock = 0, valread;
	struct sockaddr_in serv_addr;
	std::string hello = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt;1;76.3275146484;38.3087158203;0,;0.0$2;97.2351074219;87.4938964844;3,1,;0.0$3;76.3275146484;38.3087158203;0,1,;0.0$4;76.3275146484;38.3087158203;3,;0.0$5;71.1517333984;8.80432128906;1,3,;0.0$6;71.1517333984;8.80432128906;1,0,;0.0$7;71.1517333984;8.80432128906;1,0,;0.0$8;71.1517333984;8.80432128906;3,;0.0$9;97.2351074219;87.4938964844;3,;0.0$10;97.2351074219;87.4938964844;1,0,3,;0.0$+29;15.0146484375;96.1303710938;3,;0.0;19;21;4$43;29.931640625;88.8519287109;3,;0.0;22;24;4$44;77.4658203125;23.9532470703;1,;0.0;1;3;5$45;3.88488769531;2.18811035156;3,;0.0;18;20;8$1;29.1931152344;32.5958251953;0,;0.0;9;11;7$27;32.7239990234;17.2760009766;3,;0.0;4;6;4$23;64.9108886719;52.2979736328;1,;0.0;6;8;5$20;39.1021728516;32.5500488281;0,;0.0;6;8;7$19;6.80541992188;5.908203125;3,;0.0;16;18;8$36;11.0870361328;85.3179931641;3,;0.0;15;17;5$2;42.5659179688;72.3480224609;1,;0.0;22;24;2$48;11.7248535156;70.6024169922;1,;0.0;12;14;6$3;80.4016113281;66.8487548828;1,;0.0;5;7;10$14;49.2218017578;52.0141601562;3,;0.0;11;13;9$42;37.5366210938;4.58984375;0,;0.0;7;9;3$12;89.1143798828;1.57470703125;1,;0.0;13;15;10$10;41.7510986328;32.8308105469;1,;0.0;3;5;7$0;25.4058837891;36.4990234375;3,;0.0;8;10;4$9;82.6446533203;79.6661376953;1,;0.0;7;9;2$32;25.3723144531;72.8637695312;0,;0.0;19;21;6$13;2.68249511719;98.7396240234;1,;0.0;20;22;5$8;0.302124023438;11.2091064453;0,;0.0;17;19;3$33;97.6806640625;89.2700195312;3,;0.0;0;2;2$26;16.7022705078;12.1490478516;0,;0.0;13;15;3$18;33.8043212891;2.40478515625;1,;0.0;9;11;3$6;7.83996582031;64.8956298828;0,;0.0;15;17;6$16;18.2769775391;63.1225585938;1,;0.0;9;11;6$21;32.0556640625;23.0255126953;3,;0.0;16;18;9$31;53.4912109375;11.7156982422;1,;0.0;3;5;3$46;71.6247558594;81.8084716797;3,;0.0;2;4;9$4;30.4138183594;65.6829833984;0,;0.0;21;23;1$41;85.7788085938;70.6878662109;1,;0.0;10;12;2$35;9.72595214844;28.7078857422;0,;0.0;21;23;3$24;95.2789306641;69.4091796875;1,;0.0;4;6;2$30;77.7862548828;64.4287109375;3,;0.0;6;8;9$5;21.4935302734;14.4622802734;3,;0.0;20;22;9$47;17.7093505859;41.8304443359;1,;0.0;12;14;7$22;60.1928710938;80.5633544922;3,;0.0;18;20;2$28;85.3820800781;68.5943603516;0,;0.0;13;15;1$40;80.7495117188;81.9122314453;0,;0.0;1;3;10$25;61.4959716797;49.1882324219;0,;0.0;8;10;1$15;91.9097900391;36.9689941406;0,;0.0;1;3;1$11;67.9870605469;61.5661621094;1,;0.0;14;16;2$17;29.6356201172;68.1976318359;3,;0.0;14;16;4$7;34.5581054688;40.5151367188;1,;0.0;4;6;6$49;1.49536132812;91.3208007812;1,;0.0;18;20;5$39;85.6964111328;56.0699462891;3,;0.0;4;6;8$37;85.0738525391;42.4987792969;0,;0.0;4;6;1$38;17.1691894531;83.1298828125;1,;0.0;22;24;6$34;66.5374755859;58.7677001953;1,;0.0;19;21;7$&lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n";
	hello = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt; {\"msg_type\":\"replan\",\"tasks\":[1,2,3],\"agents\":[5,6,7]} &lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n";
	//hello = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt; {\"msg_type\":\"Ping\",\"tasks\":[1,2,3],\"agents\":[5,6,7]} &lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n";
	//hello = "@b@@r@Client@b@@r@server_group@b@@r@<ummisco.gama.network.common.CompositeGamaMessage>@n@  <unread>true</unread>@n@  <sender class='string'>Client</sender>@n@  <receivers class='string'>server_group</receivers>@n@  <contents class='string'>&lt;string&gt; {\"msg_type\":\"Mission Complete\",\"tasks\":[1,2,3],\"agents\":[5,6,7]} &lt;/string&gt;</contents>@n@  <emissionTimeStamp>8</emissionTimeStamp>@n@</ummisco.gama.network.common.CompositeGamaMessage>\n";
	char buffer[1024] = {0};
	if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
	{
		printf("\n Socket creation error \n");

	}

	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(PORT);
	
	// Convert IPv4 and IPv6 addresses from text to binary form
	if(inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr)<=0)
	{
		printf("\nInvalid address/ Address not supported \n");

	}

	if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
	{
		printf("\nConnection Failed \n");

	}
	send(sock , hello.c_str() , hello.length() , 0 );
	printf("Client said hello, data length %lu \n ", hello.length());
	valread = read( sock , buffer, 1024);
	printf("%s\n",buffer );
}

int main(int argc, char const *argv[])
{
	thread t1(server);

    // create a client
	client();
    // Makes the main thread wait for the new thread to finish execution, therefore blocks its own execution.
    t1.join();

	return 0;
}

