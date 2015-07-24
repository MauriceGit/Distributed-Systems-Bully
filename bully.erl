-module(bully).
-export([rpcOK/3, sendMessageToAll/4, process/4, processInit/2, start/0, print/1, initAll/3]).

print(Text) -> io:format("~p~n", [Text]).

rpcOK(Pid, ID, Request) ->
	Pid ! {Request, ID, self()},
	receive
		ok -> ok
		after 250 ->
			print("timout."),
			[]
	end.
	
% Leere Liste -> Abbruch
sendMessageToAll([], _, _, _) -> [];
% Sendet an alle/größere Prozesse die Nachricht weiter und gibt die Rückgabewerte als Liste zurück.
sendMessageToAll([H|T], JustBigger, ID, Message) when ((not JustBigger) or (element(1,H) > ID))
	% Filtert nur ok's raus.
	-> 	[rpcOK(element(2,H), ID, Message)] ++ [X || X <- sendMessageToAll(T, JustBigger, ID, Message), X == ok];
% An dieses Element keine Nachricht schicken und nur rekursiv weitermachen.
sendMessageToAll([_|T], JustBigger, ID, Message) 
	-> 	sendMessageToAll(T, JustBigger, ID, Message).

sendSimpleMessage([], _) -> ok;
sendSimpleMessage([H|T], Message)
	-> element(2,H) ! {Message, element(2,H)}, sendSimpleMessage(T, Message).

% Leere Antwortliste --> Ich bin Chef.
nextLevelElection([], ID, Processes, _, _)
	-> sendSimpleMessage(Processes, coordinator), process(ID, Processes, true, self());
% Nur neu starten, nix los.
nextLevelElection(_, ID, Processes, _, CID)
	-> process(ID, Processes, false, CID).

process(ID, Processes, Elected, CID) ->
	receive
		% Ich bin potentiell neuer Chef.
		{ startElection, StartID, Pid } when StartID < ID
			-> 	Pid ! ok,
				nextLevelElection(sendMessageToAll(Processes, true, ID, startElection), ID, Processes, Elected, CID);
		% Neuer Chef wurde auserkoren.
		{ coordinator, Pid }
			->	%print("Yeay, a new coordinator is elected."),
				process(ID, Processes, Elected, Pid);
		{ status, _} -> io:format("Status -- ID:~p, Elected:~p~n", [ID, Elected]), process(ID, Processes, Elected, CID)
		after 1000000 -> 
			% Wenn nach ner Zeit keine Abstimmung kommt, starten wir halt selber eine!
			nextLevelElection(sendMessageToAll(Processes, true, ID, startElection), ID, Processes, Elected, CID)
	end.


% List: [{ID, Pid}, ..]
processInit(ID, Elected) ->
	% Hier wird eine Nachricht mit einer Liste mit anderen Prozessen erwartet.
	receive
		{ initProcesses, List } 
			-> 	process(ID, List, Elected, self())				
		after 10000 -> ok
	end.
	
initAll([], _, _) 
	->	ok;
initAll([H|T], Message, List)
	->	H ! {Message, List}, initAll(T, Message, List).
	
start() ->
	P1 = spawn(?MODULE, processInit, [2, false]),
	P2 = spawn(?MODULE, processInit, [5, false]),
	P3 = spawn(?MODULE, processInit, [7, false]),
	P4 = spawn(?MODULE, processInit, [13, false]),
	P5 = spawn(?MODULE, processInit, [17, false]),
	P6 = spawn(?MODULE, processInit, [19, false]),
	P7 = spawn(?MODULE, processInit, [90, false]),
	List = [{2, P1}, {5, P2}, {7, P3}, {13, P4}, {17, P5}, {19, P6}, {90, P7}],
	Pids = [P1, P2, P3, P4, P5, P6, P7],
	initAll(Pids, initProcesses, List),
	
	P1 ! {startElection, 0, self()},
	
	receive
		after 20 -> ok
	end,
	
	initAll(Pids, status, List).











