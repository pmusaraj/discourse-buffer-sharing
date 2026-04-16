# frozen_string_literal: true

module DiscourseBufferSharing
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseBufferSharing
    config.autoload_paths << File.join(config.root, "lib")
  end
end
