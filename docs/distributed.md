# Distributed Elixir

Whistle uses a Registry and a DynamicSupervisor to start and monitor running programs.

By default, we use Elixir's versions: `Elixir.Registry` and `Elixir.DynamicSupervisor` which spawn programs in a single node, if you've got multiple Elixir nodes connected, you might want to distribute programs and prevent launching the same program in two different nodes.

[Horde](https://github.com/derekkraan/horde) is a very good drop in replacement for the Elixir core modules, as it supports the same API, you can swap the registry and supervisor used like this:


```elixir
config :whistle,
  program_registry: Horde.Registry,
  program_supervisor: Horde.DynamicSupervisor
```
