%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 80 -*-
%% ex: ts=4 sw=4 et
%% @author Tyler Cloke <tyler@chef.io>
%% @author Marc Paradise <marc@chef.io>
%% Copyright 2015 Chef Software, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%

-module(oc_chef_wm_keys_SUITE).

-include_lib("common_test/include/ct.hrl").
-include("../../../include/oc_chef_wm.hrl").
-include_lib("eunit/include/eunit.hrl").

-compile([export_all, {parse_transform, lager_transform}]).

-define(CLIENT_NAME, <<"client1">>).
-define(CLIENT_NAME2, <<"client2">>).
-define(CLIENT_AUTHZ_ID, <<"00000000000000000000000000000003">>).

-define(USER_NAME, <<"user1">>).
-define(USER_NAME2, <<"user2">>).
-define(ADMIN_USER_NAME, <<"admin">>).
-define(USER_AUTHZ_ID, <<"00000000000000000000000000000004">>).
-define(USER2_AUTHZ_ID, <<"00000000000000000000000000000006">>).
-define(ADMIN_AUTHZ_ID, <<"90000000000000000000000000000004">>).

-define(ORG_NAME, <<"testorg">>).
-define(ORG_AUTHZ_ID, <<"10000000000000000000000000000002">>).

-define(KEY1NAME, <<"key1">>).
-define(KEY1EXPIRE, {datetime, {{2099,12,31},{00,00,00}}}).
-define(KEY1EXPIRESTRING, <<"2099-12-31T00:00:00Z">>).
-define(KEY2NAME, <<"key2">>).
-define(KEY2EXPIRE, {datetime, {{2010,12,31},{00,00,00}}}).
-define(KEY2EXPIRESTRING, <<"2010-12-31T00:00:00Z">>).

-define(DEFAULT_KEY_ENTRY, {<<"default">>, false}).
-define(KEY_1_ENTRY, { ?KEY1NAME, false } ).
-define(KEY_2_ENTRY, { ?KEY2NAME, true } ).

init_per_suite(LastConfig) ->
    Config = chef_test_db_helper:start_db(LastConfig, "oc_chef_wm_itests"),
    Config2 = setup_helper:start_server(Config),
    make_org(?ORG_NAME, ?ORG_AUTHZ_ID),
    OrgId = chef_db:fetch_org_id(context(), ?ORG_NAME),
    {ok, PubKey} = file:read_file("../../spki_public.pem"),
    [{org_id, OrgId}, {pubkey, PubKey}] ++ Config2.

end_per_suite(Config) ->
    setup_helper:base_end_per_suite(Config).

all() ->
    [list_client_default_key,
     list_user_default_key,
     list_client_multiple_keys,
     list_user_multiple_keys,
     list_client_no_keys,
     list_user_no_keys,
     get_client_default_key,
     get_user_default_key,
     get_client_multiple_keys,
     get_user_multiple_keys,
     get_client_no_keys,
     get_user_no_keys,
     get_client_wrong_key,
     get_user_wrong_key,
     get_key_for_nonexistant_user,
     get_key_for_nonexistant_client,
     post_user_new_valid_key,
     post_client_new_valid_key,
     post_new_key_invalid_date,
     post_new_key_invalid_utc_date,
     post_new_key_invalid_digits_date,
     post_new_key_well_formed_invalid_date,
     post_key_with_infinity_date,
     post_key_with_invalid_key_name,
     post_key_with_invalid_public_key,
     post_conflicting_user_key,
     post_conflicting_client_key,
     post_multiple_valid_user_keys,
     post_multiple_valid_client_keys
     ].

%% GET /organizations/org/clients/client/keys && GET /users/client/keys
list_client_default_key(_) ->
    Result = http_keys_request(get, client, ?CLIENT_NAME),
    ?assertMatch({ok, "200", _, _} , Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = client_key_list_ejson(?CLIENT_NAME, [?DEFAULT_KEY_ENTRY]),
    ?assertMatch(ExpectedEJ, BodyEJ),
    ok.

list_user_default_key(_) ->
    Result = http_keys_request(get, user, ?USER_NAME),
    ?assertMatch({ok, "200", _, _} , Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = user_key_list_ejson(?USER_NAME, [?DEFAULT_KEY_ENTRY]),
    ?assertMatch(ExpectedEJ, BodyEJ),
    ok.

list_client_multiple_keys(_) ->
    Result = http_keys_request(get, client, ?CLIENT_NAME),
    ?assertMatch({ok, "200", _, _} , Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = client_key_list_ejson(?CLIENT_NAME, [?DEFAULT_KEY_ENTRY, ?KEY_1_ENTRY, ?KEY_2_ENTRY]),
    ?assertMatch(ExpectedEJ, BodyEJ),
    ok.

list_user_multiple_keys(_) ->
    Result = http_keys_request(get, user, ?USER_NAME),
    ?assertMatch({ok, "200", _, _} , Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = user_key_list_ejson(?USER_NAME, [?DEFAULT_KEY_ENTRY, ?KEY_1_ENTRY, ?KEY_2_ENTRY]),
    ?assertMatch(ExpectedEJ, BodyEJ),
    ok.

list_client_no_keys(_) ->
    Result = http_keys_request(get, client, ?ADMIN_USER_NAME),
    ?assertMatch({ok, "200", _, "[]"} , Result),
    ok.

list_user_no_keys(_) ->
    Result = http_keys_request(get, user, ?ADMIN_USER_NAME),
    ?assertMatch({ok, "200", _, "[]"} , Result),
    ok.

%% GET /organizations/org/clients/client/keys/key && GET /users/client/keys/key
get_client_default_key(Config) ->
    Result = http_named_key_request(get, client, ?CLIENT_NAME, "default"),
    ?assertMatch({ok, "200", _, _}, Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = new_key_ejson(Config, <<"default">>, <<"infinity">>),
    ?assertMatch(ExpectedEJ, BodyEJ),
    ok.

get_user_default_key(Config) ->
    Result = http_named_key_request(get, user, ?USER_NAME, "default"),
    ?assertMatch({ok, "200", _, _}, Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = new_key_ejson(Config, <<"default">>, <<"infinity">>),
    ?assertMatch(ExpectedEJ, BodyEJ),
    ok.

get_client_multiple_keys(Config) ->
    %% KEY1
    Result = http_named_key_request(get, client, ?CLIENT_NAME, ?KEY1NAME),
    ?assertMatch({ok, "200", _, _}, Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = new_key_ejson(Config, ?KEY1NAME, ?KEY1EXPIRESTRING),
    ?assertMatch(ExpectedEJ, BodyEJ),

    %% KEY2
    Result2 = http_named_key_request(get, client, ?CLIENT_NAME, ?KEY2NAME),
    ?assertMatch({ok, "200", _, _} , Result2),
    BodyEJ2 = chef_json:decode(response_body(Result2)),
    ExpectedEJ2 = new_key_ejson(Config, ?KEY2NAME, ?KEY2EXPIRESTRING),
    ?assertMatch(ExpectedEJ2, BodyEJ2),
    ok.

get_user_multiple_keys(Config) ->
    %% KEY1
    Result = http_named_key_request(get, user, ?USER_NAME, ?KEY1NAME),
    ?assertMatch({ok, "200", _, _}, Result),
    BodyEJ = chef_json:decode(response_body(Result)),
    ExpectedEJ = new_key_ejson(Config, ?KEY1NAME, ?KEY1EXPIRESTRING),
    ?assertMatch(ExpectedEJ, BodyEJ),

    %% KEY2
    Result2 = http_named_key_request(get, user, ?USER_NAME, ?KEY2NAME),
    ?assertMatch({ok, "200", _, _}, Result2),
    BodyEJ2 = chef_json:decode(response_body(Result2)),
    ExpectedEJ2 = new_key_ejson(Config, ?KEY2NAME, ?KEY2EXPIRESTRING),
    ?assertMatch(ExpectedEJ2, BodyEJ2),
    ok.

get_client_no_keys(_) ->
    Result = http_named_key_request(get, client, ?ADMIN_USER_NAME, "default"),
    ?assertMatch({ok, "404", _, _} , Result),
    ok.

get_user_no_keys(_) ->
    Result = http_named_key_request(get, user, ?ADMIN_USER_NAME, "default"),
    ?assertMatch({ok, "404", _, _} , Result),
    ok.

get_client_wrong_key(_) ->
    Result = http_named_key_request(get, client, ?ADMIN_USER_NAME, "wrong_key"),
    ?assertMatch({ok, "404", _, _} , Result),
    ok.

get_user_wrong_key(_) ->
    Result = http_named_key_request(get, user, ?ADMIN_USER_NAME, "wrong_key"),
    ?assertMatch({ok, "404", _, _} , Result),
    ok.

get_key_for_nonexistant_user(_) ->
    Result = http_named_key_request(get, user, ?ADMIN_USER_NAME, "default"),
    ?assertMatch({ok, "404", _, _} , Result),
    ok.

get_key_for_nonexistant_client(_) ->
    Result = http_named_key_request(get, client, ?ADMIN_USER_NAME, "default"),
    ?assertMatch({ok, "404", _, _} , Result),
    ok.

%% POST /organizations/org/clients/client/keys && POST /users/client/keys
post_client_new_valid_key(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-24T22:49:08Z">>)),
    Result = http_keys_request(post, client, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "201", _, _}, Result).

post_user_new_valid_key(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-25T22:49:08Z">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "201", _, _}, Result).

post_new_key_invalid_date(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"bad-date">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "400", _, _}, Result),

    {_, _, _, UnparsedMessage} = Result,
    [ParsedMessage] = ej:get({<<"error">>},chef_json:decode(UnparsedMessage)),
    ExpectedMessage = ?BAD_DATE_MESSAGE(<<"expiration_date">>),
    ?assertMatch(ExpectedMessage, ParsedMessage).

post_new_key_invalid_utc_date(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-24T22:49:08">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "400", _, _}, Result),

    {_, _, _, UnparsedMessage} = Result,
    [ParsedMessage] = ej:get({<<"error">>},chef_json:decode(UnparsedMessage)),
    ExpectedMessage = ?BAD_DATE_MESSAGE(<<"expiration_date">>),
    ?assertMatch(ExpectedMessage, ParsedMessage).

post_new_key_invalid_digits_date(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2-1-2T2:4:0Z">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "400", _, _}, Result),

    {_, _, _, UnparsedMessage} = Result,
    [ParsedMessage] = ej:get({<<"error">>},chef_json:decode(UnparsedMessage)),
    ExpectedMessage = ?BAD_DATE_MESSAGE(<<"expiration_date">>),
    ?assertMatch(ExpectedMessage, ParsedMessage).

post_new_key_well_formed_invalid_date(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2010-01-35T00:00:00Z">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "400", _, _}, Result),

    {_, _, _, UnparsedMessage} = Result,
    [ParsedMessage] = ej:get({<<"error">>},chef_json:decode(UnparsedMessage)),
    ExpectedMessage = ?BAD_DATE_MESSAGE(<<"expiration_date">>),
    ?assertMatch(ExpectedMessage, ParsedMessage).

post_key_with_infinity_date(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"infinity">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "201", _, _}, Result).

post_key_with_invalid_key_name(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"invalid^character">>, <<"2099-10-25T22:49:08Z">>)),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "400", _, _}, Result).

post_key_with_invalid_public_key(_) ->
    Ejson = {[{name, <<"test1">>}, {public_key, <<"-----BEGIN PUBLIC KEY-----\ninvalid_key\n-----END PUBLIC KEY-----">>}, {expiration_date, <<"2099-10-25T22:49:08Z">>}]},
    Body = chef_json:encode(Ejson),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "400", _, _}, Result).

post_conflicting_user_key(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-25T22:49:08Z">>)),
    http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    Result = http_keys_request(post, user, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "409", _, _}, Result).

post_conflicting_client_key(Config) ->
    Body = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-24T22:49:08Z">>)),
    http_keys_request(post, client, ?ADMIN_USER_NAME, Body),
    Result = http_keys_request(post, client, ?ADMIN_USER_NAME, Body),
    ?assertMatch({ok, "409", _, _}, Result).

post_multiple_valid_user_keys(Config) ->
    Body1 = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-25T22:49:08Z">>)),
    Result1 = http_keys_request(post, user, ?ADMIN_USER_NAME, Body1),
    ?assertMatch({ok, "201", _, _}, Result1),
    Body2 = chef_json:encode(new_key_ejson(Config, <<"test2">>, <<"2099-10-25T22:49:08Z">>)),
    Result2 = http_keys_request(post, user, ?ADMIN_USER_NAME, Body2),
    ?assertMatch({ok, "201", _, _}, Result2).

post_multiple_valid_client_keys(Config) ->
    Body1 = chef_json:encode(new_key_ejson(Config, <<"test1">>, <<"2099-10-24T22:49:08Z">>)),
    Result1 = http_keys_request(post, client, ?ADMIN_USER_NAME, Body1),
    ?assertMatch({ok, "201", _, _}, Result1),
    Body2 = chef_json:encode(new_key_ejson(Config, <<"test2">>, <<"2099-10-24T22:49:08Z">>)),
    Result2 = http_keys_request(post, client, ?ADMIN_USER_NAME, Body2),
    ?assertMatch({ok, "201", _, _}, Result2).

%% Test case initializers
init_per_testcase(TestCase, Config) when TestCase =:= post_new_key_invalid_date;
                                         TestCase =:= post_new_key_invalid_digits_date;
                                         TestCase =:= post_new_key_well_formed_invalid_date;
                                         TestCase =:= post_new_key_invalid_utc_date ->
    make_admin_non_admin_and_client(Config);
init_per_testcase(TestCase, Config) when TestCase =:= post_client_new_valid_key;
                                         TestCase =:= post_conflicting_client_key;
                                         TestCase =:= post_multiple_valid_client_keys ->
    make_admin_and_client(Config);
init_per_testcase(TestCase, Config) when TestCase =:= post_user_new_valid_key;
                                         TestCase =:= post_key_with_infinity_date;
                                         TestCase =:= post_key_with_invalid_key_name;
                                         TestCase =:= post_key_with_invalid_public_key;
                                         TestCase =:= post_conflicting_user_key;
                                         TestCase =:= post_multiple_valid_user_keys ->
    make_admin_non_admin_and_client(Config);
init_per_testcase(list_user_default_key,  Config) ->
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    Config;
init_per_testcase(list_client_default_key, Config) ->
    make_client(Config, ?CLIENT_NAME),
    Config;
init_per_testcase(list_client_multiple_keys, Config) ->
    make_client(Config, ?CLIENT_NAME),
    ClientId = client_id(Config, ?CLIENT_NAME),
    add_key(Config, ClientId, ?KEY1NAME, ?KEY1EXPIRE),
    add_key(Config, ClientId, ?KEY2NAME, ?KEY2EXPIRE),
    Config;
init_per_testcase(list_user_multiple_keys, Config) ->
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    UserId = user_id(?USER_NAME),
    add_key(Config, UserId, ?KEY1NAME, ?KEY1EXPIRE),
    add_key(Config, UserId, ?KEY2NAME, ?KEY2EXPIRE),
    Config;
init_per_testcase(list_client_no_keys, Config) ->
    make_client(Config, ?CLIENT_NAME),
    sqerl:adhoc_delete(<<"keys">>, all),
    % make this user after clearing keys, so that we have a user
    % who can make the request.
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    Config;
init_per_testcase(list_user_no_keys, Config) ->
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    sqerl:adhoc_delete(<<"keys">>, all),
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    Config;
init_per_testcase(get_user_default_key,  Config) ->
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    Config;
init_per_testcase(get_client_default_key, Config) ->
    make_client(Config, ?CLIENT_NAME),
    Config;
init_per_testcase(get_client_multiple_keys, Config) ->
    make_client(Config, ?CLIENT_NAME),
    ClientId = client_id(Config, ?CLIENT_NAME),
    add_key(Config, ClientId, ?KEY1NAME, ?KEY1EXPIRE),
    add_key(Config, ClientId, ?KEY2NAME, ?KEY2EXPIRE),
    Config;
init_per_testcase(get_user_multiple_keys, Config) ->
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    UserId = user_id(?USER_NAME),
    add_key(Config, UserId, ?KEY1NAME, ?KEY1EXPIRE),
    add_key(Config, UserId, ?KEY2NAME, ?KEY2EXPIRE),
    Config;
init_per_testcase(get_client_no_keys, Config) ->
    make_client(Config, ?CLIENT_NAME),
    sqerl:adhoc_delete(<<"keys">>, all),
    % make this user after clearing keys, so that we have a user
    % who can make the request.
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    Config;
init_per_testcase(get_user_no_keys, Config) ->
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    sqerl:adhoc_delete(<<"keys">>, all),
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    Config;
init_per_testcase(get_client_wrong_key, Config) ->
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    make_client(Config, ?CLIENT_NAME),
    Config;
init_per_testcase(get_user_wrong_key, Config) ->
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    Config;
init_per_testcase(get_key_for_nonexistant_user, Config) ->
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    Config;
init_per_testcase(get_key_for_nonexistant_client, Config) ->
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    Config;
init_per_testcase(_, Config) ->
    Config.

%% Test case cleanup
end_per_testcase(_, Config) ->
    sqerl:adhoc_delete("clients", all),
    sqerl:adhoc_delete("users", all),
    Config.

make_admin_non_admin_and_client(Config) ->
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    make_user(Config, ?USER_NAME, ?USER_AUTHZ_ID),
    make_client(Config, ?CLIENT_NAME),
    Config.

make_admin_and_client(Config) ->
    make_user(Config, ?ADMIN_USER_NAME, ?ADMIN_AUTHZ_ID),
    make_client(Config, ?CLIENT_NAME),
    Config.

http_keys_request(Method, Type, Requestor) ->
    http_keys_request(Method, Type, Requestor, <<>>).

http_keys_request(Method, user, Requestor, Body) ->
    Url = "http://localhost:8000/users/user1/keys",
    ibrowse:send_req(Url, [{"x-ops-userid", binary_to_list(Requestor)},
                           {"accept", "application/json"},
                           {"content-type", "application/json"}], Method, Body);
http_keys_request(Method, client, Requestor, Body) ->
    Url = "http://localhost:8000/organizations/testorg/clients/client1/keys",
    ibrowse:send_req(Url, [{"x-ops-userid", binary_to_list(Requestor)},
                           {"accept", "application/json"},
                           {"content-type", "application/json"}], Method, Body).

http_named_key_request(Method, Type, Requestor, Name) ->
    http_named_keys_request(Method, Type, Requestor, Name, <<>>).

http_named_keys_request(Method, user, Requestor, Name, Body) ->
    Url = "http://localhost:8000/users/user1/keys/" ++ Name,
    ibrowse:send_req(Url, [{"x-ops-userid", binary_to_list(Requestor)},
                           {"accept", "application/json"},
                           {"content-type", "application/json"}], Method, Body);
http_named_keys_request(Method, client, Requestor, Name, Body) ->
    Url = "http://localhost:8000/organizations/testorg/clients/client1/keys/" ++ Name,
    ibrowse:send_req(Url, [{"x-ops-userid", binary_to_list(Requestor)},
                           {"accept", "application/json"},
                           {"content-type", "application/json"}], Method, Body).

% Some helpers to keep noise out of the tests...
make_org(OrgName, OrgAuthzId) ->
    Org = chef_object:new_record(oc_chef_organization, nil, OrgAuthzId,
                                 {[{<<"name">>, OrgName}, {<<"full_name">>, OrgName}]}),
    chef_db:create(Org, context(), OrgAuthzId).

make_client(Config, Name) ->
    OrgId = proplists:get_value(org_id, Config),
    PubKey = proplists:get_value(pubkey, Config),
    Client = chef_object:new_record(chef_client, OrgId, ?CLIENT_AUTHZ_ID,
                                    {[{<<"name">>, Name},
                                      {<<"validator">>, true},
                                      {<<"admin">>, true},
                                      {<<"public_key">>, PubKey}]}),
    chef_db:create(Client, context(), ?CLIENT_AUTHZ_ID).

make_user(Config, Name, AuthzId) ->
    OrgId = proplists:get_value(org_id, Config),
    make_user(Config, Name, AuthzId, OrgId).

make_user(Config, Name, AuthzId, OrgId) ->
    PubKey = proplists:get_value(pubkey, Config),
    Dom = <<"@somewhere.com">>,
    User = chef_object:new_record(chef_user, OrgId, AuthzId,
                                   {[{<<"username">>, Name},
                                     {<<"password">>, <<"zuperzecret">>},
                                     {<<"email">>, <<Name/binary,Dom/binary>>},
                                     {<<"public_key">>, PubKey},
                                     {<<"display_name">>, <<"someone">>}]}),
    chef_db:create(User, context(), ?USER_AUTHZ_ID).

%% TODO: should this be updated to use the POST endpoint?
add_key(Config, Id, KeyName, ExpirationDate) ->
    PubKey = proplists:get_value(pubkey, Config),
    {ok, 1} = sqerl:execute(<<"INSERT INTO KEYS (id, key_name, public_key, key_version, created_at, expires_at, last_updated_by, updated_at)
                               VALUES ($1, $2, $3, 1, CURRENT_TIMESTAMP, $4, 'me', CURRENT_TIMESTAMP )">>,
                  [Id, KeyName, PubKey, ExpirationDate]).

response_body({_, _, _, Body}) ->
    Body.

context() ->
    chef_db:make_context(<<"AB">>).

client_id(Config, Name) ->
    OrgId = proplists:get_value(org_id, Config),
    #chef_client{id = ClientId} = chef_db:fetch(#chef_client{org_id = OrgId, name = Name}, context()),
    ClientId.

user_id(Name) ->
    #chef_user{id = UserId} = chef_db:fetch(#chef_user{username = Name}, context()),
    UserId.

%% Expected Results and Inputs
%%
user_key_list_ejson(Name, KeyInfo) ->
    Base = <<"http://localhost:8000/users/">>,
    Keys = <<"/keys/">>,
    key_list_ejson(<<Base/binary,Name/binary,Keys/binary>>, KeyInfo).
client_key_list_ejson(Name, KeyInfo) ->
    Base = <<"http://localhost:8000/organizations/testorg/clients/">>,
    Keys = <<"/keys/">>,
    key_list_ejson(<<Base/binary,Name/binary,Keys/binary>>, KeyInfo).

key_list_ejson(BaseURI, KeyInfo) ->
    [ {[{<<"uri">>, <<BaseURI/binary,KeyName/binary>>},
        {<<"name">>, KeyName},
        {<<"expired">>, Expired}] } || {KeyName, Expired} <- KeyInfo].

new_key_ejson(Config, Name, Expiration) ->
    PubKey = proplists:get_value(pubkey, Config),
    {[{<<"name">>, Name}, {<<"public_key">>, PubKey}, {<<"expiration_date">>, Expiration}]}.
