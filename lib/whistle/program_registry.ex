defmodule Whistle.ProgramRegistry do

  @registry Application.get_env(:whistle, :program_registry, Elixir.Registry)
  @supervisor Application.get_env(:whistle, :program_supervisor, Elixir.DynamicSupervisor)

  def start_program(router, name, program, params) do
    spec = {
      Whistle.ProgramInstance,
      {router, name, program, params}
    }

    @supervisor.start_child(Module.concat(router, Supervisor), spec)
  end

  def ensure_started(router, name, program, params) do
    case @registry.whereis_name({Module.concat(router, Registry), name}) do
      :undefined ->
        router
        |> build_group_name(name)
        |> :pg2.create()

        case start_program(router, name, program, params) do
          {:ok, pid} ->
            {:ok, pid}

          error ->
            error
        end

      pid ->
        {:ok, pid}
    end
  end

  def build_group_name(router, name) do
    Atom.to_string(router) <> "." <> name
  end

  def subscribe(router, name, pid) do
    router
    |> build_group_name(name)
    |> :pg2.join(pid)
  end

  def broadcast(router, name, message) do
    router
    |> build_group_name(name)
    |> :pg2.get_members()
    |> Enum.each(fn pid ->
      send(pid, message)
    end)
  end
end
