defmodule ExDir do
  @moduledoc """
  `ExDir` is an iterative directory listing for Elixir.

  Elixir function `File.ls/1` return files from directories _after_ reading
  them from the filesystem.  When you have an humongous number of files on a
  single folder, `File.ls/1` will block for a certain time.

  In these cases you may not be interested in returning the full list of files,
  but instead you may want to list them _iteratively_, returning each entry
  after the another to your process, at the moment they are taken from
  [_readdir_](http://man7.org/linux/man-pages/man3/readdir.3.html).

  The `Enumerable` protocol has been implemented for `ExDir`, so all usual
  functions such as `Enum.map`, `Enum.reduce`, etc are available.

  For example, you can return all files in a given directory in a list with:

      {:ok, dir} = ExDir.opendir(".")
      Enum.map(dir, &(&1))

  Or count the number of files in a directory:

      {:ok, dir} = ExDir.opendir(".")
      Enum.count(dir)

  The above examples aren't practical when you have tons of files in the
  directory, which makes the above functions very similar to `File.ls/1`.

  If your intention is to consume files from a very large folder, then you
  might be interested in reading the file names and distribute them to worker
  processes to do some job. In this case the following example is the most
  suitable:

      {:ok, dir} = ExDir.opendir(".")
      Enum.each(fn file_path ->
        push_to_worker(file_path)
      end)

  So you can start consuming files straight away, without having to wait for
  `File.ls/1` to complete as you would normally do.

  Notice that `ExDir` is a system resource and thus it is _mutable_. It means
  that after reading all files from the directory, the only way to read it a
  second time is by opening the directory again.

  The order of the files is highly dependent of the filesystem, and no ordering
  is guaranteeded. This is intentional as large directories is the main purpose
  of this library. If reading tons of files in a specific order is important
  for your application, you should think twice: or you read all files from
  system and order them by yourself, which will be very time consuming for very
  long directories, or better accept listing them unordered.
  """

  @type t :: reference

  @type options :: [option]

  @type option :: {:read, :type | :raw}

  @type filename :: Path.t

  @type dirname :: Path.t

  @type posix_error :: :enoent | :eacces | :emfile | :enfile | :enomem | :enotdir | atom

  @type file_type :: :device | :directory | :symlink | :regular | :other | :undefined

  @doc """
  Opens the given `path`.

  Possible error reasons:

    * `:enoent`: Directory does not exist, or `path` is an empty string.
    * `:eacces`: Permission denied.
    * `:emfile`: The per-process limit on the number of open file descriptors
      has been reached.
    * `:enfile`: The system-wide limit on the total number of open files has
      been reached.
    * `:enomem`: Insufficient memory to complete the operation.
    * `:enotdir`: `path` is not a directory.

  ## Example

      ExDir.open(".")
      {:ok, #Reference<0.3456274719.489029636.202763>}
  """
  @spec open(dirname) :: {:ok, t} | {:error, posix_error}
  def open(path \\ ".") when is_binary(path) do
    case :dirent.opendir(path) do
      {:ok, dir} -> {:ok, dir}
      error -> error
    end
  end

  @doc """
  Reads the opened directory.

  The only available option is `:read`. You can choose one of the following:

    * `:type` - if the filesystem supports it, returns the file type along the
      file name while reading. It will skip filenames with invalid Unicode
      characters.
    * `:raw` - returns the file type, and doesn't skip filenames containing
      invalid Unicode characters (use with care).

  If not specified, the `readdir` will not return file types and will skip
  invalid filenames.

  This function returns each entry in the directory iteratively. Filenames
  contain the full path, including the start `path` passed to `opendir/1`.

  This function breaks the general immutability of the language in the sense
  that `ExDir` is actually a system resource identifier, and thus it is mutable
  internally. It means that calling this function twice for the same `dir`
  will result in different results.
  """
  @spec read(t) ::
          filename
          | {file_type, filename}
          | {:error, reason :: {:no_translation, binary} | :not_owner}
          | nil
  def read(dir, opts \\ []) when is_list(opts) do
    result =
      case Keyword.get(opts, :read) do
        nil -> :dirent.readdir(dir)
        :type -> :dirent.readdir_type(dir)
        :raw -> :dirent.readdir_raw(dir)
      end

    case result do
      :finished ->
        nil

      {:error, reason} ->
        {:error, reason}

      {file_path, :unknown} ->
        file_path
        |> normalize_to_binary()
        |> file_stat()

      {file_path, file_type} ->
        file_path =
          file_path
          |> normalize_to_binary()

        {file_type, file_path}

      file_path ->
        file_path
        |> normalize_to_binary()
    end
  end

  defp normalize_to_binary(file_path) when is_list(file_path),
    do: IO.chardata_to_string(file_path)

  defp normalize_to_binary(file_path), do: file_path

  defp file_stat(file_path) do
    case File.lstat(file_path) do
      {:ok, %{type: file_type}} -> {file_type, file_path}
      error -> error
    end
  end

  @doc """
  Set controlling affinity.

  Once created, `ExDir` resources are associated to the calling process and
  `readdir/1` should be executed by the same process. If passing to another
  process is required, then this function should be called from the process
  owner, delegating control to another process indicated by `pid`.
  """
  @spec set_controlling_process(t, pid) :: :ok
  def set_controlling_process(dir, owner) when is_pid(owner),
    do: :dirent.controlling_process(dir, owner)

  @doc """
  Returns a `ExDir.Stream` for the given `path` with the given `options`.

  The stream implements only the `Enumerable` protocol, which means it can be
  used for read only.

  The `options` argument configures how the filenames are returned when
  streaming. It can be:

    * `:raw` - all filenames will be returned, even invalid Unicode filenames.
      Case this option is `false` (default) and the filename can't be
      translated to Unicode, then an exception `ExDir.Error` will be raised.
    * `type` - filenames will be returned along with their types in tuples
      `{file_type, file_path}`, otherwise just `file_path`.

  If the `recursive` argument is true, all subdirectories will be recursed,
  except directory entries themselves.
  """
  def stream!(path, recursive \\ false, options \\ []),
    do: ExDir.Stream.__build__(path, recursive, options)
end
