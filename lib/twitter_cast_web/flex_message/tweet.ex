defmodule TwitterCastWeb.FlexMessage.Tweet do
  import TwitterCastWeb.FlexMessage

  @color_white "#ffffff"
  @color_gray "#8899a6"
  @color_dark "#15202b"

  defp author(url, name, sub) do
    twitter_url = "https://twitter.com/#{sub}"
    [author_image(url), author_names(name, sub)]
    |> box({:horizontal, [spacing: "md"], action({:uri, twitter_url})})
    |> box({:vertical, padding_all: "16px"})
  end

  defp author_image(url) do
    image(url, size: "full", aspect_mode: "cover")
    |> box({:vertical, [
      width: "45px",
      height: "45px",
      corner_radius: "22.5px"
    ]})
  end

  defp author_names(name, sub) do
    [
      text(name, [
        flex: 1,
        size: "sm",
        color: @color_white,
        gravity: "bottom"
      ]),
      text("@#{sub}", [
        flex: 1,
        size: "sm",
        color: @color_gray,
        gravity: "top"
      ])
    ]
    |> box({:vertical, spacing: "xs"})
  end

  defp tweet_text(text) do
    text
    |> String.split(~r/\r|\r\n|\n/)
    |> Enum.map(fn word ->
      text(word, color: @color_white)
    end)
    |> box({:vertical, %{}})
  end

  defp social_images(urls) do
    social_ratios(length urls)
    |> Enum.reduce(urls, fn ratio, acc ->
      [head | tail] = acc

      opt = %{
        aspect_ratio: ratio,
        aspect_mode: "cover",
        size: "full"
      }

      image(head, opt, action({:postback, head}))
      |> list_push(tail)
    end)
    |> social_contents()
    |> box({:horizontal, spacing: "sm", corner_radius: "10px"})
  end

  defp social_ratios(length) do
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

  defp social_contents do
    box([], {:vertical, spacing: "sm"})
    |> List.duplicate(2)
  end

  defp social_contents(images) do
    images
    |> Enum.with_index
    |> Enum.reduce(social_contents(), fn {image, i}, acc ->
      [head | tail] = acc
      upd_contents = list_push(image, head.contents)
      upd_head = %{head | contents: upd_contents}

      case length images do
        3 when i == 1 ->
          [upd_head | tail]
        _ ->
          upd_head |> list_push(tail)
      end
    end)
    |> Enum.filter(&Enum.any?(&1.contents))
  end

  def new(tweet) do
    %{
      full_text: text,
      user: %{
        name: name,
        screen_name: screen_name,
        profile_image_url_https: profile_image_url
      }
    } = Map.from_struct(tweet)

    header =
      author(profile_image_url, name, screen_name)

    body =
      case tweet[:extended_entities] do
        %{media: media} ->
          media
          |> Enum.map(&(&1.media_url_https))
          |> social_images()
          |> list_push([tweet_text(text)])
        _ -> [tweet_text(text)]
      end
      |> box({:vertical, [
        spacing: "xl",
        padding_all: "16px",
        padding_top: "0px"
      ]})

    [header: header, body: body]
    |> new(text, {:bubble, [
      header: %{backgroundColor: @color_dark},
      body: %{backgroundColor: @color_dark}
    ]})
  end
end