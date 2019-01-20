defmodule Whistle.Config do
  @moduledoc false

  def registry() do
    Application.get_env(:whistle, :program_registry, Elixir.Registry)
  end

  def supervisor() do
    Application.get_env(:whistle, :program_supervisor, Elixir.DynamicSupervisor)
  end

  def json_library() do
    Application.get_env(:whistle, :json_library, Jason)
  end

end
