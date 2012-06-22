%% @private
-module(doko_index_app).

-behaviour(application).

%% application callbacks
-export([start/2,stop/1]).

%%----------------------------------------------------------------------------
%% application callbacks
%%----------------------------------------------------------------------------

start(_StartType, _StartArgs) ->
    doko_index_top_sup:start_link().

stop(_State) ->
    ok.

%% Local variables:
%% mode: erlang
%% fill-column: 78
%% coding: latin-1
%% End:
