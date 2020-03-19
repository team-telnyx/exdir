# ExDir - Iterative directory listing library

Copyright (c) 2020 Telnyx LLC.

**dirent** is an iterative directory listing for Elixir.

Elixir function `File.ls/1` return files from directories _after_ reading them
from the filesystem.  When you have an humongous number of files on a single
folder, `File.ls/1` will block for a certain time.

In these cases you may not be interested in returning the full list of files,
but instead you may want to list them _iteratively_, returning each entry after
the another to your process, at the moment they are taken from
[_readdir_](http://man7.org/linux/man-pages/man3/readdir.3.html).

## Installation

The package can be installed by adding `exdir` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:exdir, "~> 0.1.0"}
  ]
end
```

Further docs can be found at
[https://hexdocs.pm/exdir](https://hexdocs.pm/exdir).
