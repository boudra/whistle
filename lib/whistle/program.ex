defmodule Whistle.Program do
  alias Whistle.Socket

  defmacro __using__(_opts) do
    quote do
      @behaviour Whistle.Program

      alias Whistle.Html
      import Whistle.Socket
    end
  end

  @callback init(map()) :: {:ok, Whistle.state()}
  @callback authorize(Whistle.state(), Socket.t(), map()) :: {:ok, Socket.t()} | {:error, any()}
  @callback update(Whistle.message(), Whistle.state(), Socket.t()) :: {:ok, Whistle.state(), Socket.t()}
  @callback view(Whistle.state(), Socket.t()) :: Whistle.Dom.t()
end
