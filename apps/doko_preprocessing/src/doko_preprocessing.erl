-module(doko_preprocessing).

%% API
-export([uterms/2]).

%%----------------------------------------------------------------------------
%% API
%%----------------------------------------------------------------------------

%% @doc Returns a list of terms with duplicates removed.
-spec uterms(doko_utf8:str(), doko_utf8:iso_639_1()) -> [doko_utf8:str()].
uterms(Text, Lang) ->
    Str = expand(Text, Lang),
    Mod = list_to_atom("doko_stemming_" ++ atom_to_list(Lang)),
    plists:usort(
      plists:map(
        fun (T) -> Mod:stem(T) end,
        plists:usort(
          [T||T <- tokenize(doko_utf8:case_fold(Str), Lang),
              not(stop_word(T, Lang))]))).

%%----------------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------------

%% TODO: move this code to separate modules (like stemming)
expand(Str, Lang) ->
    case Lang of
        nl -> Str;
        en ->
            re:replace(Str, <<"(.)n't">>, <<"\\1 not">>,
                       [unicode,global,{return,binary}])
    end.

tokenize(Str, Lang) ->
    RE = case Lang of
             en -> <<"[a-z0-9]+">>;
             nl -> unicode:characters_to_binary("[a-z0-9�����������]+")
         end,
    case re:run(Str, RE, [unicode,{capture,all,binary},global]) of
        {match, Tokens} -> lists:flatten(Tokens);
        nomatch         -> []
    end.

stop_word(Token, Lang) ->
    case Lang of
        en -> lists:member(Token, [
                                   <<"i">>,
                                   <<"me">>,
                                   <<"my">>,
                                   <<"myself">>,
                                   <<"we">>,
                                   <<"our">>,
                                   <<"ours">>,
                                   <<"ourselves">>,
                                   <<"you">>,
                                   <<"your">>,
                                   <<"yours">>,
                                   <<"yourself">>,
                                   <<"yourselves">>,
                                   <<"he">>,
                                   <<"him">>,
                                   <<"his">>,
                                   <<"himself">>,
                                   <<"she">>,
                                   <<"her">>,
                                   <<"hers">>,
                                   <<"herself">>,
                                   <<"it">>,
                                   <<"its">>,
                                   <<"itself">>,
                                   <<"they">>,
                                   <<"them">>,
                                   <<"their">>,
                                   <<"theirs">>,
                                   <<"themselves">>,
                                   <<"what">>,
                                   <<"which">>,
                                   <<"who">>,
                                   <<"whom">>,
                                   <<"this">>,
                                   <<"that">>,
                                   <<"these">>,
                                   <<"those">>,
                                   <<"am">>,
                                   <<"is">>,
                                   <<"are">>,
                                   <<"was">>,
                                   <<"were">>,
                                   <<"be">>,
                                   <<"been">>,
                                   <<"being">>,
                                   <<"have">>,
                                   <<"has">>,
                                   <<"had">>,
                                   <<"having">>,
                                   <<"do">>,
                                   <<"does">>,
                                   <<"did">>,
                                   <<"doing">>,
                                   <<"would">>,
                                   <<"should">>,
                                   <<"could">>,
                                   <<"ought">>,
                                   <<"cannot">>,
                                   <<"a">>,
                                   <<"an">>,
                                   <<"the">>,
                                   <<"and">>,
                                   <<"but">>,
                                   <<"if">>,
                                   <<"or">>,
                                   <<"because">>,
                                   <<"as">>,
                                   <<"until">>,
                                   <<"while">>,
                                   <<"of">>,
                                   <<"at">>,
                                   <<"by">>,
                                   <<"for">>,
                                   <<"with">>,
                                   <<"about">>,
                                   <<"against">>,
                                   <<"between">>,
                                   <<"into">>,
                                   <<"through">>,
                                   <<"during">>,
                                   <<"before">>,
                                   <<"after">>,
                                   <<"above">>,
                                   <<"below">>,
                                   <<"to">>,
                                   <<"from">>,
                                   <<"up">>,
                                   <<"down">>,
                                   <<"in">>,
                                   <<"out">>,
                                   <<"on">>,
                                   <<"off">>,
                                   <<"over">>,
                                   <<"under">>,
                                   <<"again">>,
                                   <<"further">>,
                                   <<"then">>,
                                   <<"once">>,
                                   <<"here">>,
                                   <<"there">>,
                                   <<"when">>,
                                   <<"where">>,
                                   <<"why">>,
                                   <<"how">>,
                                   <<"all">>,
                                   <<"any">>,
                                   <<"both">>,
                                   <<"each">>,
                                   <<"few">>,
                                   <<"more">>,
                                   <<"most">>,
                                   <<"other">>,
                                   <<"some">>,
                                   <<"such">>,
                                   <<"no">>,
                                   <<"nor">>,
                                   <<"not">>,
                                   <<"only">>,
                                   <<"own">>,
                                   <<"same">>,
                                   <<"so">>,
                                   <<"than">>,
                                   <<"too">>,
                                   <<"very">>
                                  ]);
        nl -> lists:member(Token, [
                                   <<"de">>,
                                   <<"en">>,
                                   <<"van">>,
                                   <<"ik">>,
                                   <<"te">>,
                                   <<"dat">>,
                                   <<"die">>,
                                   <<"in">>,
                                   <<"een">>,
                                   <<"hij">>,
                                   <<"het">>,
                                   <<"niet">>,
                                   <<"zijn">>,
                                   <<"is">>,
                                   <<"was">>,
                                   <<"op">>,
                                   <<"aan">>,
                                   <<"met">>,
                                   <<"als">>,
                                   <<"voor">>,
                                   <<"had">>,
                                   <<"er">>,
                                   <<"maar">>,
                                   <<"om">>,
                                   <<"hem">>,
                                   <<"dan">>,
                                   <<"zou">>,
                                   <<"of">>,
                                   <<"wat">>,
                                   <<"mijn">>,
                                   <<"men">>,
                                   <<"dit">>,
                                   <<"zo">>,
                                   <<"door">>,
                                   <<"over">>,
                                   <<"ze">>,
                                   <<"zich">>,
                                   <<"bij">>,
                                   <<"ook">>,
                                   <<"tot">>,
                                   <<"je">>,
                                   <<"mij">>,
                                   <<"uit">>,
                                   <<"der">>,
                                   <<"daar">>,
                                   <<"haar">>,
                                   <<"naar">>,
                                   <<"heb">>,
                                   <<"hoe">>,
                                   <<"heeft">>,
                                   <<"hebben">>,
                                   <<"deze">>,
                                   <<"u">>,
                                   <<"want">>,
                                   <<"nog">>,
                                   <<"zal">>,
                                   <<"me">>,
                                   <<"zij">>,
                                   <<"nu">>,
                                   <<"ge">>,
                                   <<"geen">>,
                                   <<"omdat">>,
                                   <<"iets">>,
                                   <<"worden">>,
                                   <<"toch">>,
                                   <<"al">>,
                                   <<"waren">>,
                                   <<"veel">>,
                                   <<"meer">>,
                                   <<"doen">>,
                                   <<"toen">>,
                                   <<"moet">>,
                                   <<"ben">>,
                                   <<"zonder">>,
                                   <<"kan">>,
                                   <<"hun">>,
                                   <<"dus">>,
                                   <<"alles">>,
                                   <<"onder">>,
                                   <<"ja">>,
                                   <<"eens">>,
                                   <<"hier">>,
                                   <<"wie">>,
                                   <<"werd">>,
                                   <<"altijd">>,
                                   <<"doch">>,
                                   <<"wordt">>,
                                   <<"wezen">>,
                                   <<"kunnen">>,
                                   <<"ons">>,
                                   <<"zelf">>,
                                   <<"tegen">>,
                                   <<"na">>,
                                   <<"reeds">>,
                                   <<"wil">>,
                                   <<"kon">>,
                                   <<"niets">>,
                                   <<"uw">>,
                                   <<"iemand">>,
                                   <<"geweest">>,
                                   <<"andere">>
                                  ]);
        _ -> false
    end.

%% Local variables:
%% mode: erlang
%% fill-column: 78
%% coding: latin-1
%% End:
