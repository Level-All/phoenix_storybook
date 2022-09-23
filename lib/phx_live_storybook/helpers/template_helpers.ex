defmodule PhxLiveStorybook.TemplateHelpers do
  @moduledoc false

  @variation_regex ~r{(<\.lsb-variation\/>)|(<\.lsb-variation\s[^(\>)]*\/>)}
  @variation_group_regex ~r{<\.lsb-variation-group[^(\>)]*\/>}
  @html_attributes_regex ~r{(\w+)=((?:.(?!["']?\s+(?:\S+)=|\s*\/?[>]))+.["']?)?}
  @js_push_regex ~r[(JS\.push\("(?:assign|toggle)".*value:\s+)(%{.*})(.*\))]

  def default_template, do: "<.lsb-variation/>"

  def set_variation_id(template, variation_id) do
    template = String.replace(template, ":variation_id", variation_id_to_s(variation_id))

    Regex.replace(@js_push_regex, template, fn _, open, match, close ->
      match =
        match
        |> Code.eval_string()
        |> elem(0)
        |> Map.put(:variation_id, variation_id_to_serializable(variation_id))
        |> inspect()

      open <> match <> close
    end)
  end

  defp variation_id_to_s({group_id, variation_id}), do: "#{group_id}:#{variation_id}"
  defp variation_id_to_s(variation_id), do: to_string(variation_id)

  defp variation_id_to_serializable({group_id, variation_id}), do: [group_id, variation_id]
  defp variation_id_to_serializable(variation_id), do: variation_id

  def variation_template?(template) do
    Regex.match?(@variation_regex, template)
  end

  def variation_group_template?(template) do
    Regex.match?(@variation_group_regex, template)
  end

  def code_hidden?(template) do
    String.contains?(template, "lsb-code-hidden")
  end

  def replace_template_variation(template, variation_markup, indent? \\ false) do
    replace_in_template(template, @variation_regex, variation_markup, indent?)
  end

  def replace_template_variation_group(template, variation_group_markup, indent? \\ false) do
    replace_in_template(template, @variation_group_regex, variation_group_markup, indent?)
  end

  def get_template(template, _variation = %{template: :unset}), do: template

  def get_template(_tpl, _variation = %{template: t}) when t in [nil, false],
    do: default_template()

  def get_template(template, nil), do: template
  def get_template(_tpl, _variation = %{template: template}), do: template

  def extract_placeholder_attributes(template, inspect \\ nil) do
    cond do
      variation_template?(template) ->
        extract_placeholder_attributes(template, @variation_regex, inspect)

      variation_group_template?(template) ->
        extract_placeholder_attributes(template, @variation_group_regex, inspect)

      true ->
        ""
    end
  end

  defp extract_placeholder_attributes(template, regex, _inspect = nil) do
    [placeholder | _] = Regex.run(regex, template)

    @html_attributes_regex
    |> Regex.scan(placeholder)
    |> Enum.map_join(" ", fn [match, _, _] -> match end)
  end

  # When rendering a variation from the component Playground, the playground will pass some context
  # (topic and variation_id).
  # We use this context to wrap template examples, unknown from the Playground, within a
  # `lsb_inspect/4` call that will broadcast examples to the Playground.
  defp extract_placeholder_attributes(template, regex, {topic, variation_id}) do
    [placeholder | _] = Regex.run(regex, template)

    @html_attributes_regex
    |> Regex.scan(placeholder)
    |> Enum.map_join(" ", fn [_, term1, term2] ->
      "#{term1}={lsb_inspect(#{inspect(topic)}, #{inspect(variation_id)}, :#{term1}, #{inspect_val(term2)})}"
    end)
  end

  defp inspect_val(var) do
    if Regex.match?(~r/{.*}/, var) do
      String.replace(var, ["{", "}"], "")
    else
      var
    end
  end

  defp replace_in_template(template, regex, markup, _indent? = true) do
    template
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      if Regex.match?(regex, line) do
        indent_size = indent_size(line)
        indent(markup, indent_size)
      else
        line
      end
    end)
  end

  defp replace_in_template(template, regex, markup, _indent? = false) do
    String.replace(template, regex, markup)
  end

  defp indent_size(line) do
    if String.starts_with?(line, " ") do
      [indent | _] = line |> String.codepoints() |> Enum.chunk_by(&(&1 == " "))
      length(indent)
    else
      0
    end
  end

  defp indent(markup, indent_size) do
    indent = indent(indent_size)

    markup
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp indent(0), do: ""
  defp indent(size), do: Enum.map_join(1..size, fn _ -> " " end)
end