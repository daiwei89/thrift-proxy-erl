%%%-------------------------------------------------------------------
%%% File    : proxy_mops_ssrtb.erl
%%% Author  : Dai Wei <dai.wei@openx.com>
%%% Description :
%%%   Thrift callback uses Handler:handle_function. This module 
%%%   mainly provides that plus proxy-specific info on top of 
%%%   proxy_base.erl.
%%%
%%% Created : 15 May 2012 by Dai Wei <dai.wei@openx.com>
%%%-------------------------------------------------------------------

-module(proxy_mops_ssrtb).

%% ssRtbAuctionContext record
-include_lib( "ssrtb_thrift_erl/include/ssrtb_service_types.hrl").

%% User defined macros:
-define(THRIFT_SVC, ssRtbService_thrift).

%% API
-export([start_link/0,
         start_link/1,
         get_adtype/0,
         set_adtype/1]).

%% gen_thrift_proxy callbacks
-export([trim_args/2]).

%% Thrift callbacks
-export([stop/1,
         handle_function/2]).

%% autogenerated macros:
-define(SERVER_NAME, list_to_atom(atom_to_list(?MODULE) ++ "_server")).

%%====================================================================
%% API
%%====================================================================
% Default replay to false (a normal proxy)
start_link() ->
  start_link(proxy).

start_link(Mode) ->
  ServerPortEnv = list_to_atom(atom_to_list(?MODULE) ++ "_server_port"),
  ServerPort = thrift_proxy_app:get_env_var(ServerPortEnv),
  ClientPortEnv = list_to_atom(atom_to_list(?MODULE) ++ "_client_port"),
  ClientPort = thrift_proxy_app:get_env_var(ClientPortEnv),
  gen_thrift_proxy:start_link(?SERVER_NAME, 
      ?MODULE, ServerPort, ClientPort, ?THRIFT_SVC, Mode).

set_adtype(NewAdType) ->
  gen_thrift_proxy:set_adtype(?SERVER_NAME, NewAdType).

get_adtype() ->
  gen_thrift_proxy:get_adtype(?SERVER_NAME).

%%====================================================================
%% gen_thrift_proxy callback functions
%%====================================================================
% Trim away timestamp, trax.id, etc. Hack hack hack!
trim_args(Fun, Args) ->
  lager:debug("Entering ~p:trim_args/1. Function = ~p", [?MODULE, Fun]),
  %lager:debug("Args = ~p.", [Args]),
  if 
    Fun =:= solicit_bids ->
      KeysToRemove = [<<"ox.internal.timestamp">>, 
                      <<"ox.internal.trax_id">>,
                      <<"ox.publisher.floor">>,
                      <<"ox.internal.market.auction_sequence">>],
      AuctionContext = element(2, Args),
      ContextDict = AuctionContext#ssRtbAuctionContext.req_context,
      TrimmedDict = 
         gen_thrift_proxy:trim_args_helper(ContextDict, KeysToRemove),
      setelement(2, Args,
         AuctionContext#ssRtbAuctionContext{req_context=TrimmedDict});
   Fun =:= notify ->
      % Don't do anything for now.
      Args
  end.

%%====================================================================
%% Thrift callback functions
%%====================================================================
handle_function (Function, Args) when is_atom(Function), is_tuple(Args) ->
  lager:info("~p:handle_function -- Function = ~p.", [?MODULE, Function]),
  if 
      Function =:= notify ->
        %% notify is a cast function
        gen_thrift_proxy:handle_function_cast(?SERVER_NAME, Function, Args);
      true ->
        gen_thrift_proxy:handle_function(?SERVER_NAME, Function, Args)
  end.

stop(Server) ->
  thrift_socket_server:stop(Server),
  ok.
