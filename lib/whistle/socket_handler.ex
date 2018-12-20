defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  def init(req, {router, []}) do
    conn = Plug.Cowboy.Conn.conn(req)
    program = router.route(conn)

    {:cowboy_websocket, req, program}
  end

  def websocket_init(program) do
    model = program.init(%{})

    send(self(), :render)

    {:ok, %{program: program, handlers: [], vdom: nil, model: model}}
  end

  def websocket_handle({:text, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"handler" => handler, "arguments" => args}} ->
        handle({handler, args}, state)
    end
  end

  def reply_render(state) do
    IEx.Helpers.r(state.program)

    new_vdom =
      {0, state.program.view(state.model)}

    vdom_diff =
      Whistle.Dom.diff([], state.vdom, new_vdom)
      |> Whistle.Dom.serialize_patches()

    handlers =
      Whistle.Dom.extract_event_handlers([], new_vdom)
      |> Enum.into(%{})

    {:reply, {:text, vdom_diff}, %{state | handlers: handlers, vdom: new_vdom}}
  end

  def websocket_info(:render, state) do
    reply_render(state)
  end

  def websocket_info({:message, message}, state) do
    update_model(message, state)
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  defp handle({handler, args}, state = %{handlers: handlers}) do
    message =
      case Map.get(handlers, handler) do
        handler when is_function(handler) ->
          apply(handler, args)

        msg ->
          msg
      end

    update_model(message, state)
  end

  defp update_model(message, state = %{model: model}) do
    new_model = state.program.update(model, message)

    reply_render(%{state | model: new_model})
  end
end
