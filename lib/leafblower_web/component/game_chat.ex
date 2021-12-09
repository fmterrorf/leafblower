defmodule LeafblowerWeb.Component.GameChat do
  use LeafblowerWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, content: "")}
  end

  @impl true
  def handle_event("submit", %{"content" => content}, socket) do
    chat_publish(socket.assigns.game_id, socket.assigns.user_id, content)
    {:noreply, assign(socket, content: "")}
  end

  @impl true
  def render(assigns) do

    ~H"""
    <aside id="sidenav-open">
     <ul style="background-color: white; width: 100%; max-height: 50vh; overflow: scroll;" phx-hook="ChatList" phx-update="append">
       <%= if @message do %>
       <li id={@message.id}><%= @player_info[@message.from].name %>: <%= @message.content %></li>
       <% end %>
     </ul>
     <form phx-submit="submit" phx-target={@myself}>
       <div>
         <input name="content" type="text" rows="4" value={@content} />
         <button type="submit">Submit</button>
       </div>
     </form>
    </aside>
    """
  end

  def chat_topic(id), do: "#{__MODULE__}/#{id}"
  def chat_subscribe(id), do: Phoenix.PubSub.subscribe(Leafblower.PubSub, chat_topic(id))

  def chat_publish(game_id, user_id, message),
    do:
      Phoenix.PubSub.broadcast(
        Leafblower.PubSub,
        chat_topic(game_id),
        {:new_message, %{id: Ecto.UUID.generate(), from: user_id, content: message}}
      )
end
