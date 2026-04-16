# frozen_string_literal: true

RSpec.describe DiscourseBufferSharing::BufferController do
  fab!(:admin)
  fab!(:user)
  fab!(:topic)

  before do
    SiteSetting.buffer_sharing_enabled = true
    SiteSetting.buffer_api_token = "test-token"
  end

  describe "GET /buffer-sharing/channels" do
    it "requires login" do
      get "/buffer-sharing/channels.json"
      expect(response.status).to eq(403)
    end

    it "requires staff" do
      sign_in(user)
      get "/buffer-sharing/channels.json"
      expect(response.status).to eq(403)
    end

    it "returns channels from Buffer API" do
      channels = [
        {
          "id" => "ch1",
          "name" => "twitter",
          "displayName" => "My Twitter",
          "service" => "twitter",
        },
        {
          "id" => "ch2",
          "name" => "pinterest",
          "displayName" => "My Pinterest",
          "service" => "pinterest",
        },
      ]

      DiscourseBufferSharing::BufferApi.stubs(:fetch_channels).returns(
        { success: true, channels: channels },
      )

      sign_in(admin)
      get "/buffer-sharing/channels.json"

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["channels"].length).to eq(2)
      expect(body["channels"][0]["id"]).to eq("ch1")
      expect(body["channels"][1]["service"]).to eq("pinterest")
    end

    it "returns error when fetch fails" do
      DiscourseBufferSharing::BufferApi.stubs(:fetch_channels).returns(
        { success: false, error: "No Buffer organization found" },
      )

      sign_in(admin)
      get "/buffer-sharing/channels.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to eq("No Buffer organization found")
    end

    it "handles exceptions gracefully" do
      DiscourseBufferSharing::BufferApi.stubs(:fetch_channels).raises(
        ArgumentError.new("Buffer API token is not configured"),
      )

      sign_in(admin)
      get "/buffer-sharing/channels.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("Buffer API token is not configured")
    end
  end

  describe "POST /buffer-sharing/share" do
    let(:channels_param) { [{ id: "ch1", service: "twitter" }] }

    it "requires login" do
      post "/buffer-sharing/share.json",
           params: {
             topic_id: topic.id,
             text: "Hello",
             channels: channels_param,
           }
      expect(response.status).to eq(403)
    end

    it "requires staff" do
      sign_in(user)
      post "/buffer-sharing/share.json",
           params: {
             topic_id: topic.id,
             text: "Hello",
             channels: channels_param,
           }
      expect(response.status).to eq(403)
    end

    it "returns 404 for missing topic" do
      sign_in(admin)
      post "/buffer-sharing/share.json",
           params: {
             topic_id: -1,
             text: "Hello",
             channels: channels_param,
           }
      expect(response.status).to eq(404)
    end

    it "shares to Buffer successfully" do
      DiscourseBufferSharing::BufferApi
        .stubs(:create_post)
        .with do |kwargs|
          kwargs[:text] == "Check this out" && kwargs[:channels][0][:id] == "ch1" &&
            kwargs[:channels][0][:service] == "twitter"
        end
        .returns({ success: true })

      sign_in(admin)
      post "/buffer-sharing/share.json",
           params: {
             topic_id: topic.id,
             text: "Check this out",
             channels: channels_param,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
    end

    it "returns error on Buffer API failure" do
      DiscourseBufferSharing::BufferApi.stubs(:create_post).returns(
        { success: false, error: "Rate limited" },
      )

      sign_in(admin)
      post "/buffer-sharing/share.json",
           params: {
             topic_id: topic.id,
             text: "Hello",
             channels: channels_param,
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to eq("Rate limited")
    end

    it "handles exceptions gracefully" do
      DiscourseBufferSharing::BufferApi.stubs(:create_post).raises(
        RuntimeError.new("Connection refused"),
      )

      sign_in(admin)
      post "/buffer-sharing/share.json",
           params: {
             topic_id: topic.id,
             text: "Hello",
             channels: channels_param,
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["error"]).to include("Connection refused")
    end

    it "passes topic image URL when present" do
      upload = Fabricate(:upload)
      topic.update!(image_upload_id: upload.id)

      DiscourseBufferSharing::BufferApi
        .stubs(:create_post)
        .with { |kwargs| kwargs[:image_url].present? && kwargs[:text] == "Hello" }
        .returns({ success: true })

      sign_in(admin)
      post "/buffer-sharing/share.json",
           params: {
             topic_id: topic.id,
             text: "Hello",
             channels: channels_param,
           }

      expect(response.status).to eq(200)
    end
  end
end
