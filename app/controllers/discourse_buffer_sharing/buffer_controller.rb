# frozen_string_literal: true

module DiscourseBufferSharing
  class BufferController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    before_action :ensure_staff

    def channels
      result = DiscourseBufferSharing::BufferApi.fetch_channels

      if result[:success]
        render json: { channels: result[:channels] }
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error(
        "[BufferSharing] Error fetching channels: #{e.message}\n#{e.backtrace.first(5).join("\n")}",
      )
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def preview
      topic_id = params.require(:topic_id)
      topic = Topic.find_by(id: topic_id)
      raise Discourse::NotFound if topic.blank?
      guardian.ensure_can_see!(topic)

      render json: {
               title: topic.title,
               excerpt: topic.excerpt,
               url: topic.url,
               image_url: resolve_image_url(topic),
             }
    end

    def share
      topic_id = params.require(:topic_id)
      text = params.require(:text)
      channels = params.require(:channels)

      topic = Topic.find_by(id: topic_id)
      raise Discourse::NotFound if topic.blank?

      image_url = resolve_image_url(topic)
      Rails.logger.info("[BufferSharing] Including image: #{image_url}") if image_url.present?

      Rails.logger.info("[BufferSharing] Raw channels param: #{channels.inspect}")

      channels_list =
        if channels.is_a?(ActionController::Parameters) || channels.is_a?(Hash)
          channels.values.map { |c| c.is_a?(ActionController::Parameters) ? c.permit!.to_h : c }
        else
          Array(channels)
        end
      channels_data = channels_list.map { |c| { id: c["id"], service: c["service"] } }

      Rails.logger.info("[BufferSharing] Parsed channels: #{channels_data.inspect}")

      result =
        DiscourseBufferSharing::BufferApi.create_post(
          text: text,
          channels: channels_data,
          image_url: image_url,
        )

      if result[:success]
        render json: { success: true }
      else
        render json: { success: false, error: result[:error] }, status: :unprocessable_entity
      end
    rescue Discourse::NotFound, Discourse::InvalidAccess
      raise
    rescue StandardError => e
      Rails.logger.error(
        "[BufferSharing] Error sharing: #{e.message}\n#{e.backtrace.first(5).join("\n")}",
      )
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def resolve_image_url(topic)
      raw = topic.image_url
      if raw.blank? && SiteSetting.generate_topic_og_image && topic.og_image_upload
        upload = topic.og_image_upload
        raw = UrlHelper.cook_url(upload.url, secure: upload.secure?)
      end
      return nil if raw.blank?
      UrlHelper.absolute(raw)
    end
  end
end
