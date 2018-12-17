defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def websocket_init(_state) do
    model = Whistle.init()

    {:ok, %{handlers: [], vdom: {0, {nil, [], []}}, model: model}}
  end

  def websocket_handle({:text, "hola"}, state) do
    reply_render(state)
  end

  def websocket_handle({:text, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"handler" => handler, "arguments" => args}} ->
        handle({handler, args}, state)
    end
  end

  def reply_render(state) do
    new_vdom =
      {0, Whistle.view(state.model)}

    vdom_diff =
      Whistle.Dom.diff([], state.vdom, new_vdom)
      |> Whistle.Dom.serialize_patches()

    handlers =
      Whistle.Dom.extract_event_handlers([], new_vdom)
      |> Enum.into(%{})

    {:reply, {:text, vdom_diff}, %{state | handlers: handlers, vdom: new_vdom}}
  end

  def handle({handler, args}, state = %{handlers: handlers, model: model}) do
    message =
      case Map.get(handlers, handler) do
        handler when is_function(handler) ->
          apply(handler, args)

        msg ->
          msg
      end

    new_model = Whistle.update(model, message)

    reply_render(%{state | model: new_model})
  end

  def websocket_info(_info, state) do
    {:reply, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end
end
