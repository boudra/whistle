defmodule Whistle.Program do
  @callback init(map()) :: Whistle.state()
  @callback update(Whistle.state(), any) :: Whistle.state()
  @callback view(Whistle.state()) :: Whistle.Dom.t()
end
