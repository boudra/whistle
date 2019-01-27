defmodule RouterTest do
  use ExUnit.Case
  doctest Whistle

  alias Whistle.Router

  defmodule ExampleRouter do
    use Whistle.Router, path: "/ws"

    match("chat:*lobby", ExampleProgram, %{})
  end

  test "router child_spec" do
    assert %{
             id: _,
             start:
               {Supervisor, :start_link,
                [
                  [
                    {Registry, _},
                    {DynamicSupervisor, _}
                  ],
                  [name: ExampleRouter, strategy: :one_for_one]
                ]}
           } = ExampleRouter.child_spec([])
  end

  test "start router" do
    assert {:ok, pid} = ExampleRouter.start_link([])
    assert Process.alive?(pid)
  end

  test "url helper" do
    assert Router.url(%Plug.Conn{port: 80}, ExampleRouter) == "ws://www.example.com/ws"

    assert Router.url(
             %Plug.Conn{req_headers: [{"x-forwarded-proto", "https"}], port: 80},
             ExampleRouter
           ) == "wss://www.example.com:80/ws"

    assert Router.url(
             %Plug.Conn{req_headers: [{"x-forwarded-port", "443"}], port: 80},
             ExampleRouter
           ) == "ws://www.example.com:443/ws"
  end

  test "route matchers" do
    assert ExampleRouter.__match(["chat", "one"]) == {:ok, ExampleProgram, %{"lobby" => "one"}}
    assert ExampleRouter.__match(["whoops"]) == {:error, :not_found}
  end
end
