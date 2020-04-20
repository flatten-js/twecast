defmodule TwecastWeb.FlexMessage.Tweet do
  import TwecastWeb.BotController, only: [list_push: 2]
  import TwecastWeb.FlexMessage

  @color_white "#ffffff"
  @color_blue "#1b95e0"
  @color_gray "#8899a6"
  @color_dark "#15202b"

  defp author(url, name, sub) do
    twitter_url = "https://twitter.com/#{sub}"
    [author_image(url), author_names(name, sub)]
    |> box({:horizontal, [spacing: "md"], action({:uri, twitter_url})})
    |> box({:vertical, padding_all: "16px"})
  end

  defp author_image(url) do
    url
    |> String.replace("_normal", "_bigger")
    |> image(size: "full", aspect_mode: "cover")
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

  @crlf "\\r|\\r\\n|\\n"
  @crlf_s "crlf"

  @at "@\\w+"
  @hash "#[^\\x00-\\x2f\\x3a-\\x40\\x5b-\\x5e\\x7b-\\x7e]+"

  defp tweet_text(text) do
    Regex.compile!(@crlf)
    |> Regex.split(text)
    |> Enum.map(fn line ->
      recycle_empty(line)
      |> color_coding()
      |> text({:span, wrap: true})
    end)
    |> box({:vertical, %{}})
  end

  defp recycle_empty(text) do
    if byte_size(text) == 0, do: @crlf_s, else: text
  end

  defp color_coding(text) do
    "(?<=^|[^\\w#$%&*-@])(#{@at})|(?<=^|[^\\w&])(#{@hash})"
    |> Regex.compile!()
    |> Regex.split(text, include_captures: true)
    |> Enum.filter(&byte_size(&1) != 0)
    |> Enum.map(fn word ->
      "^(#{@at})|(#{@hash})"
      |> Regex.compile!()
      |> Regex.match?(word)
      |> case do
        true -> @color_blue
        false when @crlf_s == word -> @color_dark
        false -> @color_white
      end
      |> (fn color -> span(word, color: color) end).()
    end)
  end

  defp date_format_jp!(ds) do
    Timex.parse!(ds, "%a %b %d %H:%M:%S %z %Y", :strftime)
    |> Timex.local()
    |> Timex.format!("{am}{h12}:{m} · {YYYY}年{M}月{D}日")
    |> time_zone_jp()
  end

  defp time_zone_jp(str) do
    String.first(str)
    |> case do
      "a" ->
        String.replace(str, "am", "午前")
      "p" ->
        String.replace(str, "pm", "午後")
    end
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
      created_at: created,
      full_text: text,
      user: %{
        name: name,
        screen_name: screen_name,
        profile_image_url_https: profile_image_url
      }
    } = tweet

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

    footer =
      date_format_jp!(created)
      |> text(size: "sm", color: @color_gray)
      |> box({:vertical, [
        padding_all: "16px",
        padding_top: "0px"
      ]})

    [header: header, body: body, footer: footer]
    |> new(text, {:bubble, [
      header: %{backgroundColor: @color_dark},
      body: %{backgroundColor: @color_dark},
      footer: %{backgroundColor: @color_dark}
    ]})
  end
end
