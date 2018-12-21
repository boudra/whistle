defmodule Whistle.ProgramChannel do
  use GenServer

  def init({name, program, flags}) do
    {:ok, {name, program, program.init(flags)}}
  end

  def handle_cast({:update, message}, {name, program, model}) do
    new_model =
      program.update(model, message)

    new_view =
      {0, program.view(new_model)}

    Phoenix.PubSub.broadcast(Whistle.PubSub, name, {:view, name, new_view})

    {:noreply, {name, program, new_model}}
  end

  def handle_call(:view, _from, state = {name, program, model}) do
    {:reply, {0, program.view(model)}, state}
  end
end
