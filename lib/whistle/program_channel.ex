defmodule Whistle.ProgramChannel do
  use GenServer

  def init({name, program, flags}) do
    {:ok, state} = program.init(name, flags)
    {:ok, {name, program, state}}
  end

  def handle_call({:update, message, socket}, _from, {name, program, model}) do
    {:ok, new_model, new_socket} =
      program.update(message, model, socket)

    new_view =
      {0, program.view(new_model, socket)}

    {:reply, {new_view, new_socket}, {name, program, new_model}}
  end

  def handle_call({:view, socket}, _from, state = {name, program, model}) do
    {:reply, {0, program.view(model, socket)}, state}
  end
end
