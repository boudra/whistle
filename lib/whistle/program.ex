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
    end
  end

  @callback init(map()) :: {:ok, Whistle.state()}
  @callback authorize(Whistle.state(), Socket.t(), map()) ::
              {:ok, Socket.t(), Whistle.Session.t()} | {:error, any()}
  @callback update(Whistle.message(), Whistle.state(), Socket.t()) ::
              {:ok, Whistle.state(), Whistle.Session.t()}
  @callback handle_info(any(), Whistle.state()) :: {:ok, Whistle.state()}
  @callback view(Whistle.state(), Whistle.Session.t()) :: Whistle.Dom.t()

  def render(conn, router, program_name, params) do
    channel_path = String.split(program_name, ":")

    socket = Whistle.Socket.new(conn)

    with {:ok, program, program_params} <- router.__match(channel_path),
         {:ok, pid} <-
           Whistle.ProgramRegistry.ensure_started(router, program_name, program, program_params),
         {:ok, _, session} <-
           Whistle.ProgramInstance.authorize(
             router,
             program_name,
             socket,
             Map.merge(program_params, params)
           ) do
      GenServer.call(pid, {:view, session})
    end
  end

  def fullscreen(conn, router, program_name, params) do
    encoded_params =
      params
      |> @json_library.encode!()
      |> Plug.HTML.html_escape()

    view =
      conn
      |> render(router, program_name, params)
      |> case do
        {0, {"html", attributes, children}} ->
          new_attributes =
            attributes
            |> Keyword.put(:"data-whistle-socket", Whistle.Router.url(conn, router))
            |> Keyword.put(:"data-whistle-program", program_name)
            |> Keyword.put(:"data-whistle-params", encoded_params)

          new_children =
            Enum.map(children, fn child ->
              embed_programs(conn, router, child)
            end)

          {0, {"html", new_attributes, new_children}}
      end
      |> Whistle.Dom.node_to_string()

    resp = "<!DOCTYPE html>#{view}"

    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, resp)
  end

  defp embed_programs(conn, router, {key, {:program, name, params}}) do
    encoded_params =
      params
      |> @json_library.encode!()
      |> Plug.HTML.html_escape()

    initial_view = render(conn, router, name, params)

    {key,
     {"whistle-program",
      [
        {"data-whistle-socket", Whistle.Router.url(conn, router)},
        {"data-whistle-program", name},
        {"data-whistle-params", encoded_params}
      ], [initial_view]}}
  end

  defp embed_programs(conn, router, node = {key, text}) when is_binary(text) do
    node
  end

  defp embed_programs(conn, router, node = {key, {tag, attributes, children}}) do
    new_children =
      Enum.map(children, fn child ->
        embed_programs(conn, router, child)
      end)

    {tag, attributes, new_children}
  end

  def embed(conn, router, program_name, params) do
    embed_programs(conn, router, {0, Whistle.Html.program(program_name, params)})
    |> Whistle.Dom.node_to_string()
  end
end
