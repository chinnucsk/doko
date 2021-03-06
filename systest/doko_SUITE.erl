-module(doko_SUITE).
-include_lib("common_test/include/ct.hrl").

%% Tests
-export([test_del_doc/1,
         test_del_index/1,
         test_node_data_persistent/1,
         test_queries/1,
         test_redundancy/1,
         test_replication/1]).

%% CT functions
-export([all/0, groups/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([init_per_testcase/2, end_per_testcase/2]).

%%----------------------------------------------------------------------------
%% Tests
%%----------------------------------------------------------------------------

test_del_doc(_Config) ->
    Nodes = test_nodes(),
    %% add index
    Index = "index",
    ok = rpc:call(random(Nodes), doko_cluster, add_index, [Index, en]),
    %% add document
    Doc1 = doko_doc:new(1, [{"body", <<"hello world">>}], en),
    ok = rpc:call(random(Nodes), doko_cluster, add_doc, [Index, Doc1]),
    %% execute query and check result
    ExecQuery = fun () ->
                        rpc:call(random(Nodes),
                                 doko_query, execute, [Index, <<"'hello'">>])
                end,
    [1] = gb_sets:to_list(ExecQuery()),
    %% delete document
    ok = rpc:call(random(Nodes), doko_cluster, del_doc, [Index, Doc1]),
    timer:sleep(100),
    %% execute query and check result
    true = gb_sets:is_empty(ExecQuery()),
    ok.

test_del_index(_Config) ->
    Nodes = test_nodes(),
    %% add index
    Index = "index",
    ok = rpc:call(random(Nodes), doko_cluster, add_index, [Index, en]),
    timer:sleep(100), % adding indices takes some time 
    Name = doko_index_sup:name(Index),
    {Result1,[]} = rpc:multicall(Nodes, erlang, whereis, [Name]),
    0 = length([X || X <- Result1, X == undefined]),
    %% del index
    ok = rpc:call(random(Nodes), doko_cluster, del_index, [Index]),
    timer:sleep(100), % deleting indices takes some time 
    {Result2,[]} = rpc:multicall(Nodes, erlang, whereis, [Name]),
    Length = length(Nodes),
    Length = length([X || X <- Result2, X == undefined]),
    %% add it again
    ok = rpc:call(random(Nodes), doko_cluster, add_index, [Index, en]),
    Name = doko_index_sup:name(Index),
    timer:sleep(100), % adding indices takes some time 
    {Result3,[]} = rpc:multicall(Nodes, erlang, whereis, [Name]),
    0 = length([X || X <- Result3, X == undefined]),
    %% done
    ok.

test_node_data_persistent(_Config) ->
    Index = "index",
    Lang = en,
    Node = random(test_nodes()),
    ok = rpc:call(Node, doko_cluster, add_index, [Index, Lang]),
    Pid = rpc:call(Node, erlang, whereis, [doko_node]),
    true = rpc:call(Node, erlang, exit, [Pid,kill]),
    timer:sleep(100),
    Lang = rpc:call(Node, doko_cluster, index_lang, [Index]),
    ok.

test_queries(_Config) ->
    Nodes = test_nodes(),
    %% add index
    Index = "index",
    ok = rpc:call(random(Nodes), doko_cluster, add_index, [Index,en]),
    %% add documents
    Body1 = <<"hello world is a very popular programming example">>,
    Doc1 =
        doko_doc:new(1, [{"title", <<"hello world">>}, {"body", Body1}], en),
    ok = rpc:call(random(Nodes), doko_cluster, add_doc, [Index,Doc1]),
    Body2 = <<"goodbye world could be the next big thing in programming ",
              "examples">>,
    Doc2 = doko_doc:new(2, [{"title", <<"goodbye world">>}, {"body", Body2}],
                        en),
    ok = rpc:call(random(Nodes), doko_cluster, add_doc, [Index,Doc2]),
    Body3 = <<"aloha world combines both hello world and goodbye world">>,
    Doc3 =
        doko_doc:new(3, [{"title",<<"aloha world">>}, {"body", Body3}], en),
    ok = rpc:call(random(Nodes), doko_cluster, add_doc, [Index,Doc3]),
    %% test queries
    Query1 = <<"'aloha'">>,
    Result1 = rpc:call(random(Nodes), doko_query, execute, [Index, Query1]),
    [3] = gb_sets:to_list(Result1),
    Query2 = <<"('hello' | 'goodbye') & 'world' & !'aloha'">>,
    Result2 = rpc:call(random(Nodes), doko_query, execute, [Index, Query2]),
    [1,2] = lists:sort(gb_sets:to_list(Result2)),
    %% test document zones in queries
    Query3 = <<"'hello' in title">>,
    Result3 = rpc:call(random(Nodes), doko_query, execute, [Index, Query3]),
    [1] = lists:sort(gb_sets:to_list(Result3)),
    Query4 = <<"'hello' in body">>,
    Result4 = rpc:call(random(Nodes), doko_query, execute, [Index, Query4]),
    [1,3] = lists:sort(gb_sets:to_list(Result4)),
    Query5 = <<"'hello' in body | 'goodbye' in title">>,
    Result5 = rpc:call(random(Nodes), doko_query, execute, [Index, Query5]),
    [1,2,3] = lists:sort(gb_sets:to_list(Result5)),
    Query6 = <<"'hello' in body & !('aloha' in title)">>,
    Result6 = rpc:call(random(Nodes), doko_query, execute, [Index, Query6]),
    [1] = lists:sort(gb_sets:to_list(Result6)),
    ok.

test_redundancy(Config) ->
    Nodes = test_nodes(),
    %% add index
    Index = "index",
    ok = rpc:call(random(Nodes), doko_cluster, add_index, [Index, en]),
    %% add document
    Doc1 = doko_doc:new(1, [{"body", <<"hello world">>}], en),
    ok = rpc:call(random(Nodes), doko_cluster, add_doc, [Index,Doc1]),
    %% stop one of the nodes that has the data
    DataId = doko_router:invix_data_id(Index, <<"hello">>),
    [Node | _] = rpc:call(random(Nodes), doko_router, from, [DataId]),
    slave:stop(Node),
    %% execute query and check result
    Result = rpc:call(random(lists:delete(Node,Nodes)),
                      doko_query, execute, [Index,<<"'hello'">>]),
    [1] = gb_sets:to_list(Result),
    %% restart node
    start_node(Node,Config),
    ok.

test_replication(_Config) ->
    Nodes = test_nodes(),
    %% add index
    Index = "index",
    ok = rpc:call(random(Nodes), doko_cluster, add_index, [Index, en]),
    %% add document
    Doc1 = doko_doc:new(1, [{"body",<<"hello world">>}], en),
    ok = rpc:call(random(Nodes), doko_cluster, add_doc, [Index,Doc1]),
    %% test replication
    {Result,[]} = rpc:multicall(Nodes, doko_index, doc_ids,
                                [Index, <<"hello">>]),
    3 = length(lists:filter(fun (X) -> dict:size(X) == 0 end, Result)),
    ok.

%%----------------------------------------------------------------------------
%% CT functions
%%----------------------------------------------------------------------------

all() ->
    [{group,systest}].

groups() ->
    [{systest, [shuffle, sequence, {repeat, 8}],
      [
       test_del_doc,
       test_del_index,
       test_node_data_persistent,
       test_queries,
       test_redundancy,
       test_replication
      ]}].

init_per_suite(Config) ->
    Nodes = test_nodes(),
    %% put path in config
    Path = code:get_path(),
    NewConfig = [{path,Path}|Config],
    %% (re)start test nodes
    lists:foreach(fun (Node) -> start_node(Node, NewConfig) end, Nodes),
    ct_cover:add_nodes(Nodes),
    %% ready
    NewConfig.

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Nodes = test_nodes(),
    %% start doko on test nodes
    Result = lists:duplicate(length(Nodes), ok),
    {Result,[]} = rpc:multicall(Nodes, doko_node, start, []),
    {Result,[]} = rpc:multicall(Nodes, doko_cluster, start, [Nodes]),
    %% ready
    Config.

end_per_testcase(_TestCase, Config) ->
    case ?config(tc_status, Config) of
        {failed,_} ->
            %% leave doko running for inspection
            ok;
        ok ->
            Nodes = test_nodes(),
            %% stop doko on test nodes
            rpc:multicall(Nodes, doko_cluster, stop, []),
            rpc:multicall(Nodes, doko_node, stop, []),
            %% ready
            ok
    end.

start_node(Node, Config) ->
    slave:stop(Node),
    {ok,_} = slave:start(host(), short_name(Node)),
    Path = ?config(path, Config),
    rpc:call(Node, code, set_path, [Path]).

%%----------------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------------

test_nodes() ->
    lists:map(fun (N) -> node_name(N) end, lists:seq(1, 5)).

node_name(N) ->
    list_to_atom("doko_systest_node" ++ integer_to_list(N) ++ "@" ++ host()).

short_name(Node) ->
    list_to_atom(lists:takewhile(fun (C) -> C/= $@ end, atom_to_list(Node))).

host() ->
    lists:takewhile(fun (C) -> C /= $. end, net_adm:localhost()).

random(List) ->
    lists:nth(random:uniform(length(List)), List).

%% Local variables:
%% mode: erlang
%% fill-column: 78
%% coding: latin-1
%% End:
