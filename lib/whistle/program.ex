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
  @callback authorize(Whistle.state(), Socket.t(), map()) :: {:ok, Socket.t(), Whistle.Session.t()} | {:error, any()}
  @callback update(Whistle.message(), Whistle.state(), Socket.t()) :: {:ok, Whistle.state(), Whistle.Session.t()}
  @callback view(Whistle.state(), Whistle.Session.t()) :: Whistle.Dom.t()
end
