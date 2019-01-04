defmodule Whistle.ProgramConnection do

  alias Whistle.ProgramRegistry

  defstruct pid: nil, name: nil, lazy_trees: %{}, vdom: {0, nil}, handlers: %{}, session: %{}

  defp handler_message(%{handlers: handlers}, name, args) do
    handlers
    |> Map.get(name, %{})
    |> Map.get(:msg)
    |> case do
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
      IO.inspect {:message}
      try do
        {:ok, new_session} = GenServer.call(pid, {:update, message, session})
        {:ok, %{program | session: new_session}}
      catch
        :exit, value ->
          {:error, :program_crash}
      end
    end
  end

  def put_new_vdom(program = %{vdom: vdom}, new_vdom) do
    vdom =
      program
      |> Map.take([:handlers, :lazy_trees])
      |> Map.put(:patches, [])
      |> Whistle.Dom.diff(vdom, new_vdom)

    new_program = %{program | vdom: new_vdom, handlers: vdom.handlers, lazy_trees: vdom.lazy_trees}

    {new_program, vdom.patches}
  end
end

