%% @private
-module(dk_nii_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% supervisor callbacks
-export([init/1]).

%%----------------------------------------------------------------------------
%% API
%%----------------------------------------------------------------------------

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%----------------------------------------------------------------------------
%% supervisor callbacks
%%----------------------------------------------------------------------------

init([]) ->
    {ok,
     {{one_for_one, 5, 10},
      [{dk_nii, {dk_nii, start_link, []},
        permanent, 2000, worker, [dk_nii]},
       {dk_nii_term_sup, {dk_nii_term_sup, start_link, []},
        permanent, 2000, supervisor, [dk_nii_term_sup]},
       {dk_nii_reg_sup, {dk_nii_reg_sup, start_link, []},
        permanent, 2000, supervisor, [dk_nii_reg_sup]}]}}.

%% Local variables:
%% mode: erlang
%% fill-column: 78
%% coding: latin-1
%% End:
