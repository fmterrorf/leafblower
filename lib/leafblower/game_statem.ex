defmodule Leafblower.GameStatem do
  use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]
  alias Leafblower.{GameTicker, ProcessRegistry, Deck}

  @type player_id :: binary()

  @type player_info :: %{player_id() => %{name: binary()}}

  @type status :: :waiting_for_players | :round_started_waiting_for_response | :round_ended

  @type data :: %{
          id: binary(),
          active_players: MapSet.t(player_id()),
          player_info: player_info(),
          round_number: non_neg_integer(),
          round_player_answers: %{player_id() => Deck.card()},
          leader_player_id: player_id() | nil,
          winner_player_id: player_id() | nil,
          min_player_count: non_neg_integer(),
          countdown_duration: non_neg_integer(),
          player_score: %{player_id() => non_neg_integer()},
          deck: Deck.t(),
          player_cards: %{player_id() => Deck.card_set()},
          black_card: Deck.card(),
          discard_pile: Deck.card_set()
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
    deck = Keyword.get_lazy(arg, :deck, &Leafblower.Deck.get_cards/0)
    player_cards = Keyword.get(arg, :player_cards, %{})

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
        player_score: %{},
        player_cards: player_cards,
        deck: deck,
        winner_player_id: nil,
        black_card: nil
      },
      name: via_tuple(id)
    )
  end

  def join_player(game, player_id, player_name),
    do: GenStateMachine.call(game, {:join_player, player_id, player_name})

  def start_round(game, player_id), do: GenStateMachine.call(game, {:start_round, player_id})

  def submit_answer(game, player_id, answer),
    do: GenStateMachine.cast(game, {:submit_answer, player_id, answer})

  def pick_winner(game, player_id),
    do: GenStateMachine.cast(game, {:pick_winner, player_id})

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
        %{
          active_players: active_players,
          player_score: player_score,
          player_info: player_info,
          player_cards: player_cards
        } = data
      ) do
    data =
      %{
        data
        | # Right now we store the whole user data
          active_players: MapSet.put(active_players, player_id),
          player_score: Map.put(player_score, player_id, 0),
          player_info: Map.put(player_info, player_id, %{name: player_name, id: player_id}),
          player_cards: Map.put(player_cards, player_id, MapSet.new())
      }
      |> maybe_assign_leader(:start_of_game)

    {:keep_state, data, [{:reply, from, :ok}, {:next_event, :internal, :broadcast}]}
  end

  @impl true
  def handle_event(
        {:call, from},
        {:start_round, player_id},
        status,
        %{
          leader_player_id: player_id
        } = data
      )
      when status in [:waiting_for_players, :round_ended, :show_winner] do
    start_timer(data, :no_response_countdown)

    data = %{
      data
      | round_number: data.round_number + 1,
        round_player_answers: %{},
        winner_player_id: nil
    }

    data =
      if status == :show_winner do
        maybe_assign_leader(data, :end_of_round)
      else
        data
      end

    {:next_state, :round_started_waiting_for_response, data,
     [
       {:reply, from, :ok},
       {:next_event, :internal, :deal_cards},
       {:next_event, :internal, :broadcast}
     ]}
  end

  @impl true
  def handle_event(
        :cast,
        {:submit_answer, player_id, answer},
        :round_started_waiting_for_response,
        %{round_player_answers: round_player_answers} = data
      ) do
    data = %{
      data
      | round_player_answers: Map.put(round_player_answers, player_id, answer),
        player_cards: Map.update!(data.player_cards, player_id, &MapSet.delete(&1, answer))
    }

    if all_players_answered?(data) do
      stop_timer(data, :no_response_countdown)
      start_timer(data, :nonexistent_winner_countdown)
      {:next_state, :round_ended, data, [{:next_event, :internal, :broadcast}]}
    else
      {:keep_state, data, [{:next_event, :internal, :broadcast}]}
    end
  end

  @impl true
  def handle_event(
        :cast,
        {:pick_winner, player_id},
        :round_ended,
        %{player_score: player_score} = data
      ) do
    data = %{
      data
      | player_score: Map.update(player_score, player_id, 0, &(&1 + 1)),
        winner_player_id: player_id
    }

    stop_timer(data, :nonexistent_winner_countdown)
    {:next_state, :show_winner, data, [{:next_event, :internal, :broadcast}]}
  end

  # info

  @impl true
  def handle_event(
        :info,
        {:timer_end, :no_response_countdown},
        :round_started_waiting_for_response,
        data
      ) do
    start_timer(data, :nonexistent_winner_countdown)
    {:next_state, :round_ended, data, {:next_event, :internal, :broadcast}}
  end

  @impl true
  def handle_event(
        :info,
        {:timer_end, :nonexistent_winner_countdown},
        _status,
        %{leader_player_id: leader_player_id, active_players: active_players}
      ) do
    winnder_player_id = MapSet.delete(active_players, leader_player_id) |> Enum.random()
    :ok = GenServer.cast(self(), {:pick_winner, winnder_player_id})
    :keep_state_and_data
  end

  # enters
  def handle_event(:enter, :round_started_waiting_for_response, :round_ended, data) do
    if all_players_answered?(data) do
      :keep_state_and_data
    else
      player_anwered_ids =
        Map.keys(data.round_player_answers)
        |> MapSet.new()

      player_without_answer_ids =
        MapSet.delete(data.active_players, data.leader_player_id)
        |> MapSet.difference(player_anwered_ids)

      player_id_card_taken_and_cards =
        for {player_id, cards} <-
              Map.take(data.player_cards, MapSet.to_list(player_without_answer_ids)) do
          card_taken = Enum.random(cards)
          new_cards = MapSet.delete(cards, card_taken)
          {player_id, card_taken, new_cards}
        end

      round_player_answers =
        Enum.into(player_id_card_taken_and_cards, data.round_player_answers, fn {player_id, card,
                                                                                 _} ->
          {player_id, card}
        end)

      player_cards =
        Enum.into(player_id_card_taken_and_cards, data.player_cards, fn {player_id, _, cards} ->
          {player_id, cards}
        end)

      {:keep_state,
       %{data | round_player_answers: round_player_answers, player_cards: player_cards}}
    end
  end

  def handle_event(:enter, _event, _state, _data) do
    :keep_state_and_data
  end

  # internal
  def handle_event(:internal, :deal_cards, _state, data) do
    {black_card, deck} = Leafblower.Deck.take_black_card(data.deck)

    {player_cards, deck} = Leafblower.Deck.deal_white_card(deck, data.player_cards)

    {:keep_state, %{data | black_card: black_card, deck: deck, player_cards: player_cards}}
  end

  def handle_event(:internal, :broadcast, status, data) do
    Phoenix.PubSub.broadcast(
      Leafblower.PubSub,
      topic(data.id),
      {:game_state_changed, status, Map.drop(data, [:deck])}
    )

    :keep_state_and_data
  end

  def generate_game_code() do
    # Generate 3 server codes to try. Take the first that is unused.
    # If no unused ones found, add an error
    codes = Enum.map(1..3, fn _ -> do_generate_code() end)

    case Enum.find(codes, &(!server_found?(&1))) do
      nil ->
        # no unused game code found. Report server busy, try again later.
        {:error, "Didn't find unused code, try again later"}

      code ->
        {:ok, code}
    end
  end

  defp do_generate_code() do
    # Generate a single 4 character random code
    range = ?A..?Z

    1..5
    |> Enum.map(fn _ -> [Enum.random(range)] |> List.to_string() end)
    |> Enum.join("")
  end

  defp server_found?(game_code) do
    # Look up the game in the registry. Return if a match is found.
    case Horde.Registry.lookup(Leafblower.ProcessRegistry, game_code) do
      [] -> false
      [{pid, _} | _] when is_pid(pid) -> true
    end
  end

  defp start_timer(data, action_meta) do
    data.id
    |> GameTicker.via_tuple()
    |> GameTicker.start_tick(action_meta, data.countdown_duration)
  end

  defp stop_timer(data, action_meta) do
    data.id
    |> GameTicker.via_tuple()
    |> GameTicker.stop_tick(action_meta)
  end

  defp maybe_assign_leader(
         %{
           leader_player_id: leader_player_id,
           active_players: active_players
         } = data,
         :start_of_game
       ) do
    active_players = MapSet.to_list(active_players)

    if leader_player_id == nil do
      %{data | leader_player_id: active_players |> hd}
    else
      data
    end
  end

  defp maybe_assign_leader(
         %{
           leader_player_id: leader_player_id,
           active_players: active_players
         } = data,
         :end_of_round
       ) do
    active_players = MapSet.to_list(active_players)

    new_idx =
      rem(Enum.find_index(active_players, &(&1 == leader_player_id)) + 1, length(active_players))

    %{data | leader_player_id: Enum.at(active_players, new_idx)}
  end

  defp all_players_answered?(data) do
    MapSet.size(data.active_players) - 1 == map_size(data.round_player_answers)
  end

  defp topic(id), do: "#{__MODULE__}/#{id}"
end
