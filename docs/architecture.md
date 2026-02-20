# Architecture

Lapidary uses [dry-system](https://dry-rb.org/gems/dry-system/) for dependency injection and component management.

## Directory Structure

```
lib/lapidary/          # Auto-registered components
system/providers/      # External service providers (database, cache, etc.)
app.rb                 # Sinatra application (HTTP layer)
config.ru              # Rack entry point
```

## Dependency Injection

- `Lapidary::Container` — the central IoC container; auto-registers components under `lib/lapidary/`
- `Lapidary::Dependency` — mixin for injecting dependencies into classes via `include Dependency[...]`

## Adding a Component

Place a file under `lib/lapidary/` and it will be auto-registered:

```ruby
# lib/lapidary/greeter.rb
module Lapidary
  class Greeter
    def call(name)
      "Hello, #{name}!"
    end
  end
end
```

Resolve it from the container:

```ruby
Lapidary::Container['greeter']
```

Or inject it into another class:

```ruby
class MyService
  include Lapidary::Dependency['greeter']
end
```
