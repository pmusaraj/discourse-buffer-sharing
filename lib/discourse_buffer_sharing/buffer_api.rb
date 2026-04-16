# frozen_string_literal: true

module DiscourseBufferSharing
  class BufferApi
    ENDPOINT = "https://api.buffer.com"

    def self.fetch_channels
      token = SiteSetting.buffer_api_token
      if token.blank?
        Rails.logger.warn("[BufferSharing] API token is blank, cannot fetch channels")
        raise ArgumentError, "Buffer API token is not configured"
      end

      Rails.logger.info("[BufferSharing] Fetching organizations from Buffer API")
      org_result = execute_query(<<~GRAPHQL)
        query GetOrganizations {
          account {
            organizations {
              id
            }
          }
        }
      GRAPHQL
      Rails.logger.info("[BufferSharing] Organizations response: #{org_result.inspect}")

      org_id = org_result.dig("data", "account", "organizations", 0, "id")
      if org_id.blank?
        Rails.logger.warn("[BufferSharing] No organization ID found in response")
        return { success: false, error: "No Buffer organization found" }
      end

      Rails.logger.info("[BufferSharing] Fetching channels for organization #{org_id}")
      channels_query = <<~GRAPHQL
        query GetChannels($input: ChannelsInput!) {
          channels(input: $input) {
            id
            name
            displayName
            service
          }
        }
      GRAPHQL

      channels_result =
        execute_query(channels_query, variables: { input: { organizationId: org_id } })
      Rails.logger.info("[BufferSharing] Channels response: #{channels_result.inspect}")

      channels = channels_result.dig("data", "channels")
      if channels.blank?
        Rails.logger.warn("[BufferSharing] No channels found in response")
        return { success: false, error: "No channels found in Buffer account" }
      end

      Rails.logger.info("[BufferSharing] Found #{channels.size} channel(s)")

      { success: true, channels: channels }
    end

    def self.create_post(text:, channels:, image_url: nil)
      token = SiteSetting.buffer_api_token
      raise ArgumentError, "Buffer API token is not configured" if token.blank?
      raise ArgumentError, "No channels selected" if channels.blank?

      query = <<~GRAPHQL
        mutation CreatePost($input: CreatePostInput!) {
          createPost(input: $input) {
            ... on PostActionSuccess {
              post {
                id
                text
                dueAt
              }
            }
            ... on MutationError {
              message
            }
          }
        }
      GRAPHQL

      results = []
      channels.each do |channel|
        channel_id = channel[:id] || channel["id"]

        variables = {
          input: {
            text: text,
            channelId: channel_id,
            schedulingType: "automatic",
            mode: "addToQueue",
          },
        }

        variables[:input][:assets] = { images: [{ url: image_url }] } if image_url.present?

        body = execute_query(query, variables: variables)
        result = body.dig("data", "createPost")

        if result&.key?("post")
          results << { success: true, channel_id: channel_id }
        else
          error_message = result&.dig("message") || "Unknown error from Buffer API"
          Rails.logger.error(
            "Buffer API mutation error for channel #{channel_id}: #{error_message}",
          )
          results << { success: false, channel_id: channel_id, error: error_message }
        end
      end

      failed = results.select { |r| !r[:success] }
      if failed.empty?
        { success: true }
      else
        { success: false, error: failed.map { |r| r[:error] }.join(", ") }
      end
    end

    private

    def self.execute_query(query, variables: nil)
      token = SiteSetting.buffer_api_token
      payload = { query: query }
      payload[:variables] = variables if variables

      json_payload = payload.to_json
      Rails.logger.info("[BufferSharing] Sending request to #{ENDPOINT}")
      Rails.logger.info("[BufferSharing] Payload: #{json_payload}")

      response =
        Faraday.post(
          ENDPOINT,
          json_payload,
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{token}",
        )

      Rails.logger.info("[BufferSharing] Response status: #{response.status}")
      Rails.logger.info("[BufferSharing] Response body: #{response.body}")

      body = JSON.parse(response.body)

      if response.status != 200
        Rails.logger.error(
          "[BufferSharing] API error (status #{response.status})\n  Request: #{json_payload}\n  Response: #{response.body}",
        )
        raise "Buffer API returned status #{response.status}: #{response.body}"
      end

      if body["errors"].present?
        Rails.logger.error("[BufferSharing] GraphQL errors: #{body["errors"].inspect}")
      end

      body
    end
  end
end
