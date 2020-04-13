defmodule TwitterCastWeb.FlexMessage do
  @image_opt %{url: "", ratio: "", mode: "cover"}

  @type string_t :: String.t()
  @type image_opt :: %{url: string_t, ratio: string_t, mode: string_t}

  import TwitterCastWeb.BotController, only: [list_push: 2, map_filter: 1]

  @spec image(image_opt) :: map
  def image(opt) do
    %{
      type: "image",
      url: opt.url,
      aspectRatio: opt.ratio,
      aspectMode: opt.mode,
      size: "full"
    }
  end

  @spec image(image_opt, map) :: map
  def image(opt, action) do
    opt
    |> image()
    |> Map.merge(action)
  end

  @spec images([image_opt, ...]) :: [map]
  def images(opts) do
    opts |> Enum.map(fn opt ->
      image opt, postback(opt.url)
    end)
  end

  @spec postback(string_t) :: map
  def postback(data) do
    %{
      action: %{
        type: "postback",
        label: "postback",
        data: data
      }
    }
  end

  @spec vertical([map] | map, map) :: map
  def vertical(contents, opt) do
    %{
      type: "box",
      layout: "vertical",
      contents: List.flatten([contents]),
      spacing: opt[:spacing]
    } |> map_filter
  end

  @spec horizontal([map] | map, map) :: map
  def horizontal(contents, opt) do
    %{
      type: "box",
      layout: "horizontal",
      contents: List.flatten([contents]),
      height: opt[:height],
      spacing: opt[:spacing]
    } |> map_filter
  end

  @spec hero([map] | map) :: map
  def hero(contents) do
    %{
      hero: horizontal(contents, %{
        spacing: "sm"
      })
    }
  end

  @spec prescribed_ratios(integer) :: [string_t]
  def prescribed_ratios(length) do
    case length do
      1 ->
        ["150:98"]
      2 ->
        ["150:200", "150:200"]
      3 ->
        ["150:200", "150:98", "150:98"]
      4 ->
        ["150:98", "150:98", "150:98", "150:98"]
      _ -> []
    end
  end

  @spec social([map, ...]) :: map
  def social(media) do
    ratios = prescribed_ratios(length media)

    media |> Enum.reduce(ratios, fn data, acc ->
      [head | tail] = acc

      Map.merge(@image_opt, %{
        url: data.media_url_https,
        ratio: head
      }) |> list_push(tail)
    end)
    |> images()
    |> social_contents()
    |> hero()
  end

  @spec social_contents :: [map, ...]
  def social_contents do
    vertical([], %{spacing: "sm"})
    |> List.duplicate(2)
  end

  @spec social_contents([map, ...]) :: [map]
  def social_contents(images) do
    images |> Enum.reduce(social_contents(), fn image, acc ->
      [head | tail] = acc
      update_contents = list_push(image, head.contents)
      update_head = %{head | contents: update_contents}

      cond do
        length(images) == 3 && (
          Enum.at(images, 1, %{}) |> Map.equal?(image)
        ) ->
          [update_head | tail]
        true -> update_head |> list_push(tail)
      end
    end) |> Enum.filter(&Enum.any?(&1.contents))
  end

  @spec flex(string_t) :: map
  def flex(text) do
    %{
      type: "flex",
      altText: text,
      contents: %{}
    }
  end

  @spec template_message(%ExTwitter.Model.Tweet{}) :: map
  def template_message(tweet) do
    %{
      full_text: text,
      user: %{
        name: name,
        screen_name: screen_name,
        profile_image_url_https: profile_url
      }
    } = tweet = Map.from_struct(tweet)

    flex = flex "call: #{text}"

    contents = %{
      type: "bubble",
      body: %{
        type: "box",
        layout: "vertical",
        contents: [
          %{
            type: "text",
            text: text,
            wrap: true
          }
        ],
        paddingAll: "16px"
      },
      footer: %{
        type: "box",
        layout: "horizontal",
        contents: [
          %{
            type: "box",
            layout: "vertical",
            contents: [
              %{
                type: "image",
                url: String.replace(profile_url, "_normal", "_bigger"),
                size: "full",
                aspectMode: "cover"
              }
            ],
            cornerRadius: "22.5px",
            backgroundColor: "#cccccc",
            width: "45px",
            height: "45px"
          },
          %{
            type: "box",
            layout: "vertical",
            contents: [
              %{
                type: "text",
                text: name,
                flex: 1,
                gravity: "bottom"
              },
              %{
                type: "text",
                text: "@#{screen_name}",
                size: "sm",
                flex: 1,
                gravity: "top"
              }
            ],
            spacing: "xs"
          }
        ],
        spacing: "xl",
        paddingAll: "16px",
        action: %{
          type: "uri",
          label: "uri",
          uri: "https://twitter.com/#{screen_name}"
        }
      },
      styles: %{
        footer: %{
          separator: true
        }
      }
    }

    case tweet[:extended_entities] do
      %{media: media} ->
        %{flex | contents: Map.merge(contents, social media)}
      nil ->
        %{flex | contents: contents}
    end
  end
end
