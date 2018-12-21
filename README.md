# Whistle

Whistle is a different approach to building web applications, it allows you to write interactive dynamic web apps entirely in Elixir.

## How does it work?

If you are familiar with [The Elm Architecture](https://guide.elm-lang.org/architecture/), Whistle moves this architecture to the server and streams DOM changes to the client via WebSockets.

```
$ iex -S mix
```

Then navigate to http://localhost:4000/index.html to preview the app

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `whistle` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:whistle, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/whistle](https://hexdocs.pm/whistle).

