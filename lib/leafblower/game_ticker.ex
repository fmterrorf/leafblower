defmodule Leafblower.GameTicker do
  use GenServer
  alias Leafblower.{GameTicker}

  defstruct [:id, :from, :timer_ref, :countdown_left, :action_meta]

  def start_link(arg) do
    id = Keyword.fetch!(arg, :id)
    GenServer.start_link(__MODULE__, arg, name: via_tuple(id))
  end

  def start_tick(ticker, caller, action_meta, duration_in_seconds),
    do: GenServer.cast(ticker, {:start_tick, caller, action_meta, duration_in_seconds})

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
       from: nil,
       action_meta: nil,
       countdown_left: 0
     }}
  end

  @impl true
  def handle_cast({:start_tick, from, action_meta, duration_in_seconds}, state) do
    timer_ref = Process.send_after(self(), :tick, :timer.seconds(1))

    {:noreply,
     %GameTicker{
       state
       | countdown_left: duration_in_seconds,
         action_meta: action_meta,
         from: from,
         timer_ref: timer_ref
     }}
  end

  @impl true
  def handle_cast({:stop_tick, action_meta}, %{action_meta: action_meta} = state) do
    {:noreply,
     %GameTicker{
       state
       | countdown_left: 0,
         action_meta: nil,
         from: nil,
         timer_ref: nil
     }}
  end

  @impl true
  def handle_info(:tick, %GameTicker{id: id} = state) when state.countdown_left > 0 do
    timer_ref = Process.send_after(self(), :tick, :timer.seconds(1))
    state = %GameTicker{state | countdown_left: state.countdown_left - 1, timer_ref: timer_ref}

    Phoenix.PubSub.broadcast(
      Leafblower.PubSub,
      topic(id),
      {:ticker_ticked, state.countdown_left}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, %GameTicker{from: from} = state) do
    state = %GameTicker{state | countdown_left: 0, timer_ref: nil}
    send(from, {:timer_end, state.action_meta})
    {:noreply, state}
  end

  defp topic(id), do: "#{__MODULE__}/#{id}"
end
