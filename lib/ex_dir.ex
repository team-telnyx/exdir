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

  defstruct dir: nil

  @type t :: %__MODULE__{dir: reference}

  @doc """
  Opens the given `path`.

  Possible errors:

    * `{:error, :enoent}`: Directory does not exist, or `path` is an empty
      string.
    * `{:error, :eacces}`: Permission denied.
    * `{:error, :emfile}`: The per-process limit on the number of open file
      descriptors has been reached.
    * `{:error, :enfile}`: The system-wide limit on the total number of open
      files has been reached.
    * `{:error, :enomem}`: Insufficient memory to complete the operation.
    * `{:error, :enotdir}`: `path` is not a directory.

  ## Example

      ExDir.opendir(".")
      {:ok, #ExDir<#Reference<0.3456274719.489029636.202763>>}
  """
  @spec opendir(Path.t()) :: {:ok, t} | {:error, term}
  def opendir(path \\ ".") when is_binary(path) do
    case :dirent.opendir(path) do
      {:ok, dir} -> {:ok, %__MODULE__{dir: dir}}
      error -> error
    end
  end

  @doc """
  Reads the opened directory.

  This function returns each entry in the directory iteratively. Filenames
  contain the full path, including the start `path` passed to `opendir/1`.

  This function breaks the general immutability of the language in the sense
  that `ExDir` is actually a system resource identifier, and thus it is mutable
  internally. It means that calling this function twice for the same `ExDir`
  will result in different results.
  """
  @spec readdir(t) :: binary | nil
  def readdir(%__MODULE__{dir: dir}) do
    case :dirent.readdir(dir) do
      :finished ->
        nil

      file_path ->
        IO.chardata_to_string(file_path)
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
  def set_controlling_process(%__MODULE__{dir: dir}, owner) when is_pid(owner),
    do: :dirent.set_controlling_process(dir, owner)
end

defimpl Enumerable, for: ExDir do
  def count(_dir), do: {:error, __MODULE__}

  def member?(_dir, _file_path), do: {:error, __MODULE__}

  def reduce(_dir, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(dir, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(dir, &1, fun)}

  def reduce(dir, {:cont, acc}, fun) do
    case ExDir.readdir(dir) do
      nil -> {:done, acc}
      head -> reduce(dir, fun.(head, acc), fun)
    end
  end

  def slice(_dir), do: {:error, __MODULE__}
end

defimpl Inspect, for: ExDir do
  import Inspect.Algebra

  def inspect(%ExDir{dir: dir}, opts) do
    concat(["#ExDir<", to_doc(dir, opts), ">"])
  end
end
