-module(evserv).
-compile(export_all).

-record(state, {events, clients}).

-record(event, {clientPid="",
                name="",
                description="",
                pid,
                timeout={{1970,1,1},{0,0,0}}}).

start() ->
    Pid=spawn(fun() -> init() end),
    Pid.

start_link() ->
    Pid=spawn(fun() -> init() end),
    Pid.

terminate(ServerPid) ->
    ServerPid ! shutdown.

init() ->
    loop(#state{events=orddict:new(),
                clients=orddict:new()}).

loop(S=#state{}) ->
    receive
        {Pid, MsgRef, {subscribe}} ->
            io:format("Server process ~p recived message ~p~n",[self(), {Pid, MsgRef, {subscribe}}]),
            Ref = erlang:monitor(process, Pid),
            NewClients = orddict:store(Ref, Pid, S#state.clients),
            Pid ! {MsgRef, ok},
            loop(S#state{clients=NewClients});
        {Pid, MsgRef, {add, Name, Description, TimeOut}} ->
            io:format("Server process ~p recived message ~p~n",[self(), {Pid, MsgRef, {add, Name, Description, TimeOut}}]),
            case valid_datetime(TimeOut) of
                true ->
                    EventPid = event:start_link(Name, TimeOut),
                    NewEvents = orddict:store(Name,
                                              #event{clientPid=Pid,
                                                     name=Name,
                                                     description=Description,
                                                     pid=EventPid,
                                                     timeout=TimeOut},
                                              S#state.events),
                    Pid ! {MsgRef, ok},
                    loop(S#state{events=NewEvents});
                false ->
                    Pid ! {MsgRef, {error, bad_timeout}},
                    loop(S)
            end;
        {Pid, MsgRef, {cancel, Name}} ->
            io:format("Server process ~p recived message ~p~n",[self(), {Pid, MsgRef, {cancel, Name}}]),
            Events = case orddict:find(Name, S#state.events) of
                         {ok, E} ->
                             event:cancel(E#event.pid),
                             orddict:erase(Name, S#state.events);
                         error ->
                             S#state.events
                     end,
            Pid ! {MsgRef, ok},
            loop(S#state{events=Events});
        {done, Name} ->
            io:format("Server process ~p recived message ~p~n",[self(), {done, Name}]),
            case orddict:find(Name, S#state.events) of
                {ok, E} ->
                    send_to_clients({done, E#event.name, E#event.description},
                                    E#event.clientPid),
                    NewEvents = orddict:erase(Name, S#state.events),
                    loop(S#state{events=NewEvents});
                error ->
                    loop(S)
            end;
        shutdown ->
            exit(shutdown);
        {'DOWN', Ref, process, Pid, Reason} ->
            io:format("Server process ~p recived message ~p~n",[self(), {'DOWN', Ref, process, Pid, Reason}]),
            loop(S#state{clients=orddict:erase(Ref, S#state.clients)});
        code_change ->
            ?MODULE:loop(S);
        {Pid, debug} ->
            Pid ! S,
            loop(S);
        Unknown ->
            io:format("Server process ~p recived unknown message: ~p~n",[self(), Unknown]),
            loop(S)
    end.

send_to_clients(Msg, ClientPid) ->
    ClientPid ! Msg.

valid_datetime({Date,Time}) ->
    try
        calendar:valid_date(Date) andalso valid_time(Time)
    catch
        error:function_clause ->
            false
    end;
valid_datetime(_) ->
    false.

valid_time({H,M,S}) -> valid_time(H,M,S).

valid_time(H,M,S) when H >= 0, H < 24,
                       M >= 0, M < 60,
                       S >= 0, S < 60 -> true;
valid_time(_,_,_) -> false.