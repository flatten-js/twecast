defmodule TwecastWeb.FlexMessage do
  @moduledoc """
  Module for building flex messages
  """

  @doc """
  Create a new flex message
  """

  def new(blocks, alt, {:bubble, opt}) do
    bubble(blocks, opt)
    |> flex(alt)
    |> map_filter
  end

  # Flex message object that is the basis of the data structure

  defp flex(container, alt) do
    %{
      type: "flex",
      altText: alt,
      contents: container
    }
  end

  # Three-layer data structure that makes up a flex message
  # --- structure: Container --- #

  # @docp """
  # Container: bubble
  # The container that displays a single message bubble
  # """

  defp bubble(blocks, opt) do
    %{
      type: "bubble",
      header: blocks[:header],
      hero: blocks[:hero],
      body: blocks[:body],
      footer: blocks[:footer],
      styles: %{
        header: opt[:header],
        hero: opt[:hero],
        body: opt[:body],
        footer: opt[:footer]
      }
    }
  end

  # --- structure: Block --- #

  # Note: Block depends on container

  # --- structure: Component --- #

  @doc """
  component: box
  The component that defines the layout of the component
  """

  def box(contents, {:vertical, opt}) do
    box("vertical", contents, opt)
  end

  def box(contents, {:vertical, opt, action}) do
    box("vertical", contents, opt, action)
  end

  def box(contents, {:horizontal, opt}) do
    box("horizontal", contents, opt)
  end

  def box(contents, {:horizontal, opt, action}) do
    box("horizontal", contents, opt, action)
  end

  # The underlying function

  defp box(layout, contents, opt) do
    %{
      type: "box",
      layout: layout,
      contents: guarantee_list(contents)
    }
    |> Map.merge(box_opt opt)
  end

  defp box(layout, contents, opt, action) do
    box(layout, contents, opt)
    |> Map.merge(action)
  end

  @doc """
  component: image
  The component that draws the image
  """

  def image(url, opt) do
    %{ type: "image", url: url }
    |> Map.merge(image_opt opt)
  end

  def image(url, opt, action) do
    image(url, opt)
    |> Map.merge(action)
  end

  @doc """
  copmonent: text
  The component that draws a string of one line
  """

  def text(contents, {:span, opt}) do
    %{type: "text", contents: guarantee_list(contents)}
    |> Map.merge(text_opt opt)
  end

  def text(text, opt) do
    %{type: "text", text: text}
    |> Map.merge(text_opt opt)
  end

  @doc """
  Component: span
  The component that draws multiple character strings with different designs in one line
  """

  def span(text, opt) do
    %{type: "span", text: text}
    |> Map.merge(span_opt opt)
  end

  # --- Option --- #

  defp box_opt(opt) do
    %{
      spacing: opt[:spacing],
      width: opt[:width],
      height: opt[:height],
      borderWidth: opt[:border_width],
      borderColor: opt[:border_color],
      cornerRadius: opt[:corner_radius]
    }
    |> Map.merge(base_opt opt, except: [:gravity, :size, :align])
    |> Map.merge(offset_opt opt)
    |> Map.merge(padding_opt opt)
  end

  defp image_opt(opt) do
    %{
      aspectRatio: opt[:aspect_ratio],
      aspectMode: opt[:aspect_mode]
    }
    |> Map.merge(base_opt opt)
    |> Map.merge(offset_opt opt)
  end

  defp common_text_opt(opt) do
    %{
      weight: opt[:weight],
      color: opt[:color],
      style: opt[:style],
      decoration: opt[:decoration]
    }
  end

  defp text_opt(opt) do
    %{
      wrap: opt[:wrap],
      maxLines: opt[:max_lines]
    }
    |> Map.merge(common_text_opt opt)
    |> Map.merge(base_opt opt, except: [:backgroundColor])
    |> Map.merge(offset_opt opt)
  end

  defp span_opt(opt) do
    common_text_opt(opt)
    |> Map.merge(base_opt opt, only: [:size])
  end

  defp base_opt(opt) do
    %{
      flex: opt[:flex],
      position: opt[:position],
      margin: opt[:margin],
      align: opt[:align],
      gravity: opt[:gravity],
      size: opt[:size],
      backgroundColor: opt[:background_color]
    }
  end

  defp base_opt(opt, [only: keys]) do
    base_opt(opt) |> Map.take(keys)
  end

  defp base_opt(opt, [except: keys]) do
    base_opt(opt)
    |> Map.split(keys)
    |> case do {_, map} -> map end
  end

  defp offset_opt(opt) do
    %{
      offsetTop: opt[:offset_top],
      offsetBottom: opt[:offset_bottom],
      offsetStart: opt[:offset_start],
      offsetEnd: opt[:offset_end]
    }
  end

  defp padding_opt(opt) do
    %{
      paddingAll: opt[:padding_all],
      paddingTop: opt[:padding_top],
      paddingBottom: opt[:padding_bottom],
      paddingStart: opt[:padding_start],
      paddingEnd: opt[:padding_end]
    }
  end

  # --- Action --- #

  @doc """
  Action to take when the user taps a control in the message
  """

  def action({:postback, data}) do
    %{
      action: %{
        type: "postback",
        data: data
      }
    }
  end

  def action({:uri, uri}) do
    %{
      action: %{
        type: "uri",
        uri: uri
      }
    }
  end

  # --- Helper function --- #

  # removes values ​​determined as false from the map
  defp map_filter({:ok, map}) do
    Map.keys(map)
    |> Enum.reduce(map, fn key, acc ->
      v = acc[key]
      cond do
        !v ->
          Map.delete(acc, key)
        is_list(v) ->
          Map.put(acc, key, Enum.map(v, &map_filter/1))
        is_map(v) ->
          Map.put(acc, key, map_filter(v))
        true ->
          acc
      end
    end)
  end

  defp map_filter(v) do
    if is_map(v), do: map_filter({:ok, v}), else: v
  end

  # Guarantees that the values ​​sent will always be a list
  defp guarantee_list(v), do: List.flatten [v]

  # Add an element to the beginning of alist
  def alist_unshift(v, atom, alist), do: [{atom, v} | alist]
end
