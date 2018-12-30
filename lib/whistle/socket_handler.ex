defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  alias Whistle.{ProgramRegistry, ProgramConnection, Socket}

  @json_library Application.get_env(:whistle, :json_library, Jason)

  def init(req, state) do
    {:cowboy_websocket, req, {req, state}}
  end

  def websocket_init({_req, {router, []}}) do
    {:ok,
     %{
       socket: %Socket{},
       router: router,
       programs: %{}
     }}
  end

  def websocket_handle({:text, payload}, state = %{socket: socket}) do
    payload
    |> @json_library.decode()
    |> case do
      {:ok, %{"type" => "event", "program" => program_name, "handler" => handler, "arguments" => args}} ->
        message =
          {:update, program_name, handler, args}

        websocket_info(message, state)

      {:ok, %{"type" => "join", "program" => program_name, "params" => params}} ->
        channel_path = String.split(program_name, ":")

        with {:ok, program, program_params} <- state.router.__match(channel_path),
             {:ok, pid} <- ProgramRegistry.ensure_started(program_name, program, program_params),
             {:ok, new_socket, session} <-
               GenServer.call(pid, {:authorize, socket, Map.merge(program_params, params)}) ,
             :ok <- ProgramRegistry.subscribe(program_name, self()) do

          program_connection = %ProgramConnection{
            name: program_name,
            vdom: nil,
            handlers: %{},
            session: session
          }

          send(pid, {:connected, socket, session})

          reply_program_view(%{state | socket: new_socket}, program_connection)
        end
    end
  end

  def terminate(reason, _req, %{socket: socket, programs: programs}) do
    IO.inspect {:terminating, reason}
    Enum.each(programs, fn {_, %{name: name, session: session}} ->
      case ProgramRegistry.pid(name) do
        {:ok, pid} ->
          send(pid, {:disconnected, socket, session})
      end
    end)

    :ok
  end

  def websocket_info({:update, program_name, handler, args}, state = %{programs: programs}) do
    IO.inspect {handler, args}
    program = Map.get(programs, program_name)

    case ProgramConnection.update(program, {handler, args}) do
      {:ok, new_program} ->
        {:ok, %{state | programs: Map.put(programs, program_name, new_program)}}
    end
  end

  def websocket_info({:updated, name}, state = %{programs: programs}) do
    case Map.get(programs, name) do
      nil ->
        nil

      program ->
        reply_program_view(state, program)
    end
  end

  defp reply_program_view(state = %{programs: programs}, program = %{name: name, session: session}) do
    {:ok, pid} = ProgramRegistry.pid(name)

    new_vdom = GenServer.call(pid, {:view, session})
    {new_program, vdom_diff} = ProgramConnection.put_new_vdom(program, new_vdom)
    response =
      @json_library.encode!(%{
        type: "render",
        program: name,
        dom_patches: vdom_diff
      })

    {:reply, {:text, response}, %{state | programs: Map.put(programs, name, new_program)}}
  end
end
