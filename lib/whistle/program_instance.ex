defmodule Whistle.ProgramInstance do
  use GenServer

  alias Whistle.ProgramRegistry

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init({name, program, params}) do
    ProgramRegistry.register(name, self())

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
        ProgramRegistry.broadcast(name, {:updated, name})
        {:reply, {:ok, new_session}, {name, program, new_model}}

      error = {:error, _} ->
        {:reply, error, state}
    end
  end

  def handle_call({:view, socket}, _from, state = {_name, program, model}) do
    {:reply, {0, program.view(model, socket)}, state}
  end

  def handle_call({:authorize, socket, params}, _from, state = {_name, program, model}) do
    case program.authorize(model, socket, params) do
      res = {:ok, _new_socket, _session} ->
        {:reply, res, state}

      other ->
        {:reply, other, state}
    end
  end

  def handle_info({:update, message, session}, state = {name, program, model}) do
    case program.update(message, model, session) do
      {:ok, new_model, _} ->
        {:noreply, {name, program, new_model}}

      {:error, _} ->
        {:noreply, state}
    end
  end

  def handle_info(message, state = {name, program, model}) do
    case program.handle_info(message, model) do
      {:ok, new_model} ->
        {:noreply, {name, program, new_model}}

      {:error, _} ->
        {:noreply, state}
    end
  end
end
