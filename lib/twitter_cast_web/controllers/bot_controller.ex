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

  defp is_need_reply(conn, events, message) do
    case extract_tweet_id(message["text"]) do
      %{"tid" => tid} ->
        line_reply(conn, events, %{reply: %{tid: tid}})
      nil -> resp(conn)
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

  defp list_push(data, list), do: [list | [data]] |> List.flatten

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
      originalContentUrl: url,
      previewImageUrl: url
    }
  end

  defp flex_image(%{url: url, ratio: ratio, mode: mode}) do
    %{
      type: "image",
      url: url,
      aspectRatio: ratio,
      aspectMode: mode,
      size: "full"
    }
  end

  defp flex_image(opt, action) do
    opt
    |> flex_image
    |> Map.merge(action)
  end

  defp flex_images(opts) do
    opts |> Enum.map(fn opt ->
      flex_image(opt, flex_action("postback", opt.url))
    end)
  end

  defp flex_action(type, data) do
    %{
      action: %{
        type: type,
        label: type,
        data: data
      }
    }
  end

  defp flex_social(media) do
    template = %{
      hero: %{
        type: "box",
        layout: "horizontal",
        contents: []
      },
      opt: %{url: "", ratio: "", mode: "cover"}
    }

    aspect_ratio = social_aspect_ratio(length media)

    contents =
      media
      |> Enum.reduce(aspect_ratio, fn data, acc ->
        [head | tail] = acc

        Map.merge(template.opt, %{
          url: data.media_url_https,
          ratio: head
        })
        |> list_push(tail)
      end)
      |> flex_images
      |> social_contents

    %{hero: %{ template.hero | contents: contents }}
  end

  defp social_contents do
    [
      %{
        type: "box",
        layout: "vertical",
        contents: []
      },
      %{
        type: "box",
        layout: "vertical",
        contents: []
      }
    ]
  end

  defp social_contents(opts) do
    opts
    |> Enum.reduce(social_contents, fn data, acc ->
      [head | tail] = acc
      update_contents = list_push(data, head.contents)
      update_head = %{head | contents: update_contents}

      cond do
        length(opts) == 3 && Enum.at(opts, 1, %{}) |> Map.equal?(data) ->
          [update_head | tail]
        true -> update_head |> list_push(tail)
      end
    end)
    |> Enum.filter(&Enum.any?(&1.contents))
  end

  defp social_aspect_ratio(length) do
    case length do
      1 ->
        ["150:98"]
      2 ->
        ["150:196", "150:196"]
      3 ->
        ["150:196", "150:98", "150:98"]
      4 ->
        ["150:98", "150:98", "150:98", "150:98"]
      _ -> []
    end
  end

  defp format_flex_message(tweet) do
    %{
      full_text: text,
      user: %{
        name: name,
        screen_name: screen_name,
        profile_image_url_https: url
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
                url: String.replace(url, "_normal", "_bigger"),
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
        %{template | contents: Map.merge(contents, flex_social media)}
      nil ->
        %{template | contents: contents}
    end
  end
end
