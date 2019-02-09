# Whistle
[![Hex.pm](https://img.shields.io/hexpm/v/whistle.svg)](https://hex.pm/packages/whistle) [![Build Status](https://travis-ci.org/boudra/whistle.svg?branch=master)](https://travis-ci.org/boudra/whistle) [![Inline docs](http://inch-ci.org/github/boudra/whistle.svg)](http://inch-ci.org/github/boudra/whistle) [![Coverage Status](https://coveralls.io/repos/github/boudra/whistle/badge.svg)](https://coveralls.io/github/boudra/whistle)

<br>

Whistle is a library for building interactive web apps or small components entirely in Elixir, it can render components in HTML and via WebSockets, all Whistle programs are able to do:

- Server side rendering, like in any modern web framework
- Client side interactivity using an architecture similar to Elm
- Single page application routing with Plug, so that the page doesn't need to be fully reloaded

For an example Single Page Application including Server Side Rendering and routing, that uses most of Whistle's features, check out this chat application:

- Code: [boudra/whistle-chat](https://github.com/boudra/whistle-chat)
- Demo: [https://lumpy-some-piglet.gigalixirapp.com/](https://lumpy-some-piglet.gigalixirapp.com/)

Links:

- Documentation: [https://hexdocs.pm/whistle](https://hexdocs.pm/whistle)
- [Getting started](https://hexdocs.pm/whistle/readme.html#getting-started)


**Please remember that this project is still in it's very early stages, some things might not work and the API will most definetly change. Also it is just a side project at the moment so development could be slow.**


## Installation

```elixir
def deps do
  [
    {:whistle, git: "https://github.com/boudra/whistle", ref: "master"},
    # {:whistle, "~> 0.1.0"},

    # optional
    {:jason, "~> 1.0"}, # for encoding and decoding JSON
    {:horde, "~> 0.4.0"} # for distributing the program processes
  ]
end
```

## Getting started

The router is where everything starts, it defines the path of the Websocket listener and what routes match to what programs.

Here is an example:

```elixir
# lib/my_app_web/program_router.ex

defmodule MyAppWeb.ProgramRouter do
  use Whistle.Router, path: "/ws"

  match("counter", MyAppWeb.ExampleProgram, %{})
end
```

Use `Whistle.Router.match/3` to define program routes, the router will spawn a new program instance for every unique route.

The program is a module where we specify how to manage and render its state, here is a very simple example:

```elixir
# lib/my_app_web/programs/example_program.ex

defmodule MyAppWeb.ExampleProgram do
  use Whistle.Program

  def init(_params) do
    {:ok, 0}
  end

  def update(:increment, state, session) do
    {:ok, state + 1, session}
  end

  def update(:decrement, state, session) do
    {:ok, state - 1, session}
  end

  def view(state, _session) do
    ~H"""
    <div>
      <button on-click={{ :increment }}>+</button>
      <span>The current number is: {{ state }}></span>
      <button on-click={{ :decrement }}>-</button>
    </div>
    """
  end
end
```

Check out the docs for `Whistle.Program` to see all the callbacks available and the different ways to render the view.

All you need to do now is add the router in your supervision tree, a router will spawn a dynamic Supervisor and Registry to keep track of all the program instances, you can run as many different routers as you want:

```elixir
# lib/my_app/application.ex

children = [
  {MyAppWeb.ProgramRouter, []}
]
```

Now that you have a router and a program set up, it's time to link everything up with a server, Whistle works with Plug so it doesn't need Phoenix to run, but you can integrate with an existing Phoenix project too:

- [Running with Whistle and Plug](https://hexdocs.pm/whistle/setup.html)
- [Integrate with your existing Phoenix project](https://hexdocs.pm/whistle/phoenix.html)


## FAQs

### What problems does Whistle address?

Whistle is a web library that works a bit differently than normal MVC web frameworks. It is composed of stateful long-running components, allowing you to create interactive applications entirely in Elixir via WebSockets, while being also able to render an HTML page like any other web framework.

It aims to provide a more functional approach to building web apps in Elixir, while also taking more advantage of Erlang's actor model.

It also provides an extensive [Javascript API](https://hexdocs.pm/whistle/javascript.html) for when Elixir alone doesn't cut it and interop with existing front-end libraries like React is needed.

### What is a Router?

A Router is a module that defines what routes match what programs, every unique route string will spawn a unique program instance. The router also supervises the [Program Regsitry](https://hexdocs.pm/whistle/Whistle.Program.Registry.html), the Program Supervisor and the [HTTP server](https://hexdocs.pm/whistle/setup.html) if there is one.

### What is a Program?

A program is a stateful component that runs as an Erlang process, this is where we define how the state looks like, how it's updated and how it's rendered.

### What is the difference between a Fullscreen Program and an Embeded Program?

A fullscreen Program is when a Program renders the whole HTML document, including the `<head>` and the `<body>`. Fullscreen programs normally take control of the routing too, you can make a whole web application with a Fullscreen program.

Embeded programs are normally small components that can be included in your web page, like a typeahead search widget or a chat.

### How does the Virtual DOM work?

The Virtual DOM is an in-memory representation of the client's DOM that lives in the server, every time a Program's state changes, Whistle will render it compare the new Virtual DOM against the old one, and send minimal changes to the client via WebSockets.

Whistle's Virtual DOM is represented as follows:

```elixir
# {key, {tag, {attributes, children}}}
{0, {"div", {[class: "red"], [{0, "first"}, {1, "second"}]}}}
```
You can use the macros to generate it (preferable):

```elixir
Html.div([class: "red"], [
  "first",
  "second"
])
```

Or the `~H` sigil (note that this is not EEx, it is a custom templating format similar to Mustache):

```elixir
~H"""
<div class="red">first second</div>
"""
```

The Virtual DOM consists of pairs of tuples so that it can also be a valid Elixir AST and be able to generate most of it at compile time:

```elixir
iex> a = "text"
iex> Html.span([], [a])
{0, {"span", {[], [{0, {:a, [], nil}}]}}}
```

Whistle also provides functions to render a VDOM to string, this is used to render a HTML response when rendering Programs in Plug.

```elixir
iex> Html.span([], ["text"]) |> Whistle.Html.Dom.node_to_string()
<span>text</span>
```

## Roadmap


What has been done so far:

- [x] Program orchestrating, program error recovery, client auto-reconnections
- [x] Program and client message communication and broadcasting
- [x] Lazy Virtual DOM trees to reduce unecessary rendering and diffing
- [x] Integrate Virtual DOM with Elixir's AST so it can be generated at compile-time
- [x] Initial render via HTTP, then stream updates via WebSockets
- [x] Full screen program mode with routing and browser history to build Single Page Applications with Server Side Rendering :rocket:
- [x] HTML string template file to VDOM tree in the view
- [x] "Single Page Applications" with built in routing and browser history support
- [x] Code reloading for code Programs without having to restart

Checkout the issues list to see what features are planned:

https://github.com/boudra/whistle/issues
