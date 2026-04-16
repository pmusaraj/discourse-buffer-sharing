# frozen_string_literal: true

RSpec.describe DiscourseBufferSharing::BufferApi do
  before { SiteSetting.buffer_api_token = "test-token" }

  def stub_buffer_api(response_body, status: 200)
    stub_request(:post, "https://api.buffer.com").to_return(
      status: status,
      body: response_body.to_json,
      headers: {
        "Content-Type" => "application/json",
      },
    )
  end

  describe ".fetch_channels" do
    it "raises when API token is blank" do
      SiteSetting.buffer_api_token = ""
      expect { described_class.fetch_channels }.to raise_error(ArgumentError, /not configured/)
    end

    it "returns channels from Buffer" do
      stub_request(:post, "https://api.buffer.com").to_return(
        {
          status: 200,
          body: { data: { account: { organizations: [{ id: "org1" }] } } }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        },
        {
          status: 200,
          body: {
            data: {
              channels: [
                { id: "ch1", name: "twitter", displayName: "My Twitter", service: "twitter" },
              ],
            },
          }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        },
      )

      result = described_class.fetch_channels

      expect(result[:success]).to eq(true)
      expect(result[:channels].length).to eq(1)
      expect(result[:channels][0]["service"]).to eq("twitter")
    end

    it "returns error when no organization found" do
      stub_buffer_api({ data: { account: { organizations: [] } } })

      result = described_class.fetch_channels

      expect(result[:success]).to eq(false)
      expect(result[:error]).to include("No Buffer organization found")
    end

    it "raises on non-200 response" do
      stub_buffer_api({ error: "Unauthorized" }, status: 401)

      expect { described_class.fetch_channels }.to raise_error(/status 401/)
    end
  end

  describe ".create_post" do
    let(:channels) { [{ id: "ch1", service: "twitter" }] }

    it "raises when API token is blank" do
      SiteSetting.buffer_api_token = ""
      expect { described_class.create_post(text: "hi", channels: channels) }.to raise_error(
        ArgumentError,
        /not configured/,
      )
    end

    it "raises when channels is empty" do
      expect { described_class.create_post(text: "hi", channels: []) }.to raise_error(
        ArgumentError,
        /No channels/,
      )
    end

    it "creates a text post successfully" do
      stub_buffer_api({ data: { createPost: { post: { id: "p1", text: "hi", dueAt: nil } } } })

      result = described_class.create_post(text: "hi", channels: channels)

      expect(result[:success]).to eq(true)
    end

    it "sends image assets when image_url provided" do
      stub_buffer_api({ data: { createPost: { post: { id: "p1", text: "hi", dueAt: nil } } } })

      described_class.create_post(
        text: "hi",
        channels: channels,
        image_url: "https://example.com/image.jpg",
      )

      expect(
        a_request(:post, "https://api.buffer.com").with do |req|
          payload = JSON.parse(req.body)
          assets = payload.dig("variables", "input", "assets")
          assets && assets["images"][0]["url"] == "https://example.com/image.jpg"
        end,
      ).to have_been_made.once
    end

    it "posts to multiple channels" do
      channels = [{ id: "ch1", service: "twitter" }, { id: "ch2", service: "pinterest" }]

      stub_buffer_api({ data: { createPost: { post: { id: "p1", text: "hi", dueAt: nil } } } })

      result = described_class.create_post(text: "hi", channels: channels)

      expect(result[:success]).to eq(true)
      expect(a_request(:post, "https://api.buffer.com")).to have_been_made.times(2)
    end

    it "reports partial failures" do
      channels = [{ id: "ch1", service: "twitter" }, { id: "ch2", service: "pinterest" }]

      stub_request(:post, "https://api.buffer.com").to_return(
        {
          status: 200,
          body: { data: { createPost: { post: { id: "p1", text: "hi", dueAt: nil } } } }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        },
        {
          status: 200,
          body: { data: { createPost: { message: "Channel not found" } } }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        },
      )

      result = described_class.create_post(text: "hi", channels: channels)

      expect(result[:success]).to eq(false)
      expect(result[:error]).to include("Channel not found")
    end
  end
end
