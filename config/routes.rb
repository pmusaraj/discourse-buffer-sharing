# frozen_string_literal: true

DiscourseBufferSharing::Engine.routes.draw do
  get "/channels" => "buffer#channels"
  get "/preview" => "buffer#preview"
  post "/share" => "buffer#share"
end

Discourse::Application.routes.draw { mount DiscourseBufferSharing::Engine, at: "/buffer-sharing" }
