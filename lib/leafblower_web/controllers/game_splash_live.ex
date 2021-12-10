defmodule LeafblowerWeb.GameSplashLive do
  use LeafblowerWeb, :live_view

  @impl true
  def mount(_param, %{"current_user_id" => user_id}, socket) do
    {:ok,
     assign(socket,
       user_id: user_id,
       page: :index
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :start_game = action, _params) do
    socket
    |> assign(:page, action)
    |> assign(:changeset, cast_user())
  end

  defp apply_action(socket, :join_by_code = action, _params) do
    socket
    |> assign(:page, action)
    |> assign(:changeset, cast_game_code())
  end

  defp apply_action(socket, _action, _params) do
    socket
  end

  @impl true
  def handle_event("validate_user", %{"user" => params}, socket) do
    changeset =
      cast_user(params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("validate_code", %{"code" => params}, socket) do
    changeset =
      cast_game_code(params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("new_game", %{"user" => params}, socket) do
    {:ok, code} = Leafblower.GameStatem.generate_game_code()

    data =
      cast_user(params)
      |> Ecto.Changeset.apply_changes()

    {:ok, game} =
      Leafblower.GameSupervisor.new_game(id: code, countdown_duration: 120, min_player_count: 2)

    Leafblower.GameStatem.join_player(game, socket.assigns.user_id, data.name)

    {:noreply,
     socket
     |> push_redirect(to: Routes.live_path(socket, LeafblowerWeb.GameLive, code), replace: true)}
  end

  def handle_event("join_by_code", %{"code" => params}, socket) do
    {:noreply,
     socket
     |> push_redirect(
       to: Routes.live_path(socket, LeafblowerWeb.GameLive, String.upcase(params["code"])),
       replace: true
     )}
  end

  @impl true
  def render(%{page: :start_game} = assigns) do
    ~H"""
      <.form let={f} for={@changeset} phx-change="validate_user" phx-submit="new_game" as="user">
        <%= label f, :name %>
        <%= text_input f, :name, placeholder: "Enter your name!" %>
        <%= error_tag f, :name %>

        <%= submit "Start a new game", [disabled: length(@changeset.errors) > 0] %>
      </.form>
    """
  end

  @impl true
  def render(%{page: :join_by_code} = assigns) do
    ~H"""
      <.form let={f} for={@changeset} phx-change="validate_code" phx-submit="join_by_code" as="code">
        <%= label f, :code, "Enter game code" %>
        <%= text_input f, :code, style: "text-transform:uppercase" %>
        <%= error_tag f, :code %>

        <%= submit "Find game", [disabled: length(@changeset.errors) > 0] %>
      </.form>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="welcome-root">
      <div class="row">
          <svg width="200" height="100" viewBox="0 0 244 95" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect x="5.97658" y="37" width="238.023" height="55" rx="7" fill="white"/>
            <path d="M15.5072 6.96891C21.7985 4.91158 37.943 4.23529 52.1904 17.9888C66.4379 31.7423 89.038 34.3211 98.5572 33.8913C86.9357 36.9789 60.5647 40.8988 48.0524 31.8769C35.54 22.8551 20.8743 28.5369 15.1055 32.5056L15.5072 6.96891Z" fill="#A2D69E" stroke="white"/>
            <path d="M14.0767 11.77C20.368 9.71264 36.5125 9.03635 50.7599 22.7898C65.0074 36.5433 87.6075 39.1221 97.1267 38.6923C85.5052 41.78 59.1342 45.6998 46.6219 36.678C34.1095 27.6562 19.4438 33.338 13.675 37.3066L14.0767 11.77Z" fill="#A2D69E" stroke="white"/>
            <path d="M9 17.5C15.2913 15.4426 31.4358 14.7664 45.6833 28.5199C59.9307 42.2733 82.5309 44.8521 92.05 44.4223C80.4286 47.51 54.0576 51.4298 41.5452 42.408C29.0329 33.3862 12.4502 38.3526 6.71151 41.9223L9 17.5Z" fill="#A2D69E" stroke="white"/>
            <path d="M2.54231 24.0941C8.83364 22.0367 24.9781 21.3604 39.2256 35.1139C53.473 48.8674 76.0732 51.4462 85.5923 51.0164C73.9709 54.1041 43.3595 53.4979 31.7235 44.5C19.7722 35.2582 16.4521 33.7608 10.7235 29.5L2.54231 24.0941Z" fill="#A2D69E" stroke="#FEFEFE"/>
            <path d="M19.4844 77.3203H35.6562V81H14.9609V46.875H19.4844V77.3203ZM49.6728 81.4688C46.2353 81.4688 43.4384 80.3438 41.2822 78.0938C39.1259 75.8281 38.0478 72.8047 38.0478 69.0234V68.2266C38.0478 65.7109 38.5244 63.4688 39.4775 61.5C40.4462 59.5156 41.79 57.9688 43.5087 56.8594C45.2431 55.7344 47.1181 55.1719 49.1337 55.1719C52.4306 55.1719 54.9931 56.2578 56.8212 58.4297C58.6494 60.6016 59.5634 63.7109 59.5634 67.7578V69.5625H42.3837C42.4462 72.0625 43.1728 74.0859 44.5634 75.6328C45.9697 77.1641 47.7509 77.9297 49.9072 77.9297C51.4384 77.9297 52.7353 77.6172 53.7978 76.9922C54.8603 76.3672 55.79 75.5391 56.5869 74.5078L59.2353 76.5703C57.1103 79.8359 53.9228 81.4688 49.6728 81.4688ZM49.1337 58.7344C47.3837 58.7344 45.915 59.375 44.7275 60.6562C43.54 61.9219 42.8056 63.7031 42.5244 66H55.2275V65.6719C55.1025 63.4688 54.5087 61.7656 53.4462 60.5625C52.3837 59.3438 50.9462 58.7344 49.1337 58.7344ZM79.2987 81C79.0487 80.5 78.8456 79.6094 78.6894 78.3281C76.6737 80.4219 74.2675 81.4688 71.4706 81.4688C68.9706 81.4688 66.9159 80.7656 65.3066 79.3594C63.7128 77.9375 62.9159 76.1406 62.9159 73.9688C62.9159 71.3281 63.9159 69.2812 65.9159 67.8281C67.9316 66.3594 70.7597 65.625 74.4003 65.625H78.6191V63.6328C78.6191 62.1172 78.1659 60.9141 77.2597 60.0234C76.3534 59.1172 75.0175 58.6641 73.2519 58.6641C71.705 58.6641 70.4081 59.0547 69.3612 59.8359C68.3144 60.6172 67.7909 61.5625 67.7909 62.6719H63.4316C63.4316 61.4062 63.8769 60.1875 64.7675 59.0156C65.6737 57.8281 66.8925 56.8906 68.4237 56.2031C69.9706 55.5156 71.6659 55.1719 73.5097 55.1719C76.4316 55.1719 78.7206 55.9062 80.3769 57.375C82.0331 58.8281 82.8925 60.8359 82.955 63.3984V75.0703C82.955 77.3984 83.2519 79.25 83.8456 80.625V81H79.2987ZM72.1034 77.6953C73.4628 77.6953 74.7519 77.3438 75.9706 76.6406C77.1894 75.9375 78.0722 75.0234 78.6191 73.8984V68.6953H75.2206C69.9081 68.6953 67.2519 70.25 67.2519 73.3594C67.2519 74.7188 67.705 75.7812 68.6112 76.5469C69.5175 77.3125 70.6816 77.6953 72.1034 77.6953ZM90.9247 81V58.9922H86.9169V55.6406H90.9247V53.0391C90.9247 50.3203 91.6512 48.2188 93.1044 46.7344C94.5575 45.25 96.6122 44.5078 99.2684 44.5078C100.268 44.5078 101.261 44.6406 102.245 44.9062L102.011 48.4219C101.276 48.2812 100.495 48.2109 99.6669 48.2109C98.2606 48.2109 97.1747 48.625 96.4091 49.4531C95.6434 50.2656 95.2606 51.4375 95.2606 52.9688V55.6406H100.675V58.9922H95.2606V81H90.9247ZM125.988 68.6016C125.988 72.4766 125.097 75.5938 123.316 77.9531C121.535 80.2969 119.144 81.4688 116.144 81.4688C112.941 81.4688 110.465 80.3359 108.715 78.0703L108.504 81H104.519V45H108.855V58.4297C110.605 56.2578 113.019 55.1719 116.097 55.1719C119.176 55.1719 121.59 56.3359 123.34 58.6641C125.105 60.9922 125.988 64.1797 125.988 68.2266V68.6016ZM121.652 68.1094C121.652 65.1562 121.082 62.875 119.941 61.2656C118.801 59.6562 117.16 58.8516 115.019 58.8516C112.16 58.8516 110.105 60.1797 108.855 62.8359V73.8047C110.183 76.4609 112.254 77.7891 115.066 77.7891C117.144 77.7891 118.762 76.9844 119.918 75.375C121.074 73.7656 121.652 71.3438 121.652 68.1094ZM135.223 81H130.887V45H135.223V81ZM140.076 68.0859C140.076 65.6016 140.56 63.3672 141.529 61.3828C142.513 59.3984 143.873 57.8672 145.607 56.7891C147.357 55.7109 149.349 55.1719 151.584 55.1719C155.037 55.1719 157.826 56.3672 159.951 58.7578C162.092 61.1484 163.162 64.3281 163.162 68.2969V68.6016C163.162 71.0703 162.685 73.2891 161.732 75.2578C160.795 77.2109 159.443 78.7344 157.677 79.8281C155.927 80.9219 153.912 81.4688 151.631 81.4688C148.193 81.4688 145.404 80.2734 143.263 77.8828C141.138 75.4922 140.076 72.3281 140.076 68.3906V68.0859ZM144.435 68.6016C144.435 71.4141 145.084 73.6719 146.381 75.375C147.693 77.0781 149.443 77.9297 151.631 77.9297C153.834 77.9297 155.584 77.0703 156.881 75.3516C158.177 73.6172 158.826 71.1953 158.826 68.0859C158.826 65.3047 158.162 63.0547 156.834 61.3359C155.521 59.6016 153.771 58.7344 151.584 58.7344C149.443 58.7344 147.717 59.5859 146.404 61.2891C145.092 62.9922 144.435 65.4297 144.435 68.6016ZM190.092 75.0234L194.967 55.6406H199.303L191.921 81H188.405L182.241 61.7812L176.241 81H172.725L165.366 55.6406H169.678L174.671 74.625L180.577 55.6406H184.069L190.092 75.0234ZM213.297 81.4688C209.859 81.4688 207.062 80.3438 204.906 78.0938C202.75 75.8281 201.672 72.8047 201.672 69.0234V68.2266C201.672 65.7109 202.148 63.4688 203.101 61.5C204.07 59.5156 205.414 57.9688 207.133 56.8594C208.867 55.7344 210.742 55.1719 212.758 55.1719C216.054 55.1719 218.617 56.2578 220.445 58.4297C222.273 60.6016 223.187 63.7109 223.187 67.7578V69.5625H206.008C206.07 72.0625 206.797 74.0859 208.187 75.6328C209.593 77.1641 211.375 77.9297 213.531 77.9297C215.062 77.9297 216.359 77.6172 217.422 76.9922C218.484 76.3672 219.414 75.5391 220.211 74.5078L222.859 76.5703C220.734 79.8359 217.547 81.4688 213.297 81.4688ZM212.758 58.7344C211.008 58.7344 209.539 59.375 208.351 60.6562C207.164 61.9219 206.429 63.7031 206.148 66H218.851V65.6719C218.726 63.4688 218.133 61.7656 217.07 60.5625C216.008 59.3438 214.57 58.7344 212.758 58.7344ZM239.524 59.5312C238.868 59.4219 238.157 59.3672 237.391 59.3672C234.547 59.3672 232.618 60.5781 231.602 63V81H227.266V55.6406H231.485L231.555 58.5703C232.977 56.3047 234.993 55.1719 237.602 55.1719C238.446 55.1719 239.087 55.2812 239.524 55.5V59.5312Z" fill="#5F5555"/>
          </svg>
      </div>
      <div class="row">
        <p>Play Cards Against Humanity online</p>
      </div>
      <div class="row">
        <div>
          <%= live_patch to: Routes.game_splash_path(@socket, :start_game) do%>
            <button>Start a game</button>
          <% end %>
        </div>
      </div>

      <div class="row" style="padding-bottom: 1em">
        <b>Or</b>
      </div>

      <div class="row">
        <div>
          <%= live_patch to: Routes.game_splash_path(@socket, :join_by_code) do%>
            <button>Join game</button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp cast_user(params \\ %{}) do
    {%{}, %{name: :string}}
    |> Ecto.Changeset.cast(params, [:name])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, max: 15)
  end

  defp cast_game_code(params \\ %{}) do
    {%{}, %{code: :string}}
    |> Ecto.Changeset.cast(params, [:code])
    |> Ecto.Changeset.validate_required([:code])
    |> Ecto.Changeset.validate_length(:code, max: 5)
  end
end
