defmodule Leafblower.GameStatem do
  use GenStateMachine
  alias Leafblower.{GameTicker, ProcessRegistry}

  @type state :: :waiting_for_players | :round_started_waiting_for_response | :round_ended

  @typedoc """
  Map of user id & answers
  """
  @type user_answers :: %{binary() => any()}

  @type data :: %{
          id: binary(),
          players: %{},
          round_number: non_neg_integer(),
          round_player_answers: map(),
          leader_player_id: binary() | nil,
          min_player_count: non_neg_integer(),
          countdown_duration: non_neg_integer(),
          ticker: any()
        }

  def start_link(arg) do
    id = Keyword.fetch!(arg, :id)
    round_number = Keyword.get(arg, :round_number, 0)
    round_player_answers = Keyword.get(arg, :round_player_answers, %{})
    players = Keyword.get(arg, :players, %{})
    min_player_count = Keyword.get(arg, :min_player_count, 3)
    leader_player_id = Keyword.get(arg, :leader_player_id)
    countdown_duration = Keyword.get(arg, :countdown_duration, 0)
    ticker = Keyword.fetch!(arg, :ticker)

    GenStateMachine.start_link(
      __MODULE__,
      %{
        id: id,
        players: players,
        round_number: round_number,
        round_player_answers: round_player_answers,
        leader_player_id: leader_player_id,
        min_player_count: min_player_count,
        countdown_duration: countdown_duration,
        ticker: ticker
      },
      name: via_tuple(id)
    )
  end

  def join_player(game, player_id), do: GenStateMachine.call(game, {:join_player, player_id})
  def start_round(game, player_id), do: GenStateMachine.call(game, {:start_round, player_id})

  def submit_answer(game, player_id, answer),
    do: GenStateMachine.cast(game, {:submit_answer, player_id, answer})

  def subscribe(id), do: Phoenix.PubSub.subscribe(Leafblower.PubSub, topic(id))
  def via_tuple(name), do: ProcessRegistry.via_tuple({__MODULE__, name})

  @spec get_state(any()) :: {state(), data()}
  def get_state(game), do: GenStateMachine.call(game, :get_state)

  @impl true
  @spec init(keyword) :: {:ok, state(), data()}
  def init(init_arg) do
    {:ok, :waiting_for_players, init_arg}
  end

  @impl true
  def handle_event({:call, from}, :get_state, state, data) do
    {:keep_state_and_data, [{:reply, from, {state, data}}]}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:join_player, player_id},
        :waiting_for_players,
        %{players: players} = data
      ) do
    data =
      %{data | players: Map.put(players, player_id, true)}
      |> maybe_assign_leader()

    {:keep_state, data, [{:reply, from, :ok}]}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:start_round, player_id},
        state,
        %{
          players: players,
          leader_player_id: player_id,
          min_player_count: min_player_count
        } = data
      )
      when map_size(players) >= min_player_count and state in [:waiting_for_players, :round_ended] do
    start_timer(data, :round_started_waiting_for_response)
    data = %{data | round_number: data.round_number + 1, round_player_answers: %{}}

    {:next_state, :round_started_waiting_for_response, data,
     [{:reply, from, :ok}, {:next_event, :internal, :broadcast}]}
  end

  @impl true
  def handle_event(
        :cast,
        {:submit_answer, player_id, answer},
        :round_started_waiting_for_response,
        %{players: players, round_player_answers: round_player_answers} = data
      )
      when map_size(round_player_answers) < map_size(players) do
    data = %{data | round_player_answers: Map.put(round_player_answers, player_id, answer)}

    {:keep_state, data,
     [{:next_event, :internal, :check_answer}, {:next_event, :internal, :broadcast}]}
  end

  # info

  @impl true
  def handle_event(
        :info,
        {:timer_tick, :round_started_waiting_for_response, duration},
        :round_started_waiting_for_response,
        _data
      )
      when duration > 0 do
    #  Publish duration to Phoenix Pubsub
    :keep_state_and_data
  end

  @impl true
  def handle_event(
        :info,
        {:timer_tick, :round_started_waiting_for_response, _duration},
        :round_started_waiting_for_response,
        data
      ) do
    {:next_state, :round_ended, data, {:next_event, :internal, :broadcast}}
  end

  # internal

  def handle_event(
        :internal,
        :check_answer,
        :round_started_waiting_for_response,
        %{players: players, round_player_answers: round_player_answers} = data
      )
      when map_size(players) == map_size(round_player_answers) do
    cancel_timer(data, :round_started_waiting_for_response)
    {:next_state, :round_ended, data, {:next_event, :internal, :broadcast}}
  end

  def handle_event(
        :internal,
        :check_answer,
        :round_started_waiting_for_response,
        _data
      ) do
    :keep_state_and_data
  end

  def handle_event(:internal, :broadcast, state, data) do
    :ok = Phoenix.PubSub.broadcast(Leafblower.PubSub, topic(data.id), {:game_state_changed, state, data})
    :keep_state_and_data
  end

  defp start_timer(data, action_meta) do
    GameTicker.start_tick(
      data.ticker,
      self(),
      action_meta,
      data.countdown_duration
    )
  end

  defp cancel_timer(data, action_meta) do
    GameTicker.stop_tick(data.ticker, action_meta)
  end

  defp maybe_assign_leader(%{players: players} = data) do
    if map_size(players) == 1 do
      %{data | leader_player_id: players |> Map.keys() |> hd}
    else
      data
    end
  end

  defp topic(id), do: "#{__MODULE__}/#{id}"
end
