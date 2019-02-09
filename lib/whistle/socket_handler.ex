defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  alias Whistle.{Program, Socket}

  require Whistle.Config

  @json_library Whistle.Config.json_library()

  defmodule State do
    @type t :: %__MODULE__{
            router: module(),
            socket: Whistle.Socket.t(),
            conns: [Whistle.Program.Connection.t()]
          }

    defstruct [:socket, :router, :conns]
  end

  def init(req, {router, []}) do
    conn = Plug.Cowboy.Conn.conn(req)
    {:cowboy_websocket, req, {conn, router}}
  end

  def websocket_init({conn, router}) do
    {:ok,
     %State{
       socket: Socket.new(conn),
       router: router,
       conns: %{}
     }}
  end

  defp generate_connection_id() do
    4
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower, padding: false)
  end

  defp program_connection(conns, id) do
    case Map.fetch(conns, id) do
      res = {:ok, _} ->
        res

      :error ->
        {:error, :conn_not_found}
    end
  end

  def handle_conn_event("event", conn, %{"conn" => id, "handler" => handler, "args" => args}) do
    case Program.Connection.handle_event(conn, {handler, args}) do
      {:ok, new_conn, replies} ->
        if length(replies) > 0 do
          replies
          |> Enum.map(fn reply ->
            %{type: "msg", program: id, payload: reply}
          end)
          |> reply!()
        end

        {:ok, new_conn}

      {:error, :program_crash} ->
        {:error, :program_crash}
    end
  end

  def handle_conn_event("route", conn, %{"uri" => uri}) do
    case Program.Connection.route(conn, uri) do
      {:ok, new_conn} ->
        {:ok, new_conn}

      error = {:error, _error} ->
        error
    end
  end

  def handle_event("leave", state, %{"conn" => id}) do
    conn = Map.get(state.conns, id)

    Program.Registry.unsubscribe(state.router, conn.name, self())
    Program.Connection.notify_disconnection(conn, state.socket)

    {:ok, %{state | conns: Map.delete(state.conns, id)}}
  end

  def handle_event("join", state = %{router: router, socket: socket, conns: conns}, %{
        "ref" => request_id,
        "program" => program_name,
        "params" => params,
        "dom" => dom,
        "uri" => uri
      }) do
    channel_path = String.split(program_name, ":")

    with {:ok, program, program_params} <- router.__match(channel_path),
         {:ok, _pid} <-
           Program.Registry.ensure_started(router, program_name, program, program_params),
         {:ok, new_socket, session} <-
           Program.Instance.authorize(
             router,
             program_name,
             socket,
             Map.merge(program_params, params)
           ),
         :ok <- Program.Registry.subscribe(router, program_name, self()) do
      conn = Program.Connection.new(router, program_name, dom, session)

      conn_id = generate_connection_id()

      response = %{
        type: "joined",
        ref: request_id,
        conn: conn_id
      }

      Program.Connection.notify_connection(conn, socket)

      new_conn =
        case Program.Connection.route(conn, uri) do
          {:ok, new_conn} ->
            new_conn

          {:error, _error} ->
            conn
        end

      reply!(response)
      send(self(), {:updated, program_name})

      {:ok,
       %{
         state
         | socket: new_socket,
           conns: Map.put(conns, conn_id, new_conn)
       }}
    end
  end

  def handle_event(type, state, payload = %{"conn" => id}) do
    with {:ok, conn} <- program_connection(state.conns, id),
         {:ok, new_conn} <- handle_conn_event(type, conn, payload) do
      {:ok, %{state | conns: Map.put(state.conns, id, new_conn)}}
    end
  end

  def websocket_handle({:text, payload}, state) do
    payload
    |> @json_library.decode()
    |> case do
      {:ok, payload = %{"type" => type}} ->
        handle_event(type, state, payload)

      {:error, err} ->
        # TODO: log malformed JSON error
        {:ok, state}
    end
  end

  def terminate(_reason, _req, %{socket: socket, conns: conns}) do
    Enum.each(conns, fn {_, conn} ->
      Program.Connection.notify_disconnection(conn, socket)
    end)

    :ok
  end

  def websocket_info({:program_terminating, _program_name, _reason}, state) do
    # program died
    {:ok, state}
  end

  def websocket_info(
        {:program_started, program_name},
        state = %{socket: socket, conns: conns}
      ) do
    Enum.each(conns, fn conn = %{name: ^program_name} ->
      Program.Connection.notify_connection(conn, socket)
    end)

    reply_program_view(state, program_name)
  end

  def websocket_info({:reply, response}, state) do
    {:reply, response, state}
  end

  def websocket_info({:updated, name}, state) do
    reply_program_view(state, name)
  end

  defp reply!(message) do
    list_message = List.wrap(message)
    send(self(), {:reply, {:text, @json_library.encode!(list_message)}})
  end

  defp reply_program_view(state = %{conns: conns}, name) do
    {new_conns, responses} =
      Enum.reduce(conns, {[], []}, fn
        {id, program = %{name: ^name}}, {conns, responses} ->
          {new_program, diff} = Program.Connection.update_view(program)

          new_responses =
            if length(diff) > 0 do
              response = %{
                type: "render",
                conn: id,
                dom_patches: diff
              }

              responses ++ [response]
            else
              responses
            end

          {conns ++ [{id, new_program}], new_responses}

        program, {conns, responses} ->
          {conns ++ [program], responses}
      end)

    new_state = %{state | conns: Enum.into(new_conns, %{})}

    if length(responses) > 0 do
      reply!(responses)
    end

    {:ok, new_state}
  end
end
