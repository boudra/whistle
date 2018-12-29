defmodule Whistle.ProgramInstance do
  use GenServer

  def init({name, program, params}) do
    case program.init(params) do
      {:ok, state} ->
        {:ok, {name, program, state}}

      error = {:error, _} ->
        error
    end
  end

  def handle_call({:update, message, session}, _from, state = {name, program, model}) do
    case program.update(message, model, session) do
      {:ok, new_model, new_session} ->
        {:reply, {:ok, new_session}, {name, program, new_model}}

      error = {:error, _} ->
        {:reply, error, state}
    end
  end

  def handle_call({:view, socket}, _from, state = {_name, program, model}) do
    {:reply, {0, program.view(model, socket)}, state}
  end

  def handle_call({:authorize, socket, params}, _from, state = {_name, program, _model}) do
    {:reply, program.authorize(state, socket, params), state}
  end
end
