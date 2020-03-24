defmodule ExDir.Error do
  defexception [:reason, :path, action: ""]

  @impl true
  def message(%{action: action, reason: reason, path: path}) do
    formatted =
      case {action, reason} do
        {_action, {:no_translation, raw_name}} ->
          "translate filename #{inspect raw_name} in"

        {_action, :not_owner} ->
          "not process owner"

        _ ->
          IO.iodata_to_binary(:file.format_error(reason))
      end

    "could not #{action} #{inspect(path)}: #{formatted}"
  end
end
