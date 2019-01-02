defmodule Whistle.ProgramConnection do

  alias Whistle.ProgramRegistry

  defstruct pid: nil, name: nil, vdom: {0, nil}, handlers: %{}, session: %{}

  defp handler_message(%{handlers: handlers}, name, args) do
    case Map.get(handlers, name) do
      nil ->
        {:error, "handler not found"}

      handler when is_function(handler) ->
        {:ok, apply(handler, args)}

      message ->
        {:ok, message}
    end
  end

  def update(program = %{pid: pid, name: name, session: session}, {handler, args}) do
    with {:ok, message} <- handler_message(program, handler, args) do
      try do
        {:ok, new_session} = GenServer.call(pid, {:update, message, session})
        {:ok, %{program | session: new_session}}
      catch
        :exit, value ->
          {:error, :program_crash}
      end
    end
  end

  def put_new_vdom(program, new_vdom) do
    {handlers, vdom_diff} =
      diff(program, new_vdom)

    new_program = %{program | vdom: new_vdom, handlers: handlers}

    {new_program, vdom_diff}
  end

  def diff(%{vdom: vdom}, new_vdom) do
    handlers =
      []
      |> Whistle.Dom.extract_event_handlers(new_vdom)
      |> Enum.into(%{})
      |> IO.inspect()

    vdom_diff =
      Whistle.Dom.diff([], vdom, new_vdom)
      |> Whistle.Dom.serialize_patches()

    {handlers, vdom_diff}
  end
end

