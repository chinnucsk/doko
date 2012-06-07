-module(dk_nii).

-behaviour(gen_server).

%% API
-export([add_post/2, posts/1]).
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%----------------------------------------------------------------------------
%% API
%%----------------------------------------------------------------------------

add_post(Term, DocId) ->
    gen_server:cast(?SERVER, {add, Term, DocId}).

posts(Term) ->
    gen_server:call(?SERVER, {get, Term}).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%----------------------------------------------------------------------------
%% gen_server callbacks
%%----------------------------------------------------------------------------

%% @private
init([]) ->
    {ok, #state{}}.

%% @private
handle_call({get, Term}, From, State) ->
    Server = dk_nii_reg:pid(Term),
    gen_server:cast(Server, {get, From}),
    {noreply, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% @private
handle_cast({add, Term, DocId}, State) ->
    Server = dk_nii_reg:pid(Term),
    dk_nii_term:add_doc_id(Server, DocId),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

%% @private
handle_info(_Info, State) ->
    {noreply, State}.

%% @private
terminate(_Reason, _State) ->
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%----------------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------------

%% Local variables:
%% mode: erlang
%% fill-column: 78
%% coding: latin-1
%% End:
