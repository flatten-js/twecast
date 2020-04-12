defmodule TwitterCastWeb.BotController do
  use TwitterCastWeb, :controller

  alias TwitterCastWeb.FlexMessage

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
          |> FlexMessage.template_message
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
      originalContentUrl: url,
      previewImageUrl: url
    }
  end

  @doc """
  Add to end of list
  However, it is unknown at this stage whether it is efficient
  """
  def list_push(data, list), do: [list | [data]] |> List.flatten
end
