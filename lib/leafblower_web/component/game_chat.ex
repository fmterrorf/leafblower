defmodule LeafblowerWeb.Component.GameChat do
  use LeafblowerWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, changeset: cast_message())}
  end

  @impl true
  def handle_event("submit", %{"message" => params}, socket) do
    chat_publish(socket.assigns.game_id, socket.assigns.user_id, params["message"])
    {:noreply, assign(socket, changeset: cast_message())}
  end

  @impl true
  def handle_event("validate-message", %{"message" => params}, socket) do
    {:noreply,
     assign(socket,
       changeset:
         cast_message(params)
         |> Map.put(:action, :insert)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
     <ul id="chatlist" phx-hook="ChatList" phx-update="append">
       <%= if @message do %>
       <li id={@message.id}><%= @player_info[@message.from].name %>: <%= @message.content %></li>
       <% end %>
     </ul>
     <.form let={f} for={@changeset} phx-target={@myself} phx-change="validate-message" phx-submit="submit" as="message">
        <%= error_tag f, :message %>
        <%= text_input f, :message %>
        <%= submit "Send", [disabled: length(@changeset.errors) > 0] %>
     </.form>
     </div>
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

  defp cast_message(params \\ %{}) do
    {%{}, %{message: :string}}
    |> Ecto.Changeset.cast(params, [:message])
    |> Ecto.Changeset.validate_required([:message])
    |> Ecto.Changeset.validate_length(:message, max: 50)
  end
end
