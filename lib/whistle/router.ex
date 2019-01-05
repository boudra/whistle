defmodule Whistle.Router do
  def child_spec(router) do
    children = [
      {Registry, [keys: :unique, name: Module.concat(router, Registry)]},
      {DynamicSupervisor, [name: Module.concat(router, Supervisor), strategy: :one_for_one]}
    ]

    default = %{
      id: router,
      start: {Supervisor, :start_link, [children, [name: router, strategy: :one_for_one]]},
      type: :supervisor
    }

    Supervisor.child_spec(default, [])
  end

  defmacro __using__(_opts) do
    quote do
      # @behaviour Whistle.Router
      import Whistle.Router
    end
  end

  defmacro match(expr, program, params) do
    expr_components = String.split(expr, ":")

    expr_match =
      Enum.map(expr_components, fn
        "*" -> {:_, [], nil}
        "*" <> name -> {String.to_atom(name), [], nil}
        part -> part
      end)

    params_map =
      Enum.reduce(expr_components, [], fn
        "*" <> name, acc when byte_size(name) > 0 ->
          acc ++
            [
              {name, {String.to_atom(name), [], nil}}
            ]

        _, acc ->
          acc
      end)

    quote do
      def __match(unquote(expr_match)) do
        new_params = Map.merge(unquote(params), Map.new(unquote(params_map)))

        {:ok, unquote(program), new_params}
      end
    end
  end
end
