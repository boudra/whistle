defmodule Whistle.Program do
  alias Whistle.Socket

  @callback join(String.t(), Socket.t(), map()) :: {:ok, Socket.t()} | {:error, any()}
  @callback init(String.t()) :: {:ok, Whistle.state()}
  @callback update(Whistle.message(), Whistle.state(), Socket.t()) :: {:ok, Whistle.state(), Socket.t()}
  @callback view(Whistle.state(), Socket.t()) :: Whistle.Dom.t()
end
