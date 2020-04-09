defmodule TwitterCastWeb.BotController do
  use TwitterCastWeb, :controller

  def line_callback(conn, %{"events" => events}) do
    case events = List.first(events) do
      %{"message" => message} ->
        is_need_reply(conn, events, message)
      %{"postback" => postback} ->
        respond_to_request(conn, events, postback)
      _ -> resp(conn)
    end
  end

  defp is_need_reply(conn, events, %{"message" => message}) do
    case extract_tweet_id(message["text"]) do
      %{"tid" => tid} ->
        line_reply(conn, events, %{reply: %{tid: tid}})
      _ -> resp(conn)
    end
  end

  defp respond_to_request(conn, events, postback) do
    reply = %{reply: new_image(postback["data"])}
    line_reply(conn, events, reply)
  end

  defp line_reply(conn, events, %{reply: reply}) do
    endpoint_url = "https://api.line.me/v2/bot/message/reply"

    message =
      case reply do
        %{tid: tid} ->
          ExTwitter.show(tid, tweet_mode: "extended")
          |> format_flex_message
        _ -> reply
      end

    body = reply_json(events["replyToken"], message)

    headers = %{
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{System.get_env("LINE_ACCESS_TOKEN")}"
    }

    case HTTPoison.post(endpoint_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.puts body
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        IO.puts "Not found :("
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end

    resp(conn)
  end

  defp reply_json(token, message) do
    %{
      replyToken: token,
      messages: [message]
    } |> Poison.encode!
  end

  defp resp(conn) do
    send_resp(conn, :no_content, "")
  end

  defp extract_tweet_id(text) do
    reg = ~r/https:\/\/twitter.com\/\w+\/status\/(?<tid>\d+)\?/
    Regex.named_captures(reg, text)
  end

  defp new_image(url) do
    %{
      type: "image",
      originContentUrl: url,
      previewImageUrl: url
    }
  end

  defp new_flex_image(url) do
    %{
      type: "image",
      url: url,
      aspectRatio: "150:98",
      aspectMode: "cover",
      size: "full"
    }
  end

  defp new_flex_image(url, action) do
    url
    |> new_flex_image
    |> Map.merge(action)
  end

  def new_flex_action(type, data) do
    %{
      action: %{
        type: type,
        label: type,
        data: data
      }
    }
  end

  defp extract_media_url(media) do
    media
    |> Enum.map(&(&1.media_url_https))
    |> List.first
  end

  defp new_flex_hero(media) do
    media_url = extract_media_url(media)
    content =
      media_url
      |> new_flex_image(new_flex_action("postback", media_url))
  end

  defp format_flex_message(tweet) do
    %{
      full_text: text,
      user: %{
        name: name,
        screen_name: screen_name,
        profile_image_url_https: profile_image_url
      }
    } = tweet = Map.from_struct(tweet)

    template = %{
      type: "flex",
      altText: "cast: #{text}",
      contents: %{}
    }

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
                url: String.replace(profile_image_url, "_normal", "_bigger"),
                size: "full",
                aspectMode: "cover"
              }
            ],
            cornerRadius: "25px",
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
          label: "action",
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
        %{template | contents: Map.merge(contents, new_flex_hero(media))}
      nil ->
        %{template | contents: contents}
    end
  end
end
