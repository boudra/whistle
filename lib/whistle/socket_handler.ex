defmodule Whistle.SocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def websocket_init({router, []}) do
    {:ok, %{
      router: router,
      channels: %{}
    }}
  end

  def websocket_handle({:text, payload}, state = %{channels: channels}) do
    case Jason.decode(payload) do
      {:ok, %{"type" => "event", "channel" => channel, "handler" => handler, "arguments" => args}} ->
        handle(channel, {handler, args}, state)

      {:ok, %{"type" => "join", "channel" => channel, "params" => params}} ->
        channel_pid =
          case state.router.join(channel, params) do
            {:ok, pid} ->
              pid
          end

        channel_info = %{
          pid: channel_pid,
          vdom: nil,
          handlers: %{}
        }

        Phoenix.PubSub.subscribe(Whistle.PubSub, channel)

        new_vdom = GenServer.call(channel_pid, :view)

        reply_render(channel, new_vdom, %{state | channels: Map.put(channels, channel, channel_info)})
    end
  end

  def reply_render(channel, new_vdom, state) do
    channel_info = %{vdom: vdom, pid: pid} =
      Map.get(state.channels, channel)

    vdom_diff =
      Whistle.Dom.diff([], vdom, new_vdom)
      |> Whistle.Dom.serialize_patches()

    handlers =
      Whistle.Dom.extract_event_handlers([], new_vdom)
      |> Enum.into(%{})

    response = Jason.encode!(%{
      channel: channel,
      dom_patches: vdom_diff
    })

    channel_info = %{ channel_info | vdom: new_vdom, handlers: handlers }

    {:reply, {:text, response}, %{state | channels: Map.put(state.channels, channel, channel_info)}}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  def websocket_info({:view, channel, vdom}, state) do
    reply_render(channel, vdom, state)
  end

  defp handle(channel, {handler, args}, state) do
    %{handlers: handlers} =
      Map.get(state.channels, channel)

    message =
      case Map.get(handlers, handler) do
        handler when is_function(handler) ->
          apply(handler, args)

        msg ->
          msg
      end

    update_model(channel, message, state)
  end

  defp update_model(channel, message, state = %{channels: channels}) do
    %{pid: pid} =
      Map.get(channels, channel)

    GenServer.cast(pid, {:update, message})

    {:ok, state}
  end
end
