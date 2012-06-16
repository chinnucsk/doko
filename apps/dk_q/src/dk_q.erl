-module(dk_q).
-include_lib("proper/include/proper.hrl").

%% API
-export([execute/1]).

%% Record declarations ("q" is short for "query")
-record(and_q,  {l_sub_q :: q(), r_sub_q :: q()}).
-record(or_q,   {l_sub_q :: q(), r_sub_q :: q()}).
-record(not_q,  {sub     :: q()}).
-record(term_q, {keyword :: utf8_str()}).

%% Type definitions
-type q() :: {and_q,  q(), q()} |
             {or_q,   q(), q()} |
             {not_q,  q()     } |
             {term_q, utf8_str()}.
-type utf8_str() :: unicode:unicode_binary().

%%----------------------------------------------------------------------------
%% API
%%----------------------------------------------------------------------------

-spec execute(utf8_str()) -> gb_set(). %% TODO: might return an error
execute(Str) ->
    %% parse and preprocess query
    Clauses = [partition(flatten(X)) || X <- clauses(dnf(from_str(Str)))],
    %% fetch data
    Fetch = fun (Keyword) ->
                    %% FIXME: hardcoded language
                    DocIds = case dk_pp:terms(Keyword, "en") of
                                 [] ->
                                     stop_word;
                                 [X|[]] ->
                                     dk_idx:doc_ids(X);
                                 Xs ->
                                     gb_sets:intersection(
                                       plists:map(fun dk_idx:doc_ids/1, Xs))
                             end,
                    {Keyword,DocIds}
            end,
    Data = plists:mapreduce(
             Fetch,
             lists:usort(lists:flatten([Xs++Ys || {Xs,Ys} <- Clauses]))),
    %% calculate result
    Filter = fun (Keywords) -> [X || X <- Keywords, X /= stop_word] end,
    Calc =
        fun ({Keywords,NotKeywords}) ->
                case [dict:fetch(X, Data) || X <- Filter(Keywords)] of
                    [] ->
                        gb_sets:new();
                    Sets ->
                        gb_sets:subtract(
                          gb_sets:intersection(Sets),
                          gb_sets:union(
                            [dict:fetch(X, Data) || X <- NotKeywords]))
                end
        end,
    gb_sets:union(plists:map(Calc, Clauses)).

%%----------------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------------

%% @doc Converts a UTF-8 string to a query. Returns a query record plus the
%% depth of the corresponding tree.
-spec from_str(utf8_str()) -> {q(),pos_integer()}.
from_str(Str) ->
    {ok,ParseTree} = dk_q_parser:parse(scan(Str)),
    tree_to_query(ParseTree).

scan(<<C/utf8,Rest/bytes>>) ->
    case C of
        $( -> [{'(',1}|scan(Rest)];
        $) -> [{')',1}|scan(Rest)];
        $& -> [{'&',1}|scan(Rest)];
        $| -> [{'|',1}|scan(Rest)];
        $! -> [{'!',1}|scan(Rest)];
        32 -> scan(Rest); % skip spaces
        _  ->
            Regex = [<<"^([^()&|! ]*)(.*)$">>],
            Options = [unicode,global,{capture,all_but_first,binary}],
            case re:run(Rest, Regex, Options) of
                {match,[[Str,RestRest]]} ->
                    [{string,<<C,Str/bytes>>,1}|scan(RestRest)];
                _ ->
                    [{string,<<C>>,1}|scan(Rest)]
            end
    end;
scan(<<>>) ->
    [{'$end',1}].

tree_to_query({and_q,SubTreeL,SubTreeR}) ->
    {L, DepthL} = tree_to_query(SubTreeL),
    {R, DepthR} = tree_to_query(SubTreeR),
    {#and_q{l_sub_q = L,r_sub_q = R},max(DepthL, DepthR)+1};
tree_to_query({or_q,SubTreeL,SubTreeR}) ->
    {L, DepthL} = tree_to_query(SubTreeL),
    {R, DepthR} = tree_to_query(SubTreeR),
    {#or_q{l_sub_q = L,r_sub_q = R},max(DepthL, DepthR)+1};
tree_to_query({not_q,SubTree}) ->
    {Sub,Depth} = tree_to_query(SubTree),
    {#not_q{sub = Sub},Depth+1};
tree_to_query({term_q,{string,Keyword,_}}) ->
    {#term_q{keyword = Keyword},0}.

%% @doc Rewrites a query to disjunctive normal form.
-spec dnf({q(),pos_integer()}) -> q().
dnf({Q,0}) ->
    Q;
dnf({Q,D}) ->
    dnf(mv_not(Q), D).

dnf(Q, 1) ->
    Q;
dnf(Q, D) ->
    dnf(mv_and(Q), D-1).

mv_not({T,L,R}) ->
    {T,mv_not(L),mv_not(R)};
mv_not({not_q,{and_q,L,R}}) ->
    {or_q,mv_not({not_q,L}),mv_not({not_q,R})};
mv_not({not_q,{or_q,L,R}}) ->
    {and_q,mv_not({not_q,L}),mv_not({not_q,R})};
mv_not({not_q,{not_q,Q}}) ->
    mv_not(Q);
mv_not(Q) ->
    Q.

mv_and({and_q,Q,{or_q,L,R}}) ->
    {or_q,mv_and({and_q,Q,mv_and(L)}),mv_and({and_q,Q,mv_and(R)})};
mv_and({and_q,{or_q,L,R},Q}) ->
    {or_q,mv_and({and_q,Q,mv_and(L)}),mv_and({and_q,Q,mv_and(R)})};
mv_and({T,L,R}) ->
    {T,mv_and(L),mv_and(R)};
mv_and(Q) ->
    Q.

%% @doc Converts a query in DNF to a lists of AND queries.
clauses({or_q,L,R}) ->
    clauses(L) ++ clauses(R);
clauses(Q) ->
    [Q].

%% @doc Converts an AND clause to  a list of TERM and NOT queries.
flatten({and_q,L,R}) ->
    lists:flatten([flatten(L),flatten(R)]);
flatten(Q) ->
    [Q].

%% @doc Partitions a list of TERM and NOT queries into two lists, where the
%% first lists contains all terms in TERM queries and the second list contains
%% all terms in NOT queries.
partition(Qs) ->
    {Pos,Neg} = lists:partition(fun (Q) -> is_record(Q, term_q) end, Qs),
    {terms(Pos),terms(Neg)}.

terms(Qs) ->
    lists:usort([term(Q) || Q <- Qs]).

term({not_q,{term_q,T}}) ->
    T;
term({term_q,T}) ->
    T.

%%----------------------------------------------------------------------------
%% PropErties
%%----------------------------------------------------------------------------

prop_all_not_element() ->
    ?FORALL(X, q(), not_element(dnf({X,depth(X)}))).

not_element({_, L, R}) ->
    not_element(L) and not_element(R);
not_element(#not_q{sub = #term_q{}}) ->
    true;
not_element(#not_q{}) ->
    false;
not_element(#term_q{}) ->
    true.

depth({_,L,R}) ->
    max(depth(L),depth(R))+1;
depth({not_q,Q}) ->
    depth(Q)+1;
depth(_) ->
    0.

prop_no_nested_or() ->
    ?FORALL(X, q(), not nested_or(dnf({X,depth(X)}))).

nested_or({q,L,R}) ->
    (is_record(L, or_q) or is_record(R, or_q))
        orelse (nested_or(L) or nested_or(R));
nested_or({or_q,L,R}) ->
    nested_or(L) or nested_or(R);
nested_or({not_q,Q}) ->
    nested_or(Q);
nested_or(_) ->
    false.

%% Local variables:
%% mode: erlang
%% fill-column: 78
%% coding: latin-1
%% End:
