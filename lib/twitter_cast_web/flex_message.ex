defmodule TwitterCastWeb.FlexMessage do
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

  @doc """
  Flex message object that is the basis of the data structure
  """

  defp flex(container, alt) do
    %{
      type: "flex",
      altText: alt,
      contents: container
    }
  end

  @doc """
  Three-layer data structure that makes up a flex message
  """

  # --- structure: Container --- #

  @doc """
  Container: bubble
  The container that displays a single message bubble
  """

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

  @doc """
  Block depends on container
  """

  # --- structure: Component --- #

  @doc """
  component: box
  The component that defines the layout of the component
  """

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

  def text(text, opt) do
    %{type: "text", text: text}
    |> Map.merge(text_opt opt)
  end

  # --- Option --- #

  @doc """
  Options used in flex messages
  """

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

  defp text_opt(opt) do
    %{
      weight: opt[:weight],
      color: opt[:color],
      style: opt[:style],
      decoration: opt[:decoration],
      wrap: opt[:wrap],
      maxLines: opt[:max_lines]
    }
    |> Map.merge(base_opt opt, except: [:backgroundColor])
    |> Map.merge(offset_opt opt)
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
  Actions used in flex messages
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

  @doc """
  removes values ​​determined as false from the map
  """
  def map_filter({:ok, map}) do
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

  def map_filter(v) do
    if is_map(v), do: map_filter({:ok, v}), else: v
  end

  @doc """
  Guarantees that the values ​​sent will always be a list
  """
  def guarantee_list(v), do: List.flatten [v]

  @doc """
  Add an element to the beginning of alist
  """
  def alist_unshift(v, atom, alist), do: [{atom, v} | alist]
end
