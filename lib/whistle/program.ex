defmodule Whistle.Program do
  alias Whistle.Socket

  @json_library Application.get_env(:whistle, :json_library, Jason)

  defmacro __using__(_opts) do
    quote do
      @behaviour Whistle.Program

      alias Whistle.Html
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

  def render(router, program_name, params) do
    channel_path = String.split(program_name, ":")

    with {:ok, program, program_params} <- router.__match(channel_path),
         {:ok, pid} <-
           Whistle.ProgramRegistry.ensure_started(router, program_name, program, program_params),
         {:ok, _, session} <-
           Whistle.ProgramInstance.authorize(
             router,
             program_name,
             %{},
             Map.merge(program_params, params)
           ) do
      new_vdom = GenServer.call(pid, {:view, session})
      Whistle.Dom.node_to_string(new_vdom)
    end
  end

  def mount(conn, router, program_name, params) do
    encoded_params =
      params
      |> @json_library.encode!()
      |> Plug.HTML.html_escape()

    initial_view = render(router, program_name, params)

    """
    <div
      data-whistle-socket="#{socket_handler_url(conn, router)}"
      data-whistle-program="#{program_name}"
      data-whistle-params="#{encoded_params}">#{initial_view}</div>
    """
  end

  defp socket_handler_url(%Plug.Conn{} = conn, router) do
    IO.iodata_to_binary([
      http_to_ws_scheme(conn.scheme),
      "://",
      conn.host,
      request_url_port(conn.scheme, conn.port),
      router.__path()
    ])
  end

  defp http_to_ws_scheme(:http), do: "ws"
  defp http_to_ws_scheme(:https), do: "wss"

  defp request_url_port(:http, 80), do: ""
  defp request_url_port(:https, 443), do: ""
  defp request_url_port(_, port), do: [?:, Integer.to_string(port)]
end
