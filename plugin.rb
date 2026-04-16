# frozen_string_literal: true

# name: discourse-buffer-sharing
# about: Share topics to social media via the Buffer API
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-buffer-sharing

enabled_site_setting :buffer_sharing_enabled

register_asset "stylesheets/buffer-sharing.scss"
register_svg_icon "fab-buffer"

module ::DiscourseBufferSharing
  PLUGIN_NAME = "discourse-buffer-sharing"
end

require_relative "lib/discourse_buffer_sharing/engine"

after_initialize do
  # nothing extra needed at this time
end
