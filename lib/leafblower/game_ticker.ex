defmodule Leafblower.GameTicker do
  use GenServer
  alias Leafblower.{GameTicker}

  defstruct [:id, :timer_ref, :countdown_left, :action_meta]

  def start_link(arg) do
    id = Keyword.fetch!(arg, :id)
    GenServer.start_link(__MODULE__, arg, name: via_tuple(id))
  end

  def start_tick(ticker, action_meta, duration_in_seconds),
    do: GenServer.cast(ticker, {:start_tick, action_meta, duration_in_seconds})

  def stop_tick(ticker, action_meta), do: GenServer.cast(ticker, {:stop_tick, action_meta})
  def subscribe(id), do: Phoenix.PubSub.subscribe(Leafblower.PubSub, topic(id))
  def via_tuple(id), do: Leafblower.ProcessRegistry.via_tuple({__MODULE__, id})

  @impl true
  def init(init_arg) do
    id = Keyword.fetch!(init_arg, :id)

    {:ok,
     %GameTicker{
       id: id,
       timer_ref: nil,
       action_meta: nil,
       countdown_left: 0
     }}
  end

  @impl true
  def handle_cast({:start_tick, action_meta, duration_in_seconds}, state) do
    if state.timer_ref != nil do
      Process.cancel_timer(state.timer_ref)
    end

    Phoenix.PubSub.broadcast(
      Leafblower.PubSub,
      topic(state.id),
      {:ticker_ticked, duration_in_seconds}
    )

    timer_ref = Process.send_after(self(), :tick, :timer.seconds(1))

    {:noreply,
     %GameTicker{
       state
       | countdown_left: duration_in_seconds,
         action_meta: action_meta,
         timer_ref: timer_ref
     }}
  end

  @impl true
  def handle_cast(
        {:stop_tick, action_meta},
        %GameTicker{action_meta: action_meta, id: id, timer_ref: timer_ref} = state
      ) do
    Phoenix.PubSub.broadcast(
      Leafblower.PubSub,
      topic(id),
      {:ticker_ticked, 0}
    )

    if timer_ref != nil do
      Process.cancel_timer(timer_ref)
    end

    {:noreply,
     %GameTicker{
       state
       | countdown_left: 0,
         action_meta: nil,
         timer_ref: nil
     }}
  end

  @impl true
  def handle_info(:tick, %GameTicker{id: id} = state) when state.countdown_left > 1 do
    timer_ref = Process.send_after(self(), :tick, :timer.seconds(1))
    state = %GameTicker{state | countdown_left: state.countdown_left - 1, timer_ref: timer_ref}

    Phoenix.PubSub.broadcast(
      Leafblower.PubSub,
      topic(id),
      {:ticker_ticked, state.countdown_left}
    )

    {:noreply, state}
  end

  def handle_info(:tick, %GameTicker{id: id} = state) do
    state = %GameTicker{state | timer_ref: nil}

    Leafblower.GameSupervisor.find_game(id)
    |> send({:timer_end, state.action_meta})

    {:noreply, state}
  end

  defp topic(id), do: "#{__MODULE__}/#{id}"
end
