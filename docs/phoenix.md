# Integrating with Phoenix

Because Whistle is based on Plug and Cowboy, it can also work alongside Phoenix.

All we need to do is add the router handlers to the Cowboy dispatch options.

To get the Cowboy handlers, pass a list of all your routers as an argument to the `build_handlers/1` helper:

```elixir
Whistle.HttpServer.build_handlers([MyAppWeb.ProgramRouter])
```

Here is how this looks looks like in your config:

```elixir
config :myapp, MyAppWeb.Endpoint,
  http: [dispatch: [
          {:_, Whistle.HttpServer.build_handlers([MyAppWeb.ProgramRouter]) ++ [
              {:_, Phoenix.Endpoint.Cowboy2Handler, {MyAppWeb.Endpoint, []}}
            ]}]]
```

Check out the [Phoenix.CowBoy2.Adapter docs](https://hexdocs.pm/phoenix/Phoenix.Endpoint.Cowboy2Adapter.html) for more info.

Once the handlers have been added, you can embed a program in your views like so:

```elixir
<%= raw(Whistle.Program.embed(conn, MyAppWeb.ProgramRouter, "counter")) %>
```

Both `Whistle.Program.embed/4` and `Whistle.Program.fullscreen/4` will do an initial server side plain HTML render and then update the program dynamically once the client has connected to the router.

## Loading the Javascript library

Add `whistle.js` from Elixir's dependency folder, remember to run `mix deps.get` before:

```
npm install --save deps/whistle
```

If you use the `Whsitle.Program` helpers, loading whistle.js in the client is all you have todo for it to work. But if you prefer to mount programs manually in the client, you can do it like this:

```javascript
import { Whistle } from 'whistle';

const socket = Whistle.open("ws://localhost:4000/socket");
const target = document.getElementById("target");
const program = socket.mount(target, "counter", {});
```

Check out the [Javascript API documentation](/docs/javascript.md) for more.

