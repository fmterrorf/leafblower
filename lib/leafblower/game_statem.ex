defmodule Leafblower.GameStatem do
  use GenStateMachine
  alias Leafblower.{GameTicker, ProcessRegistry}

  @type status :: :waiting_for_players | :round_started_waiting_for_response | :round_ended

  @type data :: %{
          id: binary(),
          players: %{},
          player_ids: list(binary()),
          player_id_idx: non_neg_integer(),
          round_number: non_neg_integer(),
          round_player_answers: %{binary() => any()},
          leader_player_id: binary() | nil,
          min_player_count: non_neg_integer(),
          countdown_duration: non_neg_integer(),
          player_score: %{binary() => non_neg_integer()},
          # Can be a Registry via tuple or pid
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
    ticker =  Leafblower.GameTicker.via_tuple(id)

    GenStateMachine.start_link(
      __MODULE__,
      %{
        id: id,
        players: players,
        player_ids: Map.keys(players),
        player_id_idx: 0,
        round_number: round_number,
        round_player_answers: round_player_answers,
        leader_player_id: leader_player_id,
        min_player_count: min_player_count,
        countdown_duration: countdown_duration,
        player_score: %{},
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
  def via_tuple(id), do: ProcessRegistry.via_tuple({__MODULE__, id})

  @spec get_state(any()) :: {status(), data()}
  def get_state(game), do: GenStateMachine.call(game, :get_state)

  @impl true
  @spec init(keyword) :: {:ok, status(), data()}
  def init(init_arg) do
    {:ok, :waiting_for_players, init_arg}
  end

  @impl true
  def handle_event({:call, from}, :get_state, status, data) do
    {:keep_state_and_data, [{:reply, from, {status, data}}]}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:join_player, player_id},
        :waiting_for_players,
        %{players: players, player_ids: player_ids, player_score: player_score} = data
      ) do
    data =
      %{
        data
        | # Right now we store the whole user data
          players: Map.put(players, player_id, Leafblower.ETSKv.get(player_id)),
          player_ids: [player_id | player_ids],
          player_score: Map.put(player_score, player_id, 0)
      }
      |> maybe_assign_leader()

    {:keep_state, data, [{:reply, from, :ok}, {:next_event, :internal, :broadcast}]}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:start_round, player_id},
        status,
        %{
          players: players,
          leader_player_id: player_id,
          min_player_count: min_player_count
        } = data
      )
      when map_size(players) >= min_player_count and
             status in [:waiting_for_players, :round_ended] do
    start_timer(data, :round_started_waiting_for_response)
    data = %{data | round_number: data.round_number + 1, round_player_answers: %{}}

    {:next_state, :round_started_waiting_for_response, data,
     [{:reply, from, :ok}, {:next_event, :internal, :broadcast}]}
  end

  @impl true
  def handle_event(
        :cast,
        {:submit_answer, player_id, answer},
        :round_started_waiting_for_response = status,
        %{players: players, round_player_answers: round_player_answers} = data
      )
      when map_size(round_player_answers) < map_size(players) do
    data = %{data | round_player_answers: Map.put(round_player_answers, player_id, answer)}

    if map_size(data.players) == map_size(data.round_player_answers) do
      GameTicker.stop_tick(data.ticker, status)
      {:next_state, :round_ended, data, [{:next_event, :internal, :broadcast}]}
    else
      {:keep_state, data, [{:next_event, :internal, :broadcast}]}
    end
  end

  # info

  @impl true
  def handle_event(
        :info,
        {:timer_end, :round_started_waiting_for_response = status},
        status,
        data
      ) do
    {:next_state, :round_ended, data, {:next_event, :internal, :broadcast}}
  end

  # internal

  def handle_event(:internal, :broadcast, status, data) do
    Phoenix.PubSub.broadcast(
      Leafblower.PubSub,
      topic(data.id),
      {:game_state_changed, status, data}
    )

    :keep_state_and_data
  end

  defp start_timer(data, action_meta) do
    GameTicker.start_tick(
      data.ticker,
      action_meta,
      data.countdown_duration
    )
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
