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
  @callback authorize(Whistle.state(), Socket.t(), map()) :: {:ok, Socket.t(), Whistle.Session.t()} | {:error, any()}
  @callback update(Whistle.message(), Whistle.state(), Socket.t()) :: {:ok, Whistle.state(), Whistle.Session.t()}
  @callback handle_info(any(), Whistle.state()) :: {:ok, Whistle.state()}
  @callback view(Whistle.state(), Whistle.Session.t()) :: Whistle.Dom.t()

  def render(router, program_name, params) do
    channel_path = String.split(program_name, ":")

    with {:ok, program, program_params} <- router.__match(channel_path),
         {:ok, pid} <- Whistle.ProgramRegistry.ensure_started(program_name, program, program_params),
         {:ok, new_socket, session} <-
           GenServer.call(pid, {:authorize, %{}, Map.merge(program_params, params)}) do
      new_vdom = GenServer.call(pid, {:view, session})
      Whistle.Dom.node_to_string(new_vdom)
    end
  end

  def mount(router, program_name, params) do
    encoded_params =
      params
      |> @json_library.encode!()
      |> Plug.HTML.html_escape()

    initial_view =
      render(router, program_name, params)

    socket_handler =
      "ws://localhost:4000/ws"

    """
    <div
      data-whistle-socket="#{socket_handler}"
      data-whistle-program="#{program_name}"
      data-whistle-params="#{encoded_params}">#{initial_view}</div>
    """
  end
end
