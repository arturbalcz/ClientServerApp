-module(client).
-compile(export_all).

start() ->
    Pid=spawn(fun() -> init() end),
    Pid.

start_link() ->
    Pid=spawn(fun() -> init() end),
    Pid.

terminate(ClientPid) ->
    ClientPid ! shutdown.

subscribe(ServerPid) ->
    Ref = make_ref(),
    ServerPid ! {self(), Ref, {subscribe}},
    receive
        {Ref, ok} ->
            io:format("Client process ~p recived message ~p~n",[self(), {Ref, ok}]),
            {ok, Ref};
        {'DOWN', Ref, process, Pid, Reason} ->
            io:format("Client process ~p recived message ~p~n",[self(), {'DOWN', Ref, process, Pid, Reason}]),
            {error, Reason}
    after 5000 ->
        {error, timeout}
    end.

add_event(ServerPid, Name, Description, TimeOut) ->
    Ref = make_ref(),
    ServerPid ! {self(), Ref, {add, Name, Description, TimeOut}},
    receive
        {Ref, Msg} ->
            io:format("Client process ~p recived message ~p~n",[self(), {Ref, Msg}]),
            Msg
    after 5000 ->
        {error, timeout}
    end.

cancel(ServerPid, Name) ->
    Ref = make_ref(),
    ServerPid ! {self(), Ref, {cancel, Name}},
    receive
        {Ref, Msg} ->
            io:format("Client process ~p recived message ~p~n",[self(), {Ref, Msg}]),
            Msg
    after 5000 ->
        {error, timeout}
    end.

listen(Delay) ->
    receive
        M = {done, _Name, _Description} ->
            [M | listen(0)]
    after Delay*1000 ->
        []
    end.

init() ->
    loop().

loop() ->
    receive
        {subscribe, ServerPid} ->
            subscribe(ServerPid),
            loop();
        {add, ServerPid, Name, Description, TimeOut} ->
            add_event(ServerPid, Name, Description, TimeOut),
            loop();
        {cancel, ServerPid, Name} ->
            cancel(ServerPid, Name),
            loop();
        shutdown ->
            exit(shutdown);
        {done, Name, Msg} ->
            io:format("Client process ~p recived message ~p~n",[self(), {done, Name, Msg}]),
            loop();
        Unknown ->
            io:format("Client process ~p recived unknown message: ~p~n",[self(), Unknown]),
            loop()
    end.