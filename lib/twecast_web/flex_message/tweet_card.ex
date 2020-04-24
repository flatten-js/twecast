defmodule TwecastWeb.TweetCard do
  import TwecastWeb.BotController, only: [list_push: 2]
  import Linex

  @color_white "#ffffff"
  @color_blue "#1b95e0"
  @color_gray "#8899a6"
  @color_dark "#15202b"

  defp author(url, name, sub) do
    twitter_url = "https://twitter.com/#{sub}"
    [author_image(url), author_names(name, sub)]
    |> box({:horizontal, spacing: "md", action: action({:uri, twitter_url})})
    |> box({:vertical, padding_all: "16px"})
  end

  defp author_image(url) do
    url
    |> String.replace("_normal", "_400x400")
    |> image(size: "full", aspect_mode: "cover")
    |> box({:vertical, [
      width: "45px",
      height: "45px",
      corner_radius: "22.5px"
    ]})
  end

  defp author_names(name, sub) do
    [
      {name, %{color: @color_white, gravity: "bottom"}},
      {"@#{sub}", %{color: @color_gray, gravity: "top"}}
    ]
    |> Enum.map(fn {name, opt} ->
      opt = %{flex: 1, size: "sm"} |> Map.merge(opt)
      text(name, opt)
    end)
    |> box({:vertical, spacing: "xs"})
  end

  @crlf "\\r|\\r\\n|\\n"
  @crlf_s "crlf"

  defp tweet_text(text, urls) do
    Regex.compile!(@crlf)
    |> Regex.split(text)
    |> Enum.map(fn line ->
      embody_empty(line)
      |> color_coding(urls)
      |> text({:span, wrap: true})
    end)
    |> box({:vertical, []})
  end

  defp is_byte?(b), do: byte_size(b) > 0

  defp embody_empty(text) do
    unless is_byte?(text), do: @crlf_s, else: text
  end

  defp url_replace(text, urls) do
    urls
    |> Enum.reduce({text, []}, fn cur, {text, urls} ->
      {
        text |> String.replace(cur.url, cur.display_url),
        cur.display_url |> list_push(urls)
      }
    end)
  end

  @at "@\\w+"
  @at_comp "(?<=^|[^\\w#$%&*-@])(#{@at})"

  @hash "#[^\\x00-\\x2f\\x3a-\\x40\\x5b-\\x5e\\x7b-\\x7e]+"
  @hash_comp "(?<=^|[^\\w&])(#{@hash})"

  @color_coding "#{@at_comp}|#{@hash_comp}"

  def color_coding(text, opt \\ [])

  def color_coding(text, opt) when length(opt) == 0,
    do: color_coding!({:ok, @color_coding, text})

  def color_coding(text, opt) do
    rs = "#{@color_coding}|#{Enum.join(opt, "|")}"
    color_coding!({:ok, rs, text})
  end

  defp color_coding!({:ok, rs, text}) do
    r = Regex.compile!(rs)

    Regex.split(r, text, include_captures: true)
    |> Enum.filter(&is_byte?/1)
    |> Enum.map(fn word ->
      case word =~ r do
        true -> @color_blue
        false when @crlf_s == word -> @color_dark
        false -> @color_white
      end
      |> (&span(word, color: &1)).()
    end)
  end

  defp date_format_jp!(ds) do
    use Timex
    tz = Timezone.get("Asia/Tokyo")

    Timex.parse!(ds, "%a %b %d %H:%M:%S %z %Y", :strftime)
    |> Timezone.convert(tz)
    |> Timex.format!("{_h24}:{m} · {YYYY}年{M}月{D}日")
    |> String.trim()
  end

  defp social_images(urls) do
    social_ratios(length urls)
    |> Enum.reduce(urls, fn ratio, acc ->
      [head | tail] = acc

      image(head, [
        aspect_ratio: ratio,
        aspect_mode: "cover",
        size: "full",
        action: action({:postback, head})
      ])
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
      entities: %{
        urls: urls
      },
      user: %{
        name: name,
        screen_name: screen_name,
        profile_image_url_https: profile_image_url
      }
    } = tweet

    {text, urls} = url_replace(text, urls)

    header =
      author(profile_image_url, name, screen_name)

    tweet_text = tweet_text(text, urls)

    body =
      case tweet[:extended_entities] do
        %{media: media} ->
          media
          |> Enum.map(&(&1.media_url_https))
          |> social_images()
          |> list_push(tweet_text)
        _ -> tweet_text
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

    blocks = [header: header, body: body, footer: footer]

    dark_styles =
      Keyword.keys(blocks)
      |> Enum.map(&({&1, %{backgroundColor: @color_dark}}))

    new(blocks, text, {:bubble, dark_styles})
  end
end