defmodule Whistle.ProgramRegistry do
  def start_program(router, name, program, params) do
    spec = {
      Whistle.ProgramInstance,
      {router, name, program, params}
    }

    DynamicSupervisor.start_child(Module.concat(router, Supervisor), spec)
  end

  def ensure_started(router, name, program, params) do
    case Registry.whereis_name({Module.concat(router, Registry), name}) do
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
