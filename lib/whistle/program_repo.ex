defmodule Whistle.ProgramRepo do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:get_or_create, name, program, flags}, _from, programs) do
    pid =
      Map.get_lazy(programs, name, fn ->
        {:ok, pid} =
          GenServer.start_link(
            Whistle.ProgramChannel,
            {name, program, flags}
          )

        pid
      end)

    {:reply, pid, Map.put(programs, name, pid)}
  end

  def get_or_create(name, program, flags) do
    GenServer.call(__MODULE__, {:get_or_create, name, program, flags})
  end

end
