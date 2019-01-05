defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  alias Whistle.{ProgramInstance, ProgramRegistry, ProgramConnection, Socket}

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

  def websocket_handle(
        {:text, payload},
        state = %{router: router, socket: socket, programs: programs}
      ) do
    payload
    |> @json_library.decode()
    |> case do
      {:ok, %{"type" => "event", "program" => program_name, "handler" => handler, "args" => args}} ->
        message = {:update, program_name, handler, args}

        websocket_info(message, state)

      {:ok, %{"type" => "join", "program" => program_name, "params" => params, "dom" => dom}} ->
        channel_path = String.split(program_name, ":")

        with {:ok, program, program_params} <- router.__match(channel_path),
             {:ok, pid} <-
               ProgramRegistry.ensure_started(router, program_name, program, program_params),
             {:ok, new_socket, session} <-
               ProgramInstance.authorize(
                 router,
                 program_name,
                 socket,
                 Map.merge(program_params, params)
               ),
             :ok <- ProgramRegistry.subscribe(router, program_name, self()) do
          program_connection = %ProgramConnection{
            router: router,
            name: program_name,
            handlers: %{},
            vdom: Whistle.Dom.from_html_string(dom),
            session: session
          }

          ProgramConnection.notify_connection(program_connection, socket)

          # trigger an initial render
          send(self(), {:updated, program_name})

          {:ok,
           %{
             state
             | socket: new_socket,
               programs: Map.put(programs, program_name, program_connection)
           }}
        end
    end
  end

  def terminate(reason, _req, %{socket: socket, programs: programs}) do
    Enum.each(programs, fn {_, program} ->
      ProgramConnection.notify_disconnection(program, socket)
    end)

    :ok
  end

  def websocket_info({:program_terminating, _program_name, _reason}, state) do
    # program died
    {:ok, state}
  end

  def websocket_info(
        {:program_started, program_name},
        state = %{socket: socket, programs: programs}
      ) do
    program = Map.get(programs, program_name)

    ProgramConnection.notify_connection(program, socket)

    reply_program_view(state, program)
  end

  def websocket_info({:update, program_name, handler, args}, state = %{programs: programs}) do
    program = Map.get(programs, program_name)

    case ProgramConnection.update(program, {handler, args}) do
      {:ok, new_program} ->
        {:ok, %{state | programs: Map.put(programs, program_name, new_program)}}

      {:error, :program_crash} ->
        {:ok, state}
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

  defp reply_program_view(state = %{programs: programs}, program = %{name: name}) do
    new_vdom = ProgramConnection.view(program)
    {new_program, vdom_diff} = ProgramConnection.put_new_vdom(program, new_vdom)
    new_state = %{state | programs: Map.put(programs, name, new_program)}

    if length(vdom_diff) > 0 do
      response =
        @json_library.encode!(%{
          type: "render",
          program: name,
          dom_patches: vdom_diff
        })

      {:reply, {:text, response}, new_state}
    else
      {:ok, new_state}
    end
  end
end
