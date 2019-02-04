defmodule Whistle.Program.Instance do
  use GenServer

  alias Whistle.Program

  @registry Whistle.Config.registry()

  if Whistle.Config.code_reload?() do
    def maybe_reload() do
      IEx.Helpers.recompile()
    end
  else
    def maybe_reload() do
      nil
    end
  end

  defstruct router: nil, name: nil, program: nil, params: nil, state: %{}

  defp via(router, name) do
    registry = Module.concat(router, Registry)

    {:via, @registry, {registry, name}}
  end

  def start_link(arg = {router, name, _program, _params}) do
    GenServer.start_link(__MODULE__, arg, name: via(router, name))
  end

  def init({router, name, program, params}) do
    case program.init(params) do
      {:ok, state} ->
        Program.Registry.broadcast(router, name, {:program_started, name})

        instance = %Program.Instance{
          router: router,
          name: name,
          program: program,
          params: params,
          state: state
        }

        {:ok, instance}

      error = {:error, _} ->
        error
    end
  end

  def terminate(reason, %{program: program, state: state, name: name, router: router}) do
    if function_exported?(program, :terminate, 1) do
      program.terminate(state)
    end

    Program.Registry.broadcast(router, name, {:program_terminating, name, reason})
  end

  def handle_call(
        {:update, message, session},
        _from,
        instance = %{router: router, name: name, program: program, state: state}
      ) do
    maybe_reload()

    case program.update(message, state, session) do
      {:reply, new_state, new_session, reply} ->
        Program.Registry.broadcast(router, name, {:updated, name})
        {:reply, {:ok, new_session, [reply]}, %{instance | state: new_state}}

      {:ok, new_state, new_session} ->
        Program.Registry.broadcast(router, name, {:updated, name})

        {:reply, {:ok, new_session, []}, %{instance | state: new_state}}

      error = {:error, _} ->
        {:reply, error, instance}
    end
  end

  def handle_call(
        {:route, session, path, query_params},
        {from, _},
        instance = %{name: name, program: program, state: state}
      ) do
    if function_exported?(program, :route, 4) do
      maybe_reload()

      case program.route(path, state, session, query_params) do
        {:ok, new_session} ->
          send(from, {:updated, name})

          {:reply, {:ok, new_session}, instance}

        error = {:error, _} ->
          {:reply, error, instance}
      end
    else
      {:reply, {:ok, session}, instance}
    end
  end

  def handle_call({:view, session}, _from, instance = %{program: program, state: state}) do
    maybe_reload()

    {:reply, {0, program.view(state, session)}, instance}
  end

  def handle_call(
        {:authorize, socket, params},
        _from,
        instance = %{program: program, state: state}
      ) do
    if function_exported?(program, :authorize, 3) do
      case program.authorize(state, socket, params) do
        res = {:ok, _new_socket, _session} ->
          {:reply, res, instance}

        other ->
          {:reply, other, instance}
      end
    else
      {:reply, {:ok, socket, params}, instance}
    end
  end

  def handle_info(
        message,
        instance = %{router: router, name: name, program: program, state: state}
      ) do
    if function_exported?(program, :handle_info, 2) do
      case program.handle_info(message, state) do
        {:ok, ^state} ->
          {:noreply, instance}

        {:ok, new_state} ->
          Program.Registry.broadcast(router, name, {:updated, name})
          {:noreply, %{instance | state: new_state}}

        {:error, _} ->
          {:noreply, instance}
      end
    else
      {:noreply, instance}
    end
  end

  # API

  def authorize(router, name, socket, params) do
    GenServer.call(via(router, name), {:authorize, socket, params})
  end

  def update(router, name, message, session) do
    GenServer.call(via(router, name), {:update, message, session})
  end

  @spec view(atom(), String.t(), any()) :: Whistle.Html.Dom.t()
  def view(router, name, session) do
    GenServer.call(via(router, name), {:view, session})
  end

  @spec route(
          router :: any(),
          name :: any(),
          session :: Whistle.Session.t(),
          path_info :: [String.t()],
          query_params :: map()
        ) ::
          {:ok, session :: any()} | {:error, :not_found}
  def route(router, name, session, path_info, query_params) do
    GenServer.call(via(router, name), {:route, session, path_info, query_params})
  end

  @spec send_info(atom() | binary(), any(), any()) :: :error | :ok
  def send_info(router, name, message) do
    case Program.Registry.pid(router, name) do
      :undefined ->
        :error

      pid ->
        send(pid, message)

        :ok
    end
  end
end
