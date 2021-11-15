defmodule Leafblower.GameStatem do
  use GenStateMachine
  alias Leafblower.{GameTicker, ProcessRegistry}

  @type status :: :waiting_for_players | :round_started_waiting_for_response | :round_ended

  @type data :: %{
          id: binary(),
          active_players: MapSet.t(),
          # player_info -> player_id: %{name: string}
          player_info: map(),
          round_number: non_neg_integer(),
          round_player_answers: %{binary() => any()},
          leader_player_id: binary() | nil,
          min_player_count: non_neg_integer(),
          countdown_duration: non_neg_integer(),
          player_score: %{binary() => non_neg_integer()}
        }

  def child_spec(init_arg) do
    id = Keyword.fetch!(init_arg, :id)

    %{
      id: "#{__MODULE__}-#{id}",
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :transient,
      shutdown: 10_000
    }
  end

  def start_link(arg) do
    id = Keyword.fetch!(arg, :id)
    round_number = Keyword.get(arg, :round_number, 0)
    round_player_answers = Keyword.get(arg, :round_player_answers, %{})
    active_players = Keyword.get(arg, :active_players, MapSet.new())
    min_player_count = Keyword.get(arg, :min_player_count, 3)
    leader_player_id = Keyword.get(arg, :leader_player_id)
    countdown_duration = Keyword.get(arg, :countdown_duration, 0)
    player_info = Keyword.get(arg, :player_info, %{})

    GenStateMachine.start_link(
      __MODULE__,
      %{
        id: id,
        active_players: active_players,
        round_number: round_number,
        round_player_answers: round_player_answers,
        leader_player_id: leader_player_id,
        min_player_count: min_player_count,
        countdown_duration: countdown_duration,
        player_info: player_info,
        player_score: %{}
      },
      name: via_tuple(id)
    )
  end

  def join_player(game, player_id, player_name),
    do: GenStateMachine.call(game, {:join_player, player_id, player_name})

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
        {:join_player, player_id, player_name},
        :waiting_for_players,
        %{active_players: active_players, player_score: player_score, player_info: player_info} =
          data
      ) do
    data =
      %{
        data
        | # Right now we store the whole user data
          active_players: MapSet.put(active_players, player_id),
          player_score: Map.put(player_score, player_id, 0),
          player_info: Map.put(player_info, player_id, %{name: player_name, id: player_id})
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
          active_players: %MapSet{map: player_map},
          leader_player_id: player_id,
          min_player_count: min_player_count
        } = data
      )
      when map_size(player_map) >= min_player_count and
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
        %{
          active_players: %MapSet{map: active_players_map},
          round_player_answers: round_player_answers
        } = data
      )
      when map_size(round_player_answers) < map_size(active_players_map) do
    round_player_answers = Map.put(round_player_answers, player_id, answer)
    data = %{data | round_player_answers: round_player_answers}

    if map_size(active_players_map) == map_size(round_player_answers) do
      data.id
      |> GameTicker.via_tuple()
      |> GameTicker.stop_tick(status)

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
    data.id
    |> GameTicker.via_tuple()
    |> GameTicker.start_tick(action_meta, data.countdown_duration)
  end

  defp maybe_assign_leader(data) do
    if data.leader_player_id == nil do
      %{data | leader_player_id: MapSet.to_list(data.active_players) |> hd}
    else
      data
    end
  end

  defp topic(id), do: "#{__MODULE__}/#{id}"
end
