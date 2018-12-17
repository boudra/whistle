defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def websocket_init(state) do
    model = Whistle.init()

    {:ok, %{handlers: [], vdom: {0, {nil, [], []}}, model: model}}
  end

  def websocket_handle({:text, payload}, state = %{model: model, vdom: vdom}) do
    message = {:increment, 1}

    new_model = Whistle.update(model, message)

    new_vdom = Whistle.view(new_model)

    vdom_diff =
      Whistle.Html.diff([], vdom, new_vdom)
      |> Whistle.Html.serialize_patches()

    IO.inspect(vdom_diff)

    {:reply, {:text, vdom_diff}, %{state | model: new_model, vdom: new_vdom}}
  end

  def websocket_info(info, state) do
    {:reply, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end
end
