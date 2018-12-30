defmodule Whistle.ProgramRegistry do
  use DynamicSupervisor

  def start_link(name) do
    DynamicSupervisor.start_link(__MODULE__, [], name: name)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_program(name, program, params) do
    spec = {
      Whistle.ProgramInstance, {name, program, params}
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def pid(name) do
    case :global.whereis_name(name) do
      :undefined ->
        {:error, :not_started}

      pid ->
        {:ok, pid}
    end
  end

  def ensure_started(name, program, params) do
    case :global.whereis_name(name) do
      :undefined ->
        case start_program(name, program, params) do
          {:ok, pid} ->
            {:ok, pid}

          error ->
            error
        end

      pid ->
        {:ok, pid}
    end
  end

  def register(name, pid) do
    IO.inspect({"register", name, pid})
    :global.register_name(name, pid)
    :pg2.create(name)
  end

  def subscribe(name, pid) do
    :pg2.join(name, pid)
  end

  def broadcast(name, message) do
    name
    |> :pg2.get_members()
    |> Enum.each(fn pid ->
      send(pid, message)
    end)
  end
end
