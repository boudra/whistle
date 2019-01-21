defmodule Whistle.Program do
  alias Whistle.Socket
  require Whistle.Html

  @json_library Application.get_env(:whistle, :json_library, Jason)

  defmacro __using__(_opts) do
    quote do
      @behaviour Whistle.Program

      alias Whistle.Html
      require Whistle.Html
      import Whistle.Socket
      import Whistle.Html.Parser, only: [sigil_H: 2]
    end
  end

  @doc """
  Receives parameters from the route, it should return the initial state or an error.

  The parameters are taken from the program route:

  ```
  defmodule Router do
    use Whistle.Router, path: "/ws"

    match("chat:*room", ChatProgram, %{"other" => true})
  end

  defmodule ChatProgram do
    use Program

    # when joining `chat:1`
    def init(%{"room" => "1", "other" => true}) do
      {:ok, %{}}
    end
  end
  ```
  """
  @callback init(map()) :: {:ok, Whistle.state()} | {:error, any()}

  @doc """
  The terminate callback will be called when the program instance shuts down, it will receive the state.

  Remember that Programs will be automatically respawned if they crash, so there is no need to try restart it yourself. This callback could be useful to serialize the state and then load it later in the `init/1` callback.
  """
  @callback terminate(Whistle.state()) :: any()

  @doc """
  The authorize callback will be called on a running program when a client tries to access it.

  It receives the current state, the client's socket and the clients params. And must return an updated socket, an initial session or an error with a reason.

  You cloud send a bearer token and verify it here to authorize a client.

  ```
  def authorize(state, socket, %{"token" => token}) do
    case MyApp.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        {:ok, socket, claims}

      {:error, reason} ->
        {:error, reason}
    end
  end
  ```
  """
  @callback authorize(Whistle.state(), Socket.t(), map()) ::
              {:ok, Socket.t(), Whistle.Session.t()} | {:error, any()}

  @doc """
  The update callback is called everytime an event handler is triggered, it will receive the message, the current state and the session of the client who triggered it.

  ```
  defmodule CounterProgram do
    use Program

    def init(_args) do
      {:ok, 0}
    end

    def update(:increase, state, session) do
      {:ok, state + 1, session}
    end

    def view(state, session) do
      Html.div([], [
        Html.p([], to_string(state)),
        Html.button([on: [click: :increase]], "Increase")
      ])
    end
  end
  ```
  """
  @callback update(Whistle.message(), Whistle.state(), Socket.Session.t()) ::
              {:ok, Whistle.state(), Whistle.Session.t()}

  @doc """
  `handle_info/2` is similar to how `GenServer.handle_info/2` works, it will receive a message and the current state, and it expects a new updated state returned. This callback can be triggered by sending Erlang messages to the program instance.

  ```
  defmodule TimeProgram do
    use Program

    def init(_args) do
      Process.send_after(self(), :tick, 1_000)
      {:ok, DateTime.utc_now()}
    end

    def handle_info(:tick, state) do
      Process.send_after(self(), :tick, 1_000)
      {:ok, DateTime.utc_now()}
    end

    def view(time, session) do
      Html.p([], DateTime.to_string(time))
    end
  end
  ```
  """
  @callback handle_info(any(), Whistle.state()) :: {:ok, Whistle.state()}

  @doc """
  The view receives the programs state and the session of the client we are rendering the view for.

  It must return a Dom tree, which looks like this:

  ```
  # {key, {tag, attributes, children}}
  {0, {"div", [class: "red"], [
  {0, {"p", [], ["some text"]}
  ]}}
  ```

  You can use the `Whistle.Html` helpers to generate this tree:

  ```
  Html.div([class: "red"], [
  Html.p([], "some text")
  ])
  ```

  Or the `Whistle.Html.Parser.sigil_H/2` if you want to write plain HTML:

  ```
  text = "some text"

  ~H"\""
  <div class="red">
  <p>{{ text }}</p>
  </div>
  "\""
  ```

  Both the HTML helpers and the sigil will expand to a DOM tree at compile time.
  """
  @callback view(Whistle.state(), Whistle.Session.t()) :: Whistle.Html.Dom.t()
  @optional_callbacks [handle_info: 2, authorize: 3, terminate: 1]

  defp render(conn, router, program_name, params) do
    channel_path = String.split(program_name, ":")

    socket = Whistle.Socket.new(conn)

    with {:ok, program, program_params} <- router.__match(channel_path),
         {:ok, _} <-
           Whistle.ProgramRegistry.ensure_started(router, program_name, program, program_params),
         {:ok, _, session} <-
           Whistle.ProgramInstance.authorize(
             router,
             program_name,
             socket,
             Map.merge(program_params, params)
           ) do
      Whistle.ProgramInstance.view(router, program_name, session)
    end
  end

  @doc """
  A fullscreen `Whistle.Program` renders the whole HTML document, this is useful if you want to also handle navigation in your program. When the Javscript library executes, it will automatically connect to the Program and become interactive.

  Remember to include the Javascript library via a `<script>` tag or module import.

  Call in a `Plug` or a `Phoenix.Controller` action:

  ```
  def index(conn, _opts) do
    fullscreen(conn, MyProgramRouter, "counter")
  end
  ```

  Example of a view:

  ```
  def view(state, session) do
    ~H"\""
    <html>
      <head>
        <title>My Whistle App</title>
        <script src="/js/whistle.js"></script>
      </head>
      <body>
        <h1>It works!<h1>
      </body>
    </html>
    "\""
  end
  ```
  """
  def fullscreen(conn, router, program_name, params \\ %{}) do
    encoded_params =
      params
      |> @json_library.encode!()
      |> Plug.HTML.html_escape()

    view =
      conn
      |> render(router, program_name, params)
      |> case do
        {0, {"html", {attributes, children}}} ->
          new_attributes =
            attributes
            |> Keyword.put(:"data-whistle-socket", Whistle.Router.url(conn, router))
            |> Keyword.put(:"data-whistle-program", program_name)
            |> Keyword.put(:"data-whistle-params", encoded_params)

          new_children =
            Enum.map(children, fn child ->
              embed_programs(conn, router, child)
            end)

          {0, Whistle.Html.html(new_attributes, new_children)}

        {0, {element, _}} ->
          raise """
          `Whistle.Program.fullscreen/4` expects program to return an <html> element as the root element,
          got #{inspect(element)} instead.
          """
      end
      |> Whistle.Html.Dom.node_to_string()

    resp = "<!DOCTYPE html>#{view}"

    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, resp)
  end

  @doc """
  Use `embed/4` to embed a Program in a view. It will render the view in plain HTML. When the Javscript library executes, it will automatically connect to the Program and become interactive.

  In a Phoenix template:

  ```html
  <!-- lib/my_app_web/templates/page/index.html.eex -->
  <div>
    <%= embed(conn, MyProgramRouter, "counter") |> raw %>
  </div>
  ```

  In a `Plug` or a `Phoenix.Controller` action:

  ```
  def index(conn, _opts) do
    resp = embed(conn, MyProgramRouter, "counter")

    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, resp)
  end
  ```
  """
  def embed(conn, router, program_name, params \\ %{}) do
    embed_programs(conn, router, {0, Whistle.Html.program(program_name, params)})
    |> Whistle.Html.Dom.node_to_string()
  end

  defp embed_programs(conn, router, {key, {:program, {name, params}}}) do
    encoded_params =
      params
      |> @json_library.encode!()
      |> Plug.HTML.html_escape()

    {0, initial_view} = render(conn, router, name, params)

    attributes = [
      {"data-whistle-socket", Whistle.Router.url(conn, router)},
      {"data-whistle-program", name},
      {"data-whistle-params", encoded_params}
    ]

    {key, Whistle.Html.node("whistle-program", attributes, [initial_view])}
  end

  defp embed_programs(_conn, _router, node = {_key, text}) when is_binary(text) do
    node
  end

  defp embed_programs(conn, router, {key, {tag, {attributes, children}}}) do
    new_children =
      Enum.map(children, fn child ->
        embed_programs(conn, router, child)
      end)

    {key, Whistle.Html.node(tag, attributes, new_children)}
  end
end
