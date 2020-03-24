defmodule ExDir.Stream do
  @moduledoc """
  Defines a `ExDir.Stream` struct returned by `ExDir.stream!/2`.

  The following fields are public:

    * `path`          - the directory path
    * `recursive`     - if file listing is recursive
    * `raw`           - if any filename should be returned, even invalid Unicode names
    * `type`          - if file types should be also returned

  """

  defstruct path: nil, recursive: false, options: []

  @type t :: %__MODULE__{}

  @doc false
  def __build__(path, recursive, options \\ []),
    do: %ExDir.Stream{path: path, recursive: recursive, options: options}

  defimpl Enumerable do
    def reduce(%{path: path, recursive: recursive, options: options}, acc, fun) do
      Stream.resource(
        fn -> opendir!(path) end,
        &readdir!(&1, recursive, options),
        & &1
      ).(acc, fun)
    end

    defp opendir!(path) do
      case :dirent.opendir(path) do
        {:ok, dir} ->
          [{dir, path}]

        {:error, reason} ->
          raise ExDir.Error,
            reason: reason,
            action: "read directory",
            path: path
      end
    end

    defp readdir!([{dir, path} | rest] = stack, recursive, options) do
      mode = Keyword.get(options, :read, :type)

      case ExDir.read(dir, read: mode) do
        nil ->
          case rest do
            [] -> {:halt, dir}
            _other -> readdir!(rest, recursive, options)
          end

        {:error, reason} ->
          raise ExDir.Error,
            reason: reason,
            action: "read directory",
            path: path

        {file_type, file_path} ->
          inspect_type(file_path, file_type, stack, recursive, options)
      end
    end

    defp inspect_type(file_path, :directory, stack, true, options),
      do: readdir!(opendir!(file_path) ++ stack, true, options)

    defp inspect_type(file_path, file_type, stack, _recursive, options)
         when file_type != :unknown do
      case Keyword.get(options, :read) do
        nil ->
          {[file_path], stack}

        _ ->
          {[{file_type, file_path}], stack}
      end
    end

    defp inspect_type(file_path, :unknown, stack, recursive, options) do
      %{type: file_type} = File.lstat!(file_path)
      inspect_type(file_path, file_type, stack, recursive, options)
    end

    def count(_stream) do
      {:error, __MODULE__}
    end

    def member?(_stream, _term) do
      {:error, __MODULE__}
    end

    def slice(_stream) do
      {:error, __MODULE__}
    end
  end
end
